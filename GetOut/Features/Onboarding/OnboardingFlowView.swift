import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @State private var socialCoordinator = PublicSocialCoordinator.shared
    @State private var step = 0
    @State private var displayName = ""
    @State private var username = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var createdUserRecordName = ""

    var body: some View {
        Group {
            if session.currentSupabaseUserID.isEmpty {
                AccountSignInView { userID, suggestedDisplayName in
                    if displayName.isEmpty, let suggestedDisplayName {
                        displayName = suggestedDisplayName
                    }
                    session.showOnboarding(for: userID)
                    Task {
                        await socialCoordinator.restoreCurrentProfile(
                            in: modelContext,
                            session: session
                        )
                    }
                }
            } else if step == 0 {
                BasicDetailsView(
                    displayName: $displayName,
                    username: $username,
                    city: $city,
                    bio: $bio
                ) { profile in
                    createdUserRecordName = profile.supabaseUserID
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
            if !session.currentSupabaseUserID.isEmpty {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Your account is ready. Now create your public profile.")
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
}

#Preview {
    OnboardingFlowView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
