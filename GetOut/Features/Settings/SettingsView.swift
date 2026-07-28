import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @State private var coordinator = PublicSocialCoordinator.shared
    @State private var showDeleteConfirmation = false
    @State private var deletionMessage: String?
    @Query private var blockedUsers: [UserBlock]
    @AppStorage("privacy.hasConfirmedCannabisLegalAge") private var hasConfirmedCannabisLegalAge = false

    private let privacyURL = URL(string: "https://parthdhroovji.me/GetOut")!
    private let termsURL = URL(string: "https://parthdhroovji.me/GetOut/terms")!
    private let supportURL = URL(string: "mailto:parthdhroovji1@gmail.com")!

    var body: some View {
        List {
            accountSection
            preferencesSection
            blockedUsersSection
            permissionsSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.appBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
        .confirmationDialog(
            "Delete your GetOut profile and data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Profile & GetOut Data", role: .destructive) {
                Task {
                    let deleted = await coordinator.deleteCurrentAccount(
                        in: modelContext,
                        session: session
                    )
                    deletionMessage = deleted
                        ? "Your GetOut profile and app data were deleted. Your Apple ID and iCloud account were not changed."
                        : (coordinator.accountError ?? "Your data could not be deleted.")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your public profile, public spots, and private GetOut data. It does not delete your Apple ID or iCloud account.")
        }
        .alert("GetOut", isPresented: Binding(
            get: { deletionMessage != nil },
            set: { if !$0 { deletionMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deletionMessage = nil }
        } message: {
            Text(deletionMessage ?? "")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Identity", value: "iCloud")
            if !session.currentUsername.isEmpty {
                LabeledContent("GetOut profile", value: "@\(session.currentUsername)")
            }
            if !session.currentCloudKitUserRecordName.isEmpty {
                LabeledContent(
                    "Account code",
                    value: String(session.currentCloudKitUserRecordName.suffix(8))
                )
            }
            Text("Your public GetOut profile is uniquely tied to the iCloud account signed in on this device.")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Button("Delete Profile & GetOut Data", role: .destructive) {
                showDeleteConfirmation = true
            }
            .disabled(coordinator.isDeletingAccount)
        }
    }

    private var preferencesSection: some View {
        Section("Cannabis content") {
            Toggle("I confirm I am of legal age", isOn: $hasConfirmedCannabisLegalAge)
            Text("Weed-friendly content is shown only when location access confirms you are in Canada or California. GetOut does not facilitate cannabis sales.")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
    }

    private var blockedUsersSection: some View {
        Section("Blocked people") {
            NavigationLink {
                BlockedPeopleView()
            } label: {
                Label("Blocked People", systemImage: "hand.raised.fill")
                Spacer()
                Text("\(blockedUsers.count)")
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            Button {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            } label: {
                Label("Open iOS Settings", systemImage: "gear")
            }

            Text("Location powers nearby discovery and legal-jurisdiction checks.")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.1")
            Link(destination: privacyURL) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            Link(destination: termsURL) {
                Label("Terms & Community Guidelines", systemImage: "doc.text")
            }
            Link(destination: supportURL) {
                Label("Support & Safety", systemImage: "envelope")
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
