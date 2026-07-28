import SwiftData
import SwiftUI

private enum ProfileSegment: String, CaseIterable, Identifiable {
    case loved = "Loved"
    case created = "Created"
    case been = "Been"
    case cities = "Cities"

    var id: String { rawValue }

    var emptyMessage: String {
        switch self {
        case .loved: "No loved spots yet"
        case .created: "No created spots yet"
        case .been: "No been-there spots yet"
        case .cities: "No cities yet"
        }
    }
}

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(sort: \Spot.createdAt) private var allSpots: [Spot]
    @Query(sort: \Like.createdAt, order: .reverse) private var allLikes: [Like]
    @Query(sort: \Save.createdAt, order: .reverse) private var allSaves: [Save]
    @Query private var blockedUsers: [UserBlock]

    @State private var selectedSegment: ProfileSegment = .loved
    @State private var selectedSpot: Spot?
    @State private var spotPendingDeletion: Spot?
    @State private var deletionError: String?
    @State private var socialCoordinator = PublicSocialCoordinator.shared

    private var profile: Profile? {
        session.currentProfile(in: profiles)
    }

    private var profileID: UUID? { profile?.id }

    private var ownedSpots: [Spot] {
        guard let profileID else { return [] }
        return allSpots.filter { $0.owner?.id == profileID }
    }

    private var lovedSpots: [Spot] {
        guard let profileID else { return [] }
        return allLikes
            .filter { $0.user?.id == profileID }
            .compactMap(\.spot)
    }

    private var beenSpots: [Spot] {
        guard let profileID else { return [] }
        return allSaves
            .filter { $0.user?.id == profileID && $0.list == SaveList.beenThere.rawValue }
            .compactMap(\.spot)
    }

    private var cityGroups: [(city: String, spots: [Spot])] {
        let combined = uniqueSpots([lovedSpots, beenSpots, ownedSpots].flatMap { $0 })
        let grouped = Dictionary(grouping: combined.filter { !$0.city.isEmpty }) { $0.city }
        return grouped
            .map { (city: $0.key, spots: $0.value) }
            .sorted { $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending }
    }

    var body: some View {
        Group {
            if let profile {
                profileContent(for: profile)
            } else {
                ProfileMissingState()
            }
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot)
        }
        .confirmationDialog(
            "Delete \(spotPendingDeletion?.title ?? "this spot")?",
            isPresented: Binding(
                get: { spotPendingDeletion != nil },
                set: { if !$0 { spotPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete spot", role: .destructive) {
                if let spotPendingDeletion {
                    delete(spotPendingDeletion)
                }
            }
            Button("Cancel", role: .cancel) { spotPendingDeletion = nil }
        } message: {
            Text("This permanently deletes the spot from your collection and removes it from the public feed if it was shared.")
        }
        .alert("Couldn’t delete spot", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }
        .task(id: profile?.id) {
            guard FeatureFlags.publicSocialEnabled, let profile else { return }
            await socialCoordinator.bootstrapIdentity(for: profile, in: modelContext)
        }
    }

    @ViewBuilder
    private func profileContent(for profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ProfileHeaderCard(
                    profile: profile,
                    spotCount: ownedSpots.count
                )

                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        ProfileManagementButton(title: "Settings", symbol: "gearshape")
                    }

                    NavigationLink {
                        BlockedPeopleView()
                    } label: {
                        ProfileManagementButton(
                            title: "Blocked people",
                            symbol: "hand.raised.fill",
                            detail: blockedUsers.isEmpty ? nil : "\(blockedUsers.count)"
                        )
                    }
                }

                Picker("Profile section", selection: $selectedSegment) {
                    ForEach(ProfileSegment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)

                segmentContent
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, 96)
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case .loved:
            ProfileSpotGrid(spots: lovedSpots, emptyMessage: ProfileSegment.loved.emptyMessage) {
                selectedSpot = $0
            }
        case .created:
            ProfileSpotGrid(
                spots: ownedSpots,
                emptyMessage: ProfileSegment.created.emptyMessage,
                onDelete: { spotPendingDeletion = $0 }
            ) {
                selectedSpot = $0
            }
        case .been:
            ProfileSpotGrid(spots: beenSpots, emptyMessage: ProfileSegment.been.emptyMessage) {
                selectedSpot = $0
            }
        case .cities:
            ProfileCitiesList(cityGroups: cityGroups, emptyMessage: ProfileSegment.cities.emptyMessage)
        }
    }

    private func uniqueSpots(_ spots: [Spot]) -> [Spot] {
        var seen = Set<UUID>()
        return spots.filter { seen.insert($0.id).inserted }
    }

    private func delete(_ spot: Spot) {
        spotPendingDeletion = nil

        Task {
            if FeatureFlags.publicSocialEnabled,
               !spot.publicRecordName.isEmpty,
               !(await socialCoordinator.unpublishSpot(spot, in: modelContext)) {
                deletionError = socialCoordinator.publishError ?? "The spot could not be removed from the public feed."
                return
            }

            profile?.spots?.removeAll { $0.id == spot.id }
            modelContext.delete(spot)

            do {
                try modelContext.save()
            } catch {
                deletionError = "The spot could not be deleted. Please try again."
            }
        }
    }
}

