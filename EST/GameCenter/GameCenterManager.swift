import GameKit
import Observation
import UIKit

/// Game Center: authentication, the solo completion-time leaderboard, and the
/// access point on the title screen.
///
/// The leaderboard must exist in App Store Connect with this exact ID,
/// score format "Elapsed Time — To the Hundredth of a Second", sort order
/// ascending (lower is better).
@Observable
final class GameCenterManager {
    static let shared = GameCenterManager()
    static let soloLeaderboardID = "est.solo.completion.time"

    private(set) var isAuthenticated = false
    private let dismissDelegate = DismissDelegate()

    private init() {}

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let viewController {
                Self.topViewController()?.present(viewController, animated: true)
                return
            }
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
        }
    }

    func setAccessPointVisible(_ visible: Bool) {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.showHighlights = true
        GKAccessPoint.shared.isActive = visible && isAuthenticated
    }

    /// Game Center elapsed-time leaderboards store centiseconds.
    func submitSoloTime(_ seconds: TimeInterval) {
        guard isAuthenticated else { return }
        let centiseconds = Int(seconds * 100)
        Task {
            try? await GKLeaderboard.submitScore(
                centiseconds,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.soloLeaderboardID]
            )
        }
    }

    func showLeaderboard() {
        guard isAuthenticated else { return }
        let vc = GKGameCenterViewController(
            leaderboardID: Self.soloLeaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        vc.gameCenterDelegate = dismissDelegate
        Self.topViewController()?.present(vc, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private final class DismissDelegate: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
