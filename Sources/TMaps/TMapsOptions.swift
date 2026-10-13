import Foundation

/// SDK configuration.
///
/// - Parameters:
///   - apiKey: your tmaps.tn API key.
///   - styleURL: default map style used by every ``TMapView``.
///   - apiKeyQueryParam: name of the query parameter the key is sent in (`nil` = don't send it as a query).
///   - apiKeyHeader: name of an HTTP header the key is sent in (`nil` = don't send it as a header).
///   - hosts: hosts that receive the key. Sub-domains are matched too (tiles.tmaps.tn, api.tmaps.tn).
public struct TMapsOptions: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public var apiKey: String
    public var styleURL: URL
    public var apiKeyQueryParam: String?
    public var apiKeyHeader: String?
    public var hosts: Set<String> {
        didSet { hostSuffixes = Self.suffixes(for: hosts) }
    }

    // Built once: this runs on every request MapLibre makes.
    private var hostSuffixes: [String]

    public init(
        apiKey: String,
        styleURL: URL = TMaps.defaultStyleURL,
        apiKeyQueryParam: String? = "api_key",
        apiKeyHeader: String? = nil,
        hosts: Set<String> = ["tmaps.tn"]
    ) {
        self.apiKey = apiKey
        self.styleURL = styleURL
        self.apiKeyQueryParam = apiKeyQueryParam
        self.apiKeyHeader = apiKeyHeader
        self.hosts = hosts
        self.hostSuffixes = Self.suffixes(for: hosts)
    }

    /// True for a configured host or any of its sub-domains — never for look-alikes such as
    /// `nottmaps.tn` or `tmaps.tn.example.com`.
    func isTMapsHost(_ host: String) -> Bool {
        let host = host.lowercased()
        return hosts.contains(host) || hostSuffixes.contains { host.hasSuffix($0) }
    }

    private static func suffixes(for hosts: Set<String>) -> [String] {
        hosts.map { "." + $0.lowercased() }
    }

    /// Keeps the key out of logs and crash reports.
    public var description: String {
        "TMapsOptions(apiKey: ***, styleURL: \(styleURL), apiKeyQueryParam: \(apiKeyQueryParam ?? "nil"), " +
            "apiKeyHeader: \(apiKeyHeader ?? "nil"), hosts: \(hosts.sorted()))"
    }

    public var debugDescription: String { description }

    // MARK: Info.plist

    /// Reads `TMapsAPIKey` (required) and `TMapsStyleURL` (optional) from the app's Info.plist.
    ///
    /// ```xml
    /// <key>TMapsAPIKey</key>
    /// <string>YOUR_KEY</string>
    /// ```
    public static func fromInfoPlist(_ bundle: Bundle = .main) throws -> TMapsOptions {
        try fromInfoDictionary(bundle.infoDictionary ?? [:])
    }

    static func fromInfoDictionary(_ info: [String: Any]) throws -> TMapsOptions {
        guard let key = (info[TMaps.infoPlistAPIKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty
        else { throw TMapsError.missingAPIKey }
        var options = TMapsOptions(apiKey: key)
        if let raw = info[TMaps.infoPlistStyleURL] as? String, !raw.isEmpty {
            guard let url = URL(string: raw) else { throw TMapsError.invalidStyleURL(raw) }
            options.styleURL = url
        }
        return options
    }
}

public enum TMapsError: Error, CustomStringConvertible, Equatable {
    case missingAPIKey
    case invalidStyleURL(String)

    public var description: String {
        switch self {
        case .missingAPIKey:
            return "Missing \(TMaps.infoPlistAPIKey) in Info.plist. Add <key>\(TMaps.infoPlistAPIKey)</key><string>YOUR_KEY</string>, " +
                "or call TMaps.initialize(apiKey:) before creating a TMapView."
        case .invalidStyleURL(let raw):
            return "\(TMaps.infoPlistStyleURL) in Info.plist is not a valid URL: \(raw)"
        }
    }
}
