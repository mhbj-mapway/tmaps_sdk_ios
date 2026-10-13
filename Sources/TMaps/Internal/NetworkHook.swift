#if canImport(MapLibre)
import Foundation
import MapLibre

/// Plugs ``RequestSigner`` into MapLibre's networking: every request MapLibre makes (style,
/// tiles, sprites, glyphs, offline packs) passes through `willSendRequest`, and the session
/// we hand it re-checks every redirect hop so the key never follows one off-host.
///
/// Called from MapLibre's network threads, so it only reads lock-protected state.
final class NetworkHook: NSObject, MLNNetworkConfigurationDelegate {

    static let shared = NetworkHook()
    private static let lock = NSLock()
    private static var installed = false

    static func install() {
        let first: Bool = lock.locked {
            defer { installed = true }
            return !installed
        }
        guard first else { return }
        // MLNNetworkConfiguration.delegate is weak; `shared` keeps the hook alive.
        MLNNetworkConfiguration.sharedManager.delegate = shared
        // MapLibre's own logging is off by default (MLNLoggingLevelNone). Leave it off in
        // release builds: failure logs include request URLs, and those carry the key.
    }

    /// Same configuration MapLibre would use on its own (timeouts, 8 connections per host,
    /// no URL cache — MapLibre has its own), plus a redirect guard as task delegate.
    /// MapLibre supports a session delegate as long as it is not a data delegate.
    private lazy var session: URLSession = URLSession(
        configuration: MLNNetworkConfiguration.sharedManager.sessionConfiguration,
        delegate: RedirectGuard(),
        delegateQueue: nil
    )

    @objc(sessionForNetworkConfiguration:)
    func session(for configuration: MLNNetworkConfiguration) -> URLSession {
        NetworkHook.lock.locked { session }
    }

    @objc(willSendRequest:)
    func willSend(_ request: NSMutableURLRequest) -> NSMutableURLRequest {
        guard let options = TMaps.currentOptions else { return request }
        let signed = RequestSigner.sign(request as URLRequest, options: options, identity: TMaps.identity)
        request.url = signed.url
        request.allHTTPHeaderFields = signed.allHTTPHeaderFields
        return request
    }
}

/// Re-signs a redirect that stays on a tmaps host over HTTPS, strips the key from any other.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let options = TMaps.currentOptions else { return completionHandler(request) }
        completionHandler(RequestSigner.redirect(request, options: options, identity: TMaps.identity))
    }
}
#endif
