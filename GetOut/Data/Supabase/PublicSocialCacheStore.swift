import Foundation
import SwiftData

enum PublicSocialCacheStore {
    static func upsertSpot(_ dto: PublicSpotDTO, in context: ModelContext) -> Spot {
        if let existing = fetchSpot(publicRecordName: dto.recordName, in: context) {
            apply(dto, to: existing)
            return existing
        }

        if let existingByID = fetchSpot(id: dto.spotID, in: context) {
            apply(dto, to: existingByID)
            return existingByID
        }

        let spot = Spot()
        apply(dto, to: spot)
        context.insert(spot)
        return spot
    }

    static func upsertProfile(_ dto: PublicUserProfileDTO, in context: ModelContext) -> Profile {
        if let existing = fetchProfile(supabaseUserID: dto.userRecordName, in: context) {
            apply(dto, to: existing)
            return existing
        }

        let profile = Profile()
        apply(dto, to: profile)
        context.insert(profile)
        return profile
    }

    static func syncFeedPage(_ page: PublicFeedPage, in context: ModelContext) {
        for dto in page.spots {
            let spot = upsertSpot(dto, in: context)
            let owner: Profile
            if let cachedOwner = fetchProfile(supabaseUserID: dto.ownerUserRecordName, in: context) {
                cachedOwner.username = dto.ownerUsername
                cachedOwner.displayName = dto.ownerDisplayName
                owner = cachedOwner
            } else {
                let newOwner = Profile()
                newOwner.supabaseUserID = dto.ownerUserRecordName
                newOwner.username = dto.ownerUsername
                newOwner.displayName = dto.ownerDisplayName
                newOwner.createdAt = dto.createdAt
                context.insert(newOwner)
                owner = newOwner
            }
            spot.owner = owner
        }
        try? context.save()
    }

    /// Makes the local public-feed cache match Supabase. This removes records that were
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
        let descriptor = FetchDescriptor<Spot>(
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

    static func apply(_ dto: PublicSpotDTO, to spot: Spot) {
        spot.id = dto.spotID
        spot.title = dto.title
        spot.details = dto.details
        spot.latitude = dto.latitude
        spot.longitude = dto.longitude
        spot.address = dto.address
        spot.city = dto.city
        spot.neighborhood = dto.neighborhood
        spot.category = dto.category
        spot.rating = dto.rating
        spot.visitHour = dto.visitHour
        spot.visitWeekday = dto.visitWeekday
        spot.photoData = dto.photoData.indices.contains(0) ? dto.photoData[0] : nil
        spot.photoData2 = dto.photoData.indices.contains(1) ? dto.photoData[1] : nil
        spot.photoData3 = dto.photoData.indices.contains(2) ? dto.photoData[2] : nil
        spot.photoData4 = dto.photoData.indices.contains(3) ? dto.photoData[3] : nil
        spot.photoData5 = dto.photoData.indices.contains(4) ? dto.photoData[4] : nil
        spot.createdAt = dto.createdAt
        spot.publicRecordName = dto.recordName
        spot.publisherUserRecordName = dto.ownerUserRecordName
        spot.publicTagNames = dto.tags
        spot.containsCannabis = dto.containsCannabis
        spot.countryCode = dto.countryCode
        spot.administrativeArea = dto.administrativeArea
    }

    static func apply(_ dto: PublicUserProfileDTO, to profile: Profile) {
        profile.supabaseUserID = dto.userRecordName
        profile.username = dto.username
        profile.displayName = dto.displayName
        profile.bio = dto.bio
        profile.avatarSystemImage = dto.avatarSystemImage
        profile.citiesVisited = dto.citiesVisited
        profile.preferredCategories = dto.preferredCategories
        profile.preferredTags = dto.preferredTags
        profile.createdAt = dto.createdAt
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

    private static func fetchProfile(supabaseUserID: String, in context: ModelContext) -> Profile? {
        var descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.supabaseUserID == supabaseUserID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

}
