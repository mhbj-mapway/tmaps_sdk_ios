#if canImport(SwiftUI) && canImport(UIKit) && canImport(MapLibre)
import SwiftUI

/// SwiftUI wrapper around ``TMapView``.
///
/// ```swift
/// TMapSwiftUIView { map in
///     map.moveCamera(camera)
///     map.addMarker(TMarkerOptions(position: .tunis, title: "Tunis", snippet: "Capital"))
///     map.setOnCameraIdleListener { camera = $0 }
/// }
/// .ignoresSafeArea()
/// ```
///
/// The map keeps the listeners you register, so capture it weakly inside them
/// (`m.setOnMapLongClickListener { [weak m] p in m?.addMarker(p) }`).
///
/// `onMapReady` runs once, when the style has loaded — not on every view update. Keep the
/// camera in `@SceneStorage`/`@State` to restore it, and use ``TMap/setStyleURL(_:onLoaded:)``
/// to switch styles at runtime. In Xcode previews it renders a placeholder.
@MainActor
public struct TMapSwiftUIView: UIViewRepresentable {
    private let styleURL: URL?
    private let onMapReady: (TMap) -> Void

    /// - Parameters:
    ///   - styleURL: style to load. `nil` uses ``TMapsOptions/styleURL``.
    ///     Read once, when the map is created.
    ///   - onMapReady: called once, when the map and its style are loaded. Do imperative
    ///     setup here (markers, listeners, camera).
    nonisolated public init(styleURL: URL? = nil, onMapReady: @escaping (TMap) -> Void) {
        self.styleURL = styleURL
        self.onMapReady = onMapReady
    }

    public func makeUIView(context: Context) -> TMapView {
        let view = TMapView(frame: .zero, styleURL: styleURL)
        let coordinator = context.coordinator
        view.getMapAsync { map in coordinator.onMapReady(map) }
        return view
    }

    public func updateUIView(_ uiView: TMapView, context: Context) {
        // Keep the latest closure, so captured @State bindings stay current.
        context.coordinator.onMapReady = onMapReady
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onMapReady: onMapReady) }

    @MainActor
    public final class Coordinator {
        var onMapReady: (TMap) -> Void
        init(onMapReady: @escaping (TMap) -> Void) { self.onMapReady = onMapReady }
    }
}
#endif
