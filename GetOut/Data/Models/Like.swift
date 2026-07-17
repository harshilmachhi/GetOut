import Foundation
import SwiftData

@Model
final class Like {
    var id: UUID = UUID()
    var createdAt: Date = Date.now

    var user: Profile?
    var spot: Spot?

    init() {}
}
