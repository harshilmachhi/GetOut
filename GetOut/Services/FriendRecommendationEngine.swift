import Foundation

struct FriendRecommendationProfile: Equatable, Sendable {
    let id: UUID
    let username: String
    let displayName: String
    let preferredCategories: [String]
    let preferredTags: [String]
    let likedSpotTags: [String]
}

struct FriendSuggestion: Identifiable, Equatable, Sendable {
    let profile: FriendRecommendationProfile
    let score: Double
    let reasons: [String]

    var id: UUID { profile.id }
}

enum FriendRecommendationEngine {
    struct Weights: Equatable, Sendable {
        var contactsMatch: Double = 40
        var mutualFriend: Double = 15
        var preferenceSimilarity: Double = 30

        static let `default` = Weights()
    }

    static func rank(
        currentUser: FriendRecommendationProfile,
        candidates: [FriendRecommendationProfile],
        follows: [(followerID: UUID, followeeID: UUID)],
        matchedContactNames: Set<String> = [],
        weights: Weights = .default
    ) -> [FriendSuggestion] {
        let currentFollowing = followeeIDs(for: currentUser.id, in: follows)

        return candidates
            .filter { $0.id != currentUser.id }
            .map { candidate in
                scoreCandidate(
                    currentUser: currentUser,
                    candidate: candidate,
                    currentFollowing: currentFollowing,
                    follows: follows,
                    matchedContactNames: matchedContactNames,
                    weights: weights
                )
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.profile.displayName.localizedCaseInsensitiveCompare(rhs.profile.displayName) == .orderedAscending
            }
    }

    private static func scoreCandidate(
        currentUser: FriendRecommendationProfile,
        candidate: FriendRecommendationProfile,
        currentFollowing: Set<UUID>,
        follows: [(followerID: UUID, followeeID: UUID)],
        matchedContactNames: Set<String>,
        weights: Weights
    ) -> FriendSuggestion {
        var score = 0.0
        var reasons: [String] = []

        if contactsMatch(candidate: candidate, contactNames: matchedContactNames) {
            score += weights.contactsMatch
            reasons.append("In contacts")
        }

        let candidateFollowing = followeeIDs(for: candidate.id, in: follows)
        let mutualCount = currentFollowing.intersection(candidateFollowing).count
        if mutualCount > 0 {
            score += Double(mutualCount) * weights.mutualFriend
            reasons.append(mutualCount == 1 ? "1 mutual friend" : "\(mutualCount) mutual friends")
        }

        let similarity = preferenceSimilarity(between: currentUser, and: candidate)
        if similarity > 0 {
            score += similarity * weights.preferenceSimilarity
            if similarity >= 0.34 {
                reasons.append("Similar taste")
            }
        }

        return FriendSuggestion(profile: candidate, score: score, reasons: reasons)
    }

    static func contactsMatch(candidate: FriendRecommendationProfile, contactNames: Set<String>) -> Bool {
        guard !contactNames.isEmpty else { return false }

        let candidateTokens = nameTokens(for: candidate.displayName) + nameTokens(for: candidate.username)
        guard !candidateTokens.isEmpty else { return false }

        for contactName in contactNames {
            let contactTokens = nameTokens(for: contactName)
            guard !contactTokens.isEmpty else { continue }

            if contactTokens.contains(where: { contactToken in
                candidateTokens.contains(where: { candidateToken in
                    fuzzyTokenMatch(candidateToken, contactToken)
                })
            }) {
                return true
            }
        }

        return false
    }

    static func preferenceSimilarity(
        between currentUser: FriendRecommendationProfile,
        and candidate: FriendRecommendationProfile
    ) -> Double {
        let currentPreferences = preferenceSet(for: currentUser)
        let candidatePreferences = preferenceSet(for: candidate)
        return jaccard(currentPreferences, candidatePreferences)
    }

    static func mutualFriendCount(
        currentUserID: UUID,
        candidateID: UUID,
        follows: [(followerID: UUID, followeeID: UUID)]
    ) -> Int {
        let currentFollowing = followeeIDs(for: currentUserID, in: follows)
        let candidateFollowing = followeeIDs(for: candidateID, in: follows)
        return currentFollowing.intersection(candidateFollowing).count
    }

    private static func followeeIDs(
        for followerID: UUID,
        in follows: [(followerID: UUID, followeeID: UUID)]
    ) -> Set<UUID> {
        Set(follows.filter { $0.followerID == followerID }.map(\.followeeID))
    }

    private static func preferenceSet(for profile: FriendRecommendationProfile) -> Set<String> {
        Set(profile.preferredCategories + profile.preferredTags + profile.likedSpotTags)
    }

    private static func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0 }
        let intersection = lhs.intersection(rhs)
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }
        return Double(intersection.count) / Double(union.count)
    }

    private static func nameTokens(for value: String) -> [String] {
        value
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    private static func fuzzyTokenMatch(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        if lhs.count >= 3, rhs.contains(lhs) { return true }
        if rhs.count >= 3, lhs.contains(rhs) { return true }
        return false
    }
}

extension Profile {
    var friendRecommendationProfile: FriendRecommendationProfile {
        let likedTags = (likes ?? [])
            .compactMap(\.spot)
            .flatMap { $0.tags ?? [] }
            .map(\.name)

        return FriendRecommendationProfile(
            id: id,
            username: username,
            displayName: displayName,
            preferredCategories: preferredCategories,
            preferredTags: preferredTags,
            likedSpotTags: likedTags
        )
    }
}

extension Follow {
    var followEdge: (followerID: UUID, followeeID: UUID)? {
        guard let followerID = follower?.id, let followeeID = followee?.id else { return nil }
        return (followerID, followeeID)
    }
}
