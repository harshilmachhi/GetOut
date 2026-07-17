import SwiftUI
import SwiftData

@main
struct GetOutApp: App {
    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .tint(Theme.Colors.accentGreen)
                .task {
                    SeedData.seedIfNeeded(in: container.mainContext)
                }
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let useCloudKit = false

        let schema = Schema([
            Profile.self,
            Spot.self,
            Tag.self,
            Like.self,
            Save.self,
            Follow.self,
            Trip.self,
            TripStop.self,
            Interaction.self,
        ])

        do {
            let configuration: ModelConfiguration
            if useCloudKit {
                // CloudKit sync — enable after signing + entitlements are wired:
                // configuration = ModelConfiguration(
                //     schema: schema,
                //     cloudKitDatabase: .private("iCloud.com.getout.app")
                // )
                configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
