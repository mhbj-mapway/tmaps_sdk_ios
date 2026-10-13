import SwiftUI
import TMaps

private let cities: [TLatLng] = [.tunis, .sousse, .sfax]

/// The interactive entry point: gestures on, annotations, live camera readout.
@MainActor
struct MapScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var map: TMap?
    @State private var toast: String?

    // Survives relaunch and scene restoration, so the map comes back where the user left it.
    // This is what `mapView.onSaveInstanceState(outState)` does on Android.
    @SceneStorage("map.camera") private var savedCamera: Data?
    @State private var zoom: Double = 12

    var body: some View {
        ZStack {
            TMapSwiftUIView { m in
                map = m
                m.moveCamera(restoredCamera)
                zoom = m.cameraPosition.zoom
                addSampleAnnotations(to: m)

                m.setOnCameraIdleListener { position in
                    zoom = position.zoom
                    savedCamera = try? JSONEncoder().encode(position)
                }

                // The map keeps its listeners: capture it weakly, or the two keep each other alive.
                m.setOnMapLongClickListener { [weak m] point in
                    m?.addMarker(TMarkerOptions(
                        position: point,
                        title: "Dropped pin",
                        snippet: String(format: "%.5f, %.5f", point.latitude, point.longitude)
                    ))
                }

                m.setOnMarkerClickListener { marker in
                    show(marker.title ?? "Marker")
                    return false // false = also show the callout
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("Back")
                    Text(String(format: "z=%.1f", zoom))
                        .font(.callout.monospacedDigit())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                    Spacer()
                }
                Spacer()
                HStack(alignment: .bottom) {
                    if let toast {
                        Text(toast)
                            .font(.callout)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.thinMaterial, in: Capsule())
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        ControlButton(title: "Fit cities", icon: "arrow.up.left.and.arrow.down.right") {
                            map?.fitBounds(cities)
                        }
                        ControlButton(title: "My location", icon: "location.fill") {
                            map?.setMyLocationEnabled(true)
                            map?.followMyLocation(true)
                        }
                    }
                }
            }
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(.olive)
    }

    private var restoredCamera: TCameraPosition {
        savedCamera.flatMap { try? JSONDecoder().decode(TCameraPosition.self, from: $0) }
            ?? TCameraPosition(target: .tunis, zoom: 12)
    }

    /// Everything the sample draws on the map, added once the style is loaded.
    private func addSampleAnnotations(to map: TMap) {
        map.addMarker(TMarkerOptions(position: .tunis, title: "Tunis", snippet: "Capital of Tunisia"))
        map.addMarker(.sousse, title: "Sousse")
        map.addMarker(.sfax, title: "Sfax")
        map.addPolyline(TPolylineOptions(points: cities, color: UIColor(hex: 0xE53935), width: 5))
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { if toast == message { toast = nil } }
        }
    }
}

private struct ControlButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.oliveContainer, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(Color.onOliveContainer)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }
}
