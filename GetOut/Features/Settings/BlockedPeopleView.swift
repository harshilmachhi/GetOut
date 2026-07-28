import SwiftData
import SwiftUI

struct BlockedPeopleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserBlock.createdAt, order: .reverse) private var blockedUsers: [UserBlock]
    @State private var coordinator = PublicSocialCoordinator.shared

    var body: some View {
        List {
            if blockedUsers.isEmpty {
                ContentUnavailableView(
                    "No blocked people",
                    systemImage: "person.crop.circle.badge.checkmark",
                    description: Text("People you block will appear here, where you can unblock them anytime.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Blocked people") {
                    ForEach(blockedUsers, id: \.id) { block in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(blockedDisplayName(block.blockedUserRecordName))
                                    .font(Theme.Typography.body().weight(.medium))
                                Text("Their public spots and activity are hidden")
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                            }
                            Spacer()
                            Button("Unblock") {
                                coordinator.unblock(
                                    userRecordName: block.blockedUserRecordName,
                                    in: modelContext
                                )
                            }
                            .font(Theme.Typography.caption().weight(.semibold))
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.appBackground)
        .navigationTitle("Blocked People")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func blockedDisplayName(_ recordName: String) -> String {
        let suffix = String(recordName.suffix(8))
        return suffix.isEmpty ? "Blocked account" : "Account •••\(suffix)"
    }
}
