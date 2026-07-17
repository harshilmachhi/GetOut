import Foundation
import SwiftData

@Model
final class Follow {
    var id: UUID = UUID()
    var createdAt: Date = Date.now

    var follower: Profile?
    var followee: Profile?

    init() {}
}
