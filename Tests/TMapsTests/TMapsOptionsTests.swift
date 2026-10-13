import XCTest
@testable import TMaps

final class TMapsOptionsTests: XCTestCase {

    func testDefaultsMatchTheDocumentedContract() {
        let options = TMapsOptions(apiKey: "ak_test")
        XCTAssertEqual(options.styleURL, TMapStyle.streets)
        XCTAssertEqual(options.apiKeyQueryParam, "api_key")
        XCTAssertNil(options.apiKeyHeader)
        XCTAssertEqual(options.hosts, ["tmaps.tn"])
    }

    func testMatchesTheHostAndItsSubdomains() {
        let options = TMapsOptions(apiKey: "ak_test")
        XCTAssertTrue(options.isTMapsHost("tmaps.tn"))
        XCTAssertTrue(options.isTMapsHost("tiles.tmaps.tn"))
        XCTAssertTrue(options.isTMapsHost("api.staging.tmaps.tn"))
        XCTAssertTrue(options.isTMapsHost("Tiles.TMaps.tn"), "hosts are case-insensitive")
    }

    func testDoesNotMatchHostsThatMerelyEndInTheSameLetters() {
        let options = TMapsOptions(apiKey: "ak_test")
        XCTAssertFalse(options.isTMapsHost("nottmaps.tn"))
        XCTAssertFalse(options.isTMapsHost("tmaps.tn.example.com"))
        XCTAssertFalse(options.isTMapsHost("tmaps.tnx"))
        XCTAssertFalse(options.isTMapsHost("example.com"))
    }

    func testChangingHostsUpdatesMatching() {
        var options = TMapsOptions(apiKey: "ak_test")
        options.hosts = ["maps.example.com"]
        XCTAssertTrue(options.isTMapsHost("a.maps.example.com"))
        XCTAssertFalse(options.isTMapsHost("tiles.tmaps.tn"))
    }

    func testEveryBuiltInStyleIsATMapsURL() {
        let options = TMapsOptions(apiKey: "ak_test")
        XCTAssertEqual(TMapStyle.all.count, 4)
        for url in TMapStyle.all {
            XCTAssertEqual(url.scheme, "https")
            XCTAssertTrue(options.isTMapsHost(url.host ?? ""), "\(url) is not covered by the request signer")
        }
    }

    func testOptionsNeverPrintTheKey() {
        let options = TMapsOptions(apiKey: "ak_secret")
        XCTAssertFalse(options.description.contains("ak_secret"))
        XCTAssertFalse(String(describing: options).contains("ak_secret"))
        XCTAssertFalse(String(reflecting: options).contains("ak_secret"))
        XCTAssertFalse("\(options)".contains("ak_secret"))
    }

    // MARK: Info.plist

    func testReadsTheKeyAndStyleFromInfoPlist() throws {
        let options = try TMapsOptions.fromInfoDictionary([
            "TMapsAPIKey": " ak_plist ",
            "TMapsStyleURL": "https://tiles.tmaps.tn/v-tile/dark.json",
        ])
        XCTAssertEqual(options.apiKey, "ak_plist")
        XCTAssertEqual(options.styleURL, TMapStyle.dark)
    }

    func testStyleDefaultsToStreetsWhenThePlistHasNone() throws {
        let options = try TMapsOptions.fromInfoDictionary(["TMapsAPIKey": "ak_plist"])
        XCTAssertEqual(options.styleURL, TMapStyle.streets)
    }

    func testMissingOrBlankKeyIsAClearError() {
        XCTAssertThrowsError(try TMapsOptions.fromInfoDictionary([:])) {
            XCTAssertEqual($0 as? TMapsError, .missingAPIKey)
        }
        XCTAssertThrowsError(try TMapsOptions.fromInfoDictionary(["TMapsAPIKey": "   "])) {
            XCTAssertEqual($0 as? TMapsError, .missingAPIKey)
        }
        XCTAssertTrue(TMapsError.missingAPIKey.description.contains("TMapsAPIKey"))
    }

    // MARK: TMaps

    func testInitializeStoresTheLastOptions() {
        TMaps.reset()
        XCTAssertFalse(TMaps.isInitialized)
        TMaps.initialize(apiKey: "ak_one")
        TMaps.initialize(options: TMapsOptions(apiKey: "ak_two", styleURL: TMapStyle.sunny))
        XCTAssertTrue(TMaps.isInitialized)
        XCTAssertEqual(TMaps.config.apiKey, "ak_two")
        XCTAssertEqual(TMaps.config.styleURL, TMapStyle.sunny)
        TMaps.reset()
    }
}
