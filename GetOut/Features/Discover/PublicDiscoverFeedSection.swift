import SwiftData
import SwiftUI

struct PublicDiscoverFeedSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = PublicSocialCoordinator.shared
    @State private var selectedSpot: Spot?
    @State private var locationManager = LocationManager()
    @AppStorage("privacy.hasConfirmedCannabisLegalAge") private var hasConfirmedCannabisLegalAge = false

    private var canViewCannabisContent: Bool {
        CannabisPolicy.canAccess(
            ageConfirmed: hasConfirmedCannabisLegalAge,
            countryCode: locationManager.countryCode,
            administrativeArea: locationManager.administrativeArea
        )
    }

    var body: some View {
        if FeatureFlags.publicSocialEnabled {
            sectionContent
                .task {
                    locationManager.requestPermission()
                    await coordinator.refreshFeed(in: modelContext)
                }
                .navigationDestination(item: $selectedSpot) { spot in
                    SpotDetailView(spot: spot)
                }
        }
    }

    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    SectionHeader(title: "Community reviews")
                    Text("Available to everyone — following is optional.")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }

                Spacer()

                if coordinator.isLoadingFeed {
                    ProgressView()
                        .tint(Theme.Colors.accentGreen)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            if let feedError = coordinator.feedError {
                PublicSocialInlineMessage(message: feedError)
                    .padding(.horizontal, Theme.Spacing.md)
            }

            let spots = coordinator.cachedFeedSpots(
                in: modelContext,
                allowCannabis: canViewCannabisContent
            )
            if spots.isEmpty && !coordinator.isLoadingFeed {
                PublicSocialInlineMessage(message: "No public spots yet. Publish a spot when you're signed into iCloud.")
                    .padding(.horizontal, Theme.Spacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                            PublicFeedSpotCard(spot: spot, gradientIndex: index) {
                                selectedSpot = spot
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }

                if coordinator.hasMoreFeed {
                    Button("Load more") {
                        Task {
                            await coordinator.refreshFeed(in: modelContext, loadMore: true)
                        }
                    }
                    .font(Theme.Typography.caption().weight(.medium))
                    .foregroundStyle(Theme.Colors.accentGreen)
                    .padding(.horizontal, Theme.Spacing.md)
                }
            }
        }
        .padding(.bottom, Theme.Spacing.xl)
    }
}

private struct PublicFeedSpotCard: View {
    let spot: Spot
    let gradientIndex: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                SpotImage(spot: spot, fallbackIndex: gradientIndex)
                    .frame(width: 220, height: 260)
                    .clipped()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(spot.title)
                            .font(Theme.Typography.serifDisplay(size: 18))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .lineLimit(2)

                        if !spot.neighborhood.isEmpty {
                            Text(spot.neighborhood)
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

struct PublicSocialInlineMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Theme.Typography.caption())
            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}

#Preview {
    ScrollView {
        PublicDiscoverFeedSection()
    }
    .background(Theme.Colors.appBackground)
    .modelContainer(for: Spot.self, inMemory: true)
    .preferredColorScheme(.dark)
}
