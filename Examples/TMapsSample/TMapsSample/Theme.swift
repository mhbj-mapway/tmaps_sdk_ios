import SwiftUI

// Olive, warm sand and terracotta — the same palette as the Android sample. It sits better
// next to a map than the default blue, and it matches the shop the store page is built around.
extension Color {
    static let olive = Color(light: 0x4E6C32, dark: 0xB4D287)
    static let oliveContainer = Color(light: 0xCFEFA5, dark: 0x374E1C)
    static let onOliveContainer = Color(light: 0x0F2000, dark: 0xCFEFA5)
    static let terracotta = Color(light: 0xB3421F, dark: 0xFFB4A0)
    static let sand = Color(light: 0xFCFAF3, dark: 0x13140F)
    static let sandContainer = Color(light: 0xF0EEE6, dark: 0x1F201B)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
