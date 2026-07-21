import SwiftUI

private enum AppTab: CaseIterable, Hashable {
    case discover
    case trips
    case add
    case profile

    var title: String {
        switch self {
        case .discover: "Discover"
        case .trips: "Trips"
        case .add: "Add"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .discover: "map"
        case .trips: "suitcase"
        case .add: "plus.circle.fill"
        case .profile: "person.crop.circle"
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .discover
    @Namespace private var tabIndicator

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(
                selectedTab: $selectedTab,
                namespace: tabIndicator
            )
        }
        .background(Theme.Colors.appBackground)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .discover:
            NavigationStack {
                DiscoverView()
            }
        case .trips:
            NavigationStack {
                TripsView()
            }
        case .add:
            NavigationStack {
                AddSpotView()
            }
        case .profile:
            NavigationStack {
                ProfileView()
            }
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var namespace: Namespace.ID

    private let indicatorWidth: CGFloat = 52
    private let indicatorHeight: CGFloat = 34
    private let barCornerRadius: CGFloat = 28

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: barCornerRadius)
                .fill(Theme.Colors.cardSurface)
                .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: barCornerRadius))
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                if selectedTab == tab {
                    Capsule()
                        .fill(Theme.Colors.accentGreen.opacity(0.28))
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        .frame(width: indicatorWidth, height: indicatorHeight)
                }

                Image(systemName: tab.icon)
                    .font(.system(size: tab == .add ? 24 : 22, weight: selectedTab == tab ? .semibold : .regular))
                    .symbolRenderingMode(selectedTab == tab ? .palette : .monochrome)
                    .foregroundStyle(
                        selectedTab == tab ? Theme.Colors.accentGreen : Theme.Colors.textOnDarkSecondary,
                        selectedTab == tab ? Theme.Colors.accentGreen : Theme.Colors.textOnDarkSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}

#Preview {
    RootTabView()
        .preferredColorScheme(.dark)
}
