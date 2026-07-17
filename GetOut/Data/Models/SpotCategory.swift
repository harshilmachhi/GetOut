import Foundation
import SwiftUI

enum SpotCategory: String, CaseIterable {
    case nearby
    case views
    case coffee
    case food
    case nature
    case nightlife

    var displayName: String {
        switch self {
        case .nearby: "Nearby"
        case .views: "Views"
        case .coffee: "Coffee"
        case .food: "Food"
        case .nature: "Nature"
        case .nightlife: "Nightlife"
        }
    }

    var symbolName: String {
        switch self {
        case .nearby: "location.north.fill"
        case .views: "mountain.2.fill"
        case .coffee: "cup.and.saucer.fill"
        case .food: "fork.knife"
        case .nature: "tree.fill"
        case .nightlife: "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .nearby: Theme.Colors.accentGreen
        case .views: Color(red: 0.92, green: 0.55, blue: 0.28)
        case .coffee: Color(red: 0.55, green: 0.40, blue: 0.28)
        case .food: Color(red: 0.85, green: 0.35, blue: 0.32)
        case .nature: Color(red: 0.38, green: 0.62, blue: 0.42)
        case .nightlife: Color(red: 0.45, green: 0.42, blue: 0.75)
        }
    }
}
