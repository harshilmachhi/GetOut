import SwiftUI

struct SpotMapPin: View {
    let category: SpotCategory
    var isSelected: Bool = false
    var isSaved: Bool = false
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(category.color)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .strokeBorder(isSaved ? Theme.Colors.accentGreen : Color.white.opacity(isSelected ? 1 : 0.85), lineWidth: isSelected ? 3 : 2)
                }
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

            Image(systemName: category.symbolName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .scaleEffect(isSelected ? 1.12 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(SpotCategory.allCases, id: \.self) { category in
            SpotMapPin(category: category)
        }
    }
    .padding()
    .background(Theme.Colors.appBackground)
    .preferredColorScheme(.dark)
}
