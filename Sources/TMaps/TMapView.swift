#if canImport(UIKit) && canImport(MapLibre)
import UIKit
import MapLibre

/// The map view. Use it in code, a storyboard (custom class `TMapView`, module `TMaps`), or
/// SwiftUI through ``TMapSwiftUIView``.
///
/// Unlike Android there are no lifecycle calls to forward: the view pauses and resumes
/// rendering with the app, and frees the map when it is deallocated.
///
/// ```swift
/// let mapView = TMapView(frame: view.bounds)
/// view.addSubview(mapView)
/// mapView.getMapAsync { map in
///     map.moveCamera(.tunis, zoom: 12)
///     map.addMarker(TMarkerOptions(position: .tunis, title: "Tunis", snippet: "Capital"))
/// }
/// ```
public final class TMapView: UIView {

    /// Style used by this view. Defaults to ``TMapsOptions/styleURL``.
    /// Set it before ``getMapAsync(_:)`` or before the view enters a window;
    /// use ``TMap/setStyleURL(_:onLoaded:)`` to switch afterwards.
    public var styleURL: URL?

    /// Called if the style can't be loaded (bad API key, no network, invalid style).
    public var onLoadError: ((Error) -> Void)?

    private var mapView: MLNMapView?
    private var tMap: TMap?
    private var pending: [(TMap) -> Void] = []
    private let proxy = MapEventProxy()
    private let isPlaceholder: Bool

    public convenience init(frame: CGRect = .zero, styleURL: URL?) {
        self.init(frame: frame)
        self.styleURL = styleURL
    }

    public override init(frame: CGRect) {
        isPlaceholder = TMapView.isDesignTime
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        isPlaceholder = TMapView.isDesignTime
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Same tone as the tiles' land colour, so the first frame doesn't flash white.
        backgroundColor = UIColor(red: 0xE5 / 255, green: 0xE3 / 255, blue: 0xDF / 255, alpha: 1)
        if isPlaceholder {
            // Interface Builder and SwiftUI previews: no GL surface, no network, no key needed.
            let label = UILabel()
            label.text = "TMapView"
            label.textColor = .darkGray
            label.textAlignment = .center
            label.frame = bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(label)
            return
        }
        if !TMaps.isInitialized {
            do { try TMaps.initialize() } catch { preconditionFailure("\(error)") }
        }
    }

    /// Get the ``TMap`` once the map and its style are loaded. Called on the main thread;
    /// immediately if the map is already loaded. Never called for a placeholder (previews).
    public func getMapAsync(_ callback: @escaping (TMap) -> Void) {
        if let tMap { return callback(tMap) }
        pending.append(callback)
        startLoadingIfNeeded()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startLoadingIfNeeded() }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        tMap?.viewDidLayout()
    }

    // MARK: - loading

    private func startLoadingIfNeeded() {
        guard mapView == nil, !isPlaceholder else { return }
        let url = styleURL ?? TMaps.config.styleURL
        let mv = MLNMapView(frame: bounds, styleURL: url)
        mv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mv.showsLogoView = false
        mv.delegate = proxy
        proxy.attachGestures(to: mv)
        proxy.onStyleLoaded = { [weak self] in self?.styleDidLoad() }
        proxy.onLoadFailed = { [weak self] error in self?.onLoadError?(error) }
        addSubview(mv)
        mapView = mv
    }

    private func styleDidLoad() {
        if let tMap {
            // A later style switch (TMap.setStyleURL).
            tMap.styleDidLoad()
            return
        }
        guard let mapView else { return }
        let map = TMap(mapView: mapView)
        proxy.map = map
        tMap = map
        let callbacks = pending
        pending.removeAll()
        callbacks.forEach { $0(map) }
    }

    private static var isDesignTime: Bool {
        #if TARGET_INTERFACE_BUILDER
        return true
        #else
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #endif
    }
}
#endif
