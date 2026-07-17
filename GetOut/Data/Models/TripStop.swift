import Foundation
import SwiftData

@Model
final class TripStop {
    var id: UUID = UUID()
    var dayIndex: Int = 0
    var order: Int = 0
    var notes: String = ""

    var trip: Trip?
    var spot: Spot?

    init() {}
}
