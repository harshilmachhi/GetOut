import Foundation
import SwiftData
import UIKit

enum SeedData {
    private static let spotPhotoAssetNames: [String: String] = [
        "Sunset hill seating": "spot_sunset_hill",
        "Hidden cafe in the garden": "spot_hidden_cafe",
        "East River quiet spot": "spot_east_river",
        "Rooftop reading nook": "spot_rooftop_nook",
        "Late-night dumpling counter": "spot_dumpling",
        "Prospect Park knoll": "spot_prospect_park",
    ]

    static func seedIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<Spot>()
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor).isEmpty) == true else {
            seedSampleTripIfNeeded(in: context)
            seedProfileEngagementIfNeeded(in: context)
            backfillSpotPhotosIfNeeded(in: context)
            return
        }

        let profile = Profile()
        profile.username = "harshil"
        profile.displayName = "Harshil"
        profile.bio = "Exploring NYC one hidden spot at a time."
        profile.citiesVisited = ["New York"]
        context.insert(profile)

        let tagNames = [
            "sunset", "view", "quiet", "cozy", "hidden", "weed-friendly",
            "waterfront", "local", "late-night", "picnic",
        ]
        var tagsByName: [String: Tag] = [:]
        for name in tagNames {
            let tag = Tag()
            tag.name = name
            context.insert(tag)
            tagsByName[name] = tag
        }

        let spotSpecs: [(title: String, neighborhood: String, category: SpotCategory, rating: Double, lat: Double, lon: Double, photo: String, tagNames: [String])] = [
            ("Sunset hill seating", "Fort Greene", .views, 4.9, 40.6892, -73.9747, "sun.horizon.fill", ["sunset", "view", "quiet"]),
            ("Hidden cafe in the garden", "Clinton Hill", .coffee, 4.8, 40.6897, -73.9618, "cup.and.saucer.fill", ["cozy", "hidden", "weed-friendly"]),
            ("East River quiet spot", "Williamsburg", .nature, 4.7, 40.7081, -73.9574, "water.waves", ["waterfront", "quiet", "view"]),
            ("Rooftop reading nook", "Dumbo", .views, 4.6, 40.7033, -73.9897, "building.2.fill", ["view", "quiet", "hidden"]),
            ("Late-night dumpling counter", "Chinatown", .food, 4.5, 40.7158, -73.9970, "fork.knife", ["local", "late-night"]),
            ("Prospect Park knoll", "Park Slope", .nature, 4.8, 40.6710, -73.9814, "tree.fill", ["picnic", "sunset", "weed-friendly"]),
        ]

        var seededSpots: [Spot] = []
        for spec in spotSpecs {
            let spot = Spot()
            spot.title = spec.title
            spot.neighborhood = spec.neighborhood
            spot.city = "New York"
            spot.category = spec.category.rawValue
            spot.rating = spec.rating
            spot.latitude = spec.lat
            spot.longitude = spec.lon
            spot.photoSystemImage = spec.photo
            spot.photoData = photoData(forTitle: spec.title)
            spot.owner = profile
            spot.tags = spec.tagNames.compactMap { tagsByName[$0] }
            context.insert(spot)
            profile.spots = (profile.spots ?? []) + [spot]
            seededSpots.append(spot)
        }

        seedSampleTrip(in: context, profile: profile, spots: seededSpots)
        seedProfileEngagementIfNeeded(in: context)

        try? context.save()
    }

    static func backfillSpotPhotosIfNeeded(in context: ModelContext) {
        guard let spots = try? context.fetch(FetchDescriptor<Spot>()) else { return }

        var didUpdate = false
        for spot in spots {
            guard spot.photoData == nil,
                  let data = photoData(forTitle: spot.title) else { continue }
            spot.photoData = data
            didUpdate = true
        }

        if didUpdate {
            try? context.save()
        }
    }

    private static func photoData(forTitle title: String) -> Data? {
        guard let assetName = spotPhotoAssetNames[title],
              let image = UIImage(named: assetName) else { return nil }
        return image.jpegData(compressionQuality: 0.85)
    }

    static func seedProfileEngagementIfNeeded(in context: ModelContext) {
        var profileDescriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.username == "harshil" }
        )
        profileDescriptor.fetchLimit = 1
        guard let profile = try? context.fetch(profileDescriptor).first else { return }

        guard let allLikes = try? context.fetch(FetchDescriptor<Like>()) else { return }
        let userLikeCount = allLikes.filter { $0.user?.id == profile.id }.count
        guard userLikeCount == 0 else { return }

        guard let spots = try? context.fetch(FetchDescriptor<Spot>()) else { return }

        func spot(named title: String) -> Spot? {
            spots.first { $0.title == title }
        }

        for title in ["Sunset hill seating", "East River quiet spot", "Rooftop reading nook"] {
            guard let spot = spot(named: title) else { continue }
            let like = Like()
            like.user = profile
            like.spot = spot
            context.insert(like)
        }

        if let spot = spot(named: "Hidden cafe in the garden") {
            let save = Save()
            save.user = profile
            save.spot = spot
            save.list = SaveList.saved.rawValue
            context.insert(save)
        }

        for title in ["Prospect Park knoll", "Late-night dumpling counter"] {
            guard let spot = spot(named: title) else { continue }
            let save = Save()
            save.user = profile
            save.spot = spot
            save.list = SaveList.beenThere.rawValue
            context.insert(save)
        }

        try? context.save()
    }

    static func seedSampleTripIfNeeded(in context: ModelContext) {
        var tripDescriptor = FetchDescriptor<Trip>()
        tripDescriptor.fetchLimit = 1
        guard (try? context.fetch(tripDescriptor).isEmpty) == true else { return }

        var profileDescriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.username == "harshil" }
        )
        profileDescriptor.fetchLimit = 1
        guard let profile = try? context.fetch(profileDescriptor).first else { return }

        var spotDescriptor = FetchDescriptor<Spot>()
        guard let spots = try? context.fetch(spotDescriptor), !spots.isEmpty else { return }

        seedSampleTrip(in: context, profile: profile, spots: spots)
        try? context.save()
    }

    private static func seedSampleTrip(in context: ModelContext, profile: Profile, spots: [Spot]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let trip = Trip()
        trip.title = "NYC Weekend"
        trip.summary = "A slow weekend through Brooklyn views, quiet corners, and late-night bites."
        trip.startDate = today
        trip.endDate = tomorrow
        trip.coverSystemImage = "sun.horizon.fill"
        trip.owner = profile
        context.insert(trip)

        let stopTitles = [
            "Sunset hill seating",
            "Hidden cafe in the garden",
            "East River quiet spot",
            "Rooftop reading nook",
            "Prospect Park knoll",
        ]

        for (order, title) in stopTitles.enumerated() {
            guard let spot = spots.first(where: { $0.title == title }) else { continue }

            let stop = TripStop()
            stop.trip = trip
            stop.spot = spot
            stop.dayIndex = 0
            stop.order = order
            context.insert(stop)
        }
    }
}
