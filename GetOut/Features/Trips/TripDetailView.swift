import MapKit
import SwiftData
import SwiftUI
import CloudKit

struct TripDetailView: View {
    let trip: Trip

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session

    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    @State private var showSpotPicker = false
    @State private var selectedSpot: Spot?
    @State private var isGeneratingPlan = false
    @State private var showShareSheet = false
    @State private var preparedShare: CKShare?
    @State private var isPreparingShare = false
    @State private var shareErrorMessage: String?
    @State private var collaborators: [TripCollaborator] = []

    private var collaborationEnabled: Bool {
        FeatureFlags.collaborativeTripsEnabled
    }

    private var currentProfile: Profile? {
        session.currentProfile(in: profiles)
    }

    private var isTripOwner: Bool {
        guard let ownerID = trip.owner?.id, let currentProfile else { return false }
        return currentProfile.id == ownerID
    }

    private var stops: [TripStop] {
        (trip.stops ?? []).sorted {
            if $0.dayIndex != $1.dayIndex { return $0.dayIndex < $1.dayIndex }
            return $0.order < $1.order
        }
    }

    private var isPlanned: Bool {
        TripFormatting.isPlanned(stops: stops)
    }

    private var groupedSections: [(title: String, dayIndex: Int?, stops: [TripStop])] {
        guard !stops.isEmpty else { return [] }

        if !isPlanned {
            return [(title: "Unscheduled", dayIndex: nil, stops: stops)]
        }

        let grouped = Dictionary(grouping: stops, by: \.dayIndex)
        return grouped.keys.sorted().map { dayIndex in
            let dayStops = (grouped[dayIndex] ?? []).sorted { $0.order < $1.order }
            return (title: "Day \(dayIndex + 1)", dayIndex: dayIndex, stops: dayStops)
        }
    }

    private var mappableStops: [TripStop] {
        stops.filter { $0.spot?.mapCoordinate != nil }
    }

