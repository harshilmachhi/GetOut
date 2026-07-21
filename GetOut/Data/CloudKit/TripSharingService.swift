import CloudKit
import CoreData
import Foundation
import SwiftData

enum TripSharingError: LocalizedError {
    case disabled
    case notAvailable
    case sharedStoreUnavailable
    case shareCreationFailed

    var errorDescription: String? {
        switch self {
        case .disabled:
            "Trip sharing is disabled in this build."
        case .notAvailable:
            "CloudKit sharing is not available. Sign in to iCloud on a signed build."
        case .sharedStoreUnavailable:
            "The shared CloudKit store is not ready yet."
        case .shareCreationFailed:
            "Could not create a share for this trip."
        }
    }
}

@MainActor
final class TripSharingService {
    static let shared = TripSharingService()

    private init() {}

    func prepareShare(for trip: Trip, in modelContext: ModelContext) async throws -> CKShare {
        guard FeatureFlags.collaborativeTripsEnabled else {
            throw TripSharingError.disabled
        }

        guard let cloudKitContainer = SwiftDataCloudKitBridge.persistentCloudKitContainer,
              let managedObject = SwiftDataCloudKitBridge.managedObject(for: trip, in: modelContext) else {
            throw TripSharingError.notAvailable
        }

        if let existingShare = try? cloudKitContainer.fetchShares(matching: [managedObject.objectID])[managedObject.objectID] {
            existingShare[CKShare.SystemFieldKey.title] = trip.title as CKRecordValue
            return existingShare
        }

        return try await withCheckedThrowingContinuation { continuation in
            cloudKitContainer.share([managedObject], to: nil) { _, share, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let share else {
                    continuation.resume(throwing: TripSharingError.shareCreationFailed)
                    return
                }
                share[CKShare.SystemFieldKey.title] = trip.title as CKRecordValue
                continuation.resume(returning: share)
            }
        }
    }

    func collaborators(for trip: Trip, in modelContext: ModelContext) async -> [TripCollaborator] {
        guard FeatureFlags.collaborativeTripsEnabled,
              let cloudKitContainer = SwiftDataCloudKitBridge.persistentCloudKitContainer,
              let managedObject = SwiftDataCloudKitBridge.managedObject(for: trip, in: modelContext),
              let share = try? cloudKitContainer.fetchShares(matching: [managedObject.objectID])[managedObject.objectID] else {
            return []
        }
        return TripCollaborator.fromShare(share)
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        guard FeatureFlags.collaborativeTripsEnabled else {
            throw TripSharingError.disabled
        }

        guard let cloudKitContainer = SwiftDataCloudKitBridge.persistentCloudKitContainer else {
            throw TripSharingError.notAvailable
        }

        let sharedStore = SwiftDataCloudKitBridge.sharedPersistentStore(in: cloudKitContainer)
            ?? cloudKitContainer.persistentStoreCoordinator.persistentStores.last

        guard let sharedStore else {
            throw TripSharingError.sharedStoreUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            cloudKitContainer.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
