import Foundation

/// CloudKit public-database record types and field keys for Phase 3 social layer.
enum PublicCloudKitSchema {
    static let containerIdentifier = "iCloud.com.parth.getout"

    enum RecordType {
        static let spot = "PublicSpot"
        static let userProfile = "PublicUserProfile"
        static let report = "PublicReport"
        static let usernameClaim = "PublicUsernameClaim"
    }

    enum SpotField {
        static let spotID = "spotID"
        static let title = "title"
        static let details = "details"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let address = "address"
        static let city = "city"
        static let neighborhood = "neighborhood"
        static let category = "category"
        static let rating = "rating"
        static let photo = "photo"
        static let createdAt = "createdAt"
        static let ownerUserRecordName = "ownerUserRecordName"
        static let ownerDisplayName = "ownerDisplayName"
        static let ownerUsername = "ownerUsername"
        static let tags = "tags"
        static let containsCannabis = "containsCannabis"
        static let countryCode = "countryCode"
        static let administrativeArea = "administrativeArea"
    }

    enum UserProfileField {
        static let userRecordName = "userRecordName"
        static let username = "username"
        static let displayName = "displayName"
        static let bio = "bio"
        static let avatarSystemImage = "avatarSystemImage"
        static let createdAt = "createdAt"
    }

    enum ReportField {
        static let reporterUserRecordName = "reporterUserRecordName"
        static let targetRecordName = "targetRecordName"
        static let targetOwnerUserRecordName = "targetOwnerUserRecordName"
        static let targetKind = "targetKind"
        static let reason = "reason"
        static let details = "details"
        static let status = "status"
        static let createdAt = "createdAt"
    }

    enum UsernameClaimField {
        static let username = "username"
        static let userRecordName = "userRecordName"
        static let createdAt = "createdAt"
    }

    static func usernameClaimRecordName(_ username: String) -> String {
        "username-\(PublicContentPolicy.normalizedUsername(username))"
    }

}
