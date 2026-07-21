import SwiftData
import SwiftUI

struct LocalSocialListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(sort: \Follow.createdAt) private var follows: [Follow]

    let kind: PublicSocialListKind
    let profile: Profile

    private var currentProfile: Profile? {
        profiles.first(where: { $0.username == session.currentUsername }) ?? profiles.first
    }

    private var listedProfiles: [Profile] {
        let relevantFollows = follows.filter { follow in
            switch kind {
            case .followers:
                return follow.followee?.id == profile.id
            case .following:
                return follow.follower?.id == profile.id
            }
        }

        let mapped: [Profile] = relevantFollows.compactMap { follow in
            switch kind {
            case .followers:
                return follow.follower
            case .following:
                return follow.followee
            }
        }

        var seen = Set<UUID>()
        return mapped.filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        Group {
            if listedProfiles.isEmpty {
                LocalSocialEmptyState(kind: kind)
            } else {
                List {
                    ForEach(listedProfiles, id: \.id) { listedProfile in
                        LocalSocialProfileRow(
                            profile: listedProfile,
                            isFollowing: isFollowing(listedProfile),
                            showsFollowToggle: listedProfile.id != currentProfile?.id,
                            onToggleFollow: { toggleFollow(for: listedProfile) }
                        )
                        .listRowBackground(Theme.Colors.cardSurface)
                        .listRowSeparatorTint(Theme.Colors.textOnDarkSecondary.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 96)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.appBackground)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isFollowing(_ profile: Profile) -> Bool {
        guard let currentProfile else { return false }
        return follows.contains {
            $0.follower?.id == currentProfile.id && $0.followee?.id == profile.id
        }
    }

    private func toggleFollow(for profile: Profile) {
        guard let currentProfile, currentProfile.id != profile.id else { return }

        if let existing = follows.first(where: {
            $0.follower?.id == currentProfile.id && $0.followee?.id == profile.id
        }) {
            modelContext.delete(existing)
        } else {
            let follow = Follow()
            follow.follower = currentProfile
            follow.followee = profile
            modelContext.insert(follow)
        }

        try? modelContext.save()
    }
}

private struct LocalSocialProfileRow: View {
    let profile: Profile
    let isFollowing: Bool
    let showsFollowToggle: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.Colors.cardSurface)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: profile.avatarSystemImage)
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(Theme.Typography.body().weight(.medium))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                Text("@\(profile.username)")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }

            Spacer()

            if showsFollowToggle {
                Button(action: onToggleFollow) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(Theme.Typography.caption().weight(.semibold))
                        .foregroundStyle(isFollowing ? Theme.Colors.textOnDarkPrimary : Theme.Colors.appBackground)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(isFollowing ? Theme.Colors.cardSurface : Theme.Colors.accentGreen)
                        .clipShape(Capsule())
                        .overlay {
                            if isFollowing {
                                Capsule()
                                    .stroke(Theme.Colors.textOnDarkSecondary.opacity(0.35), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct LocalSocialEmptyState: View {
    let kind: PublicSocialListKind

    private var message: String {
        switch kind {
        case .followers:
            "No followers yet"
        case .following:
            "Not following anyone yet"
        }
    }

    private var systemImage: String {
        switch kind {
        case .followers:
            "person.2"
        case .following:
            "person.badge.plus"
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Text(message)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
    }
}

#Preview("Following") {
    let container = try! ModelContainer(
        for: Profile.self, Follow.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let harshil = Profile()
    harshil.username = "harshil"
    harshil.displayName = "Harshil"
    context.insert(harshil)

    let maya = Profile()
    maya.username = "maya"
    maya.displayName = "Maya Chen"
    context.insert(maya)

    let follow = Follow()
    follow.follower = harshil
    follow.followee = maya
    context.insert(follow)

    return NavigationStack {
        LocalSocialListView(kind: .following, profile: harshil)
    }
    .modelContainer(container)
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}
