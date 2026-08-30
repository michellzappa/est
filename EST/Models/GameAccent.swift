import SwiftUI

/// A small palette vocabulary for reusable game chrome. The tokens describe a
/// position in a game's palette rather than a particular card attribute, so
/// buttons and shared screens do not depend on EST's `Card.Tint` type.
enum GameAccent: CaseIterable {
    case first
    case second
    case third
    case danger

    var color: Color {
        Appearance.shared.theme.color(for: self)
    }

    var highlight: Color {
        Appearance.shared.theme.highlight(for: self)
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [highlight, color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Card.Tint {
    /// EST cards retain their named identity colours while shared chrome uses
    /// palette positions. Future games can map their own identity system onto
    /// the same three positions.
    var gameAccent: GameAccent {
        switch self {
        case .red: .first
        case .blue: .second
        case .yellow: .third
        }
    }
}
