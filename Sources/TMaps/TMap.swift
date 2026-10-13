#if canImport(UIKit) && canImport(MapLibre)
import UIKit
import MapLibre
import os.log

/// The map controller, obtained from ``TMapView/getMapAsync(_:)``.
/// Its API intentionally mirrors the Android SDK's `TMap` (and Google Maps' `GoogleMap`).
///
/// Use it from the main thread only.
@MainActor
public final class TMap {

    /// Street-level zoom ``showStatic(_:zoom:)`` uses when you don't pass one.
    nonisolated public static let defaultStaticZoom: Double = 15

    let mapView: MLNMapView
    public let uiSettings: TUiSettings

    // Keyed by the MapLibre object, so delegate callbacks find their TMaps wrapper.
    private var markers: [ObjectIdentifier: TMarker] = [:]
    private var polylines: [ObjectIdentifier: TPolyline] = [:]
    private var polygons: [ObjectIdentifier: TPolygon] = [:]
    // One MLNAnnotationImage per UIImage: a fresh one each time would upload an image per marker.
    private var annotationImages: [ObjectIdentifier: MLNAnnotationImage] = [:]

    private var mapClickListener: ((TLatLng) -> Void)?
    private var mapLongClickListener: ((TLatLng) -> Void)?
    private var markerClickListener: ((TMarker) -> Bool)?
    private var cameraIdleListener: ((TCameraPosition) -> Void)?

    private var styleLoadedCallbacks: [() -> Void] = []
    private var cameraBounds: MLNCoordinateBounds?
    private var interactive = true
    private var selectingFromCode = false
    /// The marker whose click listener already ran for the tap being processed, and its answer.
    private var clickInFlight: (annotation: ObjectIdentifier, consumed: Bool)?
    private var nextImageID = 0
    /// A camera set before the view had a size; MapLibre needs the size to honour a tilt.
    private var pendingCamera: TCameraPosition?

    init(mapView: MLNMapView) {
        self.mapView = mapView
        self.uiSettings = TUiSettings(mapView: mapView)
        mapView.showsLogoView = false
    }

    // MARK: - style

    /// Switch style at runtime (e.g. dark mode). Markers and shapes are kept.
    public func setStyleURL(_ url: URL, onLoaded: (() -> Void)? = nil) {
        if let onLoaded { styleLoadedCallbacks.append(onLoaded) }
        mapView.styleURL = url
    }

    func styleDidLoad() {
        let callbacks = styleLoadedCallbacks
        styleLoadedCallbacks.removeAll()
        callbacks.forEach { $0() }
    }

    // MARK: - camera

    public var cameraPosition: TCameraPosition {
        TCameraPosition(
            target: mapView.centerCoordinate.tLatLng,
            zoom: mapView.zoomLevel,
            bearing: mapView.direction,
            tilt: Double(mapView.camera.pitch)
        )
    }

    /// Centre on `target` at `zoom`, keeping the current bearing and tilt.
    public func moveCamera(_ target: TLatLng, zoom: Double) {
        pendingCamera = nil
        mapView.setCenter(target.coordinate, zoomLevel: zoom, animated: false)
    }

    public func moveCamera(_ position: TCameraPosition) {
        guard let camera = makeCamera(position) else {
            // No size yet: place it now without the tilt, then re-apply once laid out.
            pendingCamera = position
            mapView.setCenter(position.target.coordinate, zoomLevel: position.zoom,
                              direction: position.bearing, animated: false)
            return
        }
        pendingCamera = nil
        mapView.setCamera(camera, animated: false)
    }

    /// Animate to `target` at `zoom`, keeping the current bearing and tilt.
    public func animateCamera(_ target: TLatLng, zoom: Double, duration: TimeInterval = 1) {
        let current = cameraPosition
        animateCamera(TCameraPosition(target: target, zoom: zoom, bearing: current.bearing, tilt: current.tilt),
                      duration: duration)
    }

