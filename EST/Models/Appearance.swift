import SwiftUI
import Observation

/// User-facing look settings, persisted in UserDefaults. Card tint colors
/// flow through the active theme (`Card.Tint.color` delegates here), so a
/// theme change restyles cards, confetti, the title, and the progress bar
/// at once.
@Observable
final class Appearance {
    static let shared = Appearance()

    enum AccessibilitySetting: Int, CaseIterable {
        case automatic, on, off

        var name: String {
            switch self {
            case .automatic: "Auto"
            case .on: "On"
            case .off: "Off"
            }
        }

        func resolved(using systemValue: Bool) -> Bool {
            switch self {
            case .automatic: systemValue
            case .on: true
            case .off: false
            }
        }
    }

    enum FillStyle: Int, CaseIterable {
        case shaded, pinstriped

        var name: String {
            switch self {
            case .shaded: "Shaded"
            case .pinstriped: "Pinstriped"
            }
        }
    }

    enum Theme: Int, CaseIterable {
        case primary, orchard, dusk

        var name: String {
            switch self {
            case .primary: "Primary"
            case .orchard: "Orchard"
            case .dusk: "Dusk"
            }
        }

        func color(for tint: Card.Tint) -> Color {
            switch (self, tint) {
            case (.primary, .red): Color(red: 0.87, green: 0.32, blue: 0.28)
            case (.primary, .blue): Color(red: 0.24, green: 0.43, blue: 0.92)
            case (.primary, .yellow): Color(red: 0.94, green: 0.66, blue: 0.20)
            case (.orchard, .red): Color(red: 0.55, green: 0.33, blue: 0.83)
            case (.orchard, .blue): Color(red: 0.13, green: 0.62, blue: 0.39)
            case (.orchard, .yellow): Color(red: 0.93, green: 0.47, blue: 0.15)
            case (.dusk, .red): Color(red: 0.87, green: 0.33, blue: 0.46)
            case (.dusk, .blue): Color(red: 0.12, green: 0.55, blue: 0.58)
            case (.dusk, .yellow): Color(red: 0.82, green: 0.60, blue: 0.16)
            }
        }

        func color(for accent: GameAccent) -> Color {
            switch accent {
            case .first: color(for: .red)
            case .second: color(for: .blue)
            case .third: color(for: .yellow)
            case .danger: errorColor
            }
        }

        func highlight(for tint: Card.Tint) -> Color {
            switch (self, tint) {
            case (.primary, .red): Color(red: 0.96, green: 0.47, blue: 0.41)
            case (.primary, .blue): Color(red: 0.44, green: 0.60, blue: 0.98)
            case (.primary, .yellow): Color(red: 0.99, green: 0.79, blue: 0.38)
            case (.orchard, .red): Color(red: 0.68, green: 0.48, blue: 0.93)
            case (.orchard, .blue): Color(red: 0.30, green: 0.76, blue: 0.53)
            case (.orchard, .yellow): Color(red: 0.98, green: 0.62, blue: 0.31)
            case (.dusk, .red): Color(red: 0.96, green: 0.50, blue: 0.61)
            case (.dusk, .blue): Color(red: 0.29, green: 0.70, blue: 0.73)
            case (.dusk, .yellow): Color(red: 0.93, green: 0.74, blue: 0.34)
            }
        }

        func highlight(for accent: GameAccent) -> Color {
            switch accent {
            case .first: highlight(for: .red)
            case .second: highlight(for: .blue)
            case .third: highlight(for: .yellow)
            case .danger: errorColor.opacity(0.72)
            }
        }

        /// Soft semantic accents are for feedback, never for card identity.
        /// They stay readable beside the themed card tints without using the
        /// saturated system `Color.green`/`Color.red` defaults.
        var successColor: Color {
            switch self {
            case .primary: Color(red: 0.28, green: 0.64, blue: 0.40)
            case .orchard: Color(red: 0.30, green: 0.66, blue: 0.45)
            case .dusk: Color(red: 0.34, green: 0.70, blue: 0.64)
            }
        }

        /// The fourth player's identity accent. It is deliberately separate
        /// from `successColor`: that color is reserved for game feedback,
        /// while this one must remain distinct from the three card tints.
        var fourthPlayerColor: Color {
            switch self {
            case .primary: Color(red: 0.61, green: 0.34, blue: 0.78)
            case .orchard: Color(red: 0.82, green: 0.28, blue: 0.48)
            case .dusk: Color(red: 0.61, green: 0.38, blue: 0.80)
            }
        }

