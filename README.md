# TMaps iOS SDK

A native iOS maps SDK for **tmaps.tn**. It's a thin Swift layer over
[MapLibre Native](https://github.com/maplibre/maplibre-native), with the same API as the
[TMaps Android SDK](../tmaps_android) (which is itself modelled on Google Maps).

```
tmaps_ios/
├── Package.swift            ← the library (Swift Package Manager)
├── Sources/TMaps/           ← SDK sources
├── Tests/TMapsTests/        ← unit tests (also run on Linux)
└── Examples/TMapsSample/    ← demo app (SwiftUI)
```

## Run the sample

1. Open `Examples/TMapsSample/TMapsSample.xcodeproj` in Xcode 15 or newer.
2. Add your key — the iOS counterpart of `local.properties`:
   ```sh
   cp Examples/TMapsSample/Config/Secrets.example.xcconfig Examples/TMapsSample/Config/Secrets.xcconfig
   # then edit TMAPS_API_KEY in Secrets.xcconfig (it is git-ignored)
   ```
3. Pick a simulator or device and run the **TMapsSample** scheme.

The sample opens on a menu with the two ways to use the SDK:

| Entry | What it shows |
|---|---|
| **Interactive map** | Gestures, markers, polyline, long-press pins, `fitBounds`, my-location, camera saved in `@SceneStorage`. |
| **Store page** | A shop page whose header is a map frozen with `showStatic()` — pinned, fixed zoom, every gesture off. |

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen);
after adding files, run `xcodegen` in `Examples/TMapsSample` (or edit the project in Xcode).

## Styles

