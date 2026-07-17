import SwiftData
import SwiftUI

struct AddToTripSheet: View {
    let spot: Spot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate) private var trips: [Trip]

    @State private var showCreateTrip = false

    private var tripsContainingSpot: Set<UUID> {
        Set(
            trips.flatMap { trip in
                (trip.stops ?? []).compactMap { stop -> UUID? in
                    guard stop.spot?.id == spot.id else { return nil }
                    return trip.id
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(trips) { trip in
                            Button {
                                addSpot(to: trip)
                            } label: {
                                AddToTripRow(
                                    trip: trip,
                                    isAlreadyAdded: tripsContainingSpot.contains(trip.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(tripsContainingSpot.contains(trip.id))
                            .listRowBackground(Theme.Colors.cardSurface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.Colors.appBackground)
            .navigationTitle("Add to Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView { trip in
                    addSpot(to: trip)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ContentUnavailableView(
                "No trips yet",
                systemImage: "suitcase",
                description: Text("Create a trip to save this spot.")
            )

            Button("New Trip") {
                showCreateTrip = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.accentGreen)
        }
        .padding(Theme.Spacing.md)
    }

    private func addSpot(to trip: Trip) {
        guard !tripsContainingSpot.contains(trip.id) else { return }

        let baseOrder = (trip.stops ?? []).map(\.order).max() ?? -1
        let stop = TripStop()
        stop.trip = trip
        stop.spot = spot
        stop.dayIndex = 0
        stop.order = baseOrder + 1
        modelContext.insert(stop)
        try? modelContext.save()
        dismiss()
    }
}

private struct AddToTripRow: View {
    let trip: Trip
    let isAlreadyAdded: Bool

    private var coverStyle: TripCoverStyle {
        TripCoverStyle.style(for: trip.coverSystemImage)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            CategoryGradientView(
                category: coverStyle.category,
                fallbackIndex: coverStyle.fallbackIndex
            )
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title)
                    .font(Theme.Typography.body().weight(.medium))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .lineLimit(2)

                Text(TripFormatting.dateRange(start: trip.startDate, end: trip.endDate))
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }

            Spacer()

            if isAlreadyAdded {
                Text("Added")
                    .font(Theme.Typography.caption().weight(.medium))
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            } else {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accentGreen)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Profile.self, Spot.self, Trip.self, TripStop.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let spot = Spot()
    spot.title = "Sunset hill seating"
    spot.neighborhood = "Fort Greene"
    context.insert(spot)

    let trip = Trip()
    trip.title = "NYC Weekend"
    context.insert(trip)

    return AddToTripSheet(spot: spot)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
