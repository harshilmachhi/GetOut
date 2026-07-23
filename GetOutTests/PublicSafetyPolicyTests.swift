@testable import GetOut
import XCTest

final class PublicSafetyPolicyTests: XCTestCase {
    func testUsernameNormalizationAndValidation() {
        XCTAssertEqual(PublicContentPolicy.normalizedUsername("  Trail_Friend "), "trail_friend")
        XCTAssertNil(PublicContentPolicy.usernameError("trail_friend"))
        XCTAssertNotNil(PublicContentPolicy.usernameError("UPPER CASE"))
        XCTAssertNotNil(PublicContentPolicy.usernameError("support"))
        XCTAssertNotNil(PublicContentPolicy.usernameError("ab"))
    }

    func testPublicContentFilterChecksProfileAndSpotFields() {
        XCTAssertNotNil(PublicContentPolicy.profileError(
            displayName: "Nazi Club",
            username: "safe_name",
            bio: ""
        ))
        XCTAssertNotNil(PublicContentPolicy.spotError(
            title: "Quiet overlook",
            details: "",
            tags: ["porn"]
        ))
        XCTAssertNil(PublicContentPolicy.spotError(
            title: "Quiet overlook",
            details: "Sunset views",
            tags: ["scenic"]
        ))
    }

    func testCannabisJurisdictionUsesCountryAndAdministrativeArea() {
        XCTAssertTrue(CannabisPolicy.isSupportedJurisdiction(countryCode: "CA", administrativeArea: "ON"))
        XCTAssertTrue(CannabisPolicy.isSupportedJurisdiction(countryCode: "US", administrativeArea: "CA"))
        XCTAssertTrue(CannabisPolicy.isSupportedJurisdiction(countryCode: "US", administrativeArea: "California"))
        XCTAssertFalse(CannabisPolicy.isSupportedJurisdiction(countryCode: "US", administrativeArea: "NY"))
    }

    func testCannabisAccessRequiresAgeAndSupportedViewerLocation() {
        XCTAssertTrue(CannabisPolicy.canAccess(
            ageConfirmed: true,
            countryCode: "CA",
            administrativeArea: "ON"
        ))
        XCTAssertFalse(CannabisPolicy.canAccess(
            ageConfirmed: false,
            countryCode: "CA",
            administrativeArea: "ON"
        ))
        XCTAssertFalse(CannabisPolicy.canAccess(
            ageConfirmed: true,
            countryCode: "US",
            administrativeArea: "NY"
        ))
        XCTAssertFalse(CannabisPolicy.canAccess(
            ageConfirmed: true,
            countryCode: "",
            administrativeArea: ""
        ))
    }

    func testCannabisTagRecognition() {
        XCTAssertTrue(CannabisPolicy.containsCannabisTag(["scenic", "weed-friendly"]))
        XCTAssertTrue(CannabisPolicy.isCannabisTag(" 420 "))
        XCTAssertFalse(CannabisPolicy.containsCannabisTag(["coffee", "late-night"]))
    }
}
