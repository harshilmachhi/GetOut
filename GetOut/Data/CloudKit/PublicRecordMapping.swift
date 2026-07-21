import CloudKit
import Foundation

enum PublicRecordMapping {
    // MARK: - Spot

    static func spotDTO(from record: CKRecord) -> PublicSpotDTO? {
        guard record.recordType == PublicCloudKitSchema.RecordType.spot,
              let spotIDString = record[PublicCloudKitSchema.SpotField.spotID] as? String,
              let spotID = UUID(uuidString: spotIDString),
              let title = record[PublicCloudKitSchema.SpotField.title] as? String,
              let createdAt = record[PublicCloudKitSchema.SpotField.createdAt] as? Date,
              let ownerUserRecordName = record[PublicCloudKitSchema.SpotField.ownerUserRecordName] as? String else {
            return nil
        }

        return PublicSpotDTO(
            recordName: record.recordID.recordName,
            spotID: spotID,
            title: title,
            details: record[PublicCloudKitSchema.SpotField.details] as? String ?? "",
            latitude: record[PublicCloudKitSchema.SpotField.latitude] as? Double ?? 0,
            longitude: record[PublicCloudKitSchema.SpotField.longitude] as? Double ?? 0,
            address: record[PublicCloudKitSchema.SpotField.address] as? String ?? "",
            city: record[PublicCloudKitSchema.SpotField.city] as? String ?? "",
            neighborhood: record[PublicCloudKitSchema.SpotField.neighborhood] as? String ?? "",
            category: record[PublicCloudKitSchema.SpotField.category] as? String ?? SpotCategory.views.rawValue,
            rating: record[PublicCloudKitSchema.SpotField.rating] as? Double ?? 0,
            createdAt: createdAt,
            ownerUserRecordName: ownerUserRecordName,
            ownerDisplayName: record[PublicCloudKitSchema.SpotField.ownerDisplayName] as? String ?? "",
            ownerUsername: record[PublicCloudKitSchema.SpotField.ownerUsername] as? String ?? ""
        )
    }

