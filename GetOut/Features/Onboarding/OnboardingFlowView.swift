import SwiftUI

struct OnboardingFlowView: View {
    @State private var step = 0
    @State private var displayName = ""
    @State private var username = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var createdUserRecordName = ""

    var body: some View {
        Group {
            if step == 0 {
                BasicDetailsView(
                    displayName: $displayName,
                    username: $username,
                    city: $city,
                    bio: $bio
                ) { profile in
                    createdUserRecordName = profile.cloudKitUserRecordName
                    step = 1
                }
            } else {
                TasteQuestionnaireView(
                    username: username,
                    userRecordName: createdUserRecordName
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .safeAreaInset(edge: .top) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "icloud.fill")
                Text("A signed-in iCloud account is required to create a public profile.")
            }
            .font(Theme.Typography.caption())
            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.cardSurface)
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
