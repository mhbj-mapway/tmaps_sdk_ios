import XCTest
@testable import TMaps

/// Guards the classic mistakes: (longitude, latitude) the wrong way round, and bad
/// coordinates reaching the map engine.
final class ModelsTests: XCTestCase {

    func testLatitudeAndLongitudeKeepTheirPlaces() {
        let p = TLatLng(latitude: 36.8065, longitude: 10.1815)
        XCTAssertEqual(p.latitude, 36.8065, accuracy: 1e-9)
        XCTAssertEqual(p.longitude, 10.1815, accuracy: 1e-9)
    }

    func testRejectsCoordinatesTheMapEngineWouldChokeOn() {
        let bad: [(Double, Double)] = [(91, 0), (-91, 0), (.nan, 0), (0, .nan), (0, .infinity)]
        for (lat, lng) in bad {
            XCTAssertNil(TLatLng(checkedLatitude: lat, longitude: lng), "accepted (\(lat), \(lng))")
            XCTAssertFalse(TLatLng.isValid(latitude: lat, longitude: lng))
        }
        // Poles and wrapped longitudes are fine.
        XCTAssertNotNil(TLatLng(checkedLatitude: 90, longitude: 540))
    }

    func testDecodingRejectsCorruptCoordinates() {
        let bad = Data(#"{"latitude": 120, "longitude": 10}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(TLatLng.self, from: bad))
    }

    func testCameraRoundTripsThroughJSON() throws {
        let camera = TCameraPosition(target: .sfax, zoom: 13.5, bearing: 30, tilt: 45)
        let data = try JSONEncoder().encode(camera)
        XCTAssertEqual(try JSONDecoder().decode(TCameraPosition.self, from: data), camera)
    }

    func testCameraDefaultsToNorthUpAndFlat() {
        let camera = TCameraPosition(target: .tunis, zoom: 12)
        XCTAssertEqual(camera.bearing, 0)
        XCTAssertEqual(camera.tilt, 0)
    }

    func testCitiesAreInTunisia() {
        for city in [TLatLng.tunis, .sousse, .sfax] {
            XCTAssertTrue((30.0...38.0).contains(city.latitude))
            XCTAssertTrue((7.0...12.0).contains(city.longitude))
        }
    }
}
