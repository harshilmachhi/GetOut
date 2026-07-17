import SwiftUI

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 20
        static let control: CGFloat = 14
        static let pill: CGFloat = 999
    }

    enum Colors {
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let accent = Color(red: 0.42, green: 0.60, blue: 0.38)

        static let appBackground = Color(red: 0.04, green: 0.04, blue: 0.045)
        static let accentGreen = Color(red: 0.42, green: 0.60, blue: 0.38)
        static let cream = Color(red: 0.97, green: 0.96, blue: 0.93)
        static let textOnDarkPrimary = Color.white
        static let textOnDarkSecondary = Color.white.opacity(0.6)
        static let cardSurface = Color(red: 0.11, green: 0.11, blue: 0.12)
    }

    enum Typography {
        static func largeTitle() -> Font {
            .system(.largeTitle, design: .rounded, weight: .bold)
        }

        static func sectionHeader() -> Font {
            .system(.title3, design: .default, weight: .bold)
        }

        static func body() -> Font {
            .system(.body, design: .default)
        }

        static func caption() -> Font {
            .system(.caption, design: .default)
        }

        static func serifDisplay(size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .serif)
        }

        static func script(size: CGFloat) -> Font {
            if UIFont(name: "SnellRoundhand-Bold", size: size) != nil {
                .custom("SnellRoundhand-Bold", size: size)
            } else {
                .system(size: size, weight: .bold, design: .serif)
            }
        }
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.Typography.sectionHeader())
            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
