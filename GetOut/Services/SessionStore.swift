import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private enum Keys {
        static let hasCompletedOnboarding = "session.hasCompletedOnboarding"
        static let currentUsername = "session.currentUsername"
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var currentUsername: String {
        didSet { UserDefaults.standard.set(currentUsername, forKey: Keys.currentUsername) }
    }

    init() {
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        currentUsername = defaults.string(forKey: Keys.currentUsername) ?? ""
    }

    func completeOnboarding(username: String) {
        currentUsername = username
        hasCompletedOnboarding = true
    }

    func clearLocalProfileState() {
        hasCompletedOnboarding = false
        currentUsername = ""
    }
}