The styles come from `https://tiles.tmaps.tn/v-tile/{style}.json?api_key=…`
(see [tmaps.tn/documentation/api/vector-tiles](https://www.tmaps.tn/documentation/api/vector-tiles)).

| Constant | Style |
|---|---|
| `TMapStyle.streets` (default) | Light reference map (streets, POIs) |
| `TMapStyle.dark` | Dark / night mode |
| `TMapStyle.terrain` | Relief, water, topography |
| `TMapStyle.sunny` | Warm palette (tourism, retail) |

```swift
map.setStyleURL(TMapStyle.dark)                       // switch at runtime
let mapView = TMapView(styleURL: TMapStyle.terrain)   // per view
```

You don't add `api_key` to these URLs yourself: the SDK appends it to every `*.tmaps.tn`
request (the style, the .pbf tiles, sprites and glyphs).

## Usage

**Swift Package Manager**

In Xcode: *File → Add Package Dependencies…* and enter the repository URL, or in `Package.swift`:

```swift
.package(url: "https://bitbucket.org/apps-hub/tmaps_sdk_ios.git", from: "0.2.0")
// target: .product(name: "TMaps", package: "tmaps_sdk_ios")
```

Requires iOS 13+, Xcode 15+. MapLibre (6.31+) comes along as a dependency.

**Info.plist**

```xml
<key>TMapsAPIKey</key>
<string>YOUR_KEY</string>
<!-- optional -->
<key>TMapsStyleURL</key>
<string>https://…/style.json</string>
<!-- only if you show the user's location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Shows your position on the map.</string>
```

**Init** (`App.init()` or `application(_:didFinishLaunchingWithOptions:)`)

```swift
try TMaps.initialize()                                      // from Info.plist
// or
TMaps.initialize(apiKey: "…")
TMaps.initialize(options: TMapsOptions(apiKey: "…", styleURL: TMapStyle.dark))
```

If you skip it, the first `TMapView` initialises the SDK from Info.plist (and stops with a
clear message if `TMapsAPIKey` is missing).

**UIKit**

```swift
let mapView = TMapView(frame: view.bounds)
mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
view.addSubview(mapView)

mapView.getMapAsync { map in
    map.moveCamera(.tunis, zoom: 12)
    map.addMarker(TMarkerOptions(position: .tunis, title: "Tunis", snippet: "Capital"))
    map.addPolyline(TPolylineOptions(points: [.tunis, .sousse]))
    map.setOnMapClickListener { point in /* … */ }
    map.setOnMarkerClickListener { marker in false }
}
```

There are no lifecycle calls to forward (no `onStart`/`onPause`/`onDestroy`): the view
pauses with the app and frees the map when it is deallocated. `TMapView` also works in a
storyboard (custom class `TMapView`, module `TMaps`).

**SwiftUI**

The SDK ships `TMapSwiftUIView` (Android's sample carries its own `TMapCompose` instead):

```swift
TMapSwiftUIView { map in
    map.moveCamera(camera)
    map.addMarker(TMarkerOptions(position: .tunis, title: "Tunis", snippet: "Capital"))
    map.setOnCameraIdleListener { position in camera = position }
}
.ignoresSafeArea()
```

`onMapReady` runs once, when the style has loaded — not on every view update.
`TCameraPosition` is `Codable`, so it can go into `@SceneStorage` to bring the map back where
the user left it (see `MapScreen.swift`).

> The map keeps the listeners you register. Capture it weakly inside them
> (`{ [weak map] p in map?.addMarker(p) }`), or the closure and the map keep each other alive.

**Still map (lite mode)**

To show one point as a picture — pinned, at a fixed zoom, with every gesture off:

```swift
map.showStatic(.tunis, zoom: 16)                                   // pin at the centre
map.showStatic(.tunis, zoom: 16, marker: nil)                      // no pin
map.showStatic(TCameraPosition(target: .tunis, zoom: 16, bearing: 30, tilt: 45))
map.isInteractive = true                                           // hand the map back
```

Gestures, the compass and marker callouts go away; the camera can still be moved from code
and your own tap listeners still fire, so the picture can stay tappable. Attribution stays
visible — it is an ODbL requirement, not a control.

## API overview — Android → iOS

| Android (`tn.tmaps.android`) | iOS (`TMaps`) |
|---|---|
| `TMaps.init(context)` / `init(context, apiKey)` / `init(context, options)` | `TMaps.initialize()` / `initialize(apiKey:)` / `initialize(options:)` |
| Manifest `tn.tmaps.API_KEY`, `tn.tmaps.STYLE_URL` | Info.plist `TMapsAPIKey`, `TMapsStyleURL` |
| `TMapsOptions(apiKey, styleUrl, apiKeyQueryParam, apiKeyHeader, hosts)` | `TMapsOptions(apiKey:styleURL:apiKeyQueryParam:apiKeyHeader:hosts:)` |
| `TMapStyle.STREETS` … `SUNNY` (String) | `TMapStyle.streets` … `.sunny` (URL) |
| `TMapView` + `bindToLifecycle` / lifecycle forwarding | `TMapView` (no lifecycle calls) |
| `TMapCompose` (sample) | `TMapSwiftUIView` (in the SDK) |
| `getMapAsync { map -> }` | `getMapAsync { map in }` |
| `TLatLng(lat, lng)`, `TLatLng.TUNIS` | `TLatLng(latitude:longitude:)`, `.tunis`; `TLatLng(checkedLatitude:longitude:)` returns `nil` instead of trapping |
| `TCameraPosition(target, zoom, bearing, tilt)` | same, plus `Codable` |
| `moveCamera`, `animateCamera(…, durationMs)` | `moveCamera`, `animateCamera(…, duration:)` (seconds) |
| `fitBounds(points, paddingPx = 64)` | `fitBounds(_:padding: = 32)` (points) |
| `setMinZoom`, `setMaxZoom`, `setCameraBounds` | same |
| `showStatic`, `isInteractive` | same |
| `addMarker` / `addPolyline` / `addPolygon`, `clear()` | same |
| `TMarkerOptions(icon: Bitmap)` | `TMarkerOptions(icon: UIImage)` |
| colours as `@ColorInt Int`, width in dp | `UIColor`, width in points |
| `TMarker.position/title/snippet/tag`, `showInfoWindow()` | same |
| `setOnMapClickListener`, `…LongClick…`, `…MarkerClick…`, `…CameraIdle…` | same names, Swift closures |
| `setMyLocationEnabled`, `followMyLocation`, `myLocation` | same (MapLibre asks for permission itself) |
| `TUiSettings` | `TUiSettings` (`isTiltGesturesEnabled` ↔ pitch) |

## How the API key travels

`TMaps.initialize` installs a hook in MapLibre's networking (`MLNNetworkConfiguration`):

- every request to a `tmaps.tn` host (or one listed in `TMapsOptions.hosts`) over **HTTPS**
  gets `api_key=…` (or the header you configure) — other hosts and cleartext requests are
  left alone, and look-alikes such as `nottmaps.tn` never match;
- those requests also carry `X-TMaps-SDK: ios/<version>` and `X-Ios-Bundle-Identifier`
  (Google's convention), so a key can be restricted server-side to one app;
- every redirect hop is re-checked: if a redirect leaves tmaps.tn or drops to HTTP, the key
  and SDK headers are stripped (Android gets this from OkHttp's network interceptor).

The public API only uses TMaps types, so the engine can be swapped later without breaking
apps. Apps that want raw MapLibre can still `import MapLibre` themselves.

> Keep map attribution visible if your tiles contain OpenStreetMap data (ODbL).

## Tests

```sh
swift test        # macOS or Linux
```

The tests cover what can go wrong silently: which requests receive the key (and which must
not), redirects, Info.plist parsing, coordinate validation, and camera encoding. They are
ports of the Android unit tests plus the iOS-only cases. On Linux the MapLibre-dependent
code is compiled out; on macOS run them on an iOS simulator from Xcode, or with
`xcodebuild test -scheme TMaps -destination 'platform=iOS Simulator,name=iPhone 16'`.

## Publishing

- **Swift Package Manager (recommended):** the package lives at
  `https://bitbucket.org/apps-hub/tmaps_sdk_ios.git`; a release is a pushed semver tag
  (`0.2.0`, no `v` prefix) matching `TMaps.version`. Users add the repository URL in Xcode.
  Nothing else to host. While the repo is private, apps need Bitbucket access to resolve it.
- **CocoaPods / binary xcframework:** not set up. If you build an xcframework with
  library evolution, rename the `TMaps` enum or the module first — a type named like its
  module breaks `.swiftinterface` files.

## Roadmap

Same as Android: marker clustering and GeoJSON layers, offline regions
(`MLNOfflineStorage`), search/geocoding and routing clients for the tmaps.tn APIs.
