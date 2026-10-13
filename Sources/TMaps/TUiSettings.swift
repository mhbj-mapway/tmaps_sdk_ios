#if canImport(UIKit) && canImport(MapLibre)
import UIKit
import MapLibre

/// Gesture and on-map control settings. Get it from ``TMap/uiSettings``.
@MainActor
public final class TUiSettings {
    private unowned let mapView: MLNMapView

    init(mapView: MLNMapView) { self.mapView = mapView }

    /// Pinch, double-tap, two-finger tap and one-finger quick zoom.
    public var isZoomGesturesEnabled: Bool {
        get { mapView.isZoomEnabled }
        set { mapView.isZoomEnabled = newValue }
    }

    public var isScrollGesturesEnabled: Bool {
        get { mapView.isScrollEnabled }
        set { mapView.isScrollEnabled = newValue }
    }

    public var isRotateGesturesEnabled: Bool {
        get { mapView.isRotateEnabled }
        set { mapView.isRotateEnabled = newValue }
    }

    public var isTiltGesturesEnabled: Bool {
        get { mapView.isPitchEnabled }
        set { mapView.isPitchEnabled = newValue }
    }

    /// The compass appears while the map is rotated away from north; tap it to reset.
    public var isCompassEnabled: Bool {
        get { mapView.showsCompassView }
        set { mapView.showsCompassView = newValue }
    }

    /// Keep attribution visible if your tiles contain OpenStreetMap data (ODbL requirement).
    public var isAttributionEnabled: Bool {
        get { mapView.showsAttributionButton }
        set { mapView.showsAttributionButton = newValue }
    }

    public func setAllGesturesEnabled(_ enabled: Bool) {
        isZoomGesturesEnabled = enabled
        isScrollGesturesEnabled = enabled
        isRotateGesturesEnabled = enabled
        isTiltGesturesEnabled = enabled
    }
}
#endif
