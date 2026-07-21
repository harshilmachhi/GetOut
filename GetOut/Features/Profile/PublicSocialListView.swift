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
    }
}
