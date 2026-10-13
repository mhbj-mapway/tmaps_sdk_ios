#if canImport(UIKit)
import UIKit

/// What to draw for a marker. Pass it to ``TMap/addMarker(_:)``.
public struct TMarkerOptions {
    public var position: TLatLng
    public var title: String?
    public var snippet: String?
    /// Custom icon, centred on ``position``. `nil` = default pin.
    /// Reuse the same `UIImage` instance for many markers: the SDK uploads each image once.
    public var icon: UIImage?

    public init(position: TLatLng, title: String? = nil, snippet: String? = nil, icon: UIImage? = nil) {
        self.position = position
        self.title = title
        self.snippet = snippet
        self.icon = icon
    }
}

public struct TPolylineOptions {
    public var points: [TLatLng]
    public var color: UIColor
    /// Width in points.
    public var width: CGFloat

    public init(points: [TLatLng], color: UIColor = .tmapsBlue, width: CGFloat = 4) {
        self.points = points
        self.color = color
        self.width = width
    }
}

public struct TPolygonOptions {
    public var points: [TLatLng]
    /// Include alpha in the colour for a see-through fill (the default is 25% blue).
    public var fillColor: UIColor
    public var strokeColor: UIColor

    public init(
        points: [TLatLng],
        fillColor: UIColor = UIColor.tmapsBlue.withAlphaComponent(64.0 / 255.0),
        strokeColor: UIColor = .tmapsBlue
    ) {
        self.points = points
        self.fillColor = fillColor
        self.strokeColor = strokeColor
    }
}

extension UIColor {
    /// #1E88E5, the default line and polygon colour (same as the Android SDK).
    public static let tmapsBlue = UIColor(red: 30 / 255, green: 136 / 255, blue: 229 / 255, alpha: 1)
}
#endif
