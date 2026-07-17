import SwiftUI

enum TripCoverStyle: Identifiable, CaseIterable {
    case sunset
    case coffee
    case nature
    case food
    case nightlife
    case travel

    var id: String { systemImage }

    var systemImage: String {
        switch self {
        case .sunset: "sun.horizon.fill"
        case .coffee: "cup.and.saucer.fill"
        case .nature: "tree.fill"
        case .food: "fork.knife"
        case .nightlife: "moon.stars.fill"
        case .travel: "suitcase.fill"
        }
    }

    var category: SpotCategory {
        switch self {
        case .sunset: .views
        case .coffee: .coffee
        case .nature: .nature
        case .food: .food
        case .nightlife: .nightlife
        case .travel: .views
        }
    }

    var fallbackIndex: Int {
        switch self {
        case .sunset: 0
        case .coffee: 2
        case .nature: 1
        case .food: 0
        case .nightlife: 3
        case .travel: 0
        }
    }

    static func style(for systemImage: String) -> TripCoverStyle {
        allCases.first { $0.systemImage == systemImage } ?? .travel
    }
}

enum TripFormatting {
    static func dateRange(start: Date?, end: Date?) -> String {
        guard let start else { return "Dates TBD" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        if let end, !Calendar.current.isDate(start, inSameDayAs: end) {
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = ", yyyy"
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))\(yearFormatter.string(from: end))"
        }

        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "MMM d, yyyy"
        return yearFormatter.string(from: start)
    }

    static func spotCountLabel(_ count: Int) -> String {
        count == 1 ? "1 spot" : "\(count) spots"
    }

    static func isPlanned(stops: [TripStop]) -> Bool {
        guard !stops.isEmpty else { return false }
        return stops.contains { !$0.notes.isEmpty }
    }
}
