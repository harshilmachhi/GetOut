import SwiftUI

struct OnboardingFlowView: View {
    @State private var step = 0
    @State private var displayName = ""
    @State private var username = ""
    @State private var city = ""
    @State private var bio = ""

    var body: some View {
        Group {
            if step == 0 {
                BasicDetailsView(
                    displayName: $displayName,
                    username: $username,
                    city: $city,
                    bio: $bio
                ) {
                    step = 1
                }
            } else {
                TasteQuestionnaireView(username: username)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }
}

#Preview {
    OnboardingFlowView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
