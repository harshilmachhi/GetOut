import SwiftData
import SwiftUI

struct BasicDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session

    @Binding var displayName: String
    @Binding var username: String
    @Binding var city: String
    @Binding var bio: String

    let onContinue: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName, username, city, bio
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header

                VStack(spacing: Theme.Spacing.md) {
                    formField(title: "Display name", prompt: "How friends see you") {
                        TextField("Display name", text: $displayName)
                            .focused($focusedField, equals: .displayName)
                    }

                    formField(title: "Username", prompt: "Unique handle") {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .username)
                    }

                    formField(title: "City", prompt: "Optional") {
                        TextField("City", text: $city)
                            .focused($focusedField, equals: .city)
                    }

                    formField(title: "Bio", prompt: "Optional") {
                        TextField("Bio", text: $bio, axis: .vertical)
                            .lineLimit(3...5)
                            .focused($focusedField, equals: .bio)
                    }
                }

                Button(action: saveAndContinue) {
                    Text("Continue")
                        .font(Theme.Typography.body().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .background(canContinue ? Theme.Colors.accentGreen : Theme.Colors.accentGreen.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.appBackground)
        .onAppear {
            if displayName.isEmpty { displayName = session.pendingDisplayName }
            if username.isEmpty { username = session.pendingUsername }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("About you")
                .font(Theme.Typography.serifDisplay(size: 32))
                .foregroundStyle(Theme.Colors.cream)

            Text("A few basics so friends can find you.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
        }
    }

    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func formField<Content: View>(title: String, prompt: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(Theme.Typography.caption().weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                Spacer()
                Text(prompt)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }

            content()
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
        }
    }

    private func saveAndContinue() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)

        var descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.username == trimmedUsername }
        )
        descriptor.fetchLimit = 1

        let profile: Profile
        if let existing = try? modelContext.fetch(descriptor).first {
            profile = existing
        } else {
            profile = Profile()
            modelContext.insert(profile)
        }

        profile.username = trimmedUsername
        profile.displayName = trimmedDisplayName
        profile.bio = trimmedBio
        if !trimmedCity.isEmpty {
            profile.citiesVisited = [trimmedCity]
        }

        try? modelContext.save()
        onContinue()
    }
}
