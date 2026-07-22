enum FeatureFlags {
    /// Private iCloud sync via SwiftData + NSPersistentCloudKitContainer (integrator Phase 1).
    static let cloudKitSyncEnabled = true

    /// Collaborative trips via CKShare in the shared CloudKit database (integrator Phase 2).
    static let collaborativeTripsEnabled = false

    /// Public CloudKit database for social feed, profiles, and following (public-social agent).
    static let publicSocialEnabled = false

    /// SwiftData CloudKit container (private + shared scopes).
    /// Collaborative trips require private sync — enabling `collaborativeTripsEnabled` implies sync.
    /// Public social uses the public CloudKit database directly and does not enable this.
    static var effectiveCloudKitSyncEnabled: Bool {
        cloudKitSyncEnabled || collaborativeTripsEnabled
    }

    static var cloudKitDatabaseEnabled: Bool {
        effectiveCloudKitSyncEnabled
    }
}