private struct ProfileManagementButton: View {
    let title: String
    let symbol: String
    var detail: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(Theme.Typography.caption().weight(.semibold))
            if let detail {
                Text(detail)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.textOnDarkPrimary.opacity(0.12))
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}

// MARK: - Header

private struct ProfileHeaderCard: View {
    let profile: Profile
    let spotCount: Int

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.Colors.cardSurface)
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: profile.avatarSystemImage)
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }

            VStack(spacing: Theme.Spacing.xs) {
                Text(profile.displayName)
                    .font(Theme.Typography.serifDisplay(size: 22))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                Text("@\(profile.username)")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack {
                ProfileStatItem(value: spotCount, label: "Spots")
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .card()
    }
}

private struct ProfileStatItem: View {
    let value: Int
    let label: String
    var body: some View {
        statContent
    }

    private var statContent: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(value)")
                .font(Theme.Typography.sectionHeader())
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            Text(label)
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
    }
}

// MARK: - Spot Grid

private struct ProfileSpotGrid: View {
    let spots: [Spot]
    let emptyMessage: String
    var onDelete: ((Spot) -> Void)? = nil
    let onSelect: (Spot) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
    ]

    var body: some View {
        if spots.isEmpty {
            ProfileEmptyState(message: emptyMessage)
        } else {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                    ZStack(alignment: .topTrailing) {
                        ProfileSpotTile(spot: spot, gradientIndex: index) {
                            onSelect(spot)
                        }

                        if let onDelete {
                            Button {
                                onDelete(spot)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(Theme.Spacing.sm)
                            .accessibilityLabel("Delete \(spot.title)")
                        }
                    }
                }
            }
        }
    }
}

private struct ProfileSpotTile: View {
    let spot: Spot
    let gradientIndex: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                SpotImage(spot: spot, fallbackIndex: gradientIndex)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.title)
                            .font(Theme.Typography.serifDisplay(size: 14))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !spot.neighborhood.isEmpty {
                            Text(spot.neighborhood)
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(Theme.Spacing.sm)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cities

private struct ProfileCitiesList: View {
    let cityGroups: [(city: String, spots: [Spot])]
    let emptyMessage: String

    var body: some View {
        if cityGroups.isEmpty {
            ProfileEmptyState(message: emptyMessage)
        } else {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(cityGroups.enumerated()), id: \.element.city) { index, group in
                    ProfileCityRow(
                        city: group.city,
                        spotCount: group.spots.count,
                        representativeSpot: group.spots.first,
                        gradientIndex: index
                    )
                }
            }
        }
    }
}

private struct ProfileCityRow: View {
    let city: String
    let spotCount: Int
    let representativeSpot: Spot?
    let gradientIndex: Int

    private var representativeCategory: SpotCategory {
        representativeSpot?.categoryEnum
            ?? SpotCategory.allCases[gradientIndex % SpotCategory.allCases.count]
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Group {
                if let representativeSpot {
                    SpotImage(spot: representativeSpot, fallbackIndex: gradientIndex)
                } else {
                    CategoryGradientView(category: representativeCategory, fallbackIndex: gradientIndex)
                }
            }
            .frame(width: 56, height: 56)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(city)
                    .font(Theme.Typography.serifDisplay(size: 18))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                Text("\(spotCount) spot\(spotCount == 1 ? "" : "s")")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}

// MARK: - Empty States

private struct ProfileEmptyState: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Text(message)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

private struct ProfileMissingState: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Text("No profile found")
                .font(Theme.Typography.sectionHeader())
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            Text("Your profile will appear here once you're set up.")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Profile.self, Spot.self, Tag.self, Like.self, Save.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let profile = Profile()
    profile.username = "harshil"
    profile.displayName = "Harshil"
    profile.bio = "Exploring NYC one hidden spot at a time."
    profile.avatarSystemImage = "person.fill"
    context.insert(profile)

    let spotSpecs: [(String, String, SpotCategory)] = [
        ("Sunset hill seating", "Fort Greene", .views),
        ("Hidden cafe in the garden", "Clinton Hill", .coffee),
        ("East River quiet spot", "Williamsburg", .nature),
    ]

    for (title, neighborhood, category) in spotSpecs {
        let spot = Spot()
        spot.title = title
        spot.neighborhood = neighborhood
        spot.city = "New York"
        spot.category = category.rawValue
        spot.rating = 4.8
        spot.owner = profile
        context.insert(spot)

        let like = Like()
        like.user = profile
        like.spot = spot
        context.insert(like)
    }

    return NavigationStack {
        ProfileView()
    }
    .modelContainer(container)
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
