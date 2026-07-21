import SwiftData
import SwiftUI

struct TripsView: View {
    @Query(sort: \Trip.startDate) private var trips: [Trip]

    @State private var showCreateTrip = false

    var body: some View {
        Group {
            if trips.isEmpty {
                emptyState
            } else {
                tripsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.appBackground)
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "suitcase")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)

            Text("Plan your next trip")
                .font(Theme.Typography.sectionHeader())
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            Text("Save spots into a trip, invite friends, and get an itinerary.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Button("New Trip") {
                showCreateTrip = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.accentGreen)
            .controlSize(.large)

            Spacer()
        }
    }

    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(trips) { trip in
                    NavigationLink {
                        TripDetailView(trip: trip)
                    } label: {
                        TripCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, 96)
        }
    }
}

private struct TripCard: View {
    let trip: Trip

    private var coverStyle: TripCoverStyle {
        TripCoverStyle.style(for: trip.coverSystemImage)
    }

    private var stopCount: Int {
        trip.stops?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                CategoryGradientView(
                    category: coverStyle.category,
                    fallbackIndex: coverStyle.fallbackIndex,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack {
                    Image(systemName: trip.coverSystemImage.isEmpty ? "suitcase.fill" : trip.coverSystemImage)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(trip.title)
                    .font(Theme.Typography.serifDisplay(size: 22))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .lineLimit(2)

                Text(TripFormatting.dateRange(start: trip.startDate, end: trip.endDate))
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                Text(TripFormatting.spotCountLabel(stopCount))
                    .font(Theme.Typography.caption().weight(.medium))
                    .foregroundStyle(Theme.Colors.accentGreen)
            }
            .padding(Theme.Spacing.md)
        }
        .card()
    }
}

#Preview("Empty") {
    NavigationStack {
        TripsView()
    }
    .modelContainer(for: [Trip.self, Profile.self], inMemory: true)
    .preferredColorScheme(.dark)
}

#Preview("With Trips") {
    let container = try! ModelContainer(
        for: Profile.self, Trip.self, TripStop.self, Spot.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let trip = Trip()
    trip.title = "NYC Weekend"
    trip.summary = "Hidden gems across Brooklyn and Manhattan."
    trip.startDate = Date.now
    trip.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)
    trip.coverSystemImage = "sun.horizon.fill"
    context.insert(trip)

    return NavigationStack {
        TripsView()
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
