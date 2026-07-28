import Foundation
import SwiftData

@Model
final class Rating {
    var id: UUID = UUID()
    var stars: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var user: Profile?
    var spot: Spot?

    init() {}
}
