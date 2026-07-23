import Foundation

@MainActor
final class MockCloudKitPublicService: CloudKitPublicService, @unchecked Sendable {
    var currentUserRecordNameValue: String? = "mock-user-1"
    var spots: [PublicSpotDTO] = []
    var profiles: [String: PublicUserProfileDTO] = [:]
    var follows: Set<String> = []
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
        follows = follows.filter { !$0.contains(userRecordName) }
    }

    func submitReport(_ draft: PublicReportDraft, reporterUserRecordName: String) async throws {
        if shouldFail { throw PublicSocialError.offline }
    }

    func follow(userRecordName: String, currentUserRecordName: String) async throws {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        follows.insert(PublicCloudKitSchema.followRecordName(follower: currentUserRecordName, followee: userRecordName))
    }

    func unfollow(userRecordName: String, currentUserRecordName: String) async throws {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        follows.remove(PublicCloudKitSchema.followRecordName(follower: currentUserRecordName, followee: userRecordName))
    }

    func isFollowing(userRecordName: String, currentUserRecordName: String) async throws -> Bool {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        return follows.contains(PublicCloudKitSchema.followRecordName(follower: currentUserRecordName, followee: userRecordName))
    }

    func fetchFollowers(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage {
        try await followList(for: userRecordName, cursor: cursor, pageSize: pageSize, followers: true)
    }

    func fetchFollowing(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage {
        try await followList(for: userRecordName, cursor: cursor, pageSize: pageSize, followers: false)
    }

    func socialCounts(for userRecordName: String) async throws -> PublicSocialCounts {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        var followers = 0
        var following = 0
        for key in follows {
            guard key.hasPrefix("follow-") else { continue }
            let remainder = String(key.dropFirst("follow-".count))
            let parts = remainder.split(separator: "-", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[1] == userRecordName { followers += 1 }
            if parts[0] == userRecordName { following += 1 }
        }
        return PublicSocialCounts(followers: followers, following: following)
    }

    private func followList(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int,
        followers: Bool
    ) async throws -> PublicFollowListPage {
        let keys = follows.filter { key in
            if followers {
                key.hasSuffix("-\(userRecordName)")
            } else {
                key.hasPrefix("follow-\(userRecordName)-")
            }
        }.sorted()
        let start = cursor.flatMap { PublicFeedPager.pageIndex(from: PublicFeedCursor(token: $0.token)) * pageSize } ?? 0
        let end = min(start + pageSize, keys.count)
        let slice = start < keys.count ? Array(keys[start..<end]) : []
        let listedProfiles = slice.compactMap { key -> PublicUserProfileDTO? in
            let otherName: String
            if followers {
                otherName = key.replacingOccurrences(of: "follow-", with: "").components(separatedBy: "-").first ?? ""
            } else {
                otherName = key.replacingOccurrences(of: "follow-\(userRecordName)-", with: "")
            }
            return profiles[otherName] ?? PublicUserProfileDTO(
                recordName: "profile-\(otherName)",
                userRecordName: otherName,
                username: otherName,
                displayName: otherName,
                bio: "",
                avatarSystemImage: "person.fill",
                createdAt: .now
            )
        }
        let hasMore = end < keys.count
        return PublicFollowListPage(
            profiles: listedProfiles,
            nextCursor: hasMore ? PublicFollowListCursor(token: "page-\(start / pageSize + 1)") : nil
        )
    }
}
