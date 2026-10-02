import SwiftUI
import CoreText

/// Coast 99.3 color tokens — Savannah after dark: navy night, bridge-light blue, hot orange.
nonisolated enum Theme {
    static let canvas = Color(hex: 0x050A1A)
    static let surface = Color(hex: 0x0E1730)
    static let surfaceRaised = Color(hex: 0x14214A)
    static let border = Color(hex: 0x1E3A8A)
    static let orange = Color(hex: 0xFF7A1A)
    static let orangeDeep = Color(hex: 0xF25C05)
    static let blue = Color(hex: 0x1F6BFF)
    static let blueSoft = Color(hex: 0x8FB0FF)
    static let red = Color(hex: 0xE8322B)
    static let textSecondary = Color(hex: 0x9AA7C7)
    static let textTertiary = Color(hex: 0x5F6E94)

    static let orangeGradient = LinearGradient(
        colors: [Color(hex: 0xFF9A3D), Color(hex: 0xFF7A1A), Color(hex: 0xF25C05)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Brand typography: Anton for big numbers, Barlow Condensed for uppercase labels, SF Pro for body.
enum CoastFont {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Anton-Regular", size: size, relativeTo: style)
    }

    static func condensed(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("BarlowCondensed-Bold", size: size, relativeTo: style)
    }

    static func condensedSemi(_ size: CGFloat, relativeTo style: Font.TextStyle = .subheadline) -> Font {
        .custom("BarlowCondensed-SemiBold", size: size, relativeTo: style)
    }

    /// Registers bundled TTFs so they can be used without Info.plist UIAppFonts.
    static func registerFonts() {
        for name in ["Anton-Regular", "BarlowCondensed-Bold", "BarlowCondensed-SemiBold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
