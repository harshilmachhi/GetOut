import CloudKit
@testable import GetOut
import XCTest

final class PublicRecordMappingTests: XCTestCase {
    func testSpotDTOFromRecord() {
        let recordID = CKRecord.ID(recordName: "spot-abc")
        let record = CKRecord(recordType: PublicCloudKitSchema.RecordType.spot, recordID: recordID)
        let spotID = UUID()
        record[PublicCloudKitSchema.SpotField.spotID] = spotID.uuidString as CKRecordValue
        record[PublicCloudKitSchema.SpotField.title] = "Sunset point" as CKRecordValue
        record[PublicCloudKitSchema.SpotField.createdAt] = Date(timeIntervalSince1970: 1_700_000_000) as CKRecordValue
        record[PublicCloudKitSchema.SpotField.ownerUserRecordName] = "user-1" as CKRecordValue
        record[PublicCloudKitSchema.SpotField.city] = "New York" as CKRecordValue
        record[PublicCloudKitSchema.SpotField.category] = SpotCategory.views.rawValue as CKRecordValue

        let dto = PublicRecordMapping.spotDTO(from: record)

        XCTAssertEqual(dto?.recordName, "spot-abc")
        XCTAssertEqual(dto?.spotID, spotID)
        XCTAssertEqual(dto?.title, "Sunset point")
        XCTAssertEqual(dto?.ownerUserRecordName, "user-1")
        XCTAssertEqual(dto?.city, "New York")
    }

    func testApplySpotDTOToModel() {
        let dto = PublicSpotDTO(
            recordName: "spot-1",
            spotID: UUID(),
            title: "Hidden cafe",
            details: "Quiet courtyard",
            latitude: 40.7,
            longitude: -73.9,
            address: "123 Main",
            city: "Brooklyn",
            neighborhood: "Williamsburg",
            category: SpotCategory.coffee.rawValue,
            rating: 4.8,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            ownerUserRecordName: "user-42",
            ownerDisplayName: "Alex",
            ownerUsername: "alex"
        )

        let spot = Spot()
        PublicRecordMapping.apply(dto, to: spot)

        XCTAssertEqual(spot.publicRecordName, "spot-1")
        XCTAssertEqual(spot.title, "Hidden cafe")
        XCTAssertEqual(spot.publisherUserRecordName, "user-42")
        XCTAssertEqual(spot.city, "Brooklyn")
    }

    func testUserProfileRoundTripFields() {
        let record = CKRecord(
            recordType: PublicCloudKitSchema.RecordType.userProfile,
            recordID: CKRecord.ID(recordName: "profile-user-9")
        )
        record[PublicCloudKitSchema.UserProfileField.userRecordName] = "user-9" as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.username] = "alex" as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.displayName] = "Alex" as CKRecordValue
        record[PublicCloudKitSchema.UserProfileField.createdAt] = Date.now as CKRecordValue

        let dto = PublicRecordMapping.userProfileDTO(from: record)
        let profile = Profile()
        PublicRecordMapping.apply(dto!, to: profile)

        XCTAssertEqual(profile.cloudKitUserRecordName, "user-9")
        XCTAssertEqual(profile.username, "alex")
        XCTAssertEqual(profile.displayName, "Alex")
    }

    func testFollowRecordNameIsStable() {
        let name = PublicCloudKitSchema.followRecordName(follower: "a", followee: "b")
        XCTAssertEqual(name, "follow-a-b")

        let dto = PublicFollowDTO(
            recordName: name,
            followerUserRecordName: "a",
            followeeUserRecordName: "b",
            createdAt: .now
        )
        let follow = Follow()
        PublicRecordMapping.apply(dto, to: follow)

        XCTAssertTrue(follow.isPublicSocialFollow)
        XCTAssertEqual(follow.followerUserRecordName, "a")
        XCTAssertEqual(follow.followeeUserRecordName, "b")
    }
}