    private var coverStyle: TripCoverStyle {
        TripCoverStyle.style(for: trip.coverSystemImage)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                headerBanner

                actionButtons

                if collaborationEnabled {
                    collaborationSection
                }

                if !mappableStops.isEmpty {
                    tripMapSection
                }

                if !trip.planSummary.isEmpty {
                    planSummaryCard
                }

                itinerarySection
            }
            .padding(.bottom, 96)
        }
        .background(Theme.Colors.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: trip.id) {
            guard collaborationEnabled else { return }
            collaborators = await TripSharingService.shared.collaborators(for: trip, in: modelContext)
        }
        .navigationDestination(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot)
        }
        .sheet(isPresented: $showSpotPicker) {
            SpotPickerSheet(trip: trip)
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            preparedShare = nil
            Task {
                collaborators = await TripSharingService.shared.collaborators(for: trip, in: modelContext)
            }
        }) {
            if let preparedShare {
                TripSharingController(share: preparedShare) {
                    showShareSheet = false
                }
            }
        }
        .alert("Couldn’t share trip", isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { if !$0 { shareErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    private var headerBanner: some View {
        ZStack(alignment: .bottomLeading) {
            CategoryGradientView(
                category: coverStyle.category,
                fallbackIndex: coverStyle.fallbackIndex,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(trip.title)
                    .font(Theme.Typography.serifDisplay(size: 32))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .lineLimit(3)

                Text(TripFormatting.dateRange(start: trip.startDate, end: trip.endDate))
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                if !trip.summary.isEmpty {
                    Text(trip.summary)
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary.opacity(0.9))
                        .lineLimit(3)
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    showSpotPicker = true
                } label: {
                    Label("Add spots", systemImage: "plus")
                        .font(Theme.Typography.body().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.plain)

                Button {
                    generatePlan()
                } label: {
                    Label(isGeneratingPlan ? "Planning…" : "Generate plan", systemImage: "sparkles")
                        .font(Theme.Typography.body().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.accentGreen.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .stroke(Theme.Colors.accentGreen.opacity(0.45), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(stops.isEmpty || isGeneratingPlan)
            }

            if collaborationEnabled && isTripOwner {
                Button {
                    Task { await presentShareSheet() }
                } label: {
                    Label(isPreparingShare ? "Preparing invite…" : "Share trip", systemImage: "person.badge.plus")
                        .font(Theme.Typography.body().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.accentGreen.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .stroke(Theme.Colors.accentGreen.opacity(0.35), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isPreparingShare)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var planSummaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accentGreen)

                Text("Why this plan")
                    .font(Theme.Typography.sectionHeader())
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
            }

            Text(trip.planSummary)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.accentGreen.opacity(0.25), lineWidth: 1)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    @ViewBuilder
    private var collaborationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Collaborators")
                .padding(.horizontal, Theme.Spacing.md)

            if collaborators.isEmpty {
                Text(isTripOwner
                     ? "Invite friends to view and edit this trip together."
                     : "No collaborators yet.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    .padding(.horizontal, Theme.Spacing.md)
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(collaborators) { collaborator in
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: collaborator.isOwner ? "crown.fill" : "person.crop.circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    collaborator.isOwner
                                        ? Theme.Colors.accentGreen
                                        : Theme.Colors.textOnDarkSecondary
                                )
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(collaborator.displayName)
                                    .font(Theme.Typography.body().weight(.medium))
                                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                                Text(collaborator.statusLabel)
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                            }

                            Spacer()
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    @ViewBuilder
    private var tripMapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Map")
                .padding(.horizontal, Theme.Spacing.md)

            Map(position: .constant(.region(mapRegion))) {
                ForEach(mappableStops) { stop in
                    if let spot = stop.spot, let coordinate = spot.mapCoordinate {
                        Annotation(spot.title, coordinate: coordinate) {
                            SpotMapPin(category: spot.categoryEnum, size: 28)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .allowsHitTesting(false)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var mapRegion: MKCoordinateRegion {
        let coordinates = mappableStops.compactMap { $0.spot?.mapCoordinate }
        guard !coordinates.isEmpty else {
            return LocationManager.defaultRegion
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (latitudes.min()! + latitudes.max()!) / 2,
            longitude: (longitudes.min()! + longitudes.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.02, (latitudes.max()! - latitudes.min()!) * 1.4 + 0.01),
            longitudeDelta: max(0.02, (longitudes.max()! - longitudes.min()!) * 1.4 + 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    @ViewBuilder
    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Itinerary")
                .padding(.horizontal, Theme.Spacing.md)

            if stops.isEmpty {
                Text("Add spots to start building your itinerary.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    .padding(.horizontal, Theme.Spacing.md)
            } else {
                ForEach(Array(groupedSections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(section.title)
                            .font(Theme.Typography.caption().weight(.semibold))
                            .foregroundStyle(Theme.Colors.accentGreen)
                            .padding(.horizontal, Theme.Spacing.md)

                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(section.stops) { stop in
                                if let spot = stop.spot {
                                    TripStopRow(stop: stop, spot: spot) {
                                        selectedSpot = spot
                                    }
                                    .contextMenu {
                                        if let dayIndex = section.dayIndex {
                                            moveToDayMenu(for: stop, currentDay: dayIndex)
                                        }
                                        Button("Remove from trip", role: .destructive) {
                                            removeStop(stop)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func moveToDayMenu(for stop: TripStop, currentDay: Int) -> some View {
        let maxDay = max(stops.map(\.dayIndex).max() ?? 0, 2)
        ForEach(0...maxDay + 1, id: \.self) { day in
            if day != currentDay {
                Button("Move to Day \(day + 1)") {
                    moveStop(stop, toDay: day)
                }
            }
        }
    }

    private func generatePlan() {
        guard !stops.isEmpty else { return }
        isGeneratingPlan = true

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            TripPlanner.generatePlan(for: trip, in: modelContext)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isGeneratingPlan = false
        }
    }

    private func removeStop(_ stop: TripStop) {
        modelContext.delete(stop)
        try? modelContext.save()
    }

    private func moveStop(_ stop: TripStop, toDay dayIndex: Int) {
        let dayStops = stops.filter { $0.dayIndex == dayIndex }
        stop.dayIndex = dayIndex
        stop.order = (dayStops.map(\.order).max() ?? -1) + 1
        try? modelContext.save()
    }

    private func presentShareSheet() async {
        guard collaborationEnabled, isTripOwner else { return }

        isPreparingShare = true
        shareErrorMessage = nil
        defer { isPreparingShare = false }

        do {
            let share = try await TripSharingService.shared.prepareShare(for: trip, in: modelContext)
            preparedShare = share
            showShareSheet = true
        } catch {
            shareErrorMessage = error.localizedDescription
        }
    }
}

private struct TripStopRow: View {
    let stop: TripStop
    let spot: Spot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                SpotImage(spot: spot)
                    .frame(width: 52, height: 52)
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

                    if !stop.notes.isEmpty {
                        Text(stop.notes)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.Colors.accentGreen)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Profile.self, Spot.self, Trip.self, TripStop.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let trip = Trip()
    trip.title = "NYC Weekend"
    trip.summary = "A slow weekend through Brooklyn and beyond."
    trip.startDate = Date.now
    trip.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)
    trip.coverSystemImage = "sun.horizon.fill"
    context.insert(trip)

    let spot = Spot()
    spot.title = "Sunset hill seating"
    spot.neighborhood = "Fort Greene"
    spot.city = "New York"
    spot.category = SpotCategory.views.rawValue
    spot.latitude = 40.6892
    spot.longitude = -73.9747
    context.insert(spot)

    let stop = TripStop()
    stop.trip = trip
    stop.spot = spot
    stop.order = 0
    context.insert(stop)

    return NavigationStack {
        TripDetailView(trip: trip)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
