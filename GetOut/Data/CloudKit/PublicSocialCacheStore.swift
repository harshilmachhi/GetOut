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

    static func syncFeedPage(_ page: PublicFeedPage, in context: ModelContext) {
        for dto in page.spots {
            let spot = upsertSpot(dto, in: context)
            let owner = upsertProfile(
                PublicUserProfileDTO(
                    recordName: "profile-\(dto.ownerUserRecordName)",
                    userRecordName: dto.ownerUserRecordName,
                    username: dto.ownerUsername,
                    displayName: dto.ownerDisplayName,
                    bio: "",
                    avatarSystemImage: "person.fill",
                    createdAt: dto.createdAt
                ),
                in: context
            )
            spot.owner = owner
        }
        try? context.save()
    }

    /// Makes the local public-feed cache match CloudKit. This removes records that were
    /// deleted on another device instead of leaving them visible indefinitely.
    static func reconcilePublicFeed(_ spots: [PublicSpotDTO], in context: ModelContext) {
        let liveRecordNames = Set(spots.map(\.recordName))
        let descriptor = FetchDescriptor<Spot>(
            predicate: #Predicate { !$0.publicRecordName.isEmpty }
        )

        for spot in (try? context.fetch(descriptor)) ?? [] where !liveRecordNames.contains(spot.publicRecordName) {
            context.delete(spot)
        }

        syncFeedPage(PublicFeedPage(spots: spots, nextCursor: nil), in: context)
    }

    static func cachedPublicFeedSpots(
        in context: ModelContext,
        allowCannabis: Bool = false
    ) -> [Spot] {
        var descriptor = FetchDescriptor<Spot>(
            predicate: #Predicate { !$0.publicRecordName.isEmpty },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let blockedNames = Set(((try? context.fetch(FetchDescriptor<UserBlock>())) ?? []).map(\.blockedUserRecordName))
        return ((try? context.fetch(descriptor)) ?? []).filter { spot in
            !blockedNames.contains(spot.publisherUserRecordName)
                && (allowCannabis || !spot.containsCannabis)
        }
    }

    static func block(userRecordName: String, in context: ModelContext) {
        guard !userRecordName.isEmpty else { return }
        let existing = ((try? context.fetch(FetchDescriptor<UserBlock>())) ?? [])
            .contains { $0.blockedUserRecordName == userRecordName }
        guard !existing else { return }
        let block = UserBlock()
        block.blockedUserRecordName = userRecordName
        context.insert(block)
        try? context.save()
    }

    static func unblock(userRecordName: String, in context: ModelContext) {
        guard !userRecordName.isEmpty else { return }
        let blocks = (try? context.fetch(FetchDescriptor<UserBlock>())) ?? []
        for block in blocks where block.blockedUserRecordName == userRecordName {
            context.delete(block)
        }
        try? context.save()
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

}
