import AuthenticationServices
import SwiftUI

struct AccountSignInView: View {
    @State private var auth = SupabaseAuthService.shared

    let onSignedIn: (_ userID: String, _ suggestedDisplayName: String?) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(Theme.Colors.accentGreen)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Your GetOut account")
                    .font(Theme.Typography.serifDisplay(size: 32))
                    .foregroundStyle(Theme.Colors.cream)

                Text("Sign in to keep your profile, saved spots, and trips available when you reinstall or change devices.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Theme.Spacing.md) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    guard case .success(let authorization) = result else {
                        if case .failure(let error) = result {
                            authError(error)
                        }
                        return
                    }
                    Task {
                        if let result = await auth.signInWithApple(authorization: authorization) {
                            onSignedIn(result.userID, result.displayName)
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                Button {
                    Task {
                        if let result = await auth.signInWithGoogle() {
                            onSignedIn(result.userID, result.displayName)
                        }
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "g.circle.fill")
                        Text("Continue with Google")
                    }
                    .font(Theme.Typography.body().weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.plain)
            }

            if auth.isSigningIn {
                ProgressView("Signing in…")
                    .tint(Theme.Colors.accentGreen)
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            } else if let errorMessage = auth.errorMessage {
                Text(errorMessage)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            Text("By continuing, you agree to the Terms and Privacy Policy.")
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.appBackground)
        .allowsHitTesting(!auth.isSigningIn)
    }

    private func authError(_ error: Error) {
        guard (error as? ASAuthorizationError)?.code != .canceled else { return }
        auth.reportAuthorizationError(error)
    }
}
