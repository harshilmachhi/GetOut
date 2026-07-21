import SwiftUI

struct PublicFollowButton: View {
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = PublicSocialCoordinator.shared

    let targetUserRecordName: String
    var compact: Bool = false

    private var followState: FollowToggleState {
        coordinator.followState(for: targetUserRecordName)
    }

    private var errorMessage: String? {
        coordinator.followError(for: targetUserRecordName)
    }

    var body: some View {
        if FeatureFlags.publicSocialEnabled,
           !targetUserRecordName.isEmpty,
           coordinator.canFollow(targetUserRecordName: targetUserRecordName) {
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Button {
                    Task {
                        await coordinator.toggleFollow(
                            targetUserRecordName: targetUserRecordName,
                            in: modelContext
                        )
                    }
                } label: {
                    followLabel
                }
                .buttonStyle(.plain)
                .disabled(followState == .pending)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .task(id: targetUserRecordName) {
                await coordinator.loadFollowState(for: targetUserRecordName)
            }
        }
    }

    @ViewBuilder
    private var followLabel: some View {
        let isFollowing = followState == .following
        let title = followState == .pending ? "..." : (isFollowing ? "Following" : "Follow")

        if compact {
            Text(title)
                .font(Theme.Typography.caption().weight(.semibold))
                .foregroundStyle(isFollowing ? Theme.Colors.textOnDarkPrimary : Theme.Colors.accentGreen)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isFollowing ? Theme.Colors.cardSurface : Theme.Colors.accentGreen.opacity(0.15))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            isFollowing ? Theme.Colors.cream.opacity(0.2) : Theme.Colors.accentGreen.opacity(0.45),
                            lineWidth: 1
                        )
                }
        } else {
            Text(title)
                .font(Theme.Typography.body().weight(.semibold))
                .foregroundStyle(isFollowing ? Theme.Colors.textOnDarkPrimary : Theme.Colors.accentGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isFollowing ? Theme.Colors.cardSurface : Theme.Colors.accentGreen.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .stroke(
                            isFollowing ? Theme.Colors.cream.opacity(0.2) : Theme.Colors.accentGreen.opacity(0.45),
                            lineWidth: 1
                        )
                }
        }
    }
}

struct PublicPublishSpotSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = PublicSocialCoordinator.shared

    let spot: Spot
    let owner: Profile

    private var isPublished: Bool {
        !spot.publicRecordName.isEmpty
    }

    var body: some View {
        if FeatureFlags.publicSocialEnabled {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(title: "Public feed")

                if isPublished {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.accentGreen)

                        Text("Shared to the public feed")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    }
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                } else {
                    Button {
                        Task {
                            await coordinator.publishSpot(spot, owner: owner, in: modelContext)
                        }
                    } label: {
                        HStack {
                            if coordinator.isPublishingSpot {
                                ProgressView()
                                    .tint(Theme.Colors.accentGreen)
                            } else {
                                Image(systemName: "globe")
                            }

                            Text(coordinator.isPublishingSpot ? "Publishing..." : "Share to feed")
                                .font(Theme.Typography.body().weight(.medium))
                        }
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.accentGreen.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .stroke(Theme.Colors.accentGreen.opacity(0.45), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinator.isPublishingSpot)
                }

                if let publishError = coordinator.publishError {
                    Text(publishError)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(.red.opacity(0.85))
                }
            }
        }
    }
}
