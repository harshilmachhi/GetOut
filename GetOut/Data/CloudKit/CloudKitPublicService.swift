import Foundation

/// Public CloudKit database access for social feed, profiles, and following.
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

    func follow(userRecordName: String, currentUserRecordName: String) async throws
    func unfollow(userRecordName: String, currentUserRecordName: String) async throws
    func isFollowing(userRecordName: String, currentUserRecordName: String) async throws -> Bool

    func fetchFollowers(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage

    func fetchFollowing(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage

    func socialCounts(for userRecordName: String) async throws -> PublicSocialCounts
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
