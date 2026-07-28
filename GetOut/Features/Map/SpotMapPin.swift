import SwiftUI

struct SpotMapPin: View {
    let category: SpotCategory
    var isSelected: Bool = false
    var isSaved: Bool = false
    var size: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size + 10, height: size + 10)
                        .shadow(color: .black.opacity(0.5), radius: 7, x: 0, y: 3)
                }

                Circle()
                    .fill(category.color)
                    .frame(width: size, height: size)
                    .overlay {
                        Circle()
                            .strokeBorder(isSaved ? Theme.Colors.accentGreen : Color.white.opacity(0.9), lineWidth: isSelected ? 3 : 2)
                    }

                Image(systemName: category.symbolName)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            }

            if isSelected {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 9))
                    .rotationEffect(.degrees(180))
                    .foregroundStyle(.white)
                    .offset(y: -2)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .scaleEffect(isSelected ? 1.15 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        .accessibilityLabel("\(category.rawValue) spot")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
