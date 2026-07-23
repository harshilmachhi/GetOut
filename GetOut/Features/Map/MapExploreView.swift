import MapKit
import SwiftData
import SwiftUI

struct MapExploreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(sort: \Save.createdAt, order: .reverse) private var saves: [Save]

    let spots: [Spot]

    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(LocationManager.defaultRegion)
    @State private var selectedSpot: Spot?
    @State private var detailSpot: Spot?
    @State private var didSetInitialRegion = false

    private var mappableSpots: [Spot] {
        spots.filter { $0.mapCoordinate != nil }
    }

    private var currentProfileID: UUID? {
        (profiles.first { $0.username == session.currentUsername } ?? profiles.first)?.id
    }

    private var savedSpots: [Spot] {
        guard let currentProfileID else { return [] }
        let savedIDs = Set(saves.compactMap { save -> UUID? in
            guard save.user?.id == currentProfileID,
                  save.list == SaveList.saved.rawValue else { return nil }
            return save.spot?.id
        })
        return mappableSpots.filter { savedIDs.contains($0.id) }
    }

    private var savedNearbySpots: [Spot] {
        guard let userLocation = locationManager.lastLocation else { return savedSpots }
        return savedSpots.filter { spot in
            guard let coordinate = spot.mapCoordinate else { return false }
            return userLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) <= 25_000
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            VStack(spacing: Theme.Spacing.sm) {
                topBar
                Spacer()
            }

            if let selectedSpot {
                Button {
                    detailSpot = selectedSpot
                } label: {
                    SpotMapPreviewCard(spot: selectedSpot)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !savedNearbySpots.isEmpty {
                savedNearbyStrip
                    .padding(.bottom, Theme.Spacing.lg)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(Theme.Colors.appBackground)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedSpot?.id)
        .sheet(item: $detailSpot) { spot in
            SpotDetailView(spot: spot)
                .presentationDragIndicator(.visible)
        }
        .task {
            locationManager.requestPermission()
            updateCameraIfNeeded()
        }
        .onChange(of: locationManager.lastLocation) { _, _ in
            updateCameraIfNeeded()
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            ForEach(mappableSpots) { spot in
                if let coordinate = spot.mapCoordinate {
                    Annotation(spot.title, coordinate: coordinate) {
                        Button {
                            selectedSpot = spot
                        } label: {
                            SpotMapPin(
                                category: spot.categoryEnum,
                                isSelected: selectedSpot?.id == spot.id,
                                isSaved: savedSpots.contains(spot)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapCompass()
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial.opacity(0.85))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("Explore")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(.ultraThinMaterial.opacity(0.85))
                .clipShape(Capsule())

            Spacer()

            Button(action: centerOnUserTapped) {
                Image(systemName: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial.opacity(0.85))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .safeAreaPadding(.top, Theme.Spacing.sm)
    }

    private var savedNearbyStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Saved nearby", systemImage: "bookmark.fill")
                .font(Theme.Typography.caption().weight(.semibold))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(savedNearbySpots) { spot in
                        Button {
                            selectedSpot = spot
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(spot.title)
                                    .font(Theme.Typography.body().weight(.semibold))
                                    .lineLimit(1)
                                Text(spot.neighborhood.isEmpty ? "Saved spot" : spot.neighborhood)
                                    .font(Theme.Typography.caption())
                                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .frame(width: 180, alignment: .leading)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    private func centerOnUserTapped() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            guard let region = locationManager.centerOnUser() else { return }
            withAnimation {
                cameraPosition = .region(region)
            }
        case .notDetermined:
            locationManager.requestPermission()
        default:
            break
        }
    }

    private func updateCameraIfNeeded() {
        guard !didSetInitialRegion else { return }
        cameraPosition = .region(locationManager.defaultMapRegion)
        didSetInitialRegion = true
    }
}

private struct SpotMapPreviewCard: View {
    let spot: Spot

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(spot.title)
                    .font(Theme.Typography.serifDisplay(size: 20))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .lineLimit(2)

                Text(locationLine)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                    Text(String(format: "%.1f", spot.rating))
                        .font(Theme.Typography.caption().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "heart")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .frame(width: 32, height: 32)
                .background(Theme.Colors.appBackground.opacity(0.5))
                .clipShape(Circle())
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
    }

    private var locationLine: String {
        if spot.neighborhood.isEmpty {
            return "Nearby"
        }
        return "Nearby · \(spot.neighborhood)"
    }
}

#Preview {
    MapExploreView(spots: [])
        .modelContainer(for: [Profile.self, Spot.self, Tag.self, Like.self, Save.self], inMemory: true)
        .preferredColorScheme(.dark)
}
