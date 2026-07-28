import SwiftUI
import SwiftData
import CloudKit

private enum AppTab: CaseIterable, Hashable {
    case home
    case maps
    case add
    case trips
    case profile

    var title: String {
        switch self {
        case .home: "Home"
        case .maps: "Maps"
        case .trips: "Trip"
        case .add: "Add"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .maps: "map"
        case .trips: "suitcase"
        case .add: "plus.circle.fill"
        case .profile: "person.crop.circle"
        }
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @State private var selectedTab: AppTab = .home
    @State private var socialCoordinator = PublicSocialCoordinator.shared
    @State private var tabResetID = UUID()
    @Namespace private var tabIndicator

    var body: some View {
        Group {
            if session.isResolvingAccount {
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .tint(Theme.Colors.accentGreen)
                    Text("Connecting to iCloud…")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.appBackground)
            } else {
                ZStack(alignment: .bottom) {
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    CustomTabBar(
                        selectedTab: $selectedTab,
                        namespace: tabIndicator,
                        onReselect: resetCurrentTab
                    )
                }
                .background(Theme.Colors.appBackground)
            }
        }
        .task {
            await socialCoordinator.restoreCurrentProfile(in: modelContext, session: session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
            session.beginAccountResolution(clearPersistedProfile: true)
            Task {
                await socialCoordinator.restoreCurrentProfile(in: modelContext, session: session)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                DiscoverView()
            }
            .id(tabResetID)
        case .maps:
            MapExploreView()
                .id(tabResetID)
        case .trips:
            NavigationStack {
                accountProtected { TripsView() }
            }
            .id(tabResetID)
        case .add:
            NavigationStack {
                accountProtected { AddSpotView() }
            }
            .id(tabResetID)
        case .profile:
            NavigationStack {
                accountProtected { ProfileView() }
            }
            .id(tabResetID)
        }
    }

    @ViewBuilder
    private func accountProtected<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if session.hasCompletedOnboarding {
            content()
        } else {
            OnboardingFlowView()
        }
    }

    private func resetCurrentTab() {
        // A second tap on a bottom-tab item returns that section to its root screen.
        tabResetID = UUID()
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var namespace: Namespace.ID
    let onReselect: () -> Void

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
                if selectedTab == tab {
                    onReselect()
                }
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
