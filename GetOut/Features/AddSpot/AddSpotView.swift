import CoreLocation
import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddSpotView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(filter: #Predicate<Profile> { $0.username == "harshil" }) private var demoProfiles: [Profile]
    @Query private var allProfiles: [Profile]

    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(LocationManager.defaultRegion)
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var didSetInitialRegion = false

    @State private var title = ""
    @State private var details = ""
    @State private var selectedCategory: SpotCategory = .views
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
        demoProfiles.first ?? allProfiles.first
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    whatsTheSpotSection
                    photoSection
                    categorySection
                    whereSection
                    tagsSection
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

    private var whatsTheSpotSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "What's the spot?")

            VStack(spacing: Theme.Spacing.sm) {
                TextField("Name this spot", text: $title)
                    .cardInputStyle()

                TextField("What makes it special?", text: $details, axis: .vertical)
                    .lineLimit(3...6)
                    .cardInputStyle()
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Photo")

            HStack(spacing: Theme.Spacing.md) {
                Group {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            CategoryGradientView(category: selectedCategory)
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                        }
                    }
                }
                .frame(width: 88, height: 88)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Label(photoData == nil ? "Choose photo" : "Change photo", systemImage: "photo.on.rectangle")
                            .font(Theme.Typography.caption().weight(.medium))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Theme.Colors.cardSurface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if photoData != nil {
                        Button {
                            photoPickerItem = nil
                            photoData = nil
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .font(Theme.Typography.caption().weight(.medium))
                                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Category")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(SpotCategory.allCases, id: \.self) { category in
                        AddSpotCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    private var whereSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Where?")

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

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Tags")

            FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                ForEach(allTags, id: \.id) { tag in
                    TagChip(
                        name: tag.name,
                        isSelected: selectedTagNames.contains(tag.name)
                    ) {
                        toggleTag(tag.name)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                TextField("New tag", text: $newTagName)
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
        let region = locationManager.defaultMapRegion
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

    private func toggleTag(_ name: String) {
        if selectedTagNames.contains(name) {
            selectedTagNames.remove(name)
        } else {
            selectedTagNames.insert(name)
        }
    }

    private func addNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedTagNames.insert(trimmed)
        newTagName = ""
    }

    private func saveSpot() {
        guard canSave,
              let coordinate = selectedCoordinate,
              let profile = demoProfile else { return }

        let spot = Spot()
        spot.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.latitude = coordinate.latitude
        spot.longitude = coordinate.longitude
        spot.neighborhood = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.category = selectedCategory.rawValue
        spot.rating = 0
        spot.photoData = photoData
        spot.owner = profile
        spot.createdAt = .now

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

// MARK: - Category Chip

private struct AddSpotCategoryChip: View {
    let category: SpotCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Theme.Colors.accentGreen : Theme.Colors.cream)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: category.symbolName)
                            .font(.title3)
                            .foregroundStyle(isSelected ? Theme.Colors.textOnDarkPrimary : Color.black.opacity(0.75))
                    }

                Text(category.displayName)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Chip

private struct TagChip: View {
    let name: String
    let isSelected: Bool
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
            .foregroundStyle(isSelected ? Theme.Colors.textOnDarkPrimary : Theme.Colors.textOnDarkSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.Colors.accentGreen : Theme.Colors.cardSurface)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(Theme.Colors.cream.opacity(0.15), lineWidth: 1)
                }
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
