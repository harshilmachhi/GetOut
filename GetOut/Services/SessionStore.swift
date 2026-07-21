import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private enum Keys {
        static let isAuthenticated = "session.isAuthenticated"
        static let hasCompletedOnboarding = "session.hasCompletedOnboarding"
        static let currentUsername = "session.currentUsername"
        static let appleUserID = "session.appleUserID"
        static let phoneNumber = "session.phoneNumber"
    }

    var isAuthenticated: Bool {
        didSet { UserDefaults.standard.set(isAuthenticated, forKey: Keys.isAuthenticated) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var currentUsername: String {
        didSet { UserDefaults.standard.set(currentUsername, forKey: Keys.currentUsername) }
    }

    var pendingDisplayName: String = ""
    var pendingUsername: String = ""

    init() {
        let defaults = UserDefaults.standard
        isAuthenticated = defaults.bool(forKey: Keys.isAuthenticated)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        currentUsername = defaults.string(forKey: Keys.currentUsername) ?? ""
    }

    func signInAsGuest() {
        isAuthenticated = true
        hasCompletedOnboarding = true
        currentUsername = "harshil"
    }

    func signInAsDemo() {
        signInAsGuest()
    }

    func completeSignInWithApple(credential: ASAuthorizationAppleIDCredential) {
        UserDefaults.standard.set(credential.user, forKey: Keys.appleUserID)

        if let given = credential.fullName?.givenName {
            let family = credential.fullName?.familyName ?? ""
            pendingDisplayName = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        }
        pendingUsername = PublicSocialIdentityService.suggestedHandle(from: credential)

        isAuthenticated = true
        hasCompletedOnboarding = false
        currentUsername = ""
    }

    /// Local phone sign-up (no SMS backend yet). Starts onboarding for a new account.
    func beginSignInWithPhone(phoneNumber: String) {
        let digits = phoneNumber.filter(\.isNumber)
        UserDefaults.standard.set(phoneNumber, forKey: Keys.phoneNumber)
        pendingDisplayName = ""
        pendingUsername = digits.isEmpty ? "explorer" : "user\(String(digits.suffix(4)))"
        isAuthenticated = true
        hasCompletedOnboarding = false
        currentUsername = ""
    }

    func completeOnboarding(username: String) {
        currentUsername = username
        hasCompletedOnboarding = true
        pendingDisplayName = ""
        pendingUsername = ""
    }

    func signOut() {
        isAuthenticated = false
        hasCompletedOnboarding = false
        currentUsername = ""
        pendingDisplayName = ""
        pendingUsername = ""
        UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
        UserDefaults.standard.removeObject(forKey: Keys.phoneNumber)
    }
}
