import GameKit
import Observation
import UIKit

/// Game Center: authentication, the solo completion-time leaderboard, and the
/// access point on the title screen.
///
/// The leaderboard must exist in App Store Connect with this exact ID,
/// score format "Elapsed Time, To the Hundredth of a Second", sort order
/// ascending (lower is better).
@Observable
final class GameCenterManager {
    static let shared = GameCenterManager()
    static let soloLeaderboardID = "est.solo.completion.time"
    static let quickLeaderboardID = "est.quick.completion.time"

    static func leaderboardID(for variant: GameEngine.Variant) -> String {
        variant == .quick ? quickLeaderboardID : soloLeaderboardID
    }

    private(set) var isAuthenticated = false
    private let dismissDelegate = DismissDelegate()
    private var wantsAccessPointVisible = false

    private init() {}

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let viewController {
                Self.topViewController()?.present(viewController, animated: true)
                return
            }
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            self?.updateAccessPoint()
        }
    }

    func setAccessPointVisible(_ visible: Bool) {
        wantsAccessPointVisible = visible
        updateAccessPoint()
    }

    private func updateAccessPoint() {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.showHighlights = true
        GKAccessPoint.shared.isActive = wantsAccessPointVisible && isAuthenticated
    }

    /// Submit only a finite, physically possible EST completion time. This is
    /// a client-side guard for ordinary mistakes and clock tampering; a
    /// modified client could still call GameKit directly.
    @discardableResult
    func submitSoloTime(
        _ seconds: TimeInterval,
        variant: GameEngine.Variant,
        wasPaused: Bool
    ) -> Bool {
        guard isAuthenticated,
              !wasPaused,
              GameEngine.isLeaderboardTimeEligible(seconds, for: variant),
              seconds <= TimeInterval(Int.max) / 100
        else { return false }

        let centiseconds = Int((seconds * 100).rounded(.down))
        let minimumCentiseconds = GameEngine.minimumLeaderboardCentiseconds(for: variant)
        guard centiseconds >= minimumCentiseconds else { return false }

        let leaderboardID = Self.leaderboardID(for: variant)
        Task {
            try? await GKLeaderboard.submitScore(
                centiseconds,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            )
        }
        return true
    }

    func showLeaderboard(id: String = GameCenterManager.soloLeaderboardID) {
        guard isAuthenticated else { return }
        ESTTelemetry.record(.leaderboardViewed)
        let vc = GKGameCenterViewController(
            leaderboardID: id,
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
