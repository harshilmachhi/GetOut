import CoreLocation
import Foundation
import SwiftData

enum TripPlanningLogic {
    enum TimeSlot: Int, CaseIterable {
        case morning
        case midday
        case afternoon
        case evening

        var label: String {
            switch self {
            case .morning: "Morning"
            case .midday: "Midday"
            case .afternoon: "Afternoon"
            case .evening: "Evening"
            }
        }

        var timeWindow: String {
            switch self {
            case .morning: "8–11 AM"
            case .midday: "11 AM–2 PM"
            case .afternoon: "2–5 PM"
            case .evening: "5–9 PM"
            }
        }

        static func from(hour: Int) -> TimeSlot? {
            guard (0...23).contains(hour) else { return nil }
            switch hour {
            case 5..<11: return .morning
            case 11..<14: return .midday
            case 14..<17: return .afternoon
            default: return .evening
            }
        }
    }

    enum TravelMode: String {
        case walk
        case transit

        var label: String {
            switch self {
            case .walk: "walk"
            case .transit: "transit"
            }
        }
    }

    static let walkingSpeedKmh = 4.5
    static let transitSpeedKmh = 25.0
    static let walkingThresholdMeters = 1_500.0

    static func travelMode(distanceMeters: Double) -> TravelMode {
        distanceMeters < walkingThresholdMeters ? .walk : .transit
    }

    static func estimatedTravelMinutes(distanceMeters: Double) -> Int {
        guard distanceMeters > 0 else { return 0 }
        let km = distanceMeters / 1_000.0
        let speed = travelMode(distanceMeters: distanceMeters) == .walk ? walkingSpeedKmh : transitSpeedKmh
        return max(1, Int((km / speed * 60.0).rounded()))
    }

    static func tagNames(for spot: Spot) -> [String] {
        (spot.tags ?? []).map { $0.name.lowercased() }
    }

    static func preferredTimeSlots(for spot: Spot) -> [TimeSlot] {
        var scores = Dictionary(uniqueKeysWithValues: TimeSlot.allCases.map { ($0, 0.0) })

        if spot.visitHour >= 0, let contributorSlot = TimeSlot.from(hour: spot.visitHour) {
            scores[contributorSlot, default: 0] += 4.0
            if let neighbor = adjacentSlot(to: contributorSlot) {
                scores[neighbor, default: 0] += 1.5
            }
        }

        switch spot.categoryEnum {
        case .coffee:
            scores[.morning, default: 0] += 3.0
            scores[.midday, default: 0] += 0.5
        case .food:
            scores[.midday, default: 0] += 2.5
            scores[.evening, default: 0] += 2.0
        case .nature:
            scores[.morning, default: 0] += 2.5
            scores[.afternoon, default: 0] += 1.5
        case .views:
            scores[.afternoon, default: 0] += 2.0
            scores[.evening, default: 0] += 2.5
        case .nightlife:
            scores[.evening, default: 0] += 3.5
        case .nearby:
            scores[.midday, default: 0] += 1.0
            scores[.afternoon, default: 0] += 1.0
        }

        let tags = tagNames(for: spot)
        if tags.contains(where: { $0.contains("sunset") || $0.contains("golden") }) {
            scores[.evening, default: 0] += 3.0
            scores[.afternoon, default: 0] += 1.0
        }
        if tags.contains(where: { $0.contains("quiet") || $0.contains("peaceful") }) {
            scores[.morning, default: 0] += 2.5
            scores[.evening, default: 0] -= 1.5
        }
        if tags.contains(where: { $0.contains("night") || $0.contains("bar") || $0.contains("club") }) {
            scores[.evening, default: 0] += 2.5
        }
        if tags.contains(where: { $0.contains("brunch") || $0.contains("breakfast") }) {
            scores[.morning, default: 0] += 2.0
            scores[.midday, default: 0] += 1.0
        }
        if tags.contains(where: { $0.contains("outdoor") || $0.contains("hike") || $0.contains("park") }) {
            scores[.morning, default: 0] += 1.5
            scores[.afternoon, default: 0] += 1.0
        }

        return TimeSlot.allCases.sorted { scores[$0, default: 0] > scores[$1, default: 0] }
    }

    static func timeSlotFitScore(for spot: Spot, slot: TimeSlot) -> Double {
        let ranked = preferredTimeSlots(for: spot)
        guard let index = ranked.firstIndex(of: slot) else { return 0 }
        return Double(ranked.count - index) / Double(max(ranked.count, 1))
    }

