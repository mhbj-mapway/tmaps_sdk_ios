#if canImport(CoreLocation)
import CoreLocation

extension TLatLng {
    /// `CLLocationCoordinate2D(latitude:longitude:)` — named arguments on purpose, so the
    /// (longitude, latitude) swap can't creep in.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Public bridge for apps that already hold CoreLocation values.
    public init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension CLLocationCoordinate2D {
    var tLatLng: TLatLng {
        // MapLibre can report an unset camera as (NaN, NaN); never let that trap the app.
        TLatLng(checkedLatitude: latitude, longitude: longitude) ?? TLatLng(latitude: 0, longitude: 0)
    }
}

extension Array where Element == TLatLng {
    var coordinates: [CLLocationCoordinate2D] { map(\.coordinate) }
}
#endif
