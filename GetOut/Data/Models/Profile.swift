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

    @Relationship(inverse: \Spot.owner)
    var spots: [Spot]?

    @Relationship(inverse: \Like.user)
    var likes: [Like]?

    @Relationship(inverse: \Save.user)
    var saves: [Save]?

    @Relationship(inverse: \Trip.owner)
    var trips: [Trip]?

    @Relationship(inverse: \Follow.follower)
    var following: [Follow]?

    @Relationship(inverse: \Follow.followee)
    var followers: [Follow]?

    @Relationship(inverse: \Interaction.user)
    var interactions: [Interaction]?

    init() {}
}
