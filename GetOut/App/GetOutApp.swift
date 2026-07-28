import SwiftUI
import SwiftData

@main
struct GetOutApp: App {
    @UIApplicationDelegateAdaptor(CloudKitShareAcceptanceDelegate.self)
    private var cloudKitShareAcceptanceDelegate

    @State private var session = SessionStore()

    let container: ModelContainer

    init() {
        container = Self.makeContainer()
        SwiftDataCloudKitBridge.register(modelContainer: container)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                RootTabView()
            }
            .environment(session)
            .preferredColorScheme(.dark)
            .tint(Theme.Colors.accentGreen)
            .cloudKitRemoteChangeHandlingEnabled()
            .task {
                SeedData.seedTaxonomyIfNeeded(in: container.mainContext)
#if DEBUG
                SeedData.seedIfNeeded(in: container.mainContext)
#endif
            }
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Profile.self,
            Spot.self,
            Tag.self,
            Like.self,
            Save.self,
            Trip.self,
            TripStop.self,
            Interaction.self,
            UserBlock.self,
            Rating.self,
        ])

        do {
            let configuration: ModelConfiguration
            if FeatureFlags.cloudKitDatabaseEnabled {
                configuration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private("iCloud.com.parth.getout")
                )
            } else {
                configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            }
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
