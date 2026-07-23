import CoreLocation
import Foundation
import SwiftData

@Model
final class Spot {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var address: String = ""
    var city: String = ""
    var neighborhood: String = ""
    var category: String = SpotCategory.views.rawValue
    var photoSystemImage: String = "photo"
    @Attribute(.externalStorage) var photoData: Data?
    var rating: Double = 0
    var visitHour: Int = -1
    var visitWeekday: Int = -1
    var createdAt: Date = Date.now
    var publicRecordName: String = ""
    var publisherUserRecordName: String = ""
    var publicTagNames: [String] = []
    var containsCannabis: Bool = false
    var countryCode: String = ""
    var administrativeArea: String = ""

    var owner: Profile?

    @Relationship(inverse: \Tag.spots)
    var tags: [Tag]?

    @Relationship(inverse: \Like.spot)
    var likes: [Like]?

    @Relationship(inverse: \Save.spot)
    var saves: [Save]?

    @Relationship(inverse: \TripStop.spot)
    var tripStops: [TripStop]?

    @Relationship(inverse: \Interaction.spot)
    var interactions: [Interaction]?

    @Transient
    var categoryEnum: SpotCategory {
        get { SpotCategory(rawValue: category) ?? .views }
        set { category = newValue.rawValue }
    }

    @Transient
    var mapCoordinate: CLLocationCoordinate2D? {
        guard latitude != 0, longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    @Transient
    var displayTagNames: [String] {
        let localNames = tags?.map(\.name) ?? []
        return Array(Set(localNames + publicTagNames)).sorted()
    }

    init() {}
}

extension Spot: Hashable {
    static func == (lhs: Spot, rhs: Spot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
