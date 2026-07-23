import Foundation

final class DisabledCloudKitPublicService: CloudKitPublicService {
    func currentUserRecordName() async throws -> String? { nil }

    func publishSpot(_ spot: Spot, owner: Profile, ownerUserRecordName: String) async throws -> PublicSpotDTO {
        throw PublicSocialError.disabled
    }

    func fetchPublicFeed(cursor: PublicFeedCursor?, pageSize: Int) async throws -> PublicFeedPage {
        throw PublicSocialError.disabled
    }

    func upsertPublicProfile(_ profile: Profile, userRecordName: String) async throws -> PublicUserProfileDTO {
        throw PublicSocialError.disabled
    }

    func fetchPublicProfile(userRecordName: String) async throws -> PublicUserProfileDTO? {
        nil
    }

    func fetchPublicProfile(username: String) async throws -> PublicUserProfileDTO? { nil }

    func deletePublicSpot(recordName: String) async throws { throw PublicSocialError.disabled }

    func deleteAccountData(userRecordName: String) async throws { throw PublicSocialError.disabled }

    func submitReport(_ draft: PublicReportDraft, reporterUserRecordName: String) async throws {
        throw PublicSocialError.disabled
    }

    func follow(userRecordName: String, currentUserRecordName: String) async throws {
        throw PublicSocialError.disabled
    }

    func unfollow(userRecordName: String, currentUserRecordName: String) async throws {
        throw PublicSocialError.disabled
    }

    func isFollowing(userRecordName: String, currentUserRecordName: String) async throws -> Bool {
        false
    }

    func fetchFollowers(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage {
        PublicFollowListPage(profiles: [], nextCursor: nil)
    }

    func fetchFollowing(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage {
        PublicFollowListPage(profiles: [], nextCursor: nil)
    }

    func socialCounts(for userRecordName: String) async throws -> PublicSocialCounts {
        PublicSocialCounts(followers: 0, following: 0)
    }
}
