@testable import GetOut
import XCTest

final class PublicFollowToggleTests: XCTestCase {
    func testFollowSuccessFromNotFollowing() {
        let next = FollowToggleState.afterToggle(from: .notFollowing, success: true)
        XCTAssertEqual(next, .following)
    }

    func testFollowFailureRestoresNotFollowingFromPending() {
        let next = FollowToggleState.afterToggle(from: .pending, success: false)
        XCTAssertEqual(next, .notFollowing)
    }

    func testUnfollowSuccessFromFollowing() {
        let next = FollowToggleState.afterUnfollow(from: .following, success: true)
        XCTAssertEqual(next, .notFollowing)
    }

    func testUnfollowFailureRestoresFollowingFromPending() {
        let next = FollowToggleState.afterUnfollow(from: .pending, success: false)
        XCTAssertEqual(next, .following)
    }

    func testToggleFromFollowingUnfollows() {
        let next = FollowToggleState.afterToggle(from: .following, success: true)
        XCTAssertEqual(next, .notFollowing)
    }
}
