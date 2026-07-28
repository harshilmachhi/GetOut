import Foundation

@MainActor
final class MockCloudKitPublicService: CloudKitPublicService, @unchecked Sendable {
    var currentUserRecordNameValue: String? = "mock-user-1"
    var spots: [PublicSpotDTO] = []
    var profiles: [String: PublicUserProfileDTO] = [:]
    var shouldFail = false

    func currentUserRecordName() async throws -> String? {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        if shouldFail { throw PublicSocialError.offline }
        return currentUserRecordNameValue
    }

    func publishSpot(_ spot: Spot, owner: Profile, ownerUserRecordName: String) async throws -> PublicSpotDTO {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let dto = PublicSpotDTO(
            recordName: "spot-\(spot.id.uuidString)",
            spotID: spot.id,
            title: spot.title,
            details: spot.details,
            latitude: spot.latitude,
            longitude: spot.longitude,
            address: spot.address,
            city: spot.city,
            neighborhood: spot.neighborhood,
            category: spot.category,
            rating: spot.rating,
            photoData: spot.allPhotoData,
            createdAt: spot.createdAt,
            ownerUserRecordName: ownerUserRecordName,
            ownerDisplayName: owner.displayName,
            ownerUsername: owner.username,
            tags: Array(Set((spot.tags?.map(\.name) ?? []) + spot.publicTagNames)).sorted(),
            containsCannabis: spot.containsCannabis,
            countryCode: spot.countryCode,
            administrativeArea: spot.administrativeArea
        )
        spots.insert(dto, at: 0)
        return dto
    }

    func fetchPublicFeed(cursor: PublicFeedCursor?, pageSize: Int) async throws -> PublicFeedPage {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let start = PublicFeedPager.pageIndex(from: cursor) * pageSize
        let end = min(start + pageSize, spots.count)
        guard start < spots.count else {
            return PublicFeedPage(spots: [], nextCursor: nil)
        }
        let slice = Array(spots[start..<end])
        let hasMore = end < spots.count
        return PublicFeedPage(
            spots: slice,
            nextCursor: PublicFeedPager.nextCursor(
                current: cursor,
                fetchedCount: slice.count,
                pageSize: pageSize,
                hasMoreFromServer: hasMore
            )
        )
    }

    func upsertPublicProfile(_ profile: Profile, userRecordName: String) async throws -> PublicUserProfileDTO {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        if profiles.values.contains(where: {
            $0.userRecordName != userRecordName
                && $0.username.caseInsensitiveCompare(profile.username) == .orderedSame
        }) {
            throw PublicSocialError.partialFailure("That username is already taken.")
        }
        let dto = PublicUserProfileDTO(
            recordName: "profile-\(userRecordName)",
            userRecordName: userRecordName,
            username: profile.username,
            displayName: profile.displayName,
            bio: profile.bio,
            avatarSystemImage: profile.avatarSystemImage,
            createdAt: profile.createdAt
        )
        profiles[userRecordName] = dto
        return dto
    }

    func fetchPublicProfile(userRecordName: String) async throws -> PublicUserProfileDTO? {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        return profiles[userRecordName]
    }

    func fetchPublicProfile(username: String) async throws -> PublicUserProfileDTO? {
        profiles.values.first { $0.username.caseInsensitiveCompare(username) == .orderedSame }
    }

    func deletePublicSpot(recordName: String) async throws {
        spots.removeAll { $0.recordName == recordName }
    }

    func deleteAccountData(userRecordName: String) async throws {
        profiles.removeValue(forKey: userRecordName)
        spots.removeAll { $0.ownerUserRecordName == userRecordName }
    }

    func submitReport(_ draft: PublicReportDraft, reporterUserRecordName: String) async throws {
        if shouldFail { throw PublicSocialError.offline }
    }

}
