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
    let photoData: [Data]
    let createdAt: Date
    let ownerUserRecordName: String
    let ownerDisplayName: String
    let ownerUsername: String
    let tags: [String]
    let containsCannabis: Bool
    let countryCode: String
    let administrativeArea: String

    init(
        recordName: String,
        spotID: UUID,
        title: String,
        details: String,
        latitude: Double,
        longitude: Double,
        address: String,
        city: String,
        neighborhood: String,
        category: String,
        rating: Double,
        photoData: [Data] = [],
        createdAt: Date,
        ownerUserRecordName: String,
        ownerDisplayName: String,
        ownerUsername: String,
        tags: [String] = [],
        containsCannabis: Bool = false,
        countryCode: String = "",
        administrativeArea: String = ""
    ) {
        self.recordName = recordName
        self.spotID = spotID
        self.title = title
        self.details = details
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.neighborhood = neighborhood
        self.category = category
        self.rating = rating
        self.photoData = photoData
        self.createdAt = createdAt
        self.ownerUserRecordName = ownerUserRecordName
        self.ownerDisplayName = ownerDisplayName
        self.ownerUsername = ownerUsername
        self.tags = tags
        self.containsCannabis = containsCannabis
        self.countryCode = countryCode
        self.administrativeArea = administrativeArea
    }

    var id: String { recordName }

}

enum PublicReportTargetKind: String, Sendable {
    case spot
    case profile
}

enum PublicReportReason: String, CaseIterable, Identifiable, Sendable {
    case harassment
    case hateOrAbuse
    case inappropriate
    case misinformation
    case spam
    case unsafeLocation
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .harassment: "Harassment"
        case .hateOrAbuse: "Hate or abuse"
        case .inappropriate: "Inappropriate content"
        case .misinformation: "False information"
        case .spam: "Spam"
        case .unsafeLocation: "Unsafe or private location"
        case .other: "Other"
        }
    }
}

struct PublicReportDraft: Sendable {
    let targetRecordName: String
    let targetOwnerUserRecordName: String
    let targetKind: PublicReportTargetKind
    let reason: PublicReportReason
    let details: String
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
