import SwiftData
import SwiftUI

private enum ProfileSegment: String, CaseIterable, Identifiable {
    case loved = "Loved"
    case saved = "Saved"
    case been = "Been"
    case cities = "Cities"

    var id: String { rawValue }

    var emptyMessage: String {
        switch self {
        case .loved: "No loved spots yet"
        case .saved: "No saved spots yet"
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
    @Query private var allFollows: [Follow]

    @State private var selectedSegment: ProfileSegment = .loved
    @State private var selectedSpot: Spot?
    @State private var socialCoordinator = PublicSocialCoordinator.shared
    @State private var socialListKind: PublicSocialListKind?

    private var profile: Profile? {
        profiles.first(where: { $0.username == session.currentUsername }) ?? profiles.first
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

    private var savedSpots: [Spot] {
        guard let profileID else { return [] }
        return allSaves
            .filter { $0.user?.id == profileID && $0.list == SaveList.saved.rawValue }
            .compactMap(\.spot)
    }

    private var beenSpots: [Spot] {
        guard let profileID else { return [] }
        return allSaves
            .filter { $0.user?.id == profileID && $0.list == SaveList.beenThere.rawValue }
            .compactMap(\.spot)
    }

    private var cityGroups: [(city: String, spots: [Spot])] {
        let combined = uniqueSpots([lovedSpots, savedSpots, beenSpots, ownedSpots].flatMap { $0 })
        let grouped = Dictionary(grouping: combined.filter { !$0.city.isEmpty }) { $0.city }
        return grouped
            .map { (city: $0.key, spots: $0.value) }
            .sorted { $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending }
    }

    private var followerCount: Int {
        if FeatureFlags.publicSocialEnabled, let profile {
            if profile.publicFollowerCount > 0 {
                return profile.publicFollowerCount
            }
            if !profile.cloudKitUserRecordName.isEmpty {
                return PublicSocialCacheStore.publicFollowerCount(
                    for: profile.cloudKitUserRecordName,
                    in: modelContext
                )
            }
        }
        guard let profileID else { return 0 }
        return allFollows.filter { $0.followee?.id == profileID }.count
    }

    private var followingCount: Int {
        if FeatureFlags.publicSocialEnabled, let profile {
            if profile.publicFollowingCount > 0 {
                return profile.publicFollowingCount
            }
            if !profile.cloudKitUserRecordName.isEmpty {
                return PublicSocialCacheStore.publicFollowingCount(
                    for: profile.cloudKitUserRecordName,
                    in: modelContext
                )
            }
        }
        guard let profileID else { return 0 }
        return allFollows.filter { $0.follower?.id == profileID }.count
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
        .navigationDestination(item: $socialListKind) { kind in
            if FeatureFlags.publicSocialEnabled,
               let recordName = profile?.cloudKitUserRecordName,
               !recordName.isEmpty {
                PublicSocialListView(kind: kind, userRecordName: recordName)
            } else if let profile {
                LocalSocialListView(kind: kind, profile: profile)
            }
        }
        .task(id: profile?.id) {
            guard FeatureFlags.publicSocialEnabled, let profile else { return }
            await socialCoordinator.bootstrapIdentity(for: profile, in: modelContext)
            await socialCoordinator.refreshProfileSocial(for: profile, in: modelContext)
        }
    }

    @ViewBuilder
    private func profileContent(for profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ProfileHeaderCard(
                    profile: profile,
                    spotCount: ownedSpots.count,
                    followerCount: followerCount,
                    followingCount: followingCount,
                    onFollowersTap: { socialListKind = .followers },
                    onFollowingTap: { socialListKind = .following }
                )

                if FeatureFlags.publicSocialEnabled, let message = socialCoordinator.profileSocialError {
                    PublicSocialInlineMessage(message: message)
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
        case .saved:
            ProfileSpotGrid(spots: savedSpots, emptyMessage: ProfileSegment.saved.emptyMessage) {
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
}

// MARK: - Header

private struct ProfileHeaderCard: View {
    let profile: Profile
    let spotCount: Int
    let followerCount: Int
    let followingCount: Int
    var onFollowersTap: (() -> Void)?
    var onFollowingTap: (() -> Void)?

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

            HStack(spacing: Theme.Spacing.xl) {
                ProfileStatItem(value: spotCount, label: "Spots")
                ProfileStatItem(value: followerCount, label: "Followers", action: onFollowersTap)
                ProfileStatItem(value: followingCount, label: "Following", action: onFollowingTap)
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .card()
        .overlay(alignment: .topTrailing) {
            NavigationLink {
                AddFriendsView()
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accentGreen)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.accentGreen.opacity(0.14))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Theme.Colors.accentGreen.opacity(0.45), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(Theme.Spacing.sm)
        }
    }
}

private struct ProfileStatItem: View {
    let value: Int
    let label: String
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    statContent
                }
                .buttonStyle(.plain)
            } else {
                statContent
            }
        }
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
                    ProfileSpotTile(spot: spot, gradientIndex: index) {
                        onSelect(spot)
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
        for: Profile.self, Spot.self, Tag.self, Like.self, Save.self, Follow.self,
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
