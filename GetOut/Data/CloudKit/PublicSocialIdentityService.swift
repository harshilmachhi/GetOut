import CloudKit
import Foundation

/// Resolves and links the canonical iCloud identity for a GetOut profile.
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
}
