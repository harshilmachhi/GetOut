import CloudKit
import UIKit

final class CloudKitShareAcceptanceDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata,
        completionHandler: @escaping () -> Void
    ) {
        guard FeatureFlags.collaborativeTripsEnabled else {
            completionHandler()
            return
        }

        Task { @MainActor in
            defer { completionHandler() }
            try? await TripSharingService.shared.acceptShare(metadata: cloudKitShareMetadata)
        }
    }
}
