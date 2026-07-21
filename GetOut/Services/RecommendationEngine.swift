import CoreLocation
import Foundation

struct ScoredSpot: Identifiable {
    let spot: Spot
    let score: Double
    let distanceMeters: Double?

    var id: UUID { spot.id }
}

enum RecommendationEngine {
    /// Blend weights for the final score. Exposed so a future RL/AI phase can tune them.
    struct Weights {
        var proximity: Double = 0.30
        var tags: Double = 0.25
        var category: Double = 0.20
        var popularity: Double = 0.20
        var novelty: Double = 0.05

        static let `default` = Weights()
    }

    /// How strongly each kind of user signal shapes taste.
    private enum SignalWeight {
        static let like = 3.0
        static let owned = 2.0
        static let been = 2.0
        static let save = 2.0
        static let view = 1.0
    }

    /// Distance decay scale in kilometers; ~63% score at this distance.
    private static let proximityScaleKm = 2.0
    /// A spot counts as "new" for the novelty boost within this window.
    private static let noveltyWindowDays = 14.0

    struct PreferenceProfile {
        var tagAffinity: [String: Double]
        var categoryAffinity: [String: Double]
        var hasSignal: Bool
    }

    static func buildPreferenceProfile(for profile: Profile?) -> PreferenceProfile {
        var tagAffinity: [String: Double] = [:]
        var categoryAffinity: [String: Double] = [:]
        var totalWeight = 0.0

        func accumulate(_ spot: Spot?, weight: Double) {
            guard let spot else { return }
            totalWeight += weight
            categoryAffinity[spot.category, default: 0] += weight
            for tag in spot.tags ?? [] {
                tagAffinity[tag.name, default: 0] += weight
            }
        }

        for like in profile?.likes ?? [] {
            accumulate(like.spot, weight: SignalWeight.like)
        }
        for save in profile?.saves ?? [] {
            let weight = save.list == SaveList.beenThere.rawValue ? SignalWeight.been : SignalWeight.save
            accumulate(save.spot, weight: weight)
        }
        for interaction in profile?.interactions ?? [] where interaction.eventEnum == .view {
            accumulate(interaction.spot, weight: SignalWeight.view)
        }
        for owned in profile?.spots ?? [] {
            accumulate(owned, weight: SignalWeight.owned)
        }

        let engagementIsThin = totalWeight < SignalWeight.like
        if engagementIsThin, let profile {
            let coldStartWeight = totalWeight > 0 ? 0.5 : 1.0
            for category in profile.preferredCategories {
                categoryAffinity[category, default: 0] += coldStartWeight
                totalWeight += coldStartWeight
            }
            for tag in profile.preferredTags {
                tagAffinity[tag, default: 0] += coldStartWeight
                totalWeight += coldStartWeight
            }
        }

        normalize(&tagAffinity)
        normalize(&categoryAffinity)

        return PreferenceProfile(
            tagAffinity: tagAffinity,
            categoryAffinity: categoryAffinity,
            hasSignal: totalWeight > 0
        )
    }

    static func rank(
        spots: [Spot],
        for profile: Profile?,
        userLocation: CLLocation?,
        now: Date = .now,
        weights: Weights = .default
    ) -> [ScoredSpot] {
        let preference = buildPreferenceProfile(for: profile)
        let maxLikeCount = max(1, spots.map { $0.likes?.count ?? 0 }.max() ?? 0)

        let scored = spots.map { spot -> ScoredSpot in
            var distanceMeters: Double?
            var proximityScore = 0.5 // neutral when we can't measure distance

            if let userLocation, let coordinate = spot.mapCoordinate {
                let spotLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = userLocation.distance(from: spotLocation)
                distanceMeters = distance
                proximityScore = exp(-(distance / 1000) / proximityScaleKm)
            }

            let spotTags = spot.tags ?? []
            let tagScore: Double
            if spotTags.isEmpty {
                tagScore = 0
            } else {
                let sum = spotTags.reduce(0.0) { $0 + (preference.tagAffinity[$1.name] ?? 0) }
                tagScore = sum / Double(spotTags.count)
            }

            let categoryScore = preference.categoryAffinity[spot.category] ?? 0

            let ratingScore = min(max(spot.rating / 5.0, 0), 1)
            let likeScore = Double(spot.likes?.count ?? 0) / Double(maxLikeCount)
            let popularityScore = 0.7 * ratingScore + 0.3 * likeScore

            let ageDays = now.timeIntervalSince(spot.createdAt) / 86_400
            let noveltyScore = ageDays <= noveltyWindowDays ? 1.0 : 0.0

            let score =
                weights.proximity * proximityScore +
                weights.tags * tagScore +
                weights.category * categoryScore +
                weights.popularity * popularityScore +
                weights.novelty * noveltyScore

            return ScoredSpot(spot: spot, score: score, distanceMeters: distanceMeters)
        }

        return scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.spot.rating > rhs.spot.rating
        }
    }

    private static func normalize(_ values: inout [String: Double]) {
        guard let maxValue = values.values.max(), maxValue > 0 else { return }
        for key in values.keys {
            values[key]! /= maxValue
        }
    }
}

enum DistanceFormatter {
    private static let nearbyThresholdMeters = 160.934 // 0.1 mi

    private static let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.minimumFractionDigits = 0
        return formatter
    }()

    /// A short human label like "0.4 mi" or "3 mi", or "Nearby" when very close.
    /// Returns nil when distance is unknown so callers can fall back.
    static func shortLabel(meters: Double?) -> String? {
        guard let meters, meters >= 0 else { return nil }
        if meters < nearbyThresholdMeters { return "Nearby" }

        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let miles = measurement.converted(to: .miles)
        formatter.numberFormatter.maximumFractionDigits = miles.value < 10 ? 1 : 0
        return formatter.string(from: miles)
    }
}
