import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private enum Keys {
        static let hasCompletedOnboarding = "session.hasCompletedOnboarding"
        static let currentUsername = "session.currentUsername"
        static let currentSupabaseUserID = "session.currentSupabaseUserID"
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var currentUsername: String {
        didSet { UserDefaults.standard.set(currentUsername, forKey: Keys.currentUsername) }
    }

    /// The Supabase Auth user ID is the account key. Usernames are editable display data and must
    /// never be used by themselves to decide which local profile is signed in.
    var currentSupabaseUserID: String {
        didSet {
            UserDefaults.standard.set(
                currentSupabaseUserID,
                forKey: Keys.currentSupabaseUserID
            )
        }
    }

    var isResolvingAccount = true

    init() {
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        currentUsername = defaults.string(forKey: Keys.currentUsername) ?? ""
        currentSupabaseUserID = defaults.string(
            forKey: Keys.currentSupabaseUserID
        ) ?? ""

        if currentSupabaseUserID.isEmpty {
            hasCompletedOnboarding = false
            currentUsername = ""
        }
    }

    func completeOnboarding(username: String, userRecordName: String) {
        currentUsername = username
        currentSupabaseUserID = userRecordName
        hasCompletedOnboarding = true
        isResolvingAccount = false
    }

    func beginAccountResolution(clearPersistedProfile: Bool = false) {
        isResolvingAccount = true
        if clearPersistedProfile {
            hasCompletedOnboarding = false
            currentUsername = ""
            currentSupabaseUserID = ""
        }
    }

    func showOnboarding(for userRecordName: String) {
        currentSupabaseUserID = userRecordName
        currentUsername = ""
        hasCompletedOnboarding = false
        isResolvingAccount = false
    }

    func finishAccountResolutionAfterFailure() {
        isResolvingAccount = false
    }

    func clearLocalProfileState() {
        hasCompletedOnboarding = false
        currentUsername = ""
        currentSupabaseUserID = ""
        isResolvingAccount = false
    }

    func currentProfile(in profiles: [Profile]) -> Profile? {
        guard !currentSupabaseUserID.isEmpty else { return nil }
        return profiles.first { $0.supabaseUserID == currentSupabaseUserID }
    }
}
