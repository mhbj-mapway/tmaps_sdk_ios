#if canImport(UIKit) && canImport(MapLibre)
import UIKit
import MapLibre

/// Every delegate method carries its Objective-C selector explicitly: MapLibre's delegate
/// methods are optional, so a Swift-name mismatch would otherwise compile and never be called.
///
/// MapLibre's delegate and the SDK's gesture target, kept internal so the public types expose
/// no MapLibre API. Forwards everything to the view (style loading) and the ``TMap``.
@MainActor
final class MapEventProxy: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {

    weak var map: TMap?
    var onStyleLoaded: (() -> Void)?
    var onLoadFailed: ((Error) -> Void)?

    /// Adds tap and long-press recognizers that run alongside MapLibre's own gestures.
    func attachGestures(to mapView: MLNMapView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tap.delegate = self
        longPress.delegate = self
        // Wait for MapLibre's double tap and tap-then-hold quick zoom to fail, so zooming
        // isn't also a map click (MapLibre's own single tap waits for the same two).
        for recognizer in mapView.gestureRecognizers ?? [] {
            if let other = recognizer as? UITapGestureRecognizer, other.numberOfTapsRequired > 1 {
                tap.require(toFail: other)
            } else if let other = recognizer as? UILongPressGestureRecognizer, other.numberOfTapsRequired >= 1 {
                tap.require(toFail: other)
            }
        }
        mapView.addGestureRecognizer(tap)
        mapView.addGestureRecognizer(longPress)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let view = recognizer.view else { return }
        map?.handleTap(at: recognizer.location(in: view))
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let view = recognizer.view else { return }
        map?.handleLongPress(at: recognizer.location(in: view))
    }

    /// Touches on a callout or an ornament (compass, attribution button) are not map taps.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view, current !== gestureRecognizer.view {
            if current is UIControl || current is MLNCompassButton || current is MLNCalloutView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    // MARK: loading

    @objc(mapView:didFinishLoadingStyle:)
    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        onStyleLoaded?()
    }

    @objc(mapViewDidFailLoadingMap:withError:)
    func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
        onLoadFailed?(error)
    }

    // MARK: camera

    /// After every camera change settles — not `mapViewDidBecomeIdle`, which also fires when
    /// tiles finish loading and so isn't Android's `onCameraIdle`.
    @objc(mapView:regionDidChangeAnimated:)
    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        map?.cameraDidBecomeIdle()
    }

    @objc(mapView:shouldChangeFromCamera:toCamera:)
    func mapView(_ mapView: MLNMapView, shouldChangeFrom oldCamera: MLNMapCamera, to newCamera: MLNMapCamera) -> Bool {
        map?.shouldChangeCamera(from: oldCamera, to: newCamera) ?? true
    }

    // MARK: annotations

    @objc(mapView:imageForAnnotation:)
    func mapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage? {
        map?.annotationImage(for: annotation)
    }

    @objc(mapView:annotationCanShowCallout:)
    func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
        map?.canShowCallout(for: annotation) ?? false
    }

    @objc(mapView:didSelectAnnotation:)
    func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
        map?.didSelect(annotation)
    }

    /// Lines and polygons are drawings, not buttons (as on Android).
    @objc(mapView:shapeAnnotationIsEnabled:)
    func mapView(_ mapView: MLNMapView, shapeAnnotationIsEnabled annotation: MLNShape) -> Bool {
        false
    }

    @objc(mapView:strokeColorForShapeAnnotation:)
    func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
        map?.strokeColor(for: annotation) ?? .tmapsBlue
    }

    @objc(mapView:fillColorForPolygonAnnotation:)
    func mapView(_ mapView: MLNMapView, fillColorForPolygonAnnotation annotation: MLNPolygon) -> UIColor {
        map?.fillColor(for: annotation) ?? UIColor.tmapsBlue.withAlphaComponent(64.0 / 255.0)
    }

    @objc(mapView:lineWidthForPolylineAnnotation:)
    func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat {
        map?.lineWidth(for: annotation) ?? 4
    }
}
#endif
