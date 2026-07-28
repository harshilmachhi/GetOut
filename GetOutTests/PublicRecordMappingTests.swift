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
        record[PublicCloudKitSchema.SpotField.tags] = ["scenic", "weed-friendly"] as CKRecordValue
        record[PublicCloudKitSchema.SpotField.containsCannabis] = NSNumber(value: true)
        record[PublicCloudKitSchema.SpotField.countryCode] = "CA" as CKRecordValue
        record[PublicCloudKitSchema.SpotField.administrativeArea] = "ON" as CKRecordValue

        let dto = PublicRecordMapping.spotDTO(from: record)

        XCTAssertEqual(dto?.recordName, "spot-abc")
        XCTAssertEqual(dto?.spotID, spotID)
        XCTAssertEqual(dto?.title, "Sunset point")
        XCTAssertEqual(dto?.ownerUserRecordName, "user-1")
        XCTAssertEqual(dto?.city, "New York")
        XCTAssertEqual(dto?.tags, ["scenic", "weed-friendly"])
        XCTAssertEqual(dto?.containsCannabis, true)
        XCTAssertEqual(dto?.countryCode, "CA")
        XCTAssertEqual(dto?.administrativeArea, "ON")
    }

    func testSpotDTOReadsPhotoAssetBeforeCloudKitTemporaryFileExpires() throws {
        let expectedPhoto = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("getout-mapping-test-\(UUID().uuidString).jpg")
        try expectedPhoto.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let record = CKRecord(
            recordType: PublicCloudKitSchema.RecordType.spot,
            recordID: CKRecord.ID(recordName: "spot-photo")
        )
        record[PublicCloudKitSchema.SpotField.spotID] = UUID().uuidString as CKRecordValue
        record[PublicCloudKitSchema.SpotField.title] = "Photo spot" as CKRecordValue
        record[PublicCloudKitSchema.SpotField.createdAt] = Date.now as CKRecordValue
        record[PublicCloudKitSchema.SpotField.ownerUserRecordName] = "user-photo" as CKRecordValue
        record[PublicCloudKitSchema.SpotField.photo] = [CKAsset(fileURL: fileURL)] as CKRecordValue

        XCTAssertEqual(PublicRecordMapping.spotDTO(from: record)?.photoData, [expectedPhoto])
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
            ownerUsername: "alex",
            tags: ["hidden-gem"],
            containsCannabis: false,
            countryCode: "US",
            administrativeArea: "NY"
        )

        let spot = Spot()
        PublicRecordMapping.apply(dto, to: spot)

        XCTAssertEqual(spot.publicRecordName, "spot-1")
        XCTAssertEqual(spot.title, "Hidden cafe")
        XCTAssertEqual(spot.publisherUserRecordName, "user-42")
        XCTAssertEqual(spot.city, "Brooklyn")
        XCTAssertEqual(spot.publicTagNames, ["hidden-gem"])
        XCTAssertFalse(spot.containsCannabis)
        XCTAssertEqual(spot.countryCode, "US")
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

    @MainActor
    func testSessionSelectsProfileByCloudKitIdentityInsteadOfFirstProfile() {
        let session = SessionStore()
        session.clearLocalProfileState()

        let unrelated = Profile()
        unrelated.username = "harshil"
        unrelated.cloudKitUserRecordName = "icloud-harshil"

        let current = Profile()
        current.username = "parth-test"
        current.cloudKitUserRecordName = "icloud-parth-test"

        session.completeOnboarding(
            username: current.username,
            userRecordName: current.cloudKitUserRecordName
        )

        XCTAssertTrue(session.currentProfile(in: [unrelated, current]) === current)
        session.clearLocalProfileState()
    }

    @MainActor
    func testSessionNeverFallsBackToAnUnrelatedFirstProfile() {
        let session = SessionStore()
        session.clearLocalProfileState()

        let unrelated = Profile()
        unrelated.username = "harshil"
        unrelated.cloudKitUserRecordName = "icloud-harshil"

        XCTAssertNil(session.currentProfile(in: [unrelated]))
    }
}
