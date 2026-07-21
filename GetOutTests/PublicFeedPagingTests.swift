@testable import GetOut
import XCTest

final class PublicFeedPagingTests: XCTestCase {
    func testFirstPageUsesNilCursor() {
        XCTAssertEqual(PublicFeedPager.pageIndex(from: nil), 0)
    }

    func testNextCursorWhenMorePagesExist() {
        let next = PublicFeedPager.nextCursor(
            current: nil,
            fetchedCount: PublicFeedPager.defaultPageSize,
            hasMoreFromServer: true
        )
        XCTAssertEqual(next?.token, "page-1")
    }

    func testNoNextCursorWhenServerHasNoMore() {
        let next = PublicFeedPager.nextCursor(
            current: PublicFeedCursor(token: "page-0"),
            fetchedCount: PublicFeedPager.defaultPageSize,
            hasMoreFromServer: false
        )
        XCTAssertNil(next)
    }

    func testPageIndexIncrementsFromCursorToken() {
        XCTAssertEqual(PublicFeedPager.pageIndex(from: PublicFeedCursor(token: "page-2")), 2)
    }

    func testShortPageDoesNotAdvanceCursor() {
        let next = PublicFeedPager.nextCursor(
            current: nil,
            fetchedCount: 3,
            pageSize: 20,
            hasMoreFromServer: true
        )
        XCTAssertNil(next)
    }
}