        var errorColor: Color {
            switch self {
            case .primary: Color(red: 0.78, green: 0.36, blue: 0.34)
            case .orchard: Color(red: 0.78, green: 0.39, blue: 0.43)
            case .dusk: Color(red: 0.80, green: 0.40, blue: 0.49)
            }
        }

        /// Dusk is the supporter-only finish. It adds a warm paper-and-metal
        /// feel without changing card identity or giving its owner a gameplay
        /// advantage.
        var cardSurface: Color {
            switch self {
            case .dusk: Color(red: 0.96, green: 0.94, blue: 0.88)
            default: Color(.secondarySystemGroupedBackground)
            }
        }

        var cardBorder: Color {
            switch self {
            case .dusk: Color(red: 0.68, green: 0.47, blue: 0.16).opacity(0.55)
            default: Color.primary.opacity(0.12)
            }
        }
    }

    var fillStyle: FillStyle {
        didSet { UserDefaults.standard.set(fillStyle.rawValue, forKey: "appearance.fillStyle") }
    }

    var warmBackgroundEnabled: Bool {
        didSet { UserDefaults.standard.set(warmBackgroundEnabled, forKey: "appearance.warmBackground") }
    }

    var reduceMotion: AccessibilitySetting {
        didSet { UserDefaults.standard.set(reduceMotion.rawValue, forKey: "appearance.reduceMotion") }
    }

    var highContrast: AccessibilitySetting {
        didSet { UserDefaults.standard.set(highContrast.rawValue, forKey: "appearance.highContrast") }
    }

    var colorBlindAssist: AccessibilitySetting {
        didSet { UserDefaults.standard.set(colorBlindAssist.rawValue, forKey: "appearance.colorBlindAssist") }
    }

    var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appearance.theme")
            AppIconManager.update(for: theme)
        }
    }

    /// Player identity follows the card palette so a theme changes both in
    /// lockstep. The fourth slot uses the theme's implicit fourth player hue.
    func playerColor(for slot: Int) -> Color {
        switch slot {
        case 0: Card.Tint.red.color
        case 1: Card.Tint.blue.color
        case 2: Card.Tint.yellow.color
        default: theme.fourthPlayerColor
        }
    }

    /// Use these for UI feedback, not for card or player identity.
    var successColor: Color { theme.successColor }
    var errorColor: Color { theme.errorColor }

    /// Themes change the card palette, not the surrounding app surface. The
    /// warm surface is a separate, explicitly chosen supporter cosmetic.
    var gameBackground: Color {
        warmBackgroundEnabled
            ? Color(red: 0.93, green: 0.91, blue: 0.85)
            : Color(.systemGroupedBackground)
    }

    /// All themes follow the device's appearance; none forces a background
    /// color scheme when selected.
    var preferredColorScheme: ColorScheme? {
        nil
    }

    private init() {
        // New installs get pinstriped. An explicit choice still wins, so a
        // player who picked shaded keeps it.
        let storedFill = UserDefaults.standard.object(forKey: "appearance.fillStyle") as? Int
        fillStyle = storedFill.flatMap(FillStyle.init(rawValue:)) ?? .pinstriped
        warmBackgroundEnabled = UserDefaults.standard.bool(forKey: "appearance.warmBackground")
        reduceMotion = AccessibilitySetting(
            rawValue: UserDefaults.standard.integer(forKey: "appearance.reduceMotion")
        ) ?? .automatic
        highContrast = AccessibilitySetting(
            rawValue: UserDefaults.standard.integer(forKey: "appearance.highContrast")
        ) ?? .automatic
        colorBlindAssist = AccessibilitySetting(
            rawValue: UserDefaults.standard.integer(forKey: "appearance.colorBlindAssist")
        ) ?? .automatic
        // Raw value 3 was the previous Supporter theme. Carry that choice
        // forward as Dusk when upgrading to the supporter-only Dusk finish.
        theme = switch UserDefaults.standard.integer(forKey: "appearance.theme") {
        case 1: .orchard
        case 2, 3: .dusk
        default: .primary
        }
    }
}

private struct ESTReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ESTHighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ESTColorBlindAssistKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var estReduceMotion: Bool {
        get { self[ESTReduceMotionKey.self] }
        set { self[ESTReduceMotionKey.self] = newValue }
    }

    var estHighContrast: Bool {
        get { self[ESTHighContrastKey.self] }
        set { self[ESTHighContrastKey.self] = newValue }
    }

    var estColorBlindAssist: Bool {
        get { self[ESTColorBlindAssistKey.self] }
        set { self[ESTColorBlindAssistKey.self] = newValue }
    }
}
