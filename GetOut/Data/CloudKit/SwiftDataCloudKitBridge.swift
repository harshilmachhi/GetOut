import CloudKit
import CoreData
import SwiftData

/// Bridges SwiftData's `ModelContainer` to the underlying `NSPersistentCloudKitContainer`.
/// SwiftData on iOS 17 does not expose share APIs directly; this shim locates the backing
/// container created when `ModelConfiguration(cloudKitDatabase:)` is used.
enum SwiftDataCloudKitBridge {
    private static let containerIdentifier = "iCloud.com.parth.getout"
    private static weak var registeredModelContainer: ModelContainer?

    static func register(modelContainer: ModelContainer) {
        registeredModelContainer = modelContainer
    }

    static var ckContainer: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    static var persistentCloudKitContainer: NSPersistentCloudKitContainer? {
        guard FeatureFlags.cloudKitDatabaseEnabled,
              let registeredModelContainer else { return nil }
        return findPersistentCloudKitContainer(in: registeredModelContainer)
    }

    static func managedObjectContext(from modelContext: ModelContext) -> NSManagedObjectContext? {
        findManagedObjectContext(in: modelContext)
    }

    static func managedObject(
        for trip: Trip,
        in modelContext: ModelContext
    ) -> NSManagedObject? {
        managedObject(entityName: "Trip", id: trip.id, in: modelContext)
    }

    private static func managedObject(
        entityName: String,
        id: UUID,
        in modelContext: ModelContext
    ) -> NSManagedObject? {
        guard let moc = managedObjectContext(from: modelContext) else { return nil }

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? moc.fetch(request).first
    }

    static func sharedPersistentStore(
        in cloudKitContainer: NSPersistentCloudKitContainer
    ) -> NSPersistentStore? {
        cloudKitContainer.persistentStoreCoordinator.persistentStores.first { store in
            store.url?.lastPathComponent.localizedCaseInsensitiveContains("shared") == true
        }
    }

    private static func findPersistentCloudKitContainer(
        in root: Any,
        depth: Int = 0
    ) -> NSPersistentCloudKitContainer? {
        guard depth < 6 else { return nil }
        if let container = root as? NSPersistentCloudKitContainer { return container }

        let mirror = Mirror(reflecting: root)
        for child in mirror.children {
            if let container = child.value as? NSPersistentCloudKitContainer { return container }
            if let container = findPersistentCloudKitContainer(in: child.value, depth: depth + 1) {
                return container
            }
        }
        return nil
    }

    private static func findManagedObjectContext(
        in root: Any,
        depth: Int = 0
    ) -> NSManagedObjectContext? {
        guard depth < 5 else { return nil }
        if let context = root as? NSManagedObjectContext { return context }

        let mirror = Mirror(reflecting: root)
        for child in mirror.children {
            if let context = child.value as? NSManagedObjectContext { return context }
            if let context = findManagedObjectContext(in: child.value, depth: depth + 1) {
                return context
            }
        }
        return nil
    }
}
