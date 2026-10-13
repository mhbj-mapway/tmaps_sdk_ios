import Foundation

/// Entry point of the TMaps SDK.
///
/// Call ``initialize(apiKey:)`` (or ``initialize(options:)``) once, typically in
/// `application(_:didFinishLaunchingWithOptions:)` or your SwiftUI `App.init()`. If you
/// don't, the first ``TMapView`` initialises the SDK from the Info.plist keys
/// `TMapsAPIKey` (and optional `TMapsStyleURL`).
public enum TMaps {

    /// SDK version, e.g. "0.2.0". Sent to tmaps.tn as `X-TMaps-SDK: ios/<version>`.
    public static let version = "0.2.0"

    /// Default tmaps.tn style (streets). See ``TMapStyle`` for the others.
    public static let defaultStyleURL: URL = TMapStyle.streets

    /// Info.plist key holding the API key.
    public static let infoPlistAPIKey = "TMapsAPIKey"
    /// Info.plist key holding an optional default style URL.
    public static let infoPlistStyleURL = "TMapsStyleURL"

    // Read on MapLibre's network threads, written from the main thread.
    private static let lock = NSLock()
    private static var storedOptions: TMapsOptions?
    private static var storedIdentity: AppIdentity?

    public static var isInitialized: Bool { lock.locked { storedOptions != nil } }

    /// The active configuration. Traps with a clear message when the SDK isn't initialised.
    static var config: TMapsOptions {
        guard let options = currentOptions else {
            preconditionFailure("TMaps is not initialised. Call TMaps.initialize(apiKey:) first, or add \(infoPlistAPIKey) to Info.plist.")
        }
        return options
    }

    static var currentOptions: TMapsOptions? { lock.locked { storedOptions } }
    static var identity: AppIdentity? { lock.locked { storedIdentity } }

    /// Initialise with an explicit API key.
    public static func initialize(apiKey: String) {
        initialize(options: TMapsOptions(apiKey: apiKey))
    }

    /// Initialise with full options. Safe to call more than once (last call wins).
    public static func initialize(options: TMapsOptions) {
        lock.locked {
            storedOptions = options
            if storedIdentity == nil { storedIdentity = AppIdentity.current }
        }
        Engine.install()
    }

    /// Initialise from the app's Info.plist (`TMapsAPIKey`, optional `TMapsStyleURL`).
    public static func initialize(bundle: Bundle = .main) throws {
        initialize(options: try TMapsOptions.fromInfoPlist(bundle))
    }

    /// Used by tests to start from a clean slate.
    static func reset() {
        lock.locked {
            storedOptions = nil
            storedIdentity = nil
        }
    }
}

/// Hooks the SDK into the map engine. A no-op where MapLibre isn't available (Linux tests).
enum Engine {
    static func install() {
        #if canImport(MapLibre)
        NetworkHook.install()
        #endif
    }
}

// NSLock.withLock is iOS 16+; the SDK supports iOS 13.
extension NSLock {
    func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
