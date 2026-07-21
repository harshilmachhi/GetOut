import SwiftData
import SwiftUI

struct SearchView: View {
    var openFiltersOnAppear: Bool = false

    @Query private var allSpots: [Spot]

    @State private var searchText = ""
    @State private var selectedCategory: SpotCategory = .nearby
    @State private var selectedTags: Set<String> = []
    @State private var sort: SearchSort = .topRated
    @State private var showFiltersSheet = false
    @State private var selectedSpot: Spot?

    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let gridColumns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    private var categories: [SpotCategory] {
        SpotCategory.allCases
    }

    private var hasActiveSheetFilters: Bool {
        !selectedTags.isEmpty || sort != .topRated
    }

    private var hasActiveQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedCategory != .nearby
            || !selectedTags.isEmpty
    }

    private var filteredSpots: [Spot] {
        var results = allSpots

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            results = results.filter { spot in
                spot.title.localizedCaseInsensitiveContains(query)
                    || spot.neighborhood.localizedCaseInsensitiveContains(query)
                    || spot.city.localizedCaseInsensitiveContains(query)
                    || (spot.tags?.contains { $0.name.localizedCaseInsensitiveContains(query) } ?? false)
            }
        }

        if selectedCategory != .nearby {
            results = results.filter { $0.categoryEnum == selectedCategory }
        }

        if !selectedTags.isEmpty {
            results = results.filter { spot in
                let spotTagNames = Set(spot.tags?.map(\.name) ?? [])
                return selectedTags.isSubset(of: spotTagNames)
            }
        }

        switch sort {
        case .topRated:
            return results.sorted { $0.rating > $1.rating }
        case .newest:
            return results.sorted { $0.createdAt > $1.createdAt }
        case .name:
            return results.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                headerSection
                searchField
                categoryChipsRow
                filtersRow
                resultsSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, 96)
        }
        .background(Theme.Colors.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot)
        }
        .sheet(isPresented: $showFiltersSheet) {
            SearchFiltersSheet(selectedTags: $selectedTags, sort: $sort)
        }
        .onAppear {
            isSearchFocused = true
            if openFiltersOnAppear {
                showFiltersSheet = true
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.cardSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("Search")
                .font(Theme.Typography.serifDisplay(size: 34))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            Spacer()
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.gray)

            TextField("Search spots, neighborhoods, tags…", text: $searchText)
                .font(Theme.Typography.body())
                .foregroundStyle(Color.black.opacity(0.85))
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gray.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 52)
        .background(Theme.Colors.cream)
        .clipShape(Capsule())
    }

    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(categories, id: \.self) { category in
                    SearchCategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private var filtersRow: some View {
        HStack {
            Text("\(filteredSpots.count) spot\(filteredSpots.count == 1 ? "" : "s")")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Spacer()

            Button {
                showFiltersSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.cardSurface)
                        .clipShape(Circle())

                    if hasActiveSheetFilters {
                        Circle()
                            .fill(Theme.Colors.accentGreen)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filters")
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if filteredSpots.isEmpty && hasActiveQuery {
            emptyResultsState
        } else {
            LazyVGrid(columns: gridColumns, spacing: Theme.Spacing.md) {
                ForEach(Array(filteredSpots.enumerated()), id: \.element.id) { index, spot in
                    SearchSpotTile(spot: spot, gradientIndex: index) {
                        selectedSpot = spot
                    }
                }
            }
        }
    }

    private var emptyResultsState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Text("No spots match")
                .font(Theme.Typography.sectionHeader())
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            Text("Try adjusting your search or filters.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }
}

// MARK: - Category Chip

private struct SearchCategoryChip: View {
    let category: SpotCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Theme.Colors.accentGreen : Theme.Colors.cream)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: category.symbolName)
                            .font(.title3)
                            .foregroundStyle(isSelected ? Theme.Colors.textOnDarkPrimary : Color.black.opacity(0.75))
                    }

                Text(category.displayName)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spot Tile

private struct SearchSpotTile: View {
    let spot: Spot
    let gradientIndex: Int
    let onTap: () -> Void

    private let tileHeight: CGFloat = 150

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                SpotImage(spot: spot, fallbackIndex: gradientIndex)
                    .frame(height: tileHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.title)
                        .font(Theme.Typography.serifDisplay(size: 15))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(locationLine)
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                        Text(String(format: "%.1f", spot.rating))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.sm)
            }
            .frame(height: tileHeight)
        }
        .buttonStyle(.plain)
    }

    private var locationLine: String {
        spot.neighborhood.isEmpty ? "Nearby" : spot.neighborhood
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .modelContainer(for: [Profile.self, Spot.self, Tag.self], inMemory: true)
    .preferredColorScheme(.dark)
}
