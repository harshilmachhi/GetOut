import SwiftData
import SwiftUI

struct SpotPickerSheet: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Spot.rating, order: .reverse) private var allSpots: [Spot]

    @State private var selectedSpotIDs: Set<UUID> = []

    private var existingSpotIDs: Set<UUID> {
        Set((trip.stops ?? []).compactMap { $0.spot?.id })
    }

    private var availableSpots: [Spot] {
        allSpots.filter { !existingSpotIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableSpots.isEmpty {
                    ContentUnavailableView(
                        "No spots left",
                        systemImage: "mappin.slash",
                        description: Text("Every saved spot is already in this trip.")
                    )
                } else {
                    List {
                        ForEach(availableSpots) { spot in
                            Button {
                                toggleSelection(for: spot)
                            } label: {
                                SpotPickerRow(
                                    spot: spot,
                                    isSelected: selectedSpotIDs.contains(spot.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.Colors.cardSurface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.Colors.appBackground)
            .navigationTitle("Add Spots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedSpotIDs.count))") { addSelectedSpots() }
                        .fontWeight(.semibold)
                        .disabled(selectedSpotIDs.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toggleSelection(for spot: Spot) {
        if selectedSpotIDs.contains(spot.id) {
            selectedSpotIDs.remove(spot.id)
        } else {
            selectedSpotIDs.insert(spot.id)
        }
    }

    private func addSelectedSpots() {
        let selectedSpots = availableSpots.filter { selectedSpotIDs.contains($0.id) }
        let baseOrder = (trip.stops ?? []).map(\.order).max() ?? -1

        for (offset, spot) in selectedSpots.enumerated() {
            let stop = TripStop()
            stop.trip = trip
            stop.spot = spot
            stop.dayIndex = 0
            stop.order = baseOrder + offset + 1
            modelContext.insert(stop)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct SpotPickerRow: View {
    let spot: Spot
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            SpotImage(spot: spot)
                .frame(width: 48, height: 48)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.title)
                    .font(Theme.Typography.body().weight(.medium))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .lineLimit(2)

                Text(spot.neighborhood.isEmpty ? spot.city : spot.neighborhood)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Theme.Colors.accentGreen : Theme.Colors.textOnDarkSecondary)
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

    let trip = Trip()
    trip.title = "Preview Trip"
    context.insert(trip)

    return SpotPickerSheet(trip: trip)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
