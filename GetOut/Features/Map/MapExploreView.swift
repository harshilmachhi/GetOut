import MapKit
import SwiftData
import SwiftUI

struct MapExploreView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Spot.rating, order: .reverse) private var spots: [Spot]

    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(LocationManager.defaultRegion)
    @State private var selectedSpot: Spot?
    @State private var detailSpot: Spot?
    @State private var didSetInitialRegion = false

    private var mappableSpots: [Spot] {
        spots.filter { $0.mapCoordinate != nil }
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
                                isSelected: selectedSpot?.id == spot.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapUserLocationButton()
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
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
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
    MapExploreView()
        .modelContainer(for: [Profile.self, Spot.self, Tag.self, Like.self], inMemory: true)
        .preferredColorScheme(.dark)
}
