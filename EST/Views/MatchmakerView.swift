import SwiftUI
import GameKit

/// Wraps GKMatchmakerViewController: Game Center's own UI for inviting
/// friends, nearby players, or auto-matching. iPad requests may grow to the
/// same four-player roster supported by the party protocol.
struct MatchmakerView: UIViewControllerRepresentable {
    var onMatch: (GKMatch) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> GKMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = PartySession.minimumPlayerCount
        request.maxPlayers = PartySession.matchmakingMaximumPlayerCount
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
