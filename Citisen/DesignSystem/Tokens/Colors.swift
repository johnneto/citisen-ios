import SwiftUI

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&rgb)
        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255
        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    static func dynamic(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #else
        return light
        #endif
    }
}

enum BrandColor {
    static let sand = Color(hex: "C8975A")
    static let sandTint = Color(hex: "F5EDE0")
    static let sandDeep = Color(hex: "7A5430")
}

enum ModePalette {
    struct Pair {
        let color: Color
        let tint: Color
    }

    static let standard  = Pair(color: Color(hex: "C8975A"), tint: Color(hex: "F5EAD8"))
    static let food      = Pair(color: Color(hex: "D4695E"), tint: Color(hex: "FBE9E6"))
    static let nature    = Pair(color: Color(hex: "4A8C6F"), tint: Color(hex: "DFEFE6"))
    static let turbo     = Pair(color: Color(hex: "5B6BF0"), tint: Color(hex: "E3E6FC"))
    static let history   = Pair(color: Color(hex: "B85CC8"), tint: Color(hex: "F2E1F5"))
    static let sports    = Pair(color: Color(hex: "E08A3C"), tint: Color(hex: "FBEBD8"))
    static let nightlife = Pair(color: Color(hex: "7A5BCF"), tint: Color(hex: "E8E1F5"))
    static let cafes     = Pair(color: Color(hex: "A4744A"), tint: Color(hex: "F2E6DB"))
    static let art       = Pair(color: Color(hex: "CF3E6E"), tint: Color(hex: "FADFE8"))
}

enum AppColor {
    static let surfacePrimary = Color.dynamic(
        light: Color(hex: "F7F7F5"),
        dark: Color(hex: "111111")
    )
    static let surfaceElevated = Color.dynamic(
        light: Color(hex: "FFFFFF"),
        dark: Color(hex: "1C1C1C")
    )
    static let surfaceGrouped = Color.dynamic(
        light: Color(hex: "EBEBEB"),
        dark: Color(hex: "2C2C2C")
    )
    static let textPrimary = Color.dynamic(
        light: Color(hex: "0D0D0D"),
        dark: Color(hex: "FFFFFF")
    )
    static let textSecondary = Color.dynamic(
        light: Color(hex: "6B6B6B"),
        dark: Color(hex: "8C8C8C")
    )
    static let textTertiary = Color.dynamic(
        light: Color(hex: "B0B0B0"),
        dark: Color(hex: "5A5A5A")
    )
    static let divider = Color.dynamic(
        light: Color(hex: "D4D4D4"),
        dark: Color(hex: "333333")
    )
    static let dividerSoft = Color.dynamic(
        light: Color(hex: "E6E6E6"),
        dark: Color(hex: "222222")
    )
    static let danger = Color(hex: "D4695E")
    static let success = Color(hex: "4A8C6F")
    static let warning = Color(hex: "E8A93A")
}
