import Foundation
import Supabase

/// Supabase-backed public social API. The database schema and RLS policies live in
/// `supabase/migrations`; this client never embeds a privileged service-role key.
final class SupabasePublicService: PublicSocialService, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func currentUserRecordName() async throws -> String? {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        do {
            let session = try await client.auth.session
            guard !session.user.isAnonymous else {
                // Retire installation-scoped identities created by pre-account builds.
                try? await client.auth.signOut(scope: .local)
                return nil
            }
            return session.user.id.uuidString.lowercased()
        } catch {
            return nil
        }
    }

    func publishSpot(_ spot: Spot, owner: Profile, ownerUserRecordName: String) async throws -> PublicSpotDTO {
        guard let ownerID = UUID(uuidString: ownerUserRecordName) else { throw PublicSocialError.noAccount }
        let spotID = UUID(uuidString: spot.publicRecordName) ?? spot.id
        let photos = try await uploadPhotos(spot.allPhotoData, ownerID: ownerID, spotID: spotID)
        let tags = Array(Set((spot.tags?.map(\.name) ?? []) + spot.publicTagNames)).sorted()
        let payload = SpotWriteRow(
            id: spotID, ownerID: ownerID, title: spot.title, details: spot.details,
            latitude: spot.latitude, longitude: spot.longitude, address: spot.address,
            city: spot.city, neighborhood: spot.neighborhood, category: spot.category,
            rating: spot.rating, visitHour: spot.visitHour, visitWeekday: spot.visitWeekday,
            photoURLs: photos, tags: tags,
            containsCannabis: CannabisPolicy.containsCannabisTag(tags),
            countryCode: spot.countryCode, administrativeArea: spot.administrativeArea,
            createdAt: spot.createdAt
        )
        do {
            let row: SpotReadRow = try await client.from("spots")
                .upsert(payload, onConflict: "id")
                .select("*,profiles!spots_owner_id_fkey(display_name,username)")
                .single()
                .execute()
                .value
            return row.dto
        } catch { throw map(error) }
    }

    func fetchPublicFeed(cursor: PublicFeedCursor?, pageSize: Int) async throws -> PublicFeedPage {
        let start = PublicFeedPager.pageIndex(from: cursor) * pageSize
        do {
            let rows: [SpotReadRow] = try await client.from("spots")
                .select("*,profiles!spots_owner_id_fkey(display_name,username)")
                .order("created_at", ascending: false)
                .range(from: start, to: start + pageSize)
                .execute()
                .value
            let spots = rows.prefix(pageSize).map(\.dto)
            return PublicFeedPage(
                spots: spots,
                nextCursor: PublicFeedPager.nextCursor(
                    current: cursor, fetchedCount: spots.count, pageSize: pageSize,
                    hasMoreFromServer: rows.count > pageSize
                )
            )
        } catch { throw map(error) }
    }

    func upsertPublicProfile(_ profile: Profile, userRecordName: String) async throws -> PublicUserProfileDTO {
        guard let id = UUID(uuidString: userRecordName) else { throw PublicSocialError.noAccount }
        let payload = ProfileWriteRow(
            id: id,
            username: PublicContentPolicy.normalizedUsername(profile.username),
            displayName: profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: profile.bio.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarSystemImage: profile.avatarSystemImage,
            citiesVisited: profile.citiesVisited,
            preferredCategories: profile.preferredCategories,
            preferredTags: profile.preferredTags,
            createdAt: profile.createdAt
        )
        do {
            let row: ProfileRow = try await client.from("profiles").upsert(payload, onConflict: "id").select().single().execute().value
            return row.dto
        } catch { throw map(error) }
    }

    func fetchPublicProfile(userRecordName: String) async throws -> PublicUserProfileDTO? {
        do {
            let rows: [ProfileRow] = try await client.from("profiles").select().eq("id", value: userRecordName).limit(1).execute().value
            return rows.first?.dto
        } catch { throw map(error) }
    }

    func fetchPublicProfile(username: String) async throws -> PublicUserProfileDTO? {
        do {
            let rows: [ProfileRow] = try await client.from("profiles").select().eq("username", value: PublicContentPolicy.normalizedUsername(username)).limit(1).execute().value
            return rows.first?.dto
        } catch { throw map(error) }
    }

    func deletePublicSpot(recordName: String) async throws {
        do {
            if let spotID = UUID(uuidString: recordName),
               let userID = try? await client.auth.session.user.id {
                try? await removePhotos(ownerID: userID, spotIDs: [spotID])
            }
            try await client.from("spots").delete().eq("id", value: recordName).execute()
        }
        catch { throw map(error) }
    }

    func deleteAccountData(userRecordName: String) async throws {
        do {
            let rows: [OwnedSpotID] = try await client.from("spots").select("id").eq("owner_id", value: userRecordName).execute().value
            if let ownerID = UUID(uuidString: userRecordName) {
                try? await removePhotos(ownerID: ownerID, spotIDs: rows.map(\.id))
            }
            try await client.rpc("delete_my_account").execute()
            try? await client.auth.signOut(scope: .local)
        }
        catch { throw map(error) }
    }

    func submitReport(_ draft: PublicReportDraft, reporterUserRecordName: String) async throws {
        guard let reporterID = UUID(uuidString: reporterUserRecordName), let targetID = UUID(uuidString: draft.targetRecordName), let ownerID = UUID(uuidString: draft.targetOwnerUserRecordName) else { throw PublicSocialError.noAccount }
        do {
            try await client.from("reports").insert(ReportWriteRow(reporterID: reporterID, targetID: targetID, targetOwnerID: ownerID, targetKind: draft.targetKind.rawValue, reason: draft.reason.rawValue, details: draft.details)).execute()
        } catch { throw map(error) }
    }

    private func uploadPhotos(_ data: [Data], ownerID: UUID, spotID: UUID) async throws -> [String] {
        guard !data.isEmpty else { return [] }
        var urls: [String] = []
        for (index, image) in data.prefix(5).enumerated() {
            let path = "\(ownerID.uuidString.lowercased())/\(spotID.uuidString.lowercased())/\(index).jpg"
            do {
                try await client.storage.from("spot-photos").upload(path, data: image, options: FileOptions(contentType: "image/jpeg", upsert: true))
                urls.append(try client.storage.from("spot-photos").getPublicURL(path: path).absoluteString)
            } catch { throw PublicSocialError.partialFailure("Could not upload the spot photo.") }
        }
        return urls
    }

    private func removePhotos(ownerID: UUID, spotIDs: [UUID]) async throws {
        let owner = ownerID.uuidString.lowercased()
        let paths = spotIDs.flatMap { spotID in
            (0..<5).map { "\(owner)/\(spotID.uuidString.lowercased())/\($0).jpg" }
        }
        guard !paths.isEmpty else { return }
        _ = try await client.storage.from("spot-photos").remove(paths: paths)
    }

    private func map(_ error: Error) -> PublicSocialError {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("duplicate") { return .partialFailure("That username is already taken.") }
        if message.localizedCaseInsensitiveContains("network") { return .offline }
        return .underlying(message)
    }
}

