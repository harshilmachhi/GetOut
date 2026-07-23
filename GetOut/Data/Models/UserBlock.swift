import Foundation
import SwiftData

@Model
final class UserBlock {
    var id: UUID = UUID()
    var blockedUserRecordName: String = ""
    var createdAt: Date = Date.now

    init() {}
}
