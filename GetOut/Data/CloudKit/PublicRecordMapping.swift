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
            photoData: photoData(from: record[PublicCloudKitSchema.SpotField.photo] as? [CKAsset]),
            createdAt: createdAt,
            ownerUserRecordName: ownerUserRecordName,
            ownerDisplayName: record[PublicCloudKitSchema.SpotField.ownerDisplayName] as? String ?? "",
            ownerUsername: record[PublicCloudKitSchema.SpotField.ownerUsername] as? String ?? "",
            tags: record[PublicCloudKitSchema.SpotField.tags] as? [String] ?? [],
            containsCannabis: (record[PublicCloudKitSchema.SpotField.containsCannabis] as? NSNumber)?.boolValue ?? false,
            countryCode: record[PublicCloudKitSchema.SpotField.countryCode] as? String ?? "",
            administrativeArea: record[PublicCloudKitSchema.SpotField.administrativeArea] as? String ?? ""
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
        let tagNames = Array(Set((spot.tags?.map(\.name) ?? []) + spot.publicTagNames)).sorted()
        record[PublicCloudKitSchema.SpotField.tags] = tagNames as CKRecordValue
        record[PublicCloudKitSchema.SpotField.containsCannabis] = NSNumber(value: CannabisPolicy.containsCannabisTag(tagNames))
        record[PublicCloudKitSchema.SpotField.countryCode] = spot.countryCode as CKRecordValue
        record[PublicCloudKitSchema.SpotField.administrativeArea] = spot.administrativeArea as CKRecordValue
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
        spot.photoData = dto.photoData.indices.contains(0) ? dto.photoData[0] : nil
        spot.photoData2 = dto.photoData.indices.contains(1) ? dto.photoData[1] : nil
        spot.photoData3 = dto.photoData.indices.contains(2) ? dto.photoData[2] : nil
        spot.photoData4 = dto.photoData.indices.contains(3) ? dto.photoData[3] : nil
        spot.photoData5 = dto.photoData.indices.contains(4) ? dto.photoData[4] : nil
        spot.createdAt = dto.createdAt
        spot.publicRecordName = dto.recordName
        spot.publisherUserRecordName = dto.ownerUserRecordName
        spot.publicTagNames = dto.tags
        spot.containsCannabis = dto.containsCannabis
        spot.countryCode = dto.countryCode
        spot.administrativeArea = dto.administrativeArea
    }

    private static func photoData(from assets: [CKAsset]?) -> [Data] {
        (assets ?? []).compactMap { asset in
            guard let fileURL = asset.fileURL else { return nil }
            return try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        }
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

    static func makeReportRecord(
        from draft: PublicReportDraft,
        reporterUserRecordName: String
    ) -> CKRecord {
        let record = CKRecord(recordType: PublicCloudKitSchema.RecordType.report)
        record[PublicCloudKitSchema.ReportField.reporterUserRecordName] = reporterUserRecordName as CKRecordValue
        record[PublicCloudKitSchema.ReportField.targetRecordName] = draft.targetRecordName as CKRecordValue
        record[PublicCloudKitSchema.ReportField.targetOwnerUserRecordName] = draft.targetOwnerUserRecordName as CKRecordValue
        record[PublicCloudKitSchema.ReportField.targetKind] = draft.targetKind.rawValue as CKRecordValue
        record[PublicCloudKitSchema.ReportField.reason] = draft.reason.rawValue as CKRecordValue
        record[PublicCloudKitSchema.ReportField.details] = draft.details as CKRecordValue
        record[PublicCloudKitSchema.ReportField.status] = "open" as CKRecordValue
        record[PublicCloudKitSchema.ReportField.createdAt] = Date.now as CKRecordValue
        return record
    }
}
