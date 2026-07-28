import SwiftData
@testable import GetOut
import XCTest

@MainActor
final class PublicFeedCacheReconciliationTests: XCTestCase {
    func testReconcileRemovesSpotDeletedFromPublicDatabase() throws {
        let container = try ModelContainer(
            for: Profile.self, Spot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let staleSpot = Spot()
        staleSpot.publicRecordName = "deleted-public-record"
        context.insert(staleSpot)
        try context.save()

        PublicSocialCacheStore.reconcilePublicFeed([], in: context)

        let spots = try context.fetch(FetchDescriptor<Spot>())
        XCTAssertTrue(spots.isEmpty)
    }
}
