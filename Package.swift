// swift-tools-version:5.9
import PackageDescription

// MapLibre ships as an iOS binary framework. On Linux (CI, or `swift test` outside Xcode) the
// package builds without it: only the Foundation-level code (models, options, API-key
// handling) compiles there, and that is exactly what the unit tests cover.
#if os(Linux)
let mapLibreDependencies: [Package.Dependency] = []
let mapLibreProducts: [Target.Dependency] = []
#else
let mapLibreDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", from: "6.31.0"),
]
let mapLibreProducts: [Target.Dependency] = [
    .product(name: "MapLibre", package: "maplibre-gl-native-distribution"),
]
#endif

let package = Package(
    name: "TMaps",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "TMaps", targets: ["TMaps"]),
    ],
    dependencies: mapLibreDependencies,
    targets: [
        .target(
            name: "TMaps",
            dependencies: mapLibreProducts,
            path: "Sources/TMaps"
        ),
        .testTarget(
            name: "TMapsTests",
            dependencies: ["TMaps"],
            path: "Tests/TMapsTests"
        ),
    ]
)
