import Foundation
import Supabase
import SwiftData

/// Persists account-private app state. SwiftData remains the responsive local cache while
/// every user action is written through to a table protected by RLS.
@MainActor
final class SupabasePrivateDataService {
    static let shared = SupabasePrivateDataService()

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func pullRemoteState(in context: ModelContext, profile: Profile) async throws {
        async let likes: [LikeRow] = client.from("likes").select().execute().value
        async let saves: [SaveRow] = client.from("saves").select().execute().value
        async let ratings: [RatingRow] = client.from("ratings").select().eq("user_id", value: profile.supabaseUserID).execute().value
        async let trips: [TripRow] = client.from("trips").select().execute().value
        async let stops: [TripStopRow] = client.from("trip_stops").select().execute().value
        async let blocks: [BlockRow] = client.from("user_blocks").select().execute().value
        async let interactions: [InteractionRow] = client.from("interactions").select().order("created_at", ascending: false).limit(500).execute().value

        let snapshot = try await (likes, saves, ratings, trips, stops, blocks, interactions)
        let spots = Dictionary(uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Spot>())) ?? []).map { ($0.id, $0) })

        replace(profile.likes ?? [], with: snapshot.0, in: context) { row in
            guard let spot = spots[row.spotID] else { return nil }
            let value = Like(); value.id = row.id; value.createdAt = row.createdAt; value.user = profile; value.spot = spot
            return value
        }
        replace(profile.saves ?? [], with: snapshot.1, in: context) { row in
            guard let spot = spots[row.spotID] else { return nil }
            let value = Save(); value.id = row.id; value.createdAt = row.createdAt; value.list = row.list; value.user = profile; value.spot = spot
            return value
        }
        replace(profile.ratings ?? [], with: snapshot.2, in: context) { row in
            guard let spot = spots[row.spotID] else { return nil }
            let value = Rating(); value.id = row.id; value.stars = row.stars; value.createdAt = row.createdAt; value.updatedAt = row.updatedAt; value.user = profile; value.spot = spot
            return value
        }

        for oldTrip in profile.trips ?? [] { context.delete(oldTrip) }
        var localTrips: [UUID: Trip] = [:]
        for row in snapshot.3 {
            let value = Trip()
            value.id = row.id; value.title = row.title; value.summary = row.summary
            value.planSummary = row.planSummary; value.startDate = row.startDate; value.endDate = row.endDate
            value.coverSystemImage = row.coverSystemImage; value.owner = profile
            context.insert(value); localTrips[row.id] = value
        }
        for row in snapshot.4 {
            guard let trip = localTrips[row.tripID], let spot = spots[row.spotID] else { continue }
            let value = TripStop()
            value.id = row.id; value.dayIndex = row.dayIndex; value.order = row.sortOrder
            value.notes = row.notes; value.trip = trip; value.spot = spot
            context.insert(value)
        }

        for value in (try? context.fetch(FetchDescriptor<UserBlock>())) ?? [] { context.delete(value) }
        for row in snapshot.5 {
            let value = UserBlock(); value.id = row.id; value.blockedUserRecordName = row.blockedUserID.uuidString.lowercased(); value.createdAt = row.createdAt
            context.insert(value)
        }
        replace(profile.interactions ?? [], with: snapshot.6, in: context) { row in
            guard let spot = spots[row.spotID] else { return nil }
            let value = Interaction(); value.id = row.id; value.event = row.event
            value.contextCity = row.contextCity; value.createdAt = row.createdAt
            value.user = profile; value.spot = spot
            return value
        }
        try context.save()
    }

    func setLike(_ like: Like?, spotID: UUID, userID: UUID) async throws {
        if let like {
            try await client.from("likes").upsert(LikeWriteRow(id: like.id, userID: userID, spotID: spotID, createdAt: like.createdAt), onConflict: "user_id,spot_id").execute()
        } else {
            try await client.from("likes").delete().eq("user_id", value: userID).eq("spot_id", value: spotID).execute()
        }
    }

    func setSave(_ save: Save?, spotID: UUID, userID: UUID, list: String) async throws {
        if let save {
            try await client.from("saves").upsert(SaveWriteRow(id: save.id, userID: userID, spotID: spotID, list: list, createdAt: save.createdAt), onConflict: "user_id,spot_id,list").execute()
        } else {
            try await client.from("saves").delete().eq("user_id", value: userID).eq("spot_id", value: spotID).eq("list", value: list).execute()
        }
    }

    func setRating(_ rating: Rating?, spotID: UUID, userID: UUID) async throws {
        if let rating {
            try await client.from("ratings").upsert(RatingWriteRow(id: rating.id, userID: userID, spotID: spotID, stars: rating.stars, createdAt: rating.createdAt), onConflict: "user_id,spot_id").execute()
        } else {
            try await client.from("ratings").delete().eq("user_id", value: userID).eq("spot_id", value: spotID).execute()
        }
    }

    func upsertTrip(_ trip: Trip, userID: UUID) async throws {
        try await client.from("trips").upsert(TripWriteRow(trip: trip, ownerID: userID), onConflict: "id").execute()
    }

    func deleteTrip(id: UUID) async throws {
        try await client.from("trips").delete().eq("id", value: id).execute()
    }

    func upsertTripStop(_ stop: TripStop) async throws {
        guard let tripID = stop.trip?.id, let spotID = stop.spot?.id else { return }
        try await client.from("trip_stops").upsert(TripStopWriteRow(stop: stop, tripID: tripID, spotID: spotID), onConflict: "trip_id,spot_id").execute()
    }

    func deleteTripStop(id: UUID) async throws {
        try await client.from("trip_stops").delete().eq("id", value: id).execute()
    }

    func recordInteraction(_ interaction: Interaction, userID: UUID, spotID: UUID) async throws {
        try await client.from("interactions").insert(InteractionWriteRow(interaction: interaction, userID: userID, spotID: spotID)).execute()
    }

    func setBlock(blockedUserID: UUID, blockerID: UUID, isBlocked: Bool) async throws {
        if isBlocked {
            try await client.from("user_blocks").upsert(BlockWriteRow(blockerID: blockerID, blockedUserID: blockedUserID), onConflict: "blocker_id,blocked_user_id").execute()
        } else {
            try await client.from("user_blocks").delete().eq("blocker_id", value: blockerID).eq("blocked_user_id", value: blockedUserID).execute()
        }
    }

    private func replace<Local: PersistentModel, Remote>(
        _ local: [Local], with remote: [Remote], in context: ModelContext,
        make: (Remote) -> Local?
    ) {
        for value in local { context.delete(value) }
        for row in remote { if let value = make(row) { context.insert(value) } }
    }
}

