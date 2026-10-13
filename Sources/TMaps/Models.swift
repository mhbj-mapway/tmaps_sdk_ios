import Foundation

/// Built-in tmaps.tn vector styles (MapLibre style spec, tiles z0–18).
/// The API key is appended automatically by the SDK.
public enum TMapStyle {
    /// Light reference map (streets, POIs). The default.
    public static let streets = URL(string: "https://tiles.tmaps.tn/v-tile/streets.json")!
    /// Dark / night mode.
    public static let dark = URL(string: "https://tiles.tmaps.tn/v-tile/dark.json")!
    /// Relief, water, topography.
    public static let terrain = URL(string: "https://tiles.tmaps.tn/v-tile/terrain.json")!
    /// Warm palette (tourism, retail).
    public static let sunny = URL(string: "https://tiles.tmaps.tn/v-tile/sunny.json")!

    /// Every built-in style, in the order above.
    public static let all: [URL] = [streets, dark, terrain, sunny]
}

/// A geographic coordinate.
///
/// Invalid values are rejected up front, so a bad record fails here with a clear message
/// instead of deep inside the map engine. Use ``init(checkedLatitude:longitude:)`` for data
/// you don't control (a backend response, user input) to get `nil` instead of a trap.
public struct TLatLng: Hashable, Codable, CustomStringConvertible {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        precondition(Self.isValid(latitude: latitude, longitude: longitude),
                     "TLatLng: latitude must be in [-90, 90] and longitude finite, was (\(latitude), \(longitude))")
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Returns `nil` instead of trapping when the coordinate is invalid.
    public init?(checkedLatitude latitude: Double, longitude: Double) {
        guard Self.isValid(latitude: latitude, longitude: longitude) else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Poles and wrapped longitudes (e.g. 540) are fine; NaN, infinities and |lat| > 90 are not.
    public static func isValid(latitude: Double, longitude: Double) -> Bool {
        (-90.0...90.0).contains(latitude) && longitude.isFinite
    }

    // Decoding goes through the same check, so a corrupt payload can't build a bad point.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try c.decode(Double.self, forKey: .latitude)
        let lng = try c.decode(Double.self, forKey: .longitude)
        guard Self.isValid(latitude: lat, longitude: lng) else {
            throw DecodingError.dataCorruptedError(forKey: .latitude, in: c,
                                                   debugDescription: "invalid coordinate (\(lat), \(lng))")
        }
        self.latitude = lat
        self.longitude = lng
    }

    public var description: String { "TLatLng(\(latitude), \(longitude))" }

    public static let tunis = TLatLng(latitude: 36.8065, longitude: 10.1815)
    public static let sfax = TLatLng(latitude: 34.7406, longitude: 10.7603)
    public static let sousse = TLatLng(latitude: 35.8256, longitude: 10.6084)
}

/// Camera state. `zoom` 0…22, `bearing` degrees clockwise from north, `tilt` degrees 0…60.
///
/// `Codable`, so it can go straight into `@SceneStorage` / `@AppStorage` (via JSON) to bring
/// the map back where the user left it.
public struct TCameraPosition: Hashable, Codable {
    public var target: TLatLng
    public var zoom: Double
    public var bearing: Double
    public var tilt: Double

    public init(target: TLatLng, zoom: Double, bearing: Double = 0, tilt: Double = 0) {
        self.target = target
        self.zoom = zoom
        self.bearing = bearing
        self.tilt = tilt
    }
}
