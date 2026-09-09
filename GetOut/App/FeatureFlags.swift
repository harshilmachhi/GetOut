import Foundation

enum FeatureFlags {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Public profiles and discovery data are served by Supabase.
    static let publicSocialEnabled = true
}
