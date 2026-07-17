import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DiscoverView()
            }
            .tabItem {
                Label("Discover", systemImage: "map")
            }

            NavigationStack {
                TripsView()
            }
            .tabItem {
                Label("Trips", systemImage: "suitcase")
            }

            NavigationStack {
                AddSpotView()
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}

#Preview {
    RootTabView()
}
