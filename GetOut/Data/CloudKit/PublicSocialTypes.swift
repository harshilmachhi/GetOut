import Foundation

enum PublicSocialError: LocalizedError, Equatable {
    case disabled
    case noAccount
    case offline
    case notFound
    case rateLimited
    case partialFailure(String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "Public social features are disabled in this build."
        case .noAccount:
            "Sign in to iCloud to use public social features."
        case .offline:
            "You're offline. Public social data will refresh when you're back online."
        case .notFound:
            "That profile or spot could not be found."
        case .rateLimited:
            "CloudKit is busy. Try again in a moment."
        case .partialFailure(let message):
            message
        case .underlying(let message):
            message
        }
    }
}

struct PublicSpotDTO: Equatable, Sendable, Identifiable {
    let recordName: String
    let spotID: UUID
    let title: String
    let details: String
    let latitude: Double
    let longitude: Double
    let address: String
    let city: String
    let neighborhood: String
    let category: String
    let rating: Double
    let createdAt: Date
    let ownerUserRecordName: String
    let ownerDisplayName: String
    let ownerUsername: String

    var id: String { recordName }
}

struct PublicUserProfileDTO: Equatable, Sendable, Identifiable {
    let recordName: String
    let userRecordName: String
    let username: String
    let displayName: String
    let bio: String
    let avatarSystemImage: String
    let createdAt: Date

    var id: String { recordName }
}

struct PublicFollowDTO: Equatable, Sendable, Identifiable {
    let recordName: String
    let followerUserRecordName: String
    let followeeUserRecordName: String
    let createdAt: Date

    var id: String { recordName }
}

struct PublicFeedCursor: Equatable, Sendable {
    let token: String

    init(token: String) {
        self.token = token
    }
}

struct PublicFeedPage: Equatable, Sendable {
    let spots: [PublicSpotDTO]
    let nextCursor: PublicFeedCursor?
}

struct PublicFollowListCursor: Equatable, Sendable {
    let token: String
}

struct PublicFollowListPage: Equatable, Sendable {
    let profiles: [PublicUserProfileDTO]
    let nextCursor: PublicFollowListCursor?
}

struct PublicSocialCounts: Equatable, Sendable {
    let followers: Int
    let following: Int
}

enum FollowToggleState: Equatable, Sendable {
    case notFollowing
    case following
    case pending

    static func afterToggle(from current: FollowToggleState, success: Bool) -> FollowToggleState {
        guard success else { return current == .pending ? .notFollowing : current }
        switch current {
        case .notFollowing, .pending:
            return .following
        case .following:
            return .notFollowing
        }
    }

    static func afterUnfollow(from current: FollowToggleState, success: Bool) -> FollowToggleState {
        guard success else { return current == .pending ? .following : current }
        switch current {
        case .following, .pending:
            return .notFollowing
        case .notFollowing:
            return .notFollowing
        }
    }
}

enum PublicFeedPager {
    static let defaultPageSize = 20

    static func nextCursor(
        current: PublicFeedCursor?,
        fetchedCount: Int,
        pageSize: Int = defaultPageSize,
        hasMoreFromServer: Bool
    ) -> PublicFeedCursor? {
        guard hasMoreFromServer, fetchedCount >= pageSize else { return nil }
        let nextIndex = pageIndex(from: current) + 1
        return PublicFeedCursor(token: "page-\(nextIndex)")
    }

    static func pageIndex(from cursor: PublicFeedCursor?) -> Int {
        guard let cursor else { return 0 }
        guard cursor.token.hasPrefix("page-"),
              let indexString = cursor.token.split(separator: "-").last,
              let index = Int(indexString) else {
            return 0
        }
        return index
    }
}