    public func animateCamera(_ position: TCameraPosition, duration: TimeInterval = 1) {
        guard let camera = makeCamera(position) else { return moveCamera(position) }
        pendingCamera = nil
        mapView.setCamera(camera, withDuration: duration,
                          animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut),
                          completionHandler: nil)
    }

    /// Fit the camera so all `points` are visible, with `padding` points around the edges.
    public func fitBounds(_ points: [TLatLng], padding: CGFloat = 32, animated: Bool = true) {
        guard let first = points.first else { return }
        if points.count == 1 { return moveCamera(first, zoom: 15) }
        let lats = points.map(\.latitude), lngs = points.map(\.longitude)
        let bounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: lats.min()!, longitude: lngs.min()!),
            ne: CLLocationCoordinate2D(latitude: lats.max()!, longitude: lngs.max()!)
        )
        let insets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        pendingCamera = nil
        mapView.setVisibleCoordinateBounds(bounds, edgePadding: insets, animated: animated, completionHandler: nil)
    }

    public func setMinZoom(_ zoom: Double) { mapView.minimumZoomLevel = zoom }
    public func setMaxZoom(_ zoom: Double) { mapView.maximumZoomLevel = zoom }

    /// Keep the camera target inside a region while the user pans (e.g. Tunisia).
    /// Pass `nil` to remove. Camera moves made from code are not constrained.
    public func setCameraBounds(southWest: TLatLng?, northEast: TLatLng?) {
        guard let sw = southWest, let ne = northEast else { cameraBounds = nil; return }
        cameraBounds = MLNCoordinateBounds(sw: sw.coordinate, ne: ne.coordinate)
    }

    func shouldChangeCamera(from old: MLNMapCamera, to new: MLNMapCamera) -> Bool {
        guard let bounds = cameraBounds else { return true }
        // Already outside (bounds set while elsewhere): let the user pan back instead of freezing.
        return MLNCoordinateInCoordinateBounds(new.centerCoordinate, bounds)
            || !MLNCoordinateInCoordinateBounds(old.centerCoordinate, bounds)
    }

    func viewDidLayout() {
        guard let pending = pendingCamera, makeCamera(pending) != nil else { return }
        moveCamera(pending)
    }

    /// `nil` while the view has no size: zoom ↔ altitude depends on the viewport.
    private func makeCamera(_ position: TCameraPosition) -> MLNMapCamera? {
        let size = mapView.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        let pitch = CGFloat(position.tilt)
        let altitude = MLNAltitudeForZoomLevel(position.zoom, pitch, position.target.latitude, size)
        return MLNMapCamera(lookingAtCenter: position.target.coordinate,
                            altitude: altitude, pitch: pitch, heading: position.bearing)
    }

    // MARK: - still (photo) mode

    /// Whether the user can move the map.
    ///
    /// `false` turns it into a still picture: every gesture is off, the compass is hidden, and
    /// tapping a marker no longer opens its callout. The camera can still be moved from code,
    /// and the listeners you registered keep firing — so a still map can stay tappable, for
    /// instance to open a full-screen one.
    ///
    /// Attribution stays visible either way: it is an ODbL requirement, not a control.
    ///
    /// Setting this back to `true` re-enables *all* gestures, not the subset you may have
    /// configured through ``uiSettings`` beforehand.
    public var isInteractive: Bool {
        get { interactive }
        set {
            interactive = newValue
            uiSettings.setAllGesturesEnabled(newValue)
            uiSettings.isCompassEnabled = newValue
            if !newValue {
                mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: false) }
            }
        }
    }

    /// Shows `position` as a still picture: centres the camera there at `zoom`, drops a pin and
    /// switches ``isInteractive`` off, so the map reads as an image (Google Maps' lite mode).
    ///
    /// ```swift
    /// map.showStatic(.tunis, zoom: 16)                 // pin at the centre
    /// map.showStatic(.tunis, zoom: 16, marker: nil)    // no pin
    /// ```
    ///
    /// Existing markers and shapes are left alone; call ``clear()`` first if you want only the
    /// pin. Map tap listeners stay in place too — clear them as well if the picture has to be
    /// completely inert.
    ///
    /// - Returns: the pin.
    @discardableResult
    public func showStatic(_ position: TLatLng, zoom: Double = TMap.defaultStaticZoom) -> TMarker? {
        showStatic(TCameraPosition(target: position, zoom: zoom))
    }

    /// ``showStatic(_:zoom:)`` with your own pin. Pass `nil` for a still map without one.
    @discardableResult
    public func showStatic(_ position: TLatLng, zoom: Double = TMap.defaultStaticZoom,
                           marker: TMarkerOptions?) -> TMarker? {
        showStatic(TCameraPosition(target: position, zoom: zoom), marker: marker)
    }

    /// ``showStatic(_:zoom:)`` with a full camera, for a still shot with bearing or tilt.
    @discardableResult
    public func showStatic(_ camera: TCameraPosition) -> TMarker? {
        showStatic(camera, marker: TMarkerOptions(position: camera.target))
    }

    /// Full-camera still shot with your own pin, or none (`nil`).
    @discardableResult
    public func showStatic(_ camera: TCameraPosition, marker: TMarkerOptions?) -> TMarker? {
        isInteractive = false
        moveCamera(camera)
        return marker.map { addMarker($0) }
    }

    // MARK: - markers & shapes

    @discardableResult
    public func addMarker(_ options: TMarkerOptions) -> TMarker {
        let marker = TMarker(options: options, map: self)
        markers[ObjectIdentifier(marker.annotation)] = marker
        mapView.addAnnotation(marker.annotation)
        return marker
    }

    @discardableResult
    public func addMarker(_ position: TLatLng, title: String? = nil) -> TMarker {
        addMarker(TMarkerOptions(position: position, title: title))
    }

    func removeMarker(_ marker: TMarker) {
        markers[ObjectIdentifier(marker.annotation)] = nil
        mapView.removeAnnotation(marker.annotation)
    }

    @discardableResult
    public func addPolyline(_ options: TPolylineOptions) -> TPolyline {
        let line = TPolyline(options: options, map: self)
        polylines[ObjectIdentifier(line.shape)] = line
        mapView.addAnnotation(line.shape)
        return line
    }

    func removePolyline(_ line: TPolyline) {
        polylines[ObjectIdentifier(line.shape)] = nil
        mapView.removeAnnotation(line.shape)
    }

    @discardableResult
    public func addPolygon(_ options: TPolygonOptions) -> TPolygon {
        let polygon = TPolygon(options: options, map: self)
        polygons[ObjectIdentifier(polygon.shape)] = polygon
        mapView.addAnnotation(polygon.shape)
        return polygon
    }

    func removePolygon(_ polygon: TPolygon) {
        polygons[ObjectIdentifier(polygon.shape)] = nil
        mapView.removeAnnotation(polygon.shape)
    }

    /// Remove all markers, polylines and polygons.
    public func clear() {
        let all: [MLNAnnotation] = markers.values.map(\.annotation)
            + polylines.values.map(\.shape) + polygons.values.map(\.shape)
        mapView.removeAnnotations(all)
        markers.removeAll()
        polylines.removeAll()
        polygons.removeAll()
        annotationImages.removeAll()
    }

    func showInfoWindow(for marker: TMarker) {
        selectingFromCode = true
        defer { selectingFromCode = false }
        mapView.selectAnnotation(marker.annotation, animated: true, completionHandler: nil)
    }

    func hideInfoWindow(for marker: TMarker) {
        mapView.deselectAnnotation(marker.annotation, animated: true)
    }

    // MARK: - listeners
    //
    // The map keeps its listeners. Capture the map weakly inside them (`[weak map]`), or the
    // closure and the map keep each other — and the GPU surface — alive.

    public func setOnMapClickListener(_ listener: ((TLatLng) -> Void)?) { mapClickListener = listener }
    public func setOnMapLongClickListener(_ listener: ((TLatLng) -> Void)?) { mapLongClickListener = listener }
    /// Return `true` to consume the tap (no callout).
    public func setOnMarkerClickListener(_ listener: ((TMarker) -> Bool)?) { markerClickListener = listener }
    /// Called when the camera settles after any move (gesture, animation or code).
    public func setOnCameraIdleListener(_ listener: ((TCameraPosition) -> Void)?) { cameraIdleListener = listener }

    // MARK: - my location

    /// Show the user's location (blue dot, with heading).
    ///
    /// MapLibre asks for "when in use" permission the first time. That requires
    /// `NSLocationWhenInUseUsageDescription` in Info.plist; without it this does nothing
    /// (MapLibre would otherwise raise an exception), and a warning is logged.
    public func setMyLocationEnabled(_ enabled: Bool) {
        if enabled, !Self.hasLocationUsageDescription {
            os_log("TMaps: add NSLocationWhenInUseUsageDescription to Info.plist to show the user's location.",
                   type: .error)
            return
        }
        mapView.showsUserLocation = enabled
        if enabled { mapView.showsUserHeadingIndicator = true }
    }

    /// Follow the user's location with the camera (requires ``setMyLocationEnabled(_:)``).
    /// Panning the map stops following, as in Apple Maps.
    public func followMyLocation(_ follow: Bool) {
        guard mapView.showsUserLocation else { return }
        mapView.userTrackingMode = follow ? .follow : .none
    }

    /// Last known user location, or `nil`.
    public var myLocation: TLatLng? {
        guard mapView.showsUserLocation, let location = mapView.userLocation?.location else { return nil }
        return TLatLng(checkedLatitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    private static var hasLocationUsageDescription: Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        return info["NSLocationWhenInUseUsageDescription"] != nil
            || info["NSLocationAlwaysAndWhenInUseUsageDescription"] != nil
    }

    // MARK: - events from MapEventProxy

    func handleTap(at point: CGPoint) {
        // MapLibre handles taps on markers itself (selection → callout → didSelect); a map
        // click is a tap on the map *around* them, as on Android.
        if let marker = marker(at: point) {
            // Tapping the selected marker again only deselects it in MapLibre; Android still
            // reports the click, so report it here.
            if mapView.selectedAnnotations.contains(where: { $0 === marker.annotation }) {
                _ = markerClickListener?(marker)
            }
            return
        }
        mapClickListener?(mapView.convert(point, toCoordinateFrom: mapView).tLatLng)
    }

    func handleLongPress(at point: CGPoint) {
        mapLongClickListener?(mapView.convert(point, toCoordinateFrom: mapView).tLatLng)
    }

    func cameraDidBecomeIdle() {
        cameraIdleListener?(cameraPosition)
    }

    /// Asked by MapLibre while it selects a marker that has a title, *before* it builds the
    /// callout and pans it into view — so this is where the click listener runs: a consumed
    /// tap, or a still map, then gets no callout and no camera move.
    func canShowCallout(for annotation: MLNAnnotation) -> Bool {
        guard let marker = marker(for: annotation) else { return false }
        if selectingFromCode { return true } // showInfoWindow() works on a still map too
        let consumed = markerClickListener?(marker) ?? false
        clickInFlight = (ObjectIdentifier(annotation), consumed)
        return interactive && !consumed
    }

    func didSelect(_ annotation: MLNAnnotation) {
        guard !selectingFromCode, let marker = marker(for: annotation) else { return }
        let id = ObjectIdentifier(annotation)
        let consumed: Bool
        if let inFlight = clickInFlight, inFlight.annotation == id {
            consumed = inFlight.consumed
        } else {
            // Markers without a title never reach canShowCallout.
            consumed = markerClickListener?(marker) ?? false
        }
        clickInFlight = nil
        // Keep the marker unselected after a consumed tap or on a still map, so the next tap
        // on it is a fresh click rather than a deselect.
        if consumed || !interactive {
            mapView.deselectAnnotation(annotation, animated: false)
        }
    }

    func marker(for annotation: MLNAnnotation) -> TMarker? {
        markers[ObjectIdentifier(annotation)]
    }

    func annotationImage(for annotation: MLNAnnotation) -> MLNAnnotationImage? {
        guard let icon = marker(for: annotation)?.icon else { return nil } // default pin
        let key = ObjectIdentifier(icon)
        if let image = annotationImages[key] { return image }
        // Never reuse an identifier: MapLibre keeps the first sprite installed under one.
        nextImageID += 1
        let image = MLNAnnotationImage(image: icon, reuseIdentifier: "tmaps-icon-\(nextImageID)")
        annotationImages[key] = image
        return image
    }

    func strokeColor(for shape: MLNShape) -> UIColor {
        polylines[ObjectIdentifier(shape)]?.color ?? polygons[ObjectIdentifier(shape)]?.strokeColor ?? .tmapsBlue
    }

    func fillColor(for polygon: MLNPolygon) -> UIColor {
        polygons[ObjectIdentifier(polygon)]?.fillColor ?? UIColor.tmapsBlue.withAlphaComponent(64.0 / 255.0)
    }

    func lineWidth(for polyline: MLNPolyline) -> CGFloat {
        polylines[ObjectIdentifier(polyline)]?.width ?? 4
    }

    /// MapLibre's own hit test: the marker image centred on its coordinate, minus the image's
    /// alignment-rect insets, plus 5 pt of slop (MLNMapView frameOfImage / hit-test padding).
    private func marker(at point: CGPoint) -> TMarker? {
        markers.values.first { marker in
            let center = mapView.convert(marker.annotation.coordinate, toPointTo: mapView)
            let size = marker.icon?.size ?? Self.defaultPinSize
            // MapLibre's default pin rises from the centre: only its top half is tappable.
            let insets = marker.icon?.alignmentRectInsets
                ?? UIEdgeInsets(top: 0, left: 0, bottom: size.height / 2, right: 0)
            let frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                               width: size.width, height: size.height)
            return frame.inset(by: insets).insetBy(dx: -5, dy: -5).contains(point)
        }
    }

    /// Size of MapLibre's built-in pin ("default_marker" in its framework bundle).
    private static let defaultPinSize: CGSize =
        UIImage(named: "default_marker", in: Bundle(for: MLNMapView.self), compatibleWith: nil)?.size
            ?? CGSize(width: 32, height: 40)
}
#endif