private struct ProfileWriteRow: Encodable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let avatarSystemImage: String
    let citiesVisited: [String]
    let preferredCategories: [String]
    let preferredTags: [String]
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, username, bio; case displayName = "display_name"; case avatarSystemImage = "avatar_system_image"; case citiesVisited = "cities_visited"; case preferredCategories = "preferred_categories"; case preferredTags = "preferred_tags"; case createdAt = "created_at" }
}

private struct ProfileRow: Decodable {
    let id: UUID; let username: String; let displayName: String; let bio: String; let avatarSystemImage: String; let citiesVisited: [String]; let preferredCategories: [String]; let preferredTags: [String]; let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, username, bio; case displayName = "display_name"; case avatarSystemImage = "avatar_system_image"; case citiesVisited = "cities_visited"; case preferredCategories = "preferred_categories"; case preferredTags = "preferred_tags"; case createdAt = "created_at" }
    var dto: PublicUserProfileDTO { .init(recordName: id.uuidString, userRecordName: id.uuidString, username: username, displayName: displayName, bio: bio, avatarSystemImage: avatarSystemImage, citiesVisited: citiesVisited, preferredCategories: preferredCategories, preferredTags: preferredTags, createdAt: createdAt) }
}

private struct SpotWriteRow: Encodable {
    let id: UUID; let ownerID: UUID; let title: String; let details: String; let latitude: Double; let longitude: Double; let address: String; let city: String; let neighborhood: String; let category: String; let rating: Double; let visitHour: Int; let visitWeekday: Int; let photoURLs: [String]; let tags: [String]; let containsCannabis: Bool; let countryCode: String; let administrativeArea: String; let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, title, details, latitude, longitude, address, city, neighborhood, category, rating, tags; case ownerID = "owner_id"; case visitHour = "visit_hour"; case visitWeekday = "visit_weekday"; case photoURLs = "photo_urls"; case containsCannabis = "contains_cannabis"; case countryCode = "country_code"; case administrativeArea = "administrative_area"; case createdAt = "created_at" }
}

private struct SpotReadRow: Decodable {
    let id: UUID; let ownerID: UUID; let title: String; let details: String; let latitude: Double; let longitude: Double; let address: String; let city: String; let neighborhood: String; let category: String; let rating: Double; let visitHour: Int; let visitWeekday: Int; let photoURLs: [String]; let tags: [String]; let containsCannabis: Bool; let countryCode: String; let administrativeArea: String; let createdAt: Date; let profiles: OwnerRow?
    enum CodingKeys: String, CodingKey { case id, title, details, latitude, longitude, address, city, neighborhood, category, rating, tags, profiles; case ownerID = "owner_id"; case visitHour = "visit_hour"; case visitWeekday = "visit_weekday"; case photoURLs = "photo_urls"; case containsCannabis = "contains_cannabis"; case countryCode = "country_code"; case administrativeArea = "administrative_area"; case createdAt = "created_at" }
    var dto: PublicSpotDTO { .init(recordName: id.uuidString, spotID: id, title: title, details: details, latitude: latitude, longitude: longitude, address: address, city: city, neighborhood: neighborhood, category: category, rating: rating, visitHour: visitHour, visitWeekday: visitWeekday, photoData: photoURLs.compactMap { try? Data(contentsOf: URL(string: $0)!) }, createdAt: createdAt, ownerUserRecordName: ownerID.uuidString, ownerDisplayName: profiles?.displayName ?? "", ownerUsername: profiles?.username ?? "", tags: tags, containsCannabis: containsCannabis, countryCode: countryCode, administrativeArea: administrativeArea) }
}

private struct OwnerRow: Decodable { let displayName: String; let username: String; enum CodingKeys: String, CodingKey { case username; case displayName = "display_name" } }
private struct OwnedSpotID: Decodable { let id: UUID }
private struct ReportWriteRow: Encodable { let reporterID: UUID; let targetID: UUID; let targetOwnerID: UUID; let targetKind: String; let reason: String; let details: String; enum CodingKeys: String, CodingKey { case reason, details; case reporterID = "reporter_id"; case targetID = "target_id"; case targetOwnerID = "target_owner_id"; case targetKind = "target_kind" } }
