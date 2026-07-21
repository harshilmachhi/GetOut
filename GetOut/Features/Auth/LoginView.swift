import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var comingSoonMessage: String?
    @State private var showPhoneSheet = false
    @State private var showGuestOptions = false

    private let navy = Color(red: 0.12, green: 0.16, blue: 0.28)
    private let olive = Color(red: 0.45, green: 0.52, blue: 0.38)
    private let softBorder = Color(red: 0.88, green: 0.88, blue: 0.86)

    var body: some View {
        ZStack {
            heroBackground

            VStack(spacing: 0) {
                brandingHeader
                    .padding(.top, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.md)

                joinCard
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                legalFooter
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showPhoneSheet) {
            PhoneSignInSheet { phone in
                showPhoneSheet = false
                session.beginSignInWithPhone(phoneNumber: phone)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Coming soon", isPresented: Binding(
            get: { comingSoonMessage != nil },
            set: { if !$0 { comingSoonMessage = nil } }
        )) {
            Button("OK", role: .cancel) { comingSoonMessage = nil }
        } message: {
            Text(comingSoonMessage ?? "")
        }
    }

    private var heroBackground: some View {
        GeometryReader { geo in
            Image("login_hero")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }

    private var brandingHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("GetOut")
                .font(Theme.Typography.script(size: 56))
                .foregroundStyle(navy)
                .shadow(color: .white.opacity(0.55), radius: 8, y: 1)

            Text("Real local recommendations.\nAuthentic spots.")
                .font(Theme.Typography.serifDisplay(size: 18))
                .multilineTextAlignment(.center)
                .foregroundStyle(navy.opacity(0.85))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Join the community")
                    .font(Theme.Typography.serifDisplay(size: 24))
                    .foregroundStyle(navy)

                Text("It's free and always will be.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(navy.opacity(0.65))
            }

            Button {
                showPhoneSheet = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "phone.fill")
                        .font(.body.weight(.semibold))
                    Text("Continue with Phone")
                        .font(Theme.Typography.body().weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(navy)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            orDivider

            VStack(spacing: Theme.Spacing.sm) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInWithApple(result)
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                secondaryAuthButton(title: "Continue with Google", googleMark: true) {
                    comingSoonMessage = "Google sign-in is coming soon."
                }
            }

            guestDisclosure
        }
        .padding(Theme.Spacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 10)
    }

    private var guestDisclosure: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showGuestOptions.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("More options")
                        .font(Theme.Typography.caption().weight(.medium))
                        .foregroundStyle(navy.opacity(0.55))

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(navy.opacity(0.45))
                        .rotationEffect(.degrees(showGuestOptions ? 180 : 0))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xs)
            }
            .buttonStyle(.plain)

            if showGuestOptions {
                Button {
                    session.signInAsGuest()
                } label: {
                    HStack {
                        Text("Explore as a guest")
                            .font(Theme.Typography.body().weight(.semibold))
                            .foregroundStyle(olive)

                        Spacer()

                        Image(systemName: "binoculars.fill")
                            .font(.body.weight(.medium))
                            .foregroundStyle(olive)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(softBorder)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var orDivider: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Rectangle()
                .fill(softBorder)
                .frame(height: 1)

            Text("or continue with")
                .font(Theme.Typography.caption())
                .foregroundStyle(navy.opacity(0.45))

            Rectangle()
                .fill(softBorder)
                .frame(height: 1)
        }
    }

    private func secondaryAuthButton(
        title: String,
        googleMark: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if googleMark {
                    Text("G")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.26, green: 0.52, blue: 0.96),
                                    Color(red: 0.22, green: 0.67, blue: 0.35),
                                    Color(red: 0.98, green: 0.74, blue: 0.02),
                                    Color(red: 0.90, green: 0.26, blue: 0.21),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(title)
                    .font(Theme.Typography.body().weight(.semibold))
                    .foregroundStyle(navy)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(softBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var legalFooter: some View {
        Text("By continuing you agree to our Terms and Privacy Policy.")
            .font(Theme.Typography.caption())
            .foregroundStyle(navy.opacity(0.55))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            session.completeSignInWithApple(credential: credential)
        case .failure:
            comingSoonMessage = "Sign in with Apple didn’t complete. Try again or explore as a guest."
        }
    }
}

// MARK: - Phone sheet

private struct PhoneSignInSheet: View {
    let onContinue: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = ""
    @FocusState private var isFocused: Bool

    private let navy = Color(red: 0.12, green: 0.16, blue: 0.28)

    private var canContinue: Bool {
        phoneNumber.filter(\.isNumber).count >= 10
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Enter your number")
                        .font(Theme.Typography.serifDisplay(size: 26))
                        .foregroundStyle(navy)

                    Text("We’ll use this to create your account. SMS verification comes later.")
                        .font(Theme.Typography.body())
                        .foregroundStyle(navy.opacity(0.6))
                }

                TextField("Phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(Theme.Typography.body())
                    .foregroundStyle(navy)
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(height: 54)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($isFocused)

                Button {
                    onContinue(phoneNumber)
                } label: {
                    Text("Continue")
                        .font(Theme.Typography.body().weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canContinue ? navy : navy.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)

                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}