private struct LikeRow: Decodable { let id: UUID; let spotID: UUID; let createdAt: Date; enum CodingKeys: String, CodingKey { case id; case spotID = "spot_id"; case createdAt = "created_at" } }
private struct SaveRow: Decodable { let id: UUID; let spotID: UUID; let list: String; let createdAt: Date; enum CodingKeys: String, CodingKey { case id, list; case spotID = "spot_id"; case createdAt = "created_at" } }
private struct RatingRow: Decodable { let id: UUID; let spotID: UUID; let stars: Int; let createdAt: Date; let updatedAt: Date; enum CodingKeys: String, CodingKey { case id, stars; case spotID = "spot_id"; case createdAt = "created_at"; case updatedAt = "updated_at" } }
private struct TripRow: Decodable { let id: UUID; let title: String; let summary: String; let planSummary: String; let startDate: Date?; let endDate: Date?; let coverSystemImage: String; enum CodingKeys: String, CodingKey { case id, title, summary; case planSummary = "plan_summary"; case startDate = "start_date"; case endDate = "end_date"; case coverSystemImage = "cover_system_image" } }
private struct TripStopRow: Decodable { let id: UUID; let tripID: UUID; let spotID: UUID; let dayIndex: Int; let sortOrder: Int; let notes: String; enum CodingKeys: String, CodingKey { case id, notes; case tripID = "trip_id"; case spotID = "spot_id"; case dayIndex = "day_index"; case sortOrder = "sort_order" } }
private struct BlockRow: Decodable { let id: UUID; let blockedUserID: UUID; let createdAt: Date; enum CodingKeys: String, CodingKey { case id; case blockedUserID = "blocked_user_id"; case createdAt = "created_at" } }
private struct InteractionRow: Decodable { let id: UUID; let spotID: UUID; let event: String; let contextCity: String; let createdAt: Date; enum CodingKeys: String, CodingKey { case id, event; case spotID = "spot_id"; case contextCity = "context_city"; case createdAt = "created_at" } }

