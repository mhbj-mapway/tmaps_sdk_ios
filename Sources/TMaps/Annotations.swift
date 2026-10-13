#if canImport(UIKit) && canImport(MapLibre)
import UIKit
import MapLibre

/// A pin on the map, returned by ``TMap/addMarker(_:)``.
@MainActor
public final class TMarker {
    let annotation: MLNPointAnnotation
    let icon: UIImage?
    private weak var map: TMap?

    init(options: TMarkerOptions, map: TMap) {
        let annotation = MLNPointAnnotation()
        annotation.coordinate = options.position.coordinate
        annotation.title = options.title
        annotation.subtitle = options.snippet
        self.annotation = annotation
        self.icon = options.icon
        self.map = map
    }

    /// Moving a marker is live: MapLibre observes the coordinate.
    public var position: TLatLng {
        get { annotation.coordinate.tLatLng }
        set { annotation.coordinate = newValue.coordinate }
    }

    public var title: String? {
        get { annotation.title }
        set { annotation.title = newValue }
    }

    public var snippet: String? {
        get { annotation.subtitle }
        set { annotation.subtitle = newValue }
    }

    /// Free slot for app data.
    public var tag: Any?

    /// Opens the callout (title + snippet). Works on a still map too.
    public func showInfoWindow() { map?.showInfoWindow(for: self) }
    public func hideInfoWindow() { map?.hideInfoWindow(for: self) }
    public func remove() { map?.removeMarker(self) }
}

@MainActor
public final class TPolyline {
    let shape: MLNPolyline
    let color: UIColor
    let width: CGFloat
    private weak var map: TMap?

    init(options: TPolylineOptions, map: TMap) {
        var coords = options.points.coordinates
        shape = MLNPolyline(coordinates: &coords, count: UInt(coords.count))
        color = options.color
        width = options.width
        self.map = map
    }

    public var points: [TLatLng] {
        get { shape.tPoints }
        set {
            var coords = newValue.coordinates
            shape.setCoordinates(&coords, count: UInt(coords.count))
        }
    }

    public func remove() { map?.removePolyline(self) }
}

@MainActor
public final class TPolygon {
    let shape: MLNPolygon
    let fillColor: UIColor
    let strokeColor: UIColor
    private weak var map: TMap?

    init(options: TPolygonOptions, map: TMap) {
        var coords = options.points.coordinates
        shape = MLNPolygon(coordinates: &coords, count: UInt(coords.count))
        fillColor = options.fillColor
        strokeColor = options.strokeColor
        self.map = map
    }

    public var points: [TLatLng] {
        get { shape.tPoints }
        set {
            var coords = newValue.coordinates
            shape.setCoordinates(&coords, count: UInt(coords.count))
        }
    }

    public func remove() { map?.removePolygon(self) }
}

extension MLNMultiPoint {
    var tPoints: [TLatLng] {
        let count = Int(pointCount)
        guard count > 0 else { return [] }
        return UnsafeBufferPointer(start: coordinates, count: count).map(\.tLatLng)
    }
}
#endif
