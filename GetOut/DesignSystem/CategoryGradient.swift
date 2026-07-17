import SwiftUI

enum CategoryGradient {
    static func colors(for category: SpotCategory, fallbackIndex: Int = 0) -> [Color] {
        let categoryPalettes: [SpotCategory: [Color]] = [
            .views: [Color(red: 0.85, green: 0.55, blue: 0.35), Color(red: 0.65, green: 0.42, blue: 0.28)],
            .coffee: [Color(red: 0.72, green: 0.58, blue: 0.42), Color(red: 0.52, green: 0.38, blue: 0.30)],
            .nature: [Color(red: 0.45, green: 0.62, blue: 0.48), Color(red: 0.28, green: 0.42, blue: 0.35)],
            .food: [Color(red: 0.78, green: 0.45, blue: 0.38), Color(red: 0.58, green: 0.32, blue: 0.28)],
            .nightlife: [Color(red: 0.55, green: 0.48, blue: 0.68), Color(red: 0.35, green: 0.30, blue: 0.48)],
            .nearby: [Color(red: 0.65, green: 0.55, blue: 0.45), Color(red: 0.45, green: 0.38, blue: 0.32)],
        ]
        let fallback: [[Color]] = [
            [Color(red: 0.85, green: 0.55, blue: 0.35), Color(red: 0.65, green: 0.42, blue: 0.28)],
            [Color(red: 0.45, green: 0.62, blue: 0.48), Color(red: 0.28, green: 0.42, blue: 0.35)],
            [Color(red: 0.72, green: 0.58, blue: 0.42), Color(red: 0.52, green: 0.38, blue: 0.30)],
            [Color(red: 0.55, green: 0.48, blue: 0.68), Color(red: 0.35, green: 0.30, blue: 0.48)],
        ]
        return categoryPalettes[category] ?? fallback[fallbackIndex % fallback.count]
    }
}

struct CategoryGradientView: View {
    let category: SpotCategory
    var fallbackIndex: Int = 0
    var startPoint: UnitPoint = .topLeading
    var endPoint: UnitPoint = .bottomTrailing

    var body: some View {
        LinearGradient(
            colors: CategoryGradient.colors(for: category, fallbackIndex: fallbackIndex),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}
