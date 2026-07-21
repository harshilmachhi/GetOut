import MapKit
import SwiftData
import SwiftUI

struct SpotDetailView: View {
    let spot: Spot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    @State private var didLogView = false
    @State private var showAddToTrip = false
    @State private var socialCoordinator = PublicSocialCoordinator.shared

    private let heroHeight: CGFloat = 360

    private var demoProfile: Profile? {
        profiles.first { $0.username == session.currentUsername } ?? profiles.first
    }

    private var isOwner: Bool {
        guard let demoProfile else { return false }
        return spot.owner?.id == demoProfile.id
    }

    private var isLiked: Bool {
        guard let profileID = demoProfile?.id else { return false }
        return spot.likes?.contains(where: { $0.user?.id == profileID }) == true
    }

    private var isSaved: Bool {
        guard let profileID = demoProfile?.id else { return false }
        return spot.saves?.contains(where: { $0.user?.id == profileID && $0.list == SaveList.saved.rawValue }) == true
    }

    private var isBeenThere: Bool {
        guard let profileID = demoProfile?.id else { return false }
        return spot.saves?.contains(where: { $0.user?.id == profileID && $0.list == SaveList.beenThere.rawValue }) == true
    }

    private var likeCount: Int {
        spot.likes?.count ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection(topInset: geo.safeAreaInsets.top)

                    contentSection
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Theme.Colors.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            logViewIfNeeded()
            if FeatureFlags.publicSocialEnabled, let profile = demoProfile {
                await socialCoordinator.bootstrapIdentity(for: profile, in: modelContext)
            }
        }
        .sheet(isPresented: $showAddToTrip) {
            AddToTripSheet(spot: spot)
        }
    }

    // MARK: - Hero

    private func heroSection(topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            SpotImage(spot: spot, startPoint: .top, endPoint: .bottom)
                .frame(height: heroHeight)
                .clipped()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial.opacity(0.65))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        toggleLike()
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isLiked ? .red : Theme.Colors.textOnDarkPrimary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial.opacity(0.65))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, topInset + Theme.Spacing.sm)

                Spacer()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(spot.title)
                            .font(Theme.Typography.serifDisplay(size: 30))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .lineLimit(3)

                        Text(heroLocationLine)
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .frame(height: heroHeight)
        }
        .frame(height: heroHeight)
    }

    private var heroLocationLine: String {
        var parts = ["Nearby"]
        if !spot.neighborhood.isEmpty {
            parts.append(spot.neighborhood)
        }
        if !spot.city.isEmpty {
            parts.append(spot.city)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ratingRow
            actionRow
            publishSection
            aboutSection
            tagsSection
            locationSection
            addedBySection
        }
        .padding(Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xl)
    }

    private var ratingRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "star.fill")
                .foregroundStyle(Color.yellow)

            Text(String(format: "%.1f", spot.rating))
                .font(Theme.Typography.body().weight(.semibold))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)

            if likeCount > 0 {
                Text("· \(likeCount) likes")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ActionPill(
                title: "Like",
                symbol: isLiked ? "heart.fill" : "heart",
                isActive: isLiked,
                activeColor: .red
            ) {
                toggleLike()
            }

            ActionPill(
                title: "Save",
                symbol: isSaved ? "bookmark.fill" : "bookmark",
                isActive: isSaved,
                activeColor: Theme.Colors.accentGreen
            ) {
                toggleSave(list: SaveList.saved.rawValue)
            }

            ActionPill(
                title: "Been There",
                symbol: isBeenThere ? "checkmark.seal.fill" : "checkmark.seal",
                isActive: isBeenThere,
                activeColor: Theme.Colors.accentGreen
            ) {
                toggleSave(list: SaveList.beenThere.rawValue)
            }

            ActionPill(
                title: "Add to Trip",
                symbol: "suitcase",
                isActive: false,
                activeColor: Theme.Colors.accentGreen
            ) {
                showAddToTrip = true
            }
        }
    }

    @ViewBuilder
    private var publishSection: some View {
        if FeatureFlags.publicSocialEnabled, isOwner, let owner = spot.owner {
            PublicPublishSpotSection(spot: spot, owner: owner)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "About")

            Text(spot.details.isEmpty ? "A quiet corner worth discovering — details coming soon." : spot.details)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if let tags = spot.tags, !tags.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(title: "Tags")

                FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                    ForEach(tags, id: \.id) { tag in
                        TagChip(name: tag.name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        if let coordinate = spot.mapCoordinate {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(title: "Location")

                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )))) {
                    Annotation(spot.title, coordinate: coordinate) {
                        SpotMapPin(category: spot.categoryEnum, size: 32)
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .allowsHitTesting(false)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                Button {
                    openInMaps(coordinate: coordinate)
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Get Directions")
                    }
                    .font(Theme.Typography.body().weight(.medium))
                    .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var addedBySection: some View {
        if let owner = spot.owner {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(title: "Added by")

                HStack(spacing: Theme.Spacing.md) {
                    Circle()
                        .fill(Theme.Colors.cardSurface)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: owner.avatarSystemImage)
                                .font(.body)
                                .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(owner.displayName)
                            .font(Theme.Typography.body().weight(.semibold))
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)

                        Text("@\(owner.username)")
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                    }

                    Spacer()

                    if FeatureFlags.publicSocialEnabled, !owner.cloudKitUserRecordName.isEmpty {
                        PublicFollowButton(
                            targetUserRecordName: owner.cloudKitUserRecordName,
                            compact: true
                        )
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleLike() {
        guard let profile = demoProfile else { return }

        if let existing = spot.likes?.first(where: { $0.user?.id == profile.id }) {
            modelContext.delete(existing)
        } else {
            let like = Like()
            like.user = profile
            like.spot = spot
            modelContext.insert(like)
        }
    }

    private func toggleSave(list: String) {
        guard let profile = demoProfile else { return }

        if let existing = spot.saves?.first(where: { $0.user?.id == profile.id && $0.list == list }) {
            modelContext.delete(existing)
        } else {
            let save = Save()
            save.user = profile
            save.spot = spot
            save.list = list
            modelContext.insert(save)
        }
    }

    private func logViewIfNeeded() {
        guard !didLogView, let profile = demoProfile else { return }
        didLogView = true

        let interaction = Interaction()
        interaction.event = InteractionEvent.view.rawValue
        interaction.spot = spot
        interaction.user = profile
        interaction.contextCity = spot.city
        modelContext.insert(interaction)
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.title
        mapItem.openInMaps()
    }
}

// MARK: - Supporting Views

private struct ActionPill: View {
    let title: String
    let symbol: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isActive ? activeColor : Theme.Colors.textOnDarkSecondary)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isActive ? Theme.Colors.textOnDarkPrimary : Theme.Colors.textOnDarkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isActive ? activeColor.opacity(0.15) : Theme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .stroke(isActive ? activeColor.opacity(0.4) : Theme.Colors.cream.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TagChip: View {
    let name: String

    private var isWeedFriendly: Bool {
        name.lowercased() == "weed-friendly"
    }

    var body: some View {
        HStack(spacing: 4) {
            if isWeedFriendly {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
            }
            Text(name)
                .font(Theme.Typography.caption().weight(.medium))
        }
        .foregroundStyle(Theme.Colors.cream.opacity(0.9))
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(Theme.Colors.cardSurface)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Theme.Colors.cream.opacity(0.15), lineWidth: 1)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Profile.self, Spot.self, Tag.self, Like.self, Save.self, Interaction.self, Trip.self, TripStop.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let profile = Profile()
    profile.username = "harshil"
    profile.displayName = "Harshil"
    context.insert(profile)

    let tag = Tag()
    tag.name = "sunset"
    context.insert(tag)

    let spot = Spot()
    spot.title = "Sunset hill seating"
    spot.neighborhood = "Fort Greene"
    spot.city = "New York"
    spot.category = SpotCategory.views.rawValue
    spot.rating = 4.9
    spot.latitude = 40.6892
    spot.longitude = -73.9747
    spot.owner = profile
    spot.tags = [tag]
    context.insert(spot)

    return NavigationStack {
        SpotDetailView(spot: spot)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
