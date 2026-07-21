import Foundation
import SwiftData

enum PublicSocialCacheStore {
    static func upsertSpot(_ dto: PublicSpotDTO, in context: ModelContext) -> Spot {
        if let existing = fetchSpot(publicRecordName: dto.recordName, in: context) {
            PublicRecordMapping.apply(dto, to: existing)
            return existing
        }

        if let existingByID = fetchSpot(id: dto.spotID, in: context) {
            PublicRecordMapping.apply(dto, to: existingByID)
            return existingByID
        }

        let spot = Spot()
        PublicRecordMapping.apply(dto, to: spot)
        context.insert(spot)
        return spot
    }

    static func upsertProfile(_ dto: PublicUserProfileDTO, in context: ModelContext) -> Profile {
        if let existing = fetchProfile(cloudKitUserRecordName: dto.userRecordName, in: context) {
            PublicRecordMapping.apply(dto, to: existing)
            return existing
        }

        let profile = Profile()
        PublicRecordMapping.apply(dto, to: profile)
        context.insert(profile)
        return profile
    }

    static func upsertFollow(_ dto: PublicFollowDTO, in context: ModelContext) {
        if fetchPublicFollow(recordName: dto.recordName, in: context) != nil {
            return
        }

        let follow = Follow()
        PublicRecordMapping.apply(dto, to: follow)
        context.insert(follow)
    }

    static func removeFollow(follower: String, followee: String, in context: ModelContext) {
        let recordName = PublicCloudKitSchema.followRecordName(follower: follower, followee: followee)
        if let follow = fetchPublicFollow(recordName: recordName, in: context) {
            context.delete(follow)
        }
    }

    static func syncFeedPage(_ page: PublicFeedPage, in context: ModelContext) {
        for dto in page.spots {
            _ = upsertSpot(dto, in: context)
        }
        try? context.save()
    }

    static func updateSocialCounts(
        for profile: Profile,
        counts: PublicSocialCounts,
        in context: ModelContext
    ) {
        profile.publicFollowerCount = counts.followers
        profile.publicFollowingCount = counts.following
        try? context.save()
    }

    static func publicFollowerCount(for userRecordName: String, in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Follow>(
            predicate: #Predicate { $0.isPublicSocialFollow && $0.followeeUserRecordName == userRecordName }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func publicFollowingCount(for userRecordName: String, in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Follow>(
            predicate: #Predicate { $0.isPublicSocialFollow && $0.followerUserRecordName == userRecordName }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func cachedPublicFeedSpots(in context: ModelContext) -> [Spot] {
        var descriptor = FetchDescriptor<Spot>(
            predicate: #Predicate { !$0.publicRecordName.isEmpty },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchSpot(publicRecordName: String, in context: ModelContext) -> Spot? {
        var descriptor = FetchDescriptor<Spot>(
            predicate: #Predicate { $0.publicRecordName == publicRecordName }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchSpot(id: UUID, in context: ModelContext) -> Spot? {
        var descriptor = FetchDescriptor<Spot>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchProfile(cloudKitUserRecordName: String, in context: ModelContext) -> Profile? {
        var descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.cloudKitUserRecordName == cloudKitUserRecordName }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchPublicFollow(recordName: String, in context: ModelContext) -> Follow? {
        let followerPrefix = recordName
        var descriptor = FetchDescriptor<Follow>(
            predicate: #Predicate { follow in
                follow.isPublicSocialFollow
                    && follow.followerUserRecordName != ""
                    && follow.followeeUserRecordName != ""
            }
        )
        let follows = (try? context.fetch(descriptor)) ?? []
        return follows.first {
            PublicCloudKitSchema.followRecordName(
                follower: $0.followerUserRecordName,
                followee: $0.followeeUserRecordName
            ) == followerPrefix
        }
    }
}