    static func popularityScore(for spot: Spot, slot: TimeSlot) -> Double {
        var score = 0.0
        let tags = tagNames(for: spot)
        let category = spot.categoryEnum
        let isOutdoor = category == .nature || category == .views
            || tags.contains(where: { $0.contains("outdoor") || $0.contains("park") || $0.contains("view") })
        let prefersQuietMorning = tags.contains(where: { $0.contains("quiet") || $0.contains("peaceful") })

        switch slot {
        case .morning:
            if category == .coffee { score += 1.5 }
            if isOutdoor { score += 1.0 }
            if prefersQuietMorning { score += 1.5 }
        case .midday:
            if category == .food { score += 1.0 }
            if category == .nearby { score += 0.5 }
        case .afternoon:
            if isOutdoor { score += 1.0 }
            if category == .views { score += 0.8 }
        case .evening:
            if category == .views || tags.contains(where: { $0.contains("sunset") }) { score += 1.5 }
            if category == .nightlife { score += 2.0 }
            if category == .food { score += 0.8 }
            if prefersQuietMorning { score -= 1.0 }
        }

        if category == .food, slot == .midday || slot == .evening {
            score += 0.5
        }

        return score
    }

    static func combinedSlotScore(for spot: Spot, slot: TimeSlot) -> Double {
        timeSlotFitScore(for: spot, slot: slot) + popularityScore(for: spot, slot: slot)
    }

    static func chooseSlot(for spot: Spot, startingAt index: Int) -> (slot: TimeSlot, nextIndex: Int) {
        let remaining = Array(TimeSlot.allCases.dropFirst(min(index, TimeSlot.allCases.count - 1)))
        let chosen = remaining.max { combinedSlotScore(for: spot, slot: $0) < combinedSlotScore(for: spot, slot: $1) }
            ?? remaining.first
            ?? .midday
        let nextIndex = min((TimeSlot.allCases.firstIndex(of: chosen) ?? index) + 1, TimeSlot.allCases.count)
        return (chosen, nextIndex)
    }

    static func stopNotes(
        for spot: Spot,
        slot: TimeSlot,
        travelMinutes: Int?,
        travelMode: TravelMode?,
        rationale: String?
    ) -> String {
        var parts: [String] = ["Suggested: \(slot.label) (\(slot.timeWindow))"]

        if let travelMinutes, let travelMode, travelMinutes > 0 {
            parts.append("~\(travelMinutes) min \(travelMode.label) from previous stop")
        }

        if let rationale, !rationale.isEmpty {
            parts.append(rationale)
        }

        return parts.joined(separator: " · ")
    }

    static func stopRationale(for spot: Spot, slot: TimeSlot) -> String? {
        let tags = tagNames(for: spot)
        let category = spot.categoryEnum

        if tags.contains(where: { $0.contains("sunset") }) || (category == .views && slot == .evening) {
            return "Best light for views"
        }
        if category == .coffee && slot == .morning {
            return "Morning coffee before the day picks up"
        }
        if category == .food && slot == .midday {
            return "Good midday meal window"
        }
        if category == .nature && slot == .morning {
            return "Cooler, quieter hours outdoors"
        }
        if tags.contains(where: { $0.contains("quiet") }) && slot == .morning {
            return "Quiet morning visit"
        }
        if category == .nightlife && slot == .evening {
            return "Nightlife hours"
        }
        if spot.visitHour >= 0, let contributorSlot = TimeSlot.from(hour: spot.visitHour), contributorSlot == slot {
            return "Matches when a contributor visited"
        }
        return nil
    }

    private static func adjacentSlot(to slot: TimeSlot) -> TimeSlot? {
        guard let index = TimeSlot.allCases.firstIndex(of: slot) else { return nil }
        let next = index + 1
        guard next < TimeSlot.allCases.count else { return nil }
        return TimeSlot.allCases[next]
    }
}