    static func makeSpotRecord(from spot: Spot, owner: Profile, ownerUserRecordName: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: spot.publicRecordName.isEmpty ? UUID().uuidString : spot.publicRecordName)
        let record = CKRecord(recordType: PublicCloudKitSchema.RecordType.spot, recordID: recordID)
        record[PublicCloudKitSchema.SpotField.spotID] = spot.id.uuidString as CKRecordValue
        record[PublicCloudKitSchema.SpotField.title] = spot.title as CKRecordValue
        record[PublicCloudKitSchema.SpotField.details] = spot.details as CKRecordValue
        record[PublicCloudKitSchema.SpotField.latitude] = spot.latitude as CKRecordValue
        record[PublicCloudKitSchema.SpotField.longitude] = spot.longitude as CKRecordValue
        record[PublicCloudKitSchema.SpotField.address] = spot.address as CKRecordValue
        record[PublicCloudKitSchema.SpotField.city] = spot.city as CKRecordValue
        record[PublicCloudKitSchema.SpotField.neighborhood] = spot.neighborhood as CKRecordValue
        record[PublicCloudKitSchema.SpotField.category] = spot.category as CKRecordValue
        record[PublicCloudKitSchema.SpotField.rating] = spot.rating as CKRecordValue
        record[PublicCloudKitSchema.SpotField.createdAt] = spot.createdAt as CKRecordValue
        record[PublicCloudKitSchema.SpotField.ownerUserRecordName] = ownerUserRecordName as CKRecordValue
        record[PublicCloudKitSchema.SpotField.ownerDisplayName] = owner.displayName as CKRecordValue
        record[PublicCloudKitSchema.SpotField.ownerUsername] = owner.username as CKRecordValue
        return record
    }

    static func apply(_ dto: PublicSpotDTO, to spot: Spot) {
        spot.id = dto.spotID
        spot.title = dto.title
        spot.details = dto.details
        spot.latitude = dto.latitude
        spot.longitude = dto.longitude
        spot.address = dto.address
        spot.city = dto.city
        spot.neighborhood = dto.neighborhood
        spot.category = dto.category
        spot.rating = dto.rating
        spot.createdAt = dto.createdAt
        spot.publicRecordName = dto.recordName
        spot.publisherUserRecordName = dto.ownerUserRecordName
    }

    // MARK: - User profile

    static func userProfileDTO(from record: CKRecord) -> PublicUserProfileDTO? {
        guard record.recordType == PublicCloudKitSchema.RecordType.userProfile,
              let userRecordName = record[PublicCloudKitSchema.UserProfileField.userRecordName] as? String,
              let username = record[PublicCloudKitSchema.UserProfileField.username] as? String,
              let displayName = record[PublicCloudKitSchema.UserProfileField.displayName] as? String,
              let createdAt = record[PublicCloudKitSchema.UserProfileField.createdAt] as? Date else {
            return nil
        }

        return PublicUserProfileDTO(
            recordName: record.recordID.recordName,
            userRecordName: userRecordName,
            username: username,
            displayName: displayName,
            bio: record[PublicCloudKitSchema.UserProfileField.bio] as? String ?? "",
            avatarSystemImage: record[PublicCloudKitSchema.UserProfileField.avatarSystemImage] as? String ?? "person.fill",
            createdAt: createdAt
        )
    }

    static func makeUserProfileRecord(from profile: Profile, userRecordName: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "profile-\(userRecordName)")
        let record = CKRecord(recordType: PublicCloudKitSchema.RecordType.userProfile, recordID: recordID)
        record[PublicCloudKitSchema.UserProfileField.userRecordName] = userRecordName as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.username] = profile.username as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.displayName] = profile.displayName as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.bio] = profile.bio as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.avatarSystemImage] = profile.avatarSystemImage as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.createdAt] = profile.createdAt as CKRecordValue
        return record
    }

    static func apply(_ dto: PublicUserProfileDTO, to profile: Profile) {
        profile.cloudKitUserRecordName = dto.userRecordName
        profile.username = dto.username
        profile.displayName = dto.displayName
        profile.bio = dto.bio
        profile.avatarSystemImage = dto.avatarSystemImage
        profile.createdAt = dto.createdAt
    }

    // MARK: - Follow

    static func followDTO(from record: CKRecord) -> PublicFollowDTO? {
        guard record.recordType == PublicCloudKitSchema.RecordType.follow,
              let follower = record[PublicCloudKitSchema.FollowField.followerUserRecordName] as? String,
              let followee = record[PublicCloudKitSchema.FollowField.followeeUserRecordName] as? String,
              let createdAt = record[PublicCloudKitSchema.FollowField.createdAt] as? Date else {
            return nil
        }

        return PublicFollowDTO(
            recordName: record.recordID.recordName,
            followerUserRecordName: follower,
            followeeUserRecordName: followee,
            createdAt: createdAt
        )
    }

    static func makeFollowRecord(followerUserRecordName: String, followeeUserRecordName: String) -> CKRecord {
        let recordName = PublicCloudKitSchema.followRecordName(
            follower: followerUserRecordName,
            followee: followeeUserRecordName
        )
        let record = CKRecord(
            recordType: PublicCloudKitSchema.RecordType.follow,
            recordID: CKRecord.ID(recordName: recordName)
        )
        record[PublicCloudKitSchema.FollowField.followerUserRecordName] = followerUserRecordName as CKRecordValue
        record[PublicCloudKitSchema.FollowField.followeeUserRecordName] = followeeUserRecordName as CKRecordValue
        record[PublicCloudKitSchema.FollowField.createdAt] = Date.now as CKRecordValue
        return record
    }

    static func apply(_ dto: PublicFollowDTO, to follow: Follow) {
        follow.followerUserRecordName = dto.followerUserRecordName
        follow.followeeUserRecordName = dto.followeeUserRecordName
        follow.createdAt = dto.createdAt
        follow.isPublicSocialFollow = true
    }
}
