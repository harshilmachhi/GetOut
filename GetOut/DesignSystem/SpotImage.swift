import SwiftUI
import UIKit

struct SpotImage: View {
    let photoData: Data?
    let category: SpotCategory
    var fallbackIndex: Int = 0
    var startPoint: UnitPoint = .topLeading
    var endPoint: UnitPoint = .bottomTrailing

    init(
        spot: Spot,
        fallbackIndex: Int = 0,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) {
        self.photoData = spot.photoData
        self.category = spot.categoryEnum
        self.fallbackIndex = fallbackIndex
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    init(
        photoData: Data?,
        category: SpotCategory,
        fallbackIndex: Int = 0,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) {
        self.photoData = photoData
        self.category = category
        self.fallbackIndex = fallbackIndex
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    var body: some View {
        Color.clear
            .overlay {
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    CategoryGradientView(
                        category: category,
                        fallbackIndex: fallbackIndex,
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                }
            }
            .clipped()
            .contentShape(Rectangle())
    }
}
