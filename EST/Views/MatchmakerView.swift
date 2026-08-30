import SwiftUI
import GameKit

/// Product-neutral limits for one Game Center matchmaking request.
struct MatchmakerConfiguration: Equatable {
    let minimumPlayers: Int
    let maximumPlayers: Int

    init(minimumPlayers: Int, maximumPlayers: Int) {
        self.minimumPlayers = max(1, minimumPlayers)
        self.maximumPlayers = max(self.minimumPlayers, maximumPlayers)
    }
}

/// Wraps GKMatchmakerViewController: Game Center's own UI for inviting
/// friends, nearby players, or auto-matching. The game provides player limits
/// so this view is reusable by any Game Center-enabled tabletop game.
struct MatchmakerView: UIViewControllerRepresentable {
    let configuration: MatchmakerConfiguration
    var onMatch: (GKMatch) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> GKMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = configuration.minimumPlayers
        request.maxPlayers = configuration.maximumPlayers
        let controller = GKMatchmakerViewController(matchRequest: request)!
        controller.matchmakerDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: GKMatchmakerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        let parent: MatchmakerView

        init(_ parent: MatchmakerView) {
            self.parent = parent
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            parent.onDismiss()
        }

        func matchmakerViewController(
            _ viewController: GKMatchmakerViewController,
            didFailWithError error: Error
        ) {
            parent.onDismiss()
        }

        func matchmakerViewController(
            _ viewController: GKMatchmakerViewController,
            didFind match: GKMatch
        ) {
            parent.onMatch(match)
        }
    }
}
