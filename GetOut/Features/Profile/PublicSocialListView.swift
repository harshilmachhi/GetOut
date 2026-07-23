import SwiftData
import SwiftUI

enum PublicSocialListKind: String, Identifiable {
    case followers
    case following

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct PublicSocialListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]
    @Query private var follows: [Follow]
    @State private var coordinator = PublicSocialCoordinator.shared
    @State private var actionMessage: String?

    let kind: PublicSocialListKind
    let userRecordName: String

    private var listedProfiles: [Profile] {
        let relevantFollows = follows.filter { follow in
            guard follow.isPublicSocialFollow else { return false }
            switch kind {
            case .followers:
                return follow.followeeUserRecordName == userRecordName
            case .following:
                return follow.followerUserRecordName == userRecordName
            }
        }

        let recordNames: [String] = relevantFollows.map { follow in
            switch kind {
            case .followers:
                return follow.followerUserRecordName
            case .following:
                return follow.followeeUserRecordName
            }
        }

        return recordNames.compactMap { recordName in
            profiles.first { $0.cloudKitUserRecordName == recordName }
        }
    }

    var body: some View {
        List {
            if listedProfiles.isEmpty {
                Text("No \(kind.rawValue) yet")
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            } else {
                ForEach(listedProfiles, id: \.id) { profile in
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

                        if !profile.cloudKitUserRecordName.isEmpty {
                            PublicFollowButton(
                                targetUserRecordName: profile.cloudKitUserRecordName,
                                compact: true
                            )

                            Menu {
                                Menu("Report profile") {
                                    ForEach(PublicReportReason.allCases) { reason in
                                        Button(reason.title) {
                                            report(profile, reason: reason)
                                        }
                                    }
                                }
                                Button("Block @\(profile.username)", role: .destructive) {
                                    coordinator.block(
                                        userRecordName: profile.cloudKitUserRecordName,
                                        in: modelContext
                                    )
                                    actionMessage = "@\(profile.username) is blocked."
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                            }
                        }
                    }
                    .listRowBackground(Theme.Colors.cardSurface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.appBackground)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("GetOut", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
    }

    private func report(_ profile: Profile, reason: PublicReportReason) {
        Task {
            let sent = await coordinator.report(PublicReportDraft(
                targetRecordName: "profile-\(profile.cloudKitUserRecordName)",
                targetOwnerUserRecordName: profile.cloudKitUserRecordName,
                targetKind: .profile,
                reason: reason,
                details: ""
            ))
            actionMessage = sent
                ? "Report sent. Thank you."
                : (coordinator.accountError ?? "The report could not be sent.")
        }
    }
}
