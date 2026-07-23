import Contacts
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
    @State private var locationSearch = LocationSearchService()
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocation: ResolvedLocation?
    @State private var locationQuery = ""
    @State private var address = ""
    @State private var showPinPicker = false
    @State private var isResolvingSearch = false

    @State private var title = ""
    @State private var details = ""
    @State private var neighborhood = ""
    @State private var city = ""
    @State private var countryCode = ""
    @State private var administrativeArea = ""
    @State private var selectedTagNames: Set<String> = []
    @State private var newTagName = ""

    @State private var isGeocoding = false
    @State private var showSuccess = false
    @State private var geocodeTask: Task<Void, Never>?

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var formError: String?
    @State private var showCannabisAgeConfirmation = false
    @State private var showPublicationConfirmation = false
    @State private var coordinator = PublicSocialCoordinator.shared
    @AppStorage("privacy.hasConfirmedCannabisLegalAge") private var hasConfirmedCannabisLegalAge = false

    private var containsCannabis: Bool {
        CannabisPolicy.containsCannabisTag(selectedTagNames)
    }

    private var viewerCanUseCannabis: Bool {
        CannabisPolicy.canAccess(
            ageConfirmed: hasConfirmedCannabisLegalAge,
            countryCode: locationManager.countryCode,
            administrativeArea: locationManager.administrativeArea
        )
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedCoordinate != nil
            && (!containsCannabis || (
                viewerCanUseCannabis
                    && CannabisPolicy.isSupportedJurisdiction(
                        countryCode: countryCode,
                        administrativeArea: administrativeArea
                    )
            ))
    }

    private var demoProfile: Profile? {
        allProfiles.first { $0.username == session.currentUsername } ?? allProfiles.first
    }

    private var suggestedTags: [Tag] {
        allTags.filter {
            !selectedTagNames.contains($0.name)
                && (viewerCanUseCannabis || !CannabisPolicy.isCannabisTag($0.name))
        }
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
        }
        .onChange(of: photoPickerItem) { _, newItem in
            loadPhoto(from: newItem)
        }
        .alert("Legal-age confirmation", isPresented: $showCannabisAgeConfirmation) {
            Button("I am of legal age") {
                hasConfirmedCannabisLegalAge = true
                if CannabisPolicy.isSupportedJurisdiction(
                    countryCode: locationManager.countryCode,
                    administrativeArea: locationManager.administrativeArea
                ) {
                    selectedTagNames.insert(CannabisPolicy.canonicalTag)
                } else {
                    formError = "Cannabis tags are available only while you are physically in Canada or California."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cannabis-related spots are limited to adults physically in Canada or California and to spots located there. GetOut does not facilitate cannabis sales.")
        }
        .confirmationDialog(
            "Publish this spot?",
            isPresented: $showPublicationConfirmation,
            titleVisibility: .visible
        ) {
            Button("Publish spot") {
                Task { await saveAndPublishSpot() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your public profile and this exact pinned location will be visible to everyone using GetOut.")
        }
        .sheet(isPresented: $showPinPicker) {
            PinLocationPicker(initialCoordinate: pinPickerInitialCoordinate) { coordinate in
                selectDroppedPin(coordinate)
            }
        }
    }

    // MARK: - Sections

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            stepHeader(
                number: 1,
                title: "Location",
                subtitle: "Search for a real place, or pin somewhere that isn’t listed."
            )

            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    TextField("Search for a place or address", text: $locationQuery)
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: locationQuery) { _, query in
                            locationSearch.update(query: query, near: searchRegion)
                        }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                if isResolvingSearch {
                    ProgressView()
                        .tint(Theme.Colors.accentGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Theme.Spacing.sm)
                } else if !locationSearch.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(locationSearch.suggestions) { suggestion in
                            Button { resolveLocation(suggestion) } label: {
                                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(Theme.Colors.accentGreen)
                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        Text(suggestion.title)
                                            .font(Theme.Typography.body().weight(.medium))
                                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(Theme.Typography.caption())
                                                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(Theme.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if suggestion.id != locationSearch.suggestions.last?.id {
                                Divider().overlay(Theme.Colors.cream.opacity(0.12))
                            }
                        }
                    }
                    .background(Theme.Colors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
            }

            if selectedCoordinate != nil {
                selectedLocationCard()
            }

            Button { showPinPicker = true } label: {
                Label("Pin an unlisted place", systemImage: "mappin")
                    .font(Theme.Typography.caption().weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.cardSurface)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if let searchError = locationSearch.searchError {
                Text(searchError)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }
        }
    }

    private func selectedLocationCard() -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: selectedLocation == nil ? "mappin" : "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.Colors.accentGreen)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(selectedLocation?.name ?? "Pinned location")
                    .font(Theme.Typography.body().weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                if isGeocoding {
                    Text("Finding the nearest address…")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                } else if !address.isEmpty {
                    Text(address)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                        .lineLimit(2)
                } else {
                    Text("Exact coordinates selected")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }
            }
            Spacer(minLength: 0)
            Button("Adjust") { showPinPicker = true }
                .font(Theme.Typography.caption().weight(.semibold))
                .foregroundStyle(Theme.Colors.accentGreen)
                .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .stroke(Theme.Colors.cream.opacity(0.12), lineWidth: 1)
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
                                selectTag(tag.name)
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
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if containsCannabis && !canSave {
                Text("Weed-friendly spots require legal-age confirmation, current location in Canada or California, and a spot located there.")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }

            if let formError {
                Text(formError)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(.red.opacity(0.9))
            }

            Button {
                showPublicationConfirmation = true
            } label: {
                HStack {
                    if coordinator.isPublishingSpot {
                        ProgressView()
                            .tint(Theme.Colors.textOnDarkPrimary)
                    }
                    Text("Publish spot")
                }
                    .font(Theme.Typography.body().weight(.semibold))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(canSave ? Theme.Colors.accentGreen : Theme.Colors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            .buttonStyle(.plain)
            .disabled(!canSave || coordinator.isPublishingSpot)
            .opacity(canSave ? 1 : 0.5)
        }
    }

    private var successOverlay: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accentGreen)

            Text("Spot published!")
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

    private var searchRegion: MKCoordinateRegion {
        locationManager.defaultMapRegion
    }

    private var pinPickerInitialCoordinate: CLLocationCoordinate2D? {
        selectedCoordinate ?? locationManager.lastLocation?.coordinate
    }

    private func resolveLocation(_ suggestion: LocationSearchSuggestion) {
        guard !isResolvingSearch else { return }
        isResolvingSearch = true

        Task {
            defer { isResolvingSearch = false }
            do {
                let resolved = try await locationSearch.resolve(suggestion)
                applyResolvedLocation(resolved)
            } catch {
                formError = error.localizedDescription
            }
        }
    }

    private func applyResolvedLocation(_ location: ResolvedLocation) {
        selectedLocation = location
        selectedCoordinate = location.coordinate
        address = location.address
        city = location.city
        neighborhood = location.neighborhood
        countryCode = location.countryCode
        administrativeArea = location.administrativeArea
        locationQuery = ""
        locationSearch.clear()

        if let name = location.name, !name.isEmpty {
            title = name
        }
    }

    private func selectDroppedPin(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = nil
        selectedCoordinate = coordinate
        address = ""
        city = ""
        neighborhood = ""
        countryCode = ""
        administrativeArea = ""
        locationQuery = ""
        locationSearch.clear()
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
            address = placemark.postalAddress.map {
                LocationAddressFormatter.make(
                    street: $0.street,
                    city: $0.city,
                    administrativeArea: $0.state,
                    postalCode: $0.postalCode,
                    country: $0.country
                )
            } ?? placemark.name ?? ""
            countryCode = placemark.isoCountryCode ?? ""
            administrativeArea = placemark.administrativeArea ?? ""
        } catch {
            // Geocoding failed — fields remain manually editable.
        }
    }

    private func addNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectTag(trimmed)
        newTagName = ""
    }

    private func selectTag(_ value: String) {
        if CannabisPolicy.isCannabisTag(value) {
            if viewerCanUseCannabis {
                selectedTagNames.insert(CannabisPolicy.canonicalTag)
            } else if hasConfirmedCannabisLegalAge {
                formError = "Cannabis tags are available only while you are physically in Canada or California."
            } else {
                showCannabisAgeConfirmation = true
            }
        } else {
            selectedTagNames.insert(value.lowercased())
        }
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

    @MainActor
    private func saveAndPublishSpot() async {
        guard canSave,
              let coordinate = selectedCoordinate,
              let profile = demoProfile else { return }

        if let validationError = PublicContentPolicy.spotError(
            title: title,
            details: details,
            tags: Array(selectedTagNames)
        ) {
            formError = validationError
            return
        }
        formError = nil

        let now = Date.now
        let calendar = Calendar.current

        let spot = Spot()
        spot.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.latitude = coordinate.latitude
        spot.longitude = coordinate.longitude
        spot.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.neighborhood = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.category = inferredCategory(from: selectedTagNames).rawValue
        spot.rating = 0
        spot.photoData = photoData
        spot.visitHour = calendar.component(.hour, from: now)
        spot.visitWeekday = calendar.component(.weekday, from: now)
        spot.owner = profile
        spot.createdAt = now
        spot.publicTagNames = Array(selectedTagNames).sorted()
        spot.containsCannabis = containsCannabis
        spot.countryCode = countryCode
        spot.administrativeArea = administrativeArea

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

        do {
            try modelContext.save()
        } catch {
            formError = "Could not save this spot. Please try again."
            return
        }

        guard await coordinator.publishSpot(spot, owner: profile, in: modelContext) else {
            profile.spots?.removeAll { $0.id == spot.id }
            modelContext.delete(spot)
            try? modelContext.save()
            formError = coordinator.publishError ?? "Could not publish this spot. Please try again."
            return
        }

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
        selectedCoordinate = nil
        selectedLocation = nil
        locationQuery = ""
        address = ""
        neighborhood = ""
        city = ""
        countryCode = ""
        administrativeArea = ""
        formError = nil
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
