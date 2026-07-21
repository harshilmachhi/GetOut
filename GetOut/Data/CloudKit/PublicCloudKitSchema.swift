import Foundation

/// CloudKit public-database record types and field keys for Phase 3 social layer.
enum PublicCloudKitSchema {
    static let containerIdentifier = "iCloud.com.getout.app"

    enum RecordType {
        static let spot = "PublicSpot"
        static let userProfile = "PublicUserProfile"
        static let follow = "PublicFollow"
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
        static let createdAt = "createdAt"
        static let ownerUserRecordName = "ownerUserRecordName"
        static let ownerDisplayName = "ownerDisplayName"
        static let ownerUsername = "ownerUsername"
    }

    enum UserProfileField {
        static let userRecordName = "userRecordName"
        static let username = "username"
        static let displayName = "displayName"
        static let bio = "bio"
        static let avatarSystemImage = "avatarSystemImage"
        static let createdAt = "createdAt"
    }

    enum FollowField {
        static let followerUserRecordName = "followerUserRecordName"
        static let followeeUserRecordName = "followeeUserRecordName"
        static let createdAt = "createdAt"
    }

    static func followRecordName(follower: String, followee: String) -> String {
        "follow-\(follower)-\(followee)"
    }
}
