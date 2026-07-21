import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @AppStorage("settings.locationEnabled") private var locationEnabled = true
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        List {
            accountSection
            preferencesSection
            friendsSection
            appSection
            aboutSection
            signOutSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.appBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
    }

    private var accountSection: some View {
        Section("Account") {
            settingsRow("Edit Profile", systemImage: "person.crop.circle", subtitle: "Coming soon")
            settingsRow("Email & Password", systemImage: "envelope", subtitle: "Coming soon")
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            settingsRow("Taste Profile", systemImage: "sparkles", subtitle: "Coming soon")
            settingsRow("Default City", systemImage: "mappin.and.ellipse", subtitle: "Coming soon")
        }
    }

    private func settingsRow(_ title: String, systemImage: String, subtitle: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(subtitle)
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
    }

    private var friendsSection: some View {
        Section {
            NavigationLink {
                AddFriendsView()
            } label: {
                Label("Add Friends", systemImage: "person.badge.plus")
            }
        }
    }

    private var appSection: some View {
        Section("App") {
            Toggle(isOn: $locationEnabled) {
                Label("Location Access", systemImage: "location")
            }

            Toggle(isOn: $notificationsEnabled) {
                Label("Notifications", systemImage: "bell")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.1")
            settingsRow("Privacy Policy", systemImage: "hand.raised", subtitle: "Coming soon")
            settingsRow("Terms of Service", systemImage: "doc.text", subtitle: "Coming soon")
        }
    }

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        }
    }

    private func signOut() {
        session.signOut()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}
