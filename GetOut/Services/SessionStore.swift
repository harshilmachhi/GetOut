import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private enum Keys {
        static let hasCompletedOnboarding = "session.hasCompletedOnboarding"
        static let currentUsername = "session.currentUsername"
        static let currentCloudKitUserRecordName = "session.currentCloudKitUserRecordName"
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var currentUsername: String {
        didSet { UserDefaults.standard.set(currentUsername, forKey: Keys.currentUsername) }
    }

    /// The CloudKit identity is the account key. Usernames are editable display data and must
    /// never be used by themselves to decide which local profile is signed in.
    var currentCloudKitUserRecordName: String {
        didSet {
            UserDefaults.standard.set(
                currentCloudKitUserRecordName,
                forKey: Keys.currentCloudKitUserRecordName
            )
        }
    }

    var isResolvingAccount = true

    init() {
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        currentUsername = defaults.string(forKey: Keys.currentUsername) ?? ""
        currentCloudKitUserRecordName = defaults.string(
            forKey: Keys.currentCloudKitUserRecordName
        ) ?? ""

        // Builds predating account-scoped sessions only persisted a username. Force one
        // CloudKit reconciliation before trusting that legacy state.
        if currentCloudKitUserRecordName.isEmpty {
            hasCompletedOnboarding = false
        }
    }

    func completeOnboarding(username: String, userRecordName: String) {
        currentUsername = username
        currentCloudKitUserRecordName = userRecordName
        hasCompletedOnboarding = true
        isResolvingAccount = false
    }

    func beginAccountResolution(clearPersistedProfile: Bool = false) {
        isResolvingAccount = true
        if clearPersistedProfile {
            hasCompletedOnboarding = false
            currentUsername = ""
            currentCloudKitUserRecordName = ""
        }
    }

    func showOnboarding(for userRecordName: String) {
        currentCloudKitUserRecordName = userRecordName
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
        currentCloudKitUserRecordName = ""
        isResolvingAccount = false
    }

    func currentProfile(in profiles: [Profile]) -> Profile? {
        if !currentCloudKitUserRecordName.isEmpty,
           let profile = profiles.first(where: {
               $0.cloudKitUserRecordName == currentCloudKitUserRecordName
           }) {
            return profile
        }

        // One-release migration fallback for sessions created before the CloudKit identity key
        // was persisted. Deliberately do not fall back to `profiles.first`.
        guard !currentUsername.isEmpty else { return nil }
        return profiles.first(where: { $0.username == currentUsername })
    }
}