private struct LikeWriteRow: Encodable { let id: UUID; let userID: UUID; let spotID: UUID; let createdAt: Date; enum CodingKeys: String, CodingKey { case id; case userID = "user_id"; case spotID = "spot_id"; case createdAt = "created_at" } }
private struct SaveWriteRow: Encodable { let id: UUID; let userID: UUID; let spotID: UUID; let list: String; let createdAt: Date; enum CodingKeys: String, CodingKey { case id, list; case userID = "user_id"; case spotID = "spot_id"; case createdAt = "created_at" } }
private struct RatingWriteRow: Encodable { let id: UUID; let userID: UUID; let spotID: UUID; let stars: Int; let createdAt: Date; enum CodingKeys: String, CodingKey { case id, stars; case userID = "user_id"; case spotID = "spot_id"; case createdAt = "created_at" } }
private struct TripWriteRow: Encodable {
    let id: UUID; let ownerID: UUID; let title: String; let summary: String; let planSummary: String; let startDate: Date?; let endDate: Date?; let coverSystemImage: String
    init(trip: Trip, ownerID: UUID) { id = trip.id; self.ownerID = ownerID; title = trip.title; summary = trip.summary; planSummary = trip.planSummary; startDate = trip.startDate; endDate = trip.endDate; coverSystemImage = trip.coverSystemImage }
    enum CodingKeys: String, CodingKey { case id, title, summary; case ownerID = "owner_id"; case planSummary = "plan_summary"; case startDate = "start_date"; case endDate = "end_date"; case coverSystemImage = "cover_system_image" }
}
private struct TripStopWriteRow: Encodable {
    let id: UUID; let tripID: UUID; let spotID: UUID; let dayIndex: Int; let sortOrder: Int; let notes: String
    init(stop: TripStop, tripID: UUID, spotID: UUID) { id = stop.id; self.tripID = tripID; self.spotID = spotID; dayIndex = stop.dayIndex; sortOrder = stop.order; notes = stop.notes }
    enum CodingKeys: String, CodingKey { case id, notes; case tripID = "trip_id"; case spotID = "spot_id"; case dayIndex = "day_index"; case sortOrder = "sort_order" }
}
private struct InteractionWriteRow: Encodable {
    let id: UUID; let userID: UUID; let spotID: UUID; let event: String; let contextCity: String; let createdAt: Date
    init(interaction: Interaction, userID: UUID, spotID: UUID) { id = interaction.id; self.userID = userID; self.spotID = spotID; event = interaction.event; contextCity = interaction.contextCity; createdAt = interaction.createdAt }
    enum CodingKeys: String, CodingKey { case id, event; case userID = "user_id"; case spotID = "spot_id"; case contextCity = "context_city"; case createdAt = "created_at" }
}
private struct BlockWriteRow: Encodable { let blockerID: UUID; let blockedUserID: UUID; enum CodingKeys: String, CodingKey { case blockerID = "blocker_id"; case blockedUserID = "blocked_user_id" } }
