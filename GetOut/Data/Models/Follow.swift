import Foundation
import SwiftData

@Model
final class Follow {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var followerUserRecordName: String = ""
    var followeeUserRecordName: String = ""
    var isPublicSocialFollow: Bool = false

    var follower: Profile?
    var followee: Profile?

    init() {}
}
