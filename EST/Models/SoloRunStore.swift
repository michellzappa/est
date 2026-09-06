import Foundation

/// Keeps one interrupted solo run on disk so a player who leaves mid-game can
/// come back to the same table. Only solo runs are saved: a party run needs
/// everyone back in the room, and a network run needs the match.
enum SoloRunStore {
    private static let key = "soloRunInProgress"

    /// Runs older than this are dropped. A week-old table is a new game, not
    /// a resume, and the Resume button should not outlive the player's memory
    /// of what it points at.
    private static let maximumAge: TimeInterval = 60 * 60 * 24 * 3

    static func save(_ run: GameEngine.SavedRun?, defaults: UserDefaults = .standard) {
        guard let run, let data = try? JSONEncoder().encode(run) else {
            clear(defaults: defaults)
            return
        }
        defaults.set(data, forKey: key)
    }

    static func load(defaults: UserDefaults = .standard) -> GameEngine.SavedRun? {
        guard let data = defaults.data(forKey: key),
              let run = try? JSONDecoder().decode(GameEngine.SavedRun.self, from: data)
        else { return nil }
        guard Date.now.timeIntervalSince(run.savedAt) < maximumAge else {
            clear(defaults: defaults)
            return nil
        }
        return run
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
