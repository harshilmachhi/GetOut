import Foundation

/// Public CloudKit database access for the feed and public profiles.
/// UI depends on this protocol only — never on CloudKit types directly.
protocol CloudKitPublicService {
    func currentUserRecordName() async throws -> String?

    func publishSpot(_ spot: Spot, owner: Profile, ownerUserRecordName: String) async throws -> PublicSpotDTO
    func fetchPublicFeed(cursor: PublicFeedCursor?, pageSize: Int) async throws -> PublicFeedPage

    func upsertPublicProfile(_ profile: Profile, userRecordName: String) async throws -> PublicUserProfileDTO
    func fetchPublicProfile(userRecordName: String) async throws -> PublicUserProfileDTO?
    func fetchPublicProfile(username: String) async throws -> PublicUserProfileDTO?
    func deletePublicSpot(recordName: String) async throws
    func deleteAccountData(userRecordName: String) async throws
    func submitReport(_ draft: PublicReportDraft, reporterUserRecordName: String) async throws

}

enum CloudKitPublicServiceFactory {
    @MainActor
    static func makeLive() -> CloudKitPublicService {
        guard FeatureFlags.publicSocialEnabled, !FeatureFlags.isRunningTests else {
            return DisabledCloudKitPublicService()
        }
        return CloudKitPublicServiceLive()
    }

    @MainActor
    static func makeMock() -> CloudKitPublicService {
        MockCloudKitPublicService()
    }
}
