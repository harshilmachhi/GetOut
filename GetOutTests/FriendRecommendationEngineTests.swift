@testable import GetOut
import XCTest

final class FriendRecommendationEngineTests: XCTestCase {
    private let harshilID = UUID()
    private let mayaID = UUID()
    private let alexID = UUID()
    private let jordanID = UUID()
    private let samID = UUID()

    func testPreferenceSimilarityUsesJaccardOverlap() {
        let harshil = profile(
            id: harshilID,
            username: "harshil",
            displayName: "Harshil",
            categories: ["views", "nature"],
            tags: ["sunset", "quiet"],
            likedTags: ["view"]
        )
        let alex = profile(
            id: alexID,
            username: "alex",
            displayName: "Alex Rivera",
            categories: ["nature", "views"],
            tags: ["sunset", "weed-friendly", "quiet"],
            likedTags: []
        )

        let similarity = FriendRecommendationEngine.preferenceSimilarity(between: harshil, and: alex)
        XCTAssertGreaterThan(similarity, 0.5)
    }

    func testContactsMatchBoostsCandidate() {
        let maya = profile(
            id: mayaID,
            username: "maya",
            displayName: "Maya Chen",
            categories: ["coffee"],
            tags: ["cozy"],
            likedTags: []
        )

        XCTAssertTrue(
            FriendRecommendationEngine.contactsMatch(
                candidate: maya,
                contactNames: ["maya chen", "work group"]
            )
        )
    }

    func testMutualFriendsIncreaseScore() {
        let harshil = profile(
            id: harshilID,
            username: "harshil",
            displayName: "Harshil",
            categories: ["views"],
            tags: ["sunset"],
            likedTags: []
        )
        let maya = profile(
            id: mayaID,
            username: "maya",
            displayName: "Maya Chen",
            categories: ["coffee"],
            tags: ["cozy"],
            likedTags: []
        )
        let alex = profile(
            id: alexID,
            username: "alex",
            displayName: "Alex Rivera",
            categories: ["nature"],
            tags: ["quiet"],
            likedTags: []
        )

        let follows = [
            (followerID: harshilID, followeeID: jordanID),
            (followerID: alexID, followeeID: jordanID),
            (followerID: mayaID, followeeID: alexID),
        ]

        let suggestions = FriendRecommendationEngine.rank(
            currentUser: harshil,
            candidates: [maya, alex],
            follows: follows
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].profile.id, alexID)
        XCTAssertTrue(suggestions[0].reasons.contains("1 mutual friend"))
    }

    func testRankExcludesCurrentUserAndZeroScoreCandidates() {
        let harshil = profile(
            id: harshilID,
            username: "harshil",
            displayName: "Harshil",
            categories: ["views"],
            tags: ["sunset"],
            likedTags: []
        )
        let unrelated = profile(
            id: samID,
            username: "sam",
            displayName: "Sam Patel",
            categories: ["nightlife"],
            tags: ["late-night"],
            likedTags: []
        )

        let suggestions = FriendRecommendationEngine.rank(
            currentUser: harshil,
            candidates: [harshil, unrelated],
            follows: []
        )

        XCTAssertTrue(suggestions.isEmpty)
    }

    func testSimilarTasteReasonAppearsForStrongOverlap() {
        let harshil = profile(
            id: harshilID,
            username: "harshil",
            displayName: "Harshil",
            categories: ["views", "nature"],
            tags: ["sunset", "quiet", "weed-friendly"],
            likedTags: []
        )
        let alex = profile(
            id: alexID,
            username: "alex",
            displayName: "Alex Rivera",
            categories: ["nature", "views"],
            tags: ["sunset", "quiet", "weed-friendly"],
            likedTags: []
        )

        let suggestions = FriendRecommendationEngine.rank(
            currentUser: harshil,
            candidates: [alex],
            follows: []
        )

        XCTAssertEqual(suggestions.first?.reasons, ["Similar taste"])
    }

    private func profile(
        id: UUID,
        username: String,
        displayName: String,
        categories: [String],
        tags: [String],
        likedTags: [String]
    ) -> FriendRecommendationProfile {
        FriendRecommendationProfile(
            id: id,
            username: username,
            displayName: displayName,
            preferredCategories: categories,
            preferredTags: tags,
            likedSpotTags: likedTags
        )
    }
}
