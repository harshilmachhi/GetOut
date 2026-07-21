@testable import GetOut
import XCTest

final class TripPlanningLogicTests: XCTestCase {
    func testWalkingEstimateUnderThreshold() {
        let minutes = TripPlanningLogic.estimatedTravelMinutes(distanceMeters: 900)
        XCTAssertEqual(minutes, 12)
        XCTAssertEqual(TripPlanningLogic.travelMode(distanceMeters: 900), .walk)
    }

    func testTransitEstimateOverThreshold() {
        let minutes = TripPlanningLogic.estimatedTravelMinutes(distanceMeters: 3_000)
        XCTAssertEqual(minutes, 7)
        XCTAssertEqual(TripPlanningLogic.travelMode(distanceMeters: 3_000), .transit)
    }

    func testCoffeePrefersMorning() {
        let spot = Spot()
        spot.category = SpotCategory.coffee.rawValue

        let ranked = TripPlanningLogic.preferredTimeSlots(for: spot)
        XCTAssertEqual(ranked.first, .morning)
        XCTAssertGreaterThan(
            TripPlanningLogic.combinedSlotScore(for: spot, slot: .morning),
            TripPlanningLogic.combinedSlotScore(for: spot, slot: .evening)
        )
    }

    func testSunsetTagPrefersEvening() {
        let spot = Spot()
        spot.category = SpotCategory.views.rawValue
        spot.tags = [tag(named: "sunset")]

        let ranked = TripPlanningLogic.preferredTimeSlots(for: spot)
        XCTAssertEqual(ranked.first, .evening)
    }

    func testVisitHourOverridesCategoryHeuristic() {
        let spot = Spot()
        spot.category = SpotCategory.coffee.rawValue
        spot.visitHour = 19

        let ranked = TripPlanningLogic.preferredTimeSlots(for: spot)
        XCTAssertEqual(ranked.first, .evening)
    }

    func testQuietTagBoostsMorningPopularity() {
        let spot = Spot()
        spot.category = SpotCategory.nature.rawValue
        spot.tags = [tag(named: "quiet")]

        XCTAssertGreaterThan(
            TripPlanningLogic.popularityScore(for: spot, slot: .morning),
            TripPlanningLogic.popularityScore(for: spot, slot: .evening)
        )
    }

    private func tag(named name: String) -> Tag {
        let tag = Tag()
        tag.name = name
        return tag
    }
}
