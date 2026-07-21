import SwiftUI
import SwiftData
import MapKit

private struct CategoryChip: Identifiable {
    let category: SpotCategory

    var id: String { category.rawValue }
    var label: String { category.displayName }
    var symbol: String { category.symbolName }
}

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Spot.rating, order: .reverse) private var allSpots: [Spot]
    @Query(filter: #Predicate<Profile> { $0.username == "harshil" }) private var demoProfiles: [Profile]

    @State private var selectedCategory: SpotCategory = .nearby
    @State private var showMapExplore = false
    @State private var showSearch = false
    @State private var openSearchFiltersOnAppear = false
    @State private var selectedSpot: Spot?

    private var categories: [CategoryChip] {
        SpotCategory.allCases.map { CategoryChip(category: $0) }
    }

    private var filteredSpots: [Spot] {
        guard selectedCategory != .nearby else { return allSpots }
        return allSpots.filter { $0.categoryEnum == selectedCategory }
    }

    private var demoProfile: Profile? { demoProfiles.first }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeroHeader(
                        displayName: demoProfile?.displayName ?? "Harshil",
                        heroSpot: allSpots.first,
                        topInset: geo.safeAreaInsets.top,
                        onSearchTap: {
                            openSearchFiltersOnAppear = false
                            showSearch = true
                        },
                        onFilterTap: {
                            openSearchFiltersOnAppear = true
                            showSearch = true
                        }
                    )

                    CategoryChipsRow(
                        categories: categories,
                        selectedCategory: $selectedCategory
                    )
                    .padding(.top, Theme.Spacing.lg)

                    ForYouNearbySection(
                        spots: filteredSpots,
                        demoProfile: demoProfile,
                        onToggleLike: toggleLike,
                        onSelectSpot: { selectedSpot = $0 }
                    )
                    .padding(.top, Theme.Spacing.xl)

                    ExploreMapSection(spots: allSpots) {
                        showMapExplore = true
                    }
                    .padding(.top, Theme.Spacing.xl)
                }
                .padding(.bottom, 96)
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Theme.Colors.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot)
        }
        .navigationDestination(isPresented: $showSearch) {
            SearchView(openFiltersOnAppear: openSearchFiltersOnAppear)
                .onDisappear {
                    openSearchFiltersOnAppear = false
                }
        }
        .fullScreenCover(isPresented: $showMapExplore) {
            MapExploreView()
        }
    }

    private func toggleLike(for spot: Spot) {
        guard let profile = demoProfile else { return }

        if let existing = spot.likes?.first(where: { $0.user?.id == profile.id }) {
            modelContext.delete(existing)
        } else {
            let like = Like()
            like.user = profile
            like.spot = spot
            modelContext.insert(like)
        }
    }
}

// MARK: - Hero Header

private struct HeroHeader: View {
    let displayName: String
    let heroSpot: Spot?
    let topInset: CGFloat
    let onSearchTap: () -> Void
    let onFilterTap: () -> Void

    private let heroHeight: CGFloat = 330
    private let heroSubtext = Color.black.opacity(0.7)

    var body: some View {
        ZStack(alignment: .top) {
            heroBackground(height: heroHeight)

            VStack(alignment: .leading, spacing: 0) {
                topRow
                    .padding(.top, Theme.Spacing.sm)

                Spacer(minLength: Theme.Spacing.lg)

                searchRow
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, topInset)
            .frame(height: heroHeight, alignment: .top)
        }
        .frame(height: heroHeight)
    }

    private func heroBackground(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Group {
                if let heroSpot {
                    SpotImage(spot: heroSpot, startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.82, blue: 0.72),
                            Color(red: 0.96, green: 0.90, blue: 0.78),
                            Color(red: 0.72, green: 0.78, blue: 0.62),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(height: height)

            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.82, blue: 0.72).opacity(0.55),
                    Color(red: 0.96, green: 0.90, blue: 0.78).opacity(0.45),
                    Color.black.opacity(0.35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)

            LinearGradient(
                colors: [.clear, Theme.Colors.appBackground],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: height * 0.55)
        }
        .frame(height: height)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 0
            )
        )
    }

    private var topRow: some View {
        HStack {
            Text("Good morning, \(displayName)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(heroSubtext)

            Spacer()

            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.body)
                        .foregroundStyle(heroSubtext)
                }
        }
    }

    private var searchRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onSearchTap) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.gray)

                    Text("Where to next?")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Color.gray.opacity(0.85))
                }
                .padding(.horizontal, Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 52)
                .background(Theme.Colors.cream)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onFilterTap) {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, Theme.Spacing.lg)
    }
}

