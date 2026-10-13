import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import TMaps

/// The signer decides which requests carry the customer's API key, so the cases that
/// matter are the ones where it must *not* attach it.
final class RequestSignerTests: XCTestCase {

    private let options = TMapsOptions(apiKey: "ak_test")

    func testAddsTheKeyToATMapsHost() {
        XCTAssertEqual(query(send("https://tmaps.tn/v-tile/streets.json"), "api_key"), "ak_test")
    }

    func testAddsTheKeyToATMapsSubdomain() {
        XCTAssertEqual(query(send("https://tiles.tmaps.tn/v-tile/10/541/406.pbf"), "api_key"), "ak_test")
    }

    func testIdentifiesTheSdkWithAHeader() {
        let sent = send("https://tiles.tmaps.tn/v-tile/streets.json")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "X-TMaps-SDK"), "ios/\(TMaps.version)")
    }

    func testLeavesThirdPartyHostsAlone() {
        let sent = send("https://s3.amazonaws.com/elevation-tiles-prod/terrarium/11/1/1.png")
        XCTAssertNil(query(sent, "api_key"))
        XCTAssertNil(sent.value(forHTTPHeaderField: "X-TMaps-SDK"))
    }

    /// A look-alike host must not be able to harvest the key.
    func testLeavesLookAlikeHostsAlone() {
        XCTAssertNil(query(send("https://nottmaps.tn/style.json"), "api_key"))
        XCTAssertNil(query(send("https://tmaps.tn.example.com/style.json"), "api_key"))
        XCTAssertNil(query(send("https://tmaps.tnx/style.json"), "api_key"))
    }

    func testNeverSendsTheKeyOverCleartext() {
        XCTAssertNil(query(send("http://tiles.tmaps.tn/style.json"), "api_key"))
    }

    func testIdentifiesTheAppToTMapsHostsOnly() {
        let id = AppIdentity(bundleIdentifier: "com.example.app")
        let tmaps = send("https://tiles.tmaps.tn/s.json", identity: id)
        XCTAssertEqual(tmaps.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "com.example.app")
        let other = send("https://example.com/s.json", identity: id)
        XCTAssertNil(other.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"))
    }

    func testDoesNotOverwriteAKeyAlreadyOnTheURL() {
        let sent = send("https://tiles.tmaps.tn/style.json?api_key=already_there")
        XCTAssertEqual(queryValues(sent, "api_key"), ["already_there"])
    }

    func testKeepsTheExistingQueryIntact() {
        let sent = send("https://tiles.tmaps.tn/glyphs/Noto%20Sans/0-255.pbf?v=2&lang=ar")
        XCTAssertEqual(sent.url?.absoluteString,
                       "https://tiles.tmaps.tn/glyphs/Noto%20Sans/0-255.pbf?v=2&lang=ar&api_key=ak_test")
    }

    func testEncodesKeysWithReservedCharacters() {
        let sent = send("https://tiles.tmaps.tn/s.json", options: TMapsOptions(apiKey: "a+b&c=d"))
        XCTAssertEqual(query(sent, "api_key"), "a+b&c=d")
        XCTAssertEqual(queryValues(sent, "c"), [], "the key must not split into extra parameters")
    }

    func testSendsNothingWhenTheKeyIsBlank() {
        let sent = send("https://tiles.tmaps.tn/style.json", options: TMapsOptions(apiKey: "  "))
        XCTAssertNil(query(sent, "api_key"))
        XCTAssertNil(sent.value(forHTTPHeaderField: "X-TMaps-SDK"))
    }

    func testCanSendTheKeyAsAHeaderInstead() {
        let headerOnly = TMapsOptions(apiKey: "ak_test", apiKeyQueryParam: nil, apiKeyHeader: "X-Api-Key")
        let sent = send("https://tiles.tmaps.tn/style.json", options: headerOnly)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "X-Api-Key"), "ak_test")
        XCTAssertNil(query(sent, "api_key"), "the key must not leak into the url too")
    }

    func testHonoursACustomHostList() {
        let custom = TMapsOptions(apiKey: "ak_test", hosts: ["maps.example.com"])
        XCTAssertEqual(query(send("https://maps.example.com/s.json", options: custom), "api_key"), "ak_test")
        XCTAssertNil(query(send("https://tiles.tmaps.tn/s.json", options: custom), "api_key"))
    }

    // MARK: redirects (Android gets this from OkHttp's network interceptor)

    func testAKeyNeverFollowsARedirectOffHost() {
        let both = TMapsOptions(apiKey: "ak_test", apiKeyHeader: "X-Api-Key")
        let id = AppIdentity(bundleIdentifier: "com.example.app")
        let original = send("https://tiles.tmaps.tn/s.json", options: both, identity: id)

        // URLSession copies the original headers onto the redirected request.
        var hop = original
        hop.url = URL(string: "https://cdn.example.com/s.json?api_key=ak_test&v=1")
        let followed = RequestSigner.redirect(hop, options: both, identity: id)

        XCTAssertNil(query(followed, "api_key"))
        XCTAssertEqual(query(followed, "v"), "1", "unrelated parameters survive")
        XCTAssertNil(followed.value(forHTTPHeaderField: "X-Api-Key"))
        XCTAssertNil(followed.value(forHTTPHeaderField: "X-TMaps-SDK"))
        XCTAssertNil(followed.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"))
    }

    func testARedirectToCleartextIsStrippedToo() {
        var hop = send("https://tiles.tmaps.tn/s.json")
        hop.url = URL(string: "http://tiles.tmaps.tn/s.json?api_key=ak_test")
        XCTAssertNil(query(RequestSigner.redirect(hop, options: options, identity: nil), "api_key"))
    }

    func testARedirectThatStaysOnTMapsIsSigned() {
        let hop = URLRequest(url: URL(string: "https://tiles2.tmaps.tn/s.json")!)
        let followed = RequestSigner.redirect(hop, options: options, identity: nil)
        XCTAssertEqual(query(followed, "api_key"), "ak_test")
    }

    func testStrippingLeavesSomeoneElsesApiKeyAlone() {
        let hop = URLRequest(url: URL(string: "https://cdn.example.com/s.json?api_key=theirs")!)
        XCTAssertEqual(query(RequestSigner.redirect(hop, options: options, identity: nil), "api_key"), "theirs")
    }

    // MARK: helpers

    private func send(_ url: String, options: TMapsOptions? = nil, identity: AppIdentity? = nil) -> URLRequest {
        RequestSigner.sign(URLRequest(url: URL(string: url)!), options: options ?? self.options, identity: identity)
    }

    private func queryValues(_ request: URLRequest, _ name: String) -> [String] {
        guard let url = request.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [] }
        return items.filter { $0.name == name }.compactMap(\.value)
    }

    private func query(_ request: URLRequest, _ name: String) -> String? {
        queryValues(request, name).first
    }
}
