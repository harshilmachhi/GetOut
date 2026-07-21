import AuthenticationServices
import CloudKit
import Foundation

/// Resolves the current CloudKit user and optionally scaffolds Sign in with Apple for display names.
@MainActor
enum PublicSocialIdentityService {
    private static let container = SwiftDataCloudKitBridge.ckContainer

    static func resolveCurrentUserRecordName() async -> String? {
        guard FeatureFlags.publicSocialEnabled else { return nil }
        do {
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch {
            return nil
        }
    }

    /// Links the resolved CloudKit identity to the local SwiftData profile.
    static func linkIdentity(to profile: Profile, userRecordName: String) {
        profile.cloudKitUserRecordName = userRecordName
    }

    /// Stub for Sign in with Apple — full auth flow requires a paid developer account and entitlements.
    /// Call sites can use `SignInWithAppleButton` when enabled; this helper only formats a handle.
    static func suggestedHandle(from credential: ASAuthorizationAppleIDCredential) -> String {
        if let email = credential.email {
            return email.components(separatedBy: "@").first ?? "user"
        }
        return "user-\(credential.user.prefix(6))"
    }
}
