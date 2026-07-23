import Foundation

enum PublicContentPolicy {
    private static let reservedUsernames: Set<String> = [
        "admin", "administrator", "getout", "help", "moderator", "official", "root", "support",
    ]

    // Deliberately small MVP safety list. Server-side moderation can replace this later.
    private static let disallowedTerms: Set<String> = [
        "nazi", "porn", "rape", "slur",
    ]

    static func normalizedUsername(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func usernameError(_ value: String) -> String? {
        let normalized = normalizedUsername(value)
        guard (3...24).contains(normalized.count) else {
            return "Username must be 3–24 characters."
        }
        guard normalized.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil else {
            return "Use only lowercase letters, numbers, and underscores."
        }
        guard !reservedUsernames.contains(normalized) else {
            return "That username is reserved."
        }
        return contentError(normalized)
    }

    static func profileError(displayName: String, username: String, bio: String) -> String? {
        usernameError(username)
            ?? contentError(displayName)
            ?? contentError(bio)
    }

    static func spotError(title: String, details: String, tags: [String]) -> String? {
        contentError(title)
            ?? contentError(details)
            ?? tags.compactMap(contentError).first
    }

    static func contentError(_ value: String) -> String? {
        let tokens = Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        return tokens.isDisjoint(with: disallowedTerms)
            ? nil
            : "Please remove offensive or unsafe language before publishing."
    }
}
