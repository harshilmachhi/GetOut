import SwiftData
import XCTest
@testable import GetOut

@MainActor
final class SupabaseMappingTests: XCTestCase {
    func testSpotDTOMapsIntoOfflineCache() throws {
        let container = try ModelContainer(
            for: Profile.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dto = PublicSpotDTO(
            recordName: UUID().uuidString,
            spotID: UUID(),
            title: "Sunset point",
            details: "A view",
            latitude: 43.65,
            longitude: -79.38,
            address: "Toronto",
            city: "Toronto",
            neighborhood: "Downtown",
            category: SpotCategory.views.rawValue,
            rating: 4.5,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            ownerUserRecordName: UUID().uuidString,
            ownerDisplayName: "Alex",
            ownerUsername: "alex",
            tags: ["scenic"],
            countryCode: "CA",
            administrativeArea: "ON"
        )

        let spot = PublicSocialCacheStore.upsertSpot(dto, in: container.mainContext)

        XCTAssertEqual(spot.id, dto.spotID)
        XCTAssertEqual(spot.title, "Sunset point")
        XCTAssertEqual(spot.publicTagNames, ["scenic"])
        XCTAssertEqual(spot.publisherUserRecordName, dto.ownerUserRecordName)
    }

    func testProfileDTOMapsSupabaseIdentityAndPreferences() throws {
        let container = try ModelContainer(
            for: Profile.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let userID = UUID().uuidString.lowercased()
        let dto = PublicUserProfileDTO(
            recordName: userID,
            userRecordName: userID,
            username: "alex",
            displayName: "Alex",
            bio: "Explorer",
            avatarSystemImage: "person.fill",
            citiesVisited: ["Toronto"],
            preferredCategories: ["coffee"],
            preferredTags: ["quiet"],
            createdAt: .now
        )

        let profile = PublicSocialCacheStore.upsertProfile(dto, in: container.mainContext)

        XCTAssertEqual(profile.supabaseUserID, userID)
        XCTAssertEqual(profile.preferredCategories, ["coffee"])
        XCTAssertEqual(profile.preferredTags, ["quiet"])
    }

    func testSessionSelectsProfileBySupabaseIdentity() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "session.hasCompletedOnboarding")
        defaults.removeObject(forKey: "session.currentUsername")
        defaults.removeObject(forKey: "session.currentSupabaseUserID")

        let unrelated = Profile()
        unrelated.username = "same_name"
        unrelated.supabaseUserID = UUID().uuidString
        let current = Profile()
        current.username = "same_name"
        current.supabaseUserID = UUID().uuidString

        let session = SessionStore()
        session.completeOnboarding(username: current.username, userRecordName: current.supabaseUserID)

        XCTAssertTrue(session.currentProfile(in: [unrelated, current]) === current)
    }
}
