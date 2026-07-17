import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID = UUID()
    var title: String = ""
    var summary: String = ""
    var startDate: Date?
    var endDate: Date?
    var coverSystemImage: String = "suitcase"

    var owner: Profile?

    @Relationship(inverse: \TripStop.trip)
    var stops: [TripStop]?

    init() {}
}
