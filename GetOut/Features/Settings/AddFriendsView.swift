import SwiftData
import SwiftUI
import UIKit

struct AddFriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session

    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(sort: \Follow.createdAt) private var follows: [Follow]

    @State private var contactsMatcher = ContactsFriendMatcher()
    @State private var suggestions: [FriendSuggestion] = []

    private var currentProfile: Profile? {
        profiles.first(where: { $0.username == session.currentUsername }) ?? profiles.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header

                if !contactsMatcher.isAuthorized {
                    contactsPrompt
                } else if contactsMatcher.isDenied {
                    contactsDeniedBanner
                }

                if suggestions.isEmpty {
                    emptyState
                } else {
                    suggestionsList
                }
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Add Friends")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            contactsMatcher.refreshAuthorizationStatus()
            if contactsMatcher.isAuthorized {
                await contactsMatcher.loadContactNames()
            }
            refreshSuggestions()
        }
        .onChange(of: profiles.count) { _, _ in refreshSuggestions() }
        .onChange(of: follows.count) { _, _ in refreshSuggestions() }
        .onChange(of: contactsMatcher.matchedContactNames) { _, _ in refreshSuggestions() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Find your people")
                .font(Theme.Typography.serifDisplay(size: 28))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            Text("Follow friends to keep up with people you know. Community reviews and spots are available to everyone.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
    }

    private var contactsPrompt: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.accentGreen)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Find friends from contacts")
                        .font(Theme.Typography.sectionHeader())
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                    Text("We'll match names you already know — nothing leaves your device.")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }
            }

            Button {
                if contactsMatcher.canRequestAccess {
                    Task {
                        await contactsMatcher.requestAccessAndLoadContacts()
                        refreshSuggestions()
                    }
                } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text(contactsMatcher.canRequestAccess ? "Allow Contacts" : "Open Settings")
                    .font(Theme.Typography.body().weight(.semibold))
                    .foregroundStyle(Theme.Colors.appBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm + 2)
                    .background(Theme.Colors.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            .buttonStyle(.plain)
            .disabled(contactsMatcher.isLoading)
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private var contactsDeniedBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Text("Contacts access is off. You can still browse suggestions below.")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardSurface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private var suggestionsList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Suggested for you")

            ForEach(suggestions) { suggestion in
                if let profile = profile(for: suggestion.profile.id) {
                    FriendSuggestionRow(
                        profile: profile,
                        reasons: suggestion.reasons,
                        isFollowing: isFollowing(profile),
                        onToggleFollow: { toggleFollow(for: profile) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "person.2.slash")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Text("No suggestions yet")
                .font(Theme.Typography.sectionHeader())
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            Text("Check back after more people join GetOut, or allow contacts to find people you know.")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    private func refreshSuggestions() {
        guard let currentProfile else {
            suggestions = []
            return
        }

        let followEdges = follows.compactMap(\.followEdge)
        let candidates = profiles.map(\.friendRecommendationProfile)

        suggestions = FriendRecommendationEngine.rank(
            currentUser: currentProfile.friendRecommendationProfile,
            candidates: candidates,
            follows: followEdges,
            matchedContactNames: contactsMatcher.matchedContactNames
        )
    }

    private func profile(for id: UUID) -> Profile? {
        profiles.first(where: { $0.id == id })
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
        refreshSuggestions()
    }
}

private struct FriendSuggestionRow: View {
    let profile: Profile
    let reasons: [String]
    let isFollowing: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.Colors.cardSurface)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: profile.avatarSystemImage)
                        .font(.title3)
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(profile.displayName)
                        .font(Theme.Typography.serifDisplay(size: 17))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                    Text("@\(profile.username)")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }

                if !reasons.isEmpty {
                    FlowLayout(spacing: Theme.Spacing.xs, lineSpacing: Theme.Spacing.xs) {
                        ForEach(reasons, id: \.self) { reason in
                            FriendReasonChip(title: reason)
                        }
                    }
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

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
        .padding(Theme.Spacing.md)
        .card()
    }
}

private struct FriendReasonChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.Colors.accentGreen)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.accentGreen.opacity(0.14))
            .clipShape(Capsule())
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Profile.self, Follow.self, Spot.self, Tag.self, Like.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let harshil = Profile()
    harshil.username = "harshil"
    harshil.displayName = "Harshil"
    harshil.preferredCategories = [SpotCategory.views.rawValue, SpotCategory.nature.rawValue]
    harshil.preferredTags = ["sunset", "quiet"]
    context.insert(harshil)

    let maya = Profile()
    maya.username = "maya"
    maya.displayName = "Maya Chen"
    maya.preferredCategories = [SpotCategory.coffee.rawValue, SpotCategory.views.rawValue]
    maya.preferredTags = ["cozy", "sunset"]
    context.insert(maya)

    return NavigationStack {
        AddFriendsView()
    }
    .modelContainer(container)
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}
