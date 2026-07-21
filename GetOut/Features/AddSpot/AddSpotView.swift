import CoreLocation
import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddSpotView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Profile.createdAt) private var allProfiles: [Profile]

    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(LocationManager.defaultRegion)
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var didSetInitialRegion = false

    @State private var title = ""
    @State private var details = ""
    @State private var neighborhood = ""
    @State private var city = ""
    @State private var selectedTagNames: Set<String> = []
    @State private var newTagName = ""

    @State private var isGeocoding = false
    @State private var showSuccess = false
    @State private var geocodeTask: Task<Void, Never>?

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoData: Data?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedCoordinate != nil
    }

    private var demoProfile: Profile? {
        allProfiles.first { $0.username == session.currentUsername } ?? allProfiles.first
    }

    private var suggestedTags: [Tag] {
        allTags.filter { !selectedTagNames.contains($0.name) }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    locationSection
                    nameAndStorySection
                    tagsSection
                    photoSection
                    saveButton
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, 96)
            }

            if showSuccess {
                successOverlay
            }
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Add a Spot")
        .navigationBarTitleDisplayMode(.large)
        .task {
            locationManager.requestPermission()
            updateCameraIfNeeded()
        }
        .onChange(of: locationManager.lastLocation) { _, _ in
            updateCameraIfNeeded()
        }
        .onChange(of: photoPickerItem) { _, newItem in
            loadPhoto(from: newItem)
        }
    }

    // MARK: - Sections

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            stepHeader(
                number: 1,
                title: "Location",
                subtitle: "Drop a pin where this spot is — drag the map to place it."
            )

            ZStack {
                Map(position: $cameraPosition)
                    .mapStyle(.standard(elevation: .flat))
                    .onMapCameraChange(frequency: .onEnd) { context in
                        selectedCoordinate = context.region.center
                        scheduleGeocode(for: context.region.center)
                    }

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary, Theme.Colors.accentGreen)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .allowsHitTesting(false)
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.cream.opacity(0.12), lineWidth: 1)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button(action: recenterOnUserLocation) {
                    Label("Use current location", systemImage: "location.fill")
                        .font(Theme.Typography.caption().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Colors.cardSurface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: lookupArea) {
                    Label("Look up area", systemImage: "magnifyingglass")
                        .font(Theme.Typography.caption().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Colors.cardSurface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedCoordinate == nil || isGeocoding)
                .opacity(selectedCoordinate == nil || isGeocoding ? 0.5 : 1)
            }

            VStack(spacing: Theme.Spacing.sm) {
                TextField("Neighborhood", text: $neighborhood)
                    .cardInputStyle()

                TextField("City", text: $city)
                    .cardInputStyle()
            }
        }
    }

    private var nameAndStorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            stepHeader(
                number: 2,
                title: "Name & story",
                subtitle: "Give it a name and tell people what makes it worth the trip."
            )

            VStack(spacing: Theme.Spacing.sm) {
                TextField("Name this spot", text: $title)
                    .cardInputStyle()

                TextField("What makes it special?", text: $details, axis: .vertical)
                    .lineLimit(3...8)
                    .cardInputStyle()
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            stepHeader(
                number: 3,
                title: "Tags",
                subtitle: "Type anything — vibes, cuisine, accessibility. Tags power discovery."
            )

            if !selectedTagNames.isEmpty {
                FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                    ForEach(Array(selectedTagNames).sorted(), id: \.self) { name in
                        RemovableTagChip(name: name) {
                            selectedTagNames.remove(name)
                        }
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Add a tag", text: $newTagName)
                    .cardInputStyle()
                    .onSubmit(addNewTag)

                Button("Add", action: addNewTag)
                    .font(Theme.Typography.caption().weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .buttonStyle(.plain)
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }

            if !suggestedTags.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Suggestions")
                        .font(Theme.Typography.caption().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                    FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                        ForEach(suggestedTags, id: \.id) { tag in
                            SuggestedTagChip(name: tag.name) {
                                selectedTagNames.insert(tag.name)
                            }
                        }
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            stepHeader(
                number: 4,
                title: "Photo",
                subtitle: "A great shot helps others picture the vibe."
            )

            ZStack(alignment: .topTrailing) {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    photoPickerContent
                }
                .buttonStyle(.plain)

                if photoData != nil {
                    Button {
                        photoPickerItem = nil
                        photoData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary, Color.black.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .padding(Theme.Spacing.sm)
                }
            }
        }
    }

    @ViewBuilder
    private var photoPickerContent: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.Colors.cardSurface
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.Colors.accentGreen)

                        Text("Add photo")
                            .font(Theme.Typography.body().weight(.medium))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                        Text("Tap to choose from your library")
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            if photoData != nil {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        Theme.Colors.cream.opacity(0.28),
                        style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                    )
            }
        }
        .overlay(alignment: .bottom) {
            if photoData != nil {
                Label("Change photo", systemImage: "photo.on.rectangle")
                    .font(Theme.Typography.caption().weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveSpot) {
            Text("Save spot")
                .font(Theme.Typography.body().weight(.semibold))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(canSave ? Theme.Colors.accentGreen : Theme.Colors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
    }

    private var successOverlay: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accentGreen)

            Text("Spot saved!")
                .font(Theme.Typography.sectionHeader())
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
        }
        .padding(Theme.Spacing.xl)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Step Header

    private func stepHeader(number: Int, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text("\(number)")
                .font(Theme.Typography.serifDisplay(size: 28))
                .foregroundStyle(Theme.Colors.accentGreen)
                .frame(width: 28, alignment: .trailing)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.sectionHeader())
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                Text(subtitle)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private func updateCameraIfNeeded() {
        guard !didSetInitialRegion else { return }
        let region = locationManager.defaultMapRegion
        cameraPosition = .region(region)
        selectedCoordinate = region.center
        didSetInitialRegion = true
        scheduleGeocode(for: region.center)
    }

    private func recenterOnUserLocation() {
        guard let region = locationManager.centerOnUser() else { return }
        withAnimation {
            cameraPosition = .region(region)
        }
        selectedCoordinate = region.center
        scheduleGeocode(for: region.center)
    }

    private func lookupArea() {
        guard let coordinate = selectedCoordinate else { return }
        scheduleGeocode(for: coordinate, immediate: true)
    }

    private func scheduleGeocode(for coordinate: CLLocationCoordinate2D, immediate: Bool = false) {
        geocodeTask?.cancel()
        geocodeTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !Task.isCancelled else { return }
            await reverseGeocode(coordinate)
        }
    }

    @MainActor
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        isGeocoding = true
        defer { isGeocoding = false }

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard !Task.isCancelled, let placemark = placemarks.first else { return }

            if let subLocality = placemark.subLocality, !subLocality.isEmpty {
                neighborhood = subLocality
            } else if let locality = placemark.locality, !locality.isEmpty {
                neighborhood = locality
            }

            if let locality = placemark.locality, !locality.isEmpty {
                city = locality
            } else if let adminArea = placemark.administrativeArea, !adminArea.isEmpty {
                city = adminArea
            }
        } catch {
            // Geocoding failed — fields remain manually editable.
        }
    }

    private func addNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedTagNames.insert(trimmed)
        newTagName = ""
    }

    private func inferredCategory(from tagNames: Set<String>) -> SpotCategory {
        let aliases: [String: SpotCategory] = [
            "foodie": .food,
            "outdoors": .nature,
            "sunset": .views,
            "quiet": .nature,
        ]

        for name in tagNames {
            let lowered = name.lowercased()
            if let category = SpotCategory(rawValue: lowered) {
                return category
            }
            if let category = SpotCategory.allCases.first(where: { $0.displayName.lowercased() == lowered }) {
                return category
            }
            if let category = aliases[lowered] {
                return category
            }
        }
        return .nearby
    }

    private func saveSpot() {
        guard canSave,
              let coordinate = selectedCoordinate,
              let profile = demoProfile else { return }

        let now = Date.now
        let calendar = Calendar.current

        let spot = Spot()
        spot.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.latitude = coordinate.latitude
        spot.longitude = coordinate.longitude
        spot.neighborhood = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.category = inferredCategory(from: selectedTagNames).rawValue
        spot.rating = 0
        spot.photoData = photoData
        spot.visitHour = calendar.component(.hour, from: now)
        spot.visitWeekday = calendar.component(.weekday, from: now)
        spot.owner = profile
        spot.createdAt = now

        var spotTags: [Tag] = []
        for name in selectedTagNames {
            if let existing = allTags.first(where: { $0.name == name }) {
                spotTags.append(existing)
            } else {
                let tag = Tag()
                tag.name = name
                modelContext.insert(tag)
                spotTags.append(tag)
            }
        }
        spot.tags = spotTags

        modelContext.insert(spot)
        profile.spots = (profile.spots ?? []) + [spot]

        try? modelContext.save()

        withAnimation {
            showSuccess = true
        }

        resetForm()

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                showSuccess = false
            }
        }
    }

    private func resetForm() {
        title = ""
        details = ""
        selectedTagNames = []
        newTagName = ""
        photoPickerItem = nil
        photoData = nil
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else {
            photoData = nil
            return
        }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let processed = downscaledJPEG(from: data)
            await MainActor.run {
                photoData = processed
            }
        }
    }

    private func downscaledJPEG(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.85) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

// MARK: - Tag Chips

private struct RemovableTagChip: View {
    let name: String
    let onRemove: () -> Void

    private var iconName: String? {
        name == "weed-friendly" ? "leaf.fill" : nil
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.caption2)
            }

            Text(name)
                .font(Theme.Typography.caption().weight(.medium))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.accentGreen)
        .clipShape(Capsule())
    }
}

private struct SuggestedTagChip: View {
    let name: String
    let action: () -> Void

    private var iconName: String? {
        name == "weed-friendly" ? "leaf.fill" : nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.caption2)
                }

                Text(name)
                    .font(Theme.Typography.caption().weight(.medium))
            }
            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.cardSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Theme.Colors.cream.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Input Style

private extension View {
    func cardInputStyle() -> some View {
        self
            .font(Theme.Typography.body())
            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}

#Preview {
    NavigationStack {
        AddSpotView()
    }
    .modelContainer(for: [Profile.self, Spot.self, Tag.self], inMemory: true)
    .preferredColorScheme(.dark)
}
