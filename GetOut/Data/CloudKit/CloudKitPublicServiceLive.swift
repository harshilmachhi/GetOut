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

        var temporaryAssetURLs: [URL] = []
        var photoAssets: [CKAsset] = []
        for (index, photoData) in spot.allPhotoData.prefix(5).enumerated() {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("getout-spot-\(UUID().uuidString)-\(index + 1)")
                .appendingPathExtension("jpg")
            do {
                try photoData.write(to: fileURL, options: .atomic)
                photoAssets.append(CKAsset(fileURL: fileURL))
                temporaryAssetURLs.append(fileURL)
            } catch {
                temporaryAssetURLs.forEach { try? FileManager.default.removeItem(at: $0) }
                throw PublicSocialError.partialFailure("Could not prepare the spot photo for upload.")
            }
        }
        defer {
            temporaryAssetURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        if !photoAssets.isEmpty {
            record[PublicCloudKitSchema.SpotField.photo] = photoAssets as CKRecordValue
        }

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

        var idsToDelete: [CKRecord.ID] = [CKRecord.ID(recordName: "profile-\(userRecordName)")]
        idsToDelete += try await recordIDs(
            recordType: PublicCloudKitSchema.RecordType.spot,
            field: PublicCloudKitSchema.SpotField.ownerUserRecordName,
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
            case .partialFailure:
                return .underlying(cloudKitFailureDescription(for: ckError))
            case .permissionFailure, .serverRejectedRequest:
                return .underlying(cloudKitFailureDescription(for: ckError))
            default:
                return .underlying(ckError.localizedDescription)
            }
        }
        return .underlying(error.localizedDescription)
    }

    /// CKDatabase.save can wrap the useful server response in `partialFailure`; the outer
    /// localized description is only "Error saving record <CKRecordID...>". Surface the
    /// nested error so a rejected request can be diagnosed from the app itself.
    private func cloudKitFailureDescription(for error: CKError) -> String {
        let code = error.code.rawValue
        if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           let nestedError = partialErrors.values.first {
            if let nestedCloudKitError = nestedError as? CKError {
                return "CloudKit rejected this request (\(nestedCloudKitError.code.rawValue)): \(nestedCloudKitError.localizedDescription)"
            }
            return "CloudKit rejected this request (\(code)): \(nestedError.localizedDescription)"
        }
        return "CloudKit rejected this request (\(code)): \(error.localizedDescription)"
    }
}
