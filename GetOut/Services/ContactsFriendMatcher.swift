import Contacts
import Foundation
import Observation

@MainActor
@Observable
final class ContactsFriendMatcher {
    private(set) var authorizationStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    private(set) var matchedContactNames: Set<String> = []
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var canRequestAccess: Bool {
        authorizationStatus == .notDetermined
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccessAndLoadContacts() async {
        refreshAuthorizationStatus()
        lastErrorMessage = nil

        if authorizationStatus == .notDetermined {
            let store = CNContactStore()
            do {
                let granted = try await store.requestAccess(for: .contacts)
                authorizationStatus = granted ? .authorized : .denied
            } catch {
                authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
                lastErrorMessage = "Couldn't access contacts."
                matchedContactNames = []
                return
            }
        }

        guard authorizationStatus == .authorized else {
            matchedContactNames = []
            return
        }

        await loadContactNames()
    }

    func loadContactNames() async {
        guard authorizationStatus == .authorized else {
            matchedContactNames = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
        ]

        var names: Set<String> = []
        let request = CNContactFetchRequest(keysToFetch: keys)

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                for name in Self.contactNames(from: contact) {
                    names.insert(name)
                }
            }
            matchedContactNames = names
            lastErrorMessage = nil
        } catch {
            matchedContactNames = []
            lastErrorMessage = "Couldn't read contacts."
        }
    }

    static func contactNames(from contact: CNContact) -> [String] {
        var names: [String] = []

        let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        if !given.isEmpty { names.append(given.lowercased()) }
        if !family.isEmpty { names.append(family.lowercased()) }
        if !nickname.isEmpty { names.append(nickname.lowercased()) }

        let fullName = [given, family]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            names.append(fullName.lowercased())
        }

        return names
    }
}
