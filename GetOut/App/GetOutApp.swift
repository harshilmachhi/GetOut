import SwiftUI
import SwiftData

@main
struct GetOutApp: App {
    @State private var session = SessionStore()

    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                RootTabView()
            }
            .environment(session)
            .preferredColorScheme(.dark)
            .tint(Theme.Colors.accentGreen)
            .task {
                SeedData.seedTaxonomyIfNeeded(in: container.mainContext)
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
            // SwiftData is an offline cache. Supabase is the sole remote source of truth.
            let configuration = ModelConfiguration("GetOutSupabase", schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
