import CoreLocation
import Foundation
import SwiftData

enum TripPlanner {
    private static let timeHints = ["Morning", "Midday", "Afternoon", "Evening"]

    static func generatePlan(for trip: Trip, in context: ModelContext) {
        let stops = trip.stops ?? []
        guard !stops.isEmpty else { return }

        let dayCount = computeDayCount(for: trip, stopCount: stops.count)
        let orderedStops = routeOrderedStops(stops)
        let chunks = distributeEvenly(orderedStops, across: dayCount)

        for (dayIndex, dayStops) in chunks.enumerated() {
            for (order, stop) in dayStops.enumerated() {
                stop.dayIndex = dayIndex
                stop.order = order
                stop.notes = timeHint(for: order)
            }
        }

        try? context.save()
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
            let nearestIndex = remaining.indices.min(by: { indexA, indexB in
                let locA = CLLocation(latitude: remaining[indexA].1.latitude, longitude: remaining[indexA].1.longitude)
                let locB = CLLocation(latitude: remaining[indexB].1.latitude, longitude: remaining[indexB].1.longitude)
                return current.distance(from: locA) < current.distance(from: locB)
            }) ?? 0

            ordered.append(remaining.remove(at: nearestIndex).0)
        }

        return ordered + unmappable
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

    private static func timeHint(for order: Int) -> String {
        timeHints[min(order, timeHints.count - 1)]
    }
}