enum TripPlanner {
    static func generatePlan(for trip: Trip, in context: ModelContext) {
        let stops = trip.stops ?? []
        guard !stops.isEmpty else {
            trip.planSummary = ""
            try? context.save()
            return
        }

        let dayCount = computeDayCount(for: trip, stopCount: stops.count)
        let orderedStops = routeOrderedStops(stops)
        let chunks = distributeEvenly(orderedStops, across: dayCount)

        var totalWalkMinutes = 0
        var totalTransitMinutes = 0
        var goldenHourCount = 0
        var morningCoffeeCount = 0
        var morningQuietCount = 0
        var natureMorningCount = 0
        var previousLocation: CLLocation?

        for (dayIndex, dayStops) in chunks.enumerated() {
            var slotCursor = 0

            for (order, stop) in dayStops.enumerated() {
                stop.dayIndex = dayIndex
                stop.order = order

                guard let spot = stop.spot else {
                    stop.notes = ""
                    continue
                }

                let slotChoice = TripPlanningLogic.chooseSlot(for: spot, startingAt: slotCursor)
                slotCursor = slotChoice.nextIndex
                let slot = slotChoice.slot

                var travelMinutes = 0
                var mode: TripPlanningLogic.TravelMode?
                if let coordinate = spot.mapCoordinate, let previousLocation {
                    let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    let distance = previousLocation.distance(from: current)
                    travelMinutes = TripPlanningLogic.estimatedTravelMinutes(distanceMeters: distance)
                    mode = TripPlanningLogic.travelMode(distanceMeters: distance)
                    if mode == .walk {
                        totalWalkMinutes += travelMinutes
                    } else {
                        totalTransitMinutes += travelMinutes
                    }
                }

                if order == 0 {
                    travelMinutes = 0
                    mode = nil
                }

                let rationale = TripPlanningLogic.stopRationale(for: spot, slot: slot)
                stop.notes = TripPlanningLogic.stopNotes(
                    for: spot,
                    slot: slot,
                    travelMinutes: order == 0 ? nil : travelMinutes,
                    travelMode: order == 0 ? nil : mode,
                    rationale: rationale
                )

                if spot.categoryEnum == .views && slot == .evening { goldenHourCount += 1 }
                if spot.categoryEnum == .coffee && slot == .morning { morningCoffeeCount += 1 }
                if spot.categoryEnum == .nature && slot == .morning { natureMorningCount += 1 }
                if TripPlanningLogic.tagNames(for: spot).contains(where: { $0.contains("quiet") }) && slot == .morning {
                    morningQuietCount += 1
                }

                if let coordinate = spot.mapCoordinate {
                    previousLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
        }

        trip.planSummary = buildPlanSummary(
            stopCount: stops.count,
            dayCount: dayCount,
            totalWalkMinutes: totalWalkMinutes,
            totalTransitMinutes: totalTransitMinutes,
            goldenHourCount: goldenHourCount,
            morningCoffeeCount: morningCoffeeCount,
            morningQuietCount: morningQuietCount,
            natureMorningCount: natureMorningCount
        )

        try? context.save()
    }

    private static func buildPlanSummary(
        stopCount: Int,
        dayCount: Int,
        totalWalkMinutes: Int,
        totalTransitMinutes: Int,
        goldenHourCount: Int,
        morningCoffeeCount: Int,
        morningQuietCount: Int,
        natureMorningCount: Int
    ) -> String {
        var sentences: [String] = []

        let dayLabel = dayCount == 1 ? "1 day" : "\(dayCount) days"
        sentences.append("\(stopCount) stops across \(dayLabel), ordered to keep travel compact.")

        if totalWalkMinutes > 0 && totalTransitMinutes > 0 {
            sentences.append("About \(totalWalkMinutes) min walking and \(totalTransitMinutes) min transit between stops.")
        } else if totalWalkMinutes > 0 {
            sentences.append("Most hops are walkable (~\(totalWalkMinutes) min total on foot).")
        } else if totalTransitMinutes > 0 {
            sentences.append("Longer hops use transit (~\(totalTransitMinutes) min total).")
        }

        if goldenHourCount > 0 {
            let label = goldenHourCount == 1 ? "1 view spot" : "\(goldenHourCount) view spots"
            sentences.append("\(label) timed for golden-hour light.")
        }
        if morningCoffeeCount > 0 {
            sentences.append("Morning coffee leads into food and exploration.")
        }
        if natureMorningCount > 0 {
            sentences.append("Nature stops favor cooler morning hours.")
        }
        if morningQuietCount > 0 {
            sentences.append("Quiet-tagged spots land in calmer mornings.")
        }

        return sentences.joined(separator: " ")
    }

    private static func computeDayCount(for trip: Trip, stopCount: Int) -> Int {
        if let start = trip.startDate, let end = trip.endDate {
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
            return max(1, days + 1)
        }
        return max(1, Int(ceil(Double(stopCount) / 4.0)))
    }

    private static func routeOrderedStops(_ stops: [TripStop]) -> [TripStop] {
        var mappable: [(TripStop, CLLocationCoordinate2D)] = []
        var unmappable: [TripStop] = []

        for stop in stops {
            if let coordinate = stop.spot?.mapCoordinate {
                mappable.append((stop, coordinate))
            } else {
                unmappable.append(stop)
            }
        }

        guard !mappable.isEmpty else {
            return stops.sorted { $0.order < $1.order }
        }

        let locations = mappable.map { CLLocation(latitude: $0.1.latitude, longitude: $0.1.longitude) }
        let centroid = centroidLocation(of: locations)
        var remaining = mappable
        var ordered: [TripStop] = []
        var slotCursor = 0

        if let startIndex = remaining.indices.min(by: { indexA, indexB in
            let locA = CLLocation(latitude: remaining[indexA].1.latitude, longitude: remaining[indexA].1.longitude)
            let locB = CLLocation(latitude: remaining[indexB].1.latitude, longitude: remaining[indexB].1.longitude)
            return locA.distance(from: centroid) < locB.distance(from: centroid)
        }) {
            ordered.append(remaining.remove(at: startIndex).0)
        }

        while !remaining.isEmpty {
            guard let last = ordered.last,
                  let lastCoordinate = last.spot?.mapCoordinate else {
                ordered.append(remaining.removeFirst().0)
                continue
            }

            let current = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distances = remaining.map { candidate in
                CLLocation(latitude: candidate.1.latitude, longitude: candidate.1.longitude)
                    .distance(from: current)
            }
            let maxDistance = max(distances.max() ?? 1, 1)

            let expectedSlot = TripPlanningLogic.TimeSlot.allCases[
                min(slotCursor, TripPlanningLogic.TimeSlot.allCases.count - 1)
            ]

            let nearestIndex = remaining.indices.min { indexA, indexB in
                let candidateA = remaining[indexA]
                let candidateB = remaining[indexB]
                let locA = CLLocation(latitude: candidateA.1.latitude, longitude: candidateA.1.longitude)
                let locB = CLLocation(latitude: candidateB.1.latitude, longitude: candidateB.1.longitude)
                let distanceA = current.distance(from: locA)
                let distanceB = current.distance(from: locB)

                let scoreA = routeCandidateScore(
                    spot: candidateA.0.spot,
                    normalizedDistance: distanceA / maxDistance,
                    expectedSlot: expectedSlot
                )
                let scoreB = routeCandidateScore(
                    spot: candidateB.0.spot,
                    normalizedDistance: distanceB / maxDistance,
                    expectedSlot: expectedSlot
                )
                return scoreA < scoreB
            } ?? 0

            ordered.append(remaining.remove(at: nearestIndex).0)
            slotCursor += 1
        }

        return ordered + unmappable
    }

    private static func routeCandidateScore(
        spot: Spot?,
        normalizedDistance: Double,
        expectedSlot: TripPlanningLogic.TimeSlot
    ) -> Double {
        guard let spot else { return normalizedDistance }
        let timeFit = TripPlanningLogic.timeSlotFitScore(for: spot, slot: expectedSlot)
        let popularity = TripPlanningLogic.popularityScore(for: spot, slot: expectedSlot)
        return normalizedDistance * 0.55 - timeFit * 0.30 - popularity * 0.15
    }

    private static func centroidLocation(of locations: [CLLocation]) -> CLLocation {
        guard !locations.isEmpty else {
            return CLLocation(latitude: 0, longitude: 0)
        }

        let latitude = locations.map(\.coordinate.latitude).reduce(0, +) / Double(locations.count)
        let longitude = locations.map(\.coordinate.longitude).reduce(0, +) / Double(locations.count)
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    private static func distributeEvenly(_ stops: [TripStop], across dayCount: Int) -> [[TripStop]] {
        guard dayCount > 0, !stops.isEmpty else { return [] }

        let baseSize = stops.count / dayCount
        let remainder = stops.count % dayCount
        var chunks: [[TripStop]] = []
        var index = 0

        for day in 0..<dayCount {
            let size = baseSize + (day < remainder ? 1 : 0)
            let end = min(index + size, stops.count)
            if index < end {
                chunks.append(Array(stops[index..<end]))
            } else {
                chunks.append([])
            }
            index = end
        }

        return chunks
    }
}
