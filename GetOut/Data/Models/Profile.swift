import Foundation
import SwiftData

@Model
final class Profile {
    var id: UUID = UUID()
    var username: String = ""
    var displayName: String = ""
    var bio: String = ""
    var avatarSystemImage: String = "person.fill"
    var citiesVisited: [String] = []
    var createdAt: Date = Date.now
    var cloudKitUserRecordName: String = ""
    var preferredCategories: [String] = []
    var preferredTags: [String] = []

    @Relationship(inverse: \Spot.owner)
    var spots: [Spot]?

    @Relationship(inverse: \Like.user)
    var likes: [Like]?

    @Relationship(inverse: \Save.user)
    var saves: [Save]?

    @Relationship(inverse: \Trip.owner)
    var trips: [Trip]?

    @Relationship(inverse: \Interaction.user)
    var interactions: [Interaction]?

    @Relationship(deleteRule: .cascade, inverse: \Rating.user)
    var ratings: [Rating]?

    init() {}
}
