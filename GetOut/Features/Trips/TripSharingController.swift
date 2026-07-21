import CloudKit
import SwiftUI
import UIKit

struct TripSharingController: UIViewControllerRepresentable {
    let share: CKShare
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(
            share: share,
            container: SwiftDataCloudKitBridge.ckContainer
        )
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.modalPresentationStyle = .formSheet
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onComplete: (() -> Void)?

        init(onComplete: (() -> Void)?) {
            self.onComplete = onComplete
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onComplete?()
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onComplete?()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onComplete?()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?[CKShare.SystemFieldKey.title] as? String
        }
    }
}
