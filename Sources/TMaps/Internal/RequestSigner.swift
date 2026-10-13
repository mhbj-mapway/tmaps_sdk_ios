import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The calling app's identity, so the server can restrict a key to one app
/// (Google's `X-Ios-Bundle-Identifier` convention).
struct AppIdentity: Equatable {
    let bundleIdentifier: String

    static var current: AppIdentity? {
        Bundle.main.bundleIdentifier.map(AppIdentity.init(bundleIdentifier:))
    }
}

/// Adds the TMaps API key to requests going to a tmaps.tn host (style, tiles, sprites, glyphs),
/// plus the SDK and app identity headers — and makes sure none of it follows a redirect off-host.
///
/// iOS counterpart of the Android `ApiKeyInterceptor`; kept free of UIKit/MapLibre so it is
/// unit-tested on every platform.
enum RequestSigner {
    static let sdkHeader = "X-TMaps-SDK"
    static let bundleHeader = "X-Ios-Bundle-Identifier"
    static var sdkHeaderValue: String { "ios/\(TMaps.version)" }

    /// The request as it should leave the device.
    static func sign(_ request: URLRequest, options: TMapsOptions, identity: AppIdentity?) -> URLRequest {
        guard shouldSign(request.url, options: options), let url = request.url else { return request }

        var signed = request
        signed.setValue(sdkHeaderValue, forHTTPHeaderField: sdkHeader)
        if let identity {
            signed.setValue(identity.bundleIdentifier, forHTTPHeaderField: bundleHeader)
        }
        if let param = options.apiKeyQueryParam {
            signed.url = adding(param: param, value: options.apiKey, to: url)
        }
        if let header = options.apiKeyHeader {
            signed.setValue(options.apiKey, forHTTPHeaderField: header)
        }
        return signed
    }

    /// The request URLSession is about to follow after a redirect. URLSession copies the
    /// original headers and the redirect may point anywhere, so: re-sign when it stays on a
    /// tmaps host over HTTPS, otherwise strip everything the SDK added.
    static func redirect(_ request: URLRequest, options: TMapsOptions, identity: AppIdentity?) -> URLRequest {
        if shouldSign(request.url, options: options) {
            return sign(request, options: options, identity: identity)
        }
        var clean = request
        clean.setValue(nil, forHTTPHeaderField: sdkHeader)
        clean.setValue(nil, forHTTPHeaderField: bundleHeader)
        if let header = options.apiKeyHeader {
            clean.setValue(nil, forHTTPHeaderField: header)
        }
        if let param = options.apiKeyQueryParam, let url = request.url, !options.apiKey.isEmpty {
            clean.url = removing(param: param, value: options.apiKey, from: url)
        }
        return clean
    }

    /// Never over cleartext (the key would be readable on the wire), never to other hosts.
    static func shouldSign(_ url: URL?, options: TMapsOptions) -> Bool {
        guard let url,
              !options.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              url.scheme?.lowercased() == "https",
              let host = url.host
        else { return false }
        return options.isTMapsHost(host)
    }

    // MARK: - query helpers

    /// Appends `param=value` unless the URL already carries that parameter. Works on the
    /// percent-encoded query so the rest of the URL is left byte-for-byte as MapLibre built it.
    static func adding(param: String, value: String, to url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        if comps.queryItems?.contains(where: { $0.name == param }) == true { return url }
        let pair = encode(param) + "=" + encode(value)
        if let q = comps.percentEncodedQuery, !q.isEmpty {
            comps.percentEncodedQuery = q + "&" + pair
        } else {
            comps.percentEncodedQuery = pair
        }
        return comps.url ?? url
    }

    /// Drops `param=value` pairs, keeping every other pair exactly as it was encoded.
    static func removing(param: String, value: String, from url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = comps.percentEncodedQuery else { return url }
        let kept = query.split(separator: "&", omittingEmptySubsequences: false).filter { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let val = parts.count > 1 ? (String(parts[1]).removingPercentEncoding ?? String(parts[1])) : ""
            return !(name == param && val == value)
        }
        comps.percentEncodedQuery = kept.isEmpty ? nil : kept.joined(separator: "&")
        return comps.url ?? url
    }

    private static let queryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+?#/")
        return set
    }()

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) ?? s
    }
}