// MARK: - Category Chips

private struct CategoryChipsRow: View {
    let categories: [CategoryChip]
    @Binding var selectedCategory: SpotCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(categories) { category in
                    CategoryChipItem(
                        category: category,
                        isSelected: selectedCategory == category.category
                    ) {
                        selectedCategory = category.category
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
}

private struct CategoryChipItem: View {
    let category: CategoryChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Theme.Colors.accentGreen : Theme.Colors.cream)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: category.symbol)
                            .font(.title3)
                            .foregroundStyle(isSelected ? Theme.Colors.textOnDarkPrimary : Color.black.opacity(0.75))
                    }

                Text(category.label)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - For You Nearby

private struct ForYouNearbySection: View {
    let spots: [Spot]
    let demoProfile: Profile?
    let onToggleLike: (Spot) -> Void
    let onSelectSpot: (Spot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.Colors.accentGreen)

                    Text("For you nearby")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                }

                Spacer()

                Button("View all") {}
                    .font(Theme.Typography.caption().weight(.medium))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .overlay {
                        Capsule()
                            .stroke(Theme.Colors.cream.opacity(0.6), lineWidth: 1)
                    }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                        SpotCard(
                            spot: spot,
                            gradientIndex: index,
                            isLiked: isLiked(spot),
                            onToggleLike: { onToggleLike(spot) },
                            onTap: { onSelectSpot(spot) }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    private func isLiked(_ spot: Spot) -> Bool {
        guard let profileID = demoProfile?.id else { return false }
        return spot.likes?.contains(where: { $0.user?.id == profileID }) == true
    }
}

// MARK: - Spot Card

private struct SpotCard: View {
    let spot: Spot
    let gradientIndex: Int
    let isLiked: Bool
    let onToggleLike: () -> Void
    let onTap: () -> Void

    private var isNew: Bool {
        spot.createdAt.timeIntervalSinceNow > -14 * 24 * 60 * 60
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .top) {
                SpotImage(spot: spot, fallbackIndex: gradientIndex)
                    .frame(width: 240, height: 300)
                    .clipped()

                VStack {
                    HStack {
                        if isNew {
                            Text("New")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Theme.Colors.accentGreen)
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }
                    .padding(Theme.Spacing.sm)

                    Spacer()

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(spot.title)
                                .font(Theme.Typography.serifDisplay(size: 20))
                                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(locationLine)
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Color.white.opacity(0.85))

                            HStack {
                                AvatarCluster(count: 3)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                                    Text(String(format: "%.1f", spot.rating))
                                        .font(Theme.Typography.caption().weight(.medium))
                                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                    }
                }
                .frame(width: 240, height: 300)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button(action: onToggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isLiked ? .red : Theme.Colors.textOnDarkPrimary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(Theme.Spacing.sm)
        }
    }

    private var locationLine: String {
        if spot.neighborhood.isEmpty {
            return "Nearby"
        }
        return "Nearby · \(spot.neighborhood)"
    }
}

// MARK: - Explore Map

private struct ExploreMapSection: View {
    let spots: [Spot]
    let onTap: () -> Void

    private var mappableSpots: [Spot] {
        spots.filter { $0.mapCoordinate != nil }
    }

    private var previewRegion: MKCoordinateRegion {
        LocationManager.defaultRegion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Explore the map")
                .padding(.horizontal, Theme.Spacing.md)

            Button(action: onTap) {
                ZStack(alignment: .bottomLeading) {
                    Map(position: .constant(.region(previewRegion))) {
                        ForEach(mappableSpots) { spot in
                            if let coordinate = spot.mapCoordinate {
                                Annotation(spot.title, coordinate: coordinate) {
                                    SpotMapPin(category: spot.categoryEnum, size: 28)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat))
                    .allowsHitTesting(false)

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)

                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Tap to explore")
                            .font(Theme.Typography.body().weight(.medium))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    }
                    .padding(Theme.Spacing.md)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Theme.Colors.cream.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.bottom, Theme.Spacing.xl)
    }
}

// MARK: - Avatar Cluster

private struct AvatarCluster: View {
    let count: Int

    var body: some View {
        HStack(spacing: -8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(Theme.Colors.cardSurface)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    }
                    .overlay {
                        Circle()
                            .stroke(Theme.Colors.appBackground, lineWidth: 2)
                    }
                    .zIndex(Double(count - index))
            }
        }
    }
}

#Preview {
    NavigationStack {
        DiscoverView()
    }
    .modelContainer(for: [Profile.self, Spot.self, Tag.self, Like.self], inMemory: true)
    .preferredColorScheme(.dark)
}
