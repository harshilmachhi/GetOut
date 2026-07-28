import SwiftData
import SwiftUI

/// When CloudKit sync imports remote writes, merge them into the active `ModelContext`
/// so `@Query` views refresh. SwiftData already observes the store; this handles the
/// `NSPersistentStoreRemoteChange` edge where pending merges need explicit processing.
@MainActor
private struct CloudKitRemoteChangeObserver: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            ) { _ in
                Task { @MainActor in
                    modelContext.processPendingChanges()
                }
            }
    }
}

extension View {
    @ViewBuilder
    func cloudKitRemoteChangeHandlingEnabled(
        _ enabled: Bool = FeatureFlags.cloudKitDatabaseEnabled
    ) -> some View {
        if enabled {
            modifier(CloudKitRemoteChangeObserver())
        } else {
            self
        }
    }
}
