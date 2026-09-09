import AuthenticationServices
import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private(set) var isSigningIn = false
    private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    func signInWithApple(authorization: ASAuthorization) async -> (userID: String, displayName: String?)? {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Apple did not return a valid identity token. Please try again."
            return nil
        }

        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            let displayName = credential.fullName?.formatted().nilIfBlank
            if let displayName {
                _ = try? await client.auth.update(
                    user: UserAttributes(data: ["full_name": .string(displayName)])
                )
            }
            return (session.user.id.uuidString.lowercased(), displayName)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func signInWithGoogle() async -> (userID: String, displayName: String?)? {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: SupabaseConfig.authCallbackURL
            ) { webSession in
                webSession.prefersEphemeralWebBrowserSession = false
            }
            let displayName = session.user.userMetadata["full_name"]?.stringValue?.nilIfBlank
                ?? session.user.userMetadata["name"]?.stringValue?.nilIfBlank
            return (session.user.id.uuidString.lowercased(), displayName)
        } catch let error as ASWebAuthenticationSessionError
            where error.code == .canceledLogin {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func reportAuthorizationError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
