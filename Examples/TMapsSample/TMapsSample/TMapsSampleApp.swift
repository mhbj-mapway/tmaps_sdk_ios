import SwiftUI
import TMaps

@main
struct TMapsSampleApp: App {
    init() {
        // Reads TMapsAPIKey from Info.plist, which gets it from Secrets.xcconfig.
        // Alternative: TMaps.initialize(options: TMapsOptions(apiKey: "…", styleURL: TMapStyle.dark))
        do {
            try TMaps.initialize()
        } catch {
            fatalError("\(error)\n\nCopy Secrets.example.xcconfig to Secrets.xcconfig and put your key in it.")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.olive)
        }
    }
}

/// The sample's two entry points, plus the menu that leads to them.
struct RootView: View {
    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: Entry.self) { entry in
                    switch entry {
                    case .map: MapScreen()
                    case .store: StoreScreen()
                    }
                }
        }
    }
}

enum Entry: Hashable { case map, store }
