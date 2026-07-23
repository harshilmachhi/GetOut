import CloudKit
import Foundation

final class CloudKitPublicServiceLive: CloudKitPublicService, @unchecked Sendable {
    private let container: CKContainer
    private var ckCursors: [String: CKQueryOperation.Cursor] = [:]
    private let cursorLock = NSLock()

    init(container: CKContainer = SwiftDataCloudKitBridge.ckContainer) {
        self.container = container
    }

    private var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }

    func currentUserRecordName() async throws -> String? {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        do {
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch let error as CKError where error.code == .notAuthenticated {
            return nil
        } catch {
            throw mapError(error)
        }
    }

    func publishSpot(_ spot: Spot, owner: Profile, ownerUserRecordName: String) async throws -> PublicSpotDTO {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let record = PublicRecordMapping.makeSpotRecord(from: spot, owner: owner, ownerUserRecordName: ownerUserRecordName)
        let saved = try await save(record: record)
        guard let dto = PublicRecordMapping.spotDTO(from: saved) else {
            throw PublicSocialError.partialFailure("Could not read published spot.")
        }
        return dto
    }

    func fetchPublicFeed(cursor: PublicFeedCursor?, pageSize: Int) async throws -> PublicFeedPage {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }

        if let cursor, let ckCursor = storedCKCursor(for: cursor.token) {
            return try await fetchFeed(with: ckCursor, pageSize: pageSize, cursorToken: cursor.token)
        }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: PublicCloudKitSchema.RecordType.spot, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: PublicCloudKitSchema.SpotField.createdAt, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = pageSize
            operation.desiredKeys = nil

            var records: [CKRecord] = []
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    let spots = records.compactMap(PublicRecordMapping.spotDTO)
                    let token = UUID().uuidString
                    if let nextCursor {
                        self.storeCKCursor(nextCursor, token: token)
                    }
                    let page = PublicFeedPage(
                        spots: spots,
                        nextCursor: nextCursor.map { _ in PublicFeedCursor(token: token) }
                    )
                    continuation.resume(returning: page)
                case .failure(let error):
                    continuation.resume(throwing: self.mapError(error))
                }
            }
            self.publicDatabase.add(operation)
        }
    }

    func upsertPublicProfile(_ profile: Profile, userRecordName: String) async throws -> PublicUserProfileDTO {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        try await claimUsername(profile.username, for: userRecordName)
        let newRecord = PublicRecordMapping.makeUserProfileRecord(from: profile, userRecordName: userRecordName)
        let record: CKRecord
        if let existing = try? await publicDatabase.record(for: newRecord.recordID) {
            for key in newRecord.allKeys() {
                existing[key] = newRecord[key]
            }
            record = existing
        } else {
            record = newRecord
        }
        let saved = try await save(record: record)
        guard let dto = PublicRecordMapping.userProfileDTO(from: saved) else {
            throw PublicSocialError.partialFailure("Could not read saved profile.")
        }
        return dto
    }

    func fetchPublicProfile(userRecordName: String) async throws -> PublicUserProfileDTO? {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let recordID = CKRecord.ID(recordName: "profile-\(userRecordName)")
        do {
            let record = try await publicDatabase.record(for: recordID)
            return PublicRecordMapping.userProfileDTO(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw mapError(error)
        }
    }

    func fetchPublicProfile(username: String) async throws -> PublicUserProfileDTO? {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let predicate = NSPredicate(
            format: "%K == %@",
            PublicCloudKitSchema.UserProfileField.username,
            username.lowercased()
        )
        let query = CKQuery(recordType: PublicCloudKitSchema.RecordType.userProfile, predicate: predicate)
        let results = try await publicDatabase.records(matching: query, resultsLimit: 1)
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                return PublicRecordMapping.userProfileDTO(from: record)
            }
        }
        return nil
    }

    func deletePublicSpot(recordName: String) async throws {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        do {
            try await publicDatabase.deleteRecord(withID: CKRecord.ID(recordName: recordName))
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw mapError(error)
        }
    }

    func submitReport(_ draft: PublicReportDraft, reporterUserRecordName: String) async throws {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        _ = try await save(record: PublicRecordMapping.makeReportRecord(
            from: draft,
            reporterUserRecordName: reporterUserRecordName
        ))
    }

    func deleteAccountData(userRecordName: String) async throws {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }

        // Incoming follow records are owned by the followers under Creator-write permissions.
        // Leave an authenticated, non-public cleanup request before removing the profile so the
        // developer can erase those remaining references from CloudKit Dashboard.
        try await submitReport(
            PublicReportDraft(
                targetRecordName: "profile-\(userRecordName)",
                targetOwnerUserRecordName: userRecordName,
                targetKind: .profile,
                reason: .other,
                details: "ACCOUNT_DELETION: remove incoming PublicFollow references after profile deletion."
            ),
            reporterUserRecordName: userRecordName
        )

        var idsToDelete: [CKRecord.ID] = [CKRecord.ID(recordName: "profile-\(userRecordName)")]
        idsToDelete += try await recordIDs(
            recordType: PublicCloudKitSchema.RecordType.spot,
            field: PublicCloudKitSchema.SpotField.ownerUserRecordName,
            value: userRecordName
        )
        idsToDelete += try await recordIDs(
            recordType: PublicCloudKitSchema.RecordType.follow,
            field: PublicCloudKitSchema.FollowField.followerUserRecordName,
            value: userRecordName
        )
        idsToDelete += try await recordIDs(
            recordType: PublicCloudKitSchema.RecordType.usernameClaim,
            field: PublicCloudKitSchema.UsernameClaimField.userRecordName,
            value: userRecordName
        )

        let uniqueIDs = Array(Dictionary(uniqueKeysWithValues: idsToDelete.map { ($0.recordName, $0) }).values)
        let result = try await publicDatabase.modifyRecords(saving: [], deleting: uniqueIDs)
        for (_, deletionResult) in result.deleteResults {
            if case .failure(let error as CKError) = deletionResult, error.code != .unknownItem {
                throw mapError(error)
            }
        }
    }

    func follow(userRecordName: String, currentUserRecordName: String) async throws {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let record = PublicRecordMapping.makeFollowRecord(
            followerUserRecordName: currentUserRecordName,
            followeeUserRecordName: userRecordName
        )
        _ = try await save(record: record)
    }

    func unfollow(userRecordName: String, currentUserRecordName: String) async throws {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let recordName = PublicCloudKitSchema.followRecordName(
            follower: currentUserRecordName,
            followee: userRecordName
        )
        let recordID = CKRecord.ID(recordName: recordName)
        do {
            try await publicDatabase.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw mapError(error)
        }
    }

    func isFollowing(userRecordName: String, currentUserRecordName: String) async throws -> Bool {
        guard FeatureFlags.publicSocialEnabled else { throw PublicSocialError.disabled }
        let recordName = PublicCloudKitSchema.followRecordName(
            follower: currentUserRecordName,
            followee: userRecordName
        )
        do {
            _ = try await publicDatabase.record(for: CKRecord.ID(recordName: recordName))
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        } catch {
            throw mapError(error)
        }
    }

    func fetchFollowers(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage {
        try await fetchFollowProfiles(
            field: PublicCloudKitSchema.FollowField.followeeUserRecordName,
            userRecordName: userRecordName,
            cursor: cursor,
            pageSize: pageSize
        )
    }

    func fetchFollowing(
        for userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage {
        try await fetchFollowProfiles(
            field: PublicCloudKitSchema.FollowField.followerUserRecordName,
            userRecordName: userRecordName,
            cursor: cursor,
            pageSize: pageSize
        )
    }

    func socialCounts(for userRecordName: String) async throws -> PublicSocialCounts {
        async let followers = countFollowRecords(
            field: PublicCloudKitSchema.FollowField.followeeUserRecordName,
            value: userRecordName
        )
        async let following = countFollowRecords(
            field: PublicCloudKitSchema.FollowField.followerUserRecordName,
            value: userRecordName
        )
        return try await PublicSocialCounts(followers: followers, following: following)
    }

    // MARK: - Private

    private func claimUsername(_ username: String, for userRecordName: String) async throws {
        let normalized = PublicContentPolicy.normalizedUsername(username)
        let recordID = CKRecord.ID(recordName: PublicCloudKitSchema.usernameClaimRecordName(normalized))

        do {
            let existing = try await publicDatabase.record(for: recordID)
            if existing[PublicCloudKitSchema.UsernameClaimField.userRecordName] as? String == userRecordName {
                return
            }
            throw PublicSocialError.partialFailure("That username is already taken.")
        } catch let error as CKError where error.code == .unknownItem {
            // No claim exists. The save below uses the record's initial change tag, so only one
            // concurrent creator can successfully reserve this deterministic record ID.
        }

        let claim = CKRecord(recordType: PublicCloudKitSchema.RecordType.usernameClaim, recordID: recordID)
        claim[PublicCloudKitSchema.UsernameClaimField.username] = normalized as CKRecordValue
        claim[PublicCloudKitSchema.UsernameClaimField.userRecordName] = userRecordName as CKRecordValue
        claim[PublicCloudKitSchema.UsernameClaimField.createdAt] = Date.now as CKRecordValue

        do {
            _ = try await publicDatabase.save(claim)
        } catch let error as CKError where error.code == .serverRecordChanged {
            throw PublicSocialError.partialFailure("That username is already taken.")
        } catch {
            throw mapError(error)
        }
    }

    private func fetchFeed(
        with cursor: CKQueryOperation.Cursor,
        pageSize: Int,
        cursorToken: String
    ) async throws -> PublicFeedPage {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(cursor: cursor)
            operation.resultsLimit = pageSize

            var records: [CKRecord] = []
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    let spots = records.compactMap(PublicRecordMapping.spotDTO)
                    let token = UUID().uuidString
                    if let nextCursor {
                        self.storeCKCursor(nextCursor, token: token)
                    }
                    let page = PublicFeedPage(
                        spots: spots,
                        nextCursor: nextCursor.map { _ in PublicFeedCursor(token: token) }
                    )
                    continuation.resume(returning: page)
                case .failure(let error):
                    continuation.resume(throwing: self.mapError(error))
                }
            }
            self.publicDatabase.add(operation)
        }
    }

    private func fetchFollowProfiles(
        field: String,
        userRecordName: String,
        cursor: PublicFollowListCursor?,
        pageSize: Int
    ) async throws -> PublicFollowListPage {
        if let cursor, let ckCursor = storedCKCursor(for: cursor.token) {
            return try await fetchFollowPage(with: ckCursor, pageSize: pageSize, otherField: oppositeFollowField(for: field))
        }

        let predicate = NSPredicate(format: "%K == %@", field, userRecordName)
        let query = CKQuery(recordType: PublicCloudKitSchema.RecordType.follow, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: PublicCloudKitSchema.FollowField.createdAt, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = pageSize

            var followRecords: [CKRecord] = []
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    followRecords.append(record)
                }
            }
            operation.queryResultBlock = { result in
                Task {
                    do {
                        switch result {
                        case .success(let nextCursor):
                            let profiles = try await self.profiles(for: followRecords, otherField: self.oppositeFollowField(for: field))
                            let token = UUID().uuidString
                            if let nextCursor {
                                self.storeCKCursor(nextCursor, token: token)
                            }
                            continuation.resume(returning: PublicFollowListPage(
                                profiles: profiles,
                                nextCursor: nextCursor.map { _ in PublicFollowListCursor(token: token) }
                            ))
                        case .failure(let error):
                            continuation.resume(throwing: self.mapError(error))
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            self.publicDatabase.add(operation)
        }
    }

    private func fetchFollowPage(
        with cursor: CKQueryOperation.Cursor,
        pageSize: Int,
        otherField: String
    ) async throws -> PublicFollowListPage {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(cursor: cursor)
            operation.resultsLimit = pageSize

            var followRecords: [CKRecord] = []
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    followRecords.append(record)
                }
            }
            operation.queryResultBlock = { result in
                Task {
                    do {
                        switch result {
                        case .success(let nextCursor):
                            let profiles = try await self.profiles(for: followRecords, otherField: otherField)
                            let token = UUID().uuidString
                            if let nextCursor {
                                self.storeCKCursor(nextCursor, token: token)
                            }
                            continuation.resume(returning: PublicFollowListPage(
                                profiles: profiles,
                                nextCursor: nextCursor.map { _ in PublicFollowListCursor(token: token) }
                            ))
                        case .failure(let error):
                            continuation.resume(throwing: self.mapError(error))
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            self.publicDatabase.add(operation)
        }
    }

    private func profiles(for followRecords: [CKRecord], otherField: String) async throws -> [PublicUserProfileDTO] {
        var profiles: [PublicUserProfileDTO] = []
        for followRecord in followRecords {
            guard let userRecordName = followRecord[otherField] as? String else { continue }
            if let profile = try await fetchPublicProfile(userRecordName: userRecordName) {
                profiles.append(profile)
            }
        }
        return profiles
    }

    private func oppositeFollowField(for field: String) -> String {
        field == PublicCloudKitSchema.FollowField.followerUserRecordName
            ? PublicCloudKitSchema.FollowField.followeeUserRecordName
            : PublicCloudKitSchema.FollowField.followerUserRecordName
    }

    private func countFollowRecords(field: String, value: String) async throws -> Int {
        let predicate = NSPredicate(format: "%K == %@", field, value)
        let query = CKQuery(recordType: PublicCloudKitSchema.RecordType.follow, predicate: predicate)

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = []
            var count = 0
            operation.recordMatchedBlock = { _, result in
                if case .success = result {
                    count += 1
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: count)
                case .failure(let error):
                    continuation.resume(throwing: self.mapError(error))
                }
            }
            self.publicDatabase.add(operation)
        }
    }

    private func recordIDs(recordType: String, field: String, value: String) async throws -> [CKRecord.ID] {
        let predicate = NSPredicate(format: "%K == %@", field, value)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        var ids: [CKRecord.ID] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await publicDatabase.records(continuingMatchFrom: cursor, resultsLimit: 200)
            } else {
                page = try await publicDatabase.records(matching: query, desiredKeys: [], resultsLimit: 200)
            }
            ids.append(contentsOf: page.matchResults.compactMap { id, result in
                if case .success = result { return id }
                return nil
            })
            cursor = page.queryCursor
        } while cursor != nil

        return ids
    }

    private func save(record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            publicDatabase.save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                } else if let saved {
                    continuation.resume(returning: saved)
                } else {
                    continuation.resume(throwing: PublicSocialError.partialFailure("Save returned no record."))
                }
            }
        }
    }

    private func storeCKCursor(_ cursor: CKQueryOperation.Cursor, token: String) {
        cursorLock.lock()
        defer { cursorLock.unlock() }
        ckCursors[token] = cursor
    }

    private func storedCKCursor(for token: String) -> CKQueryOperation.Cursor? {
        cursorLock.lock()
        defer { cursorLock.unlock() }
        return ckCursors[token]
    }

    private func mapError(_ error: Error) -> PublicSocialError {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return .noAccount
            case .networkUnavailable, .networkFailure:
                return .offline
            case .requestRateLimited, .serviceUnavailable, .zoneBusy:
                return .rateLimited
            case .unknownItem:
                return .notFound
            default:
                return .underlying(ckError.localizedDescription)
            }
        }
        return .underlying(error.localizedDescription)
    }
}
