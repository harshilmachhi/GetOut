import SwiftData
import SwiftUI

enum OnboardingVibeTag: String, CaseIterable, Identifiable {
    case quiet
    case views
    case weedFriendly = "weed-friendly"
    case outdoors
    case nightlife
    case foodie
    case coffee
    case sunset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quiet: "Quiet"
        case .views: "Views"
        case .weedFriendly: "Weed-friendly"
        case .outdoors: "Outdoors"
        case .nightlife: "Nightlife"
        case .foodie: "Foodie"
        case .coffee: "Coffee"
        case .sunset: "Sunset"
        }
    }

    var symbolName: String? {
        switch self {
        case .weedFriendly: "leaf.fill"
        default: nil
        }
    }
}

struct TasteQuestionnaireView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session

    let username: String

    @State private var selectedCategories: Set<String> = []
    @State private var selectedTags: Set<String> = []

    private var categoryOptions: [SpotCategory] {
        SpotCategory.allCases.filter { $0 != .nearby }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Your taste")
                        .font(Theme.Typography.serifDisplay(size: 32))
                        .foregroundStyle(Theme.Colors.cream)

                    Text("Pick what you're into — we'll personalize Discover from day one.")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }

                chipSection(title: "Spot types") {
                    FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                        ForEach(categoryOptions, id: \.rawValue) { category in
                            SelectableChip(
                                label: category.displayName,
                                symbolName: category.symbolName,
                                isSelected: selectedCategories.contains(category.rawValue)
                            ) {
                                toggleCategory(category.rawValue)
                            }
                        }
                    }
                }

                chipSection(title: "Vibes") {
                    FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                        ForEach(OnboardingVibeTag.allCases) { tag in
                            SelectableChip(
                                label: tag.label,
                                symbolName: tag.symbolName,
                                isSelected: selectedTags.contains(tag.rawValue)
                            ) {
                                toggleTag(tag.rawValue)
                            }
                        }
                    }
                }

                Button(action: saveAndFinish) {
                    Text("Finish")
                        .font(Theme.Typography.body().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .background(Theme.Colors.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.appBackground)
    }

    @ViewBuilder
    private func chipSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: title)
            content()
        }
    }

    private func toggleCategory(_ rawValue: String) {
        if selectedCategories.contains(rawValue) {
            selectedCategories.remove(rawValue)
        } else {
            selectedCategories.insert(rawValue)
        }
    }

    private func toggleTag(_ rawValue: String) {
        if selectedTags.contains(rawValue) {
            selectedTags.remove(rawValue)
        } else {
            selectedTags.insert(rawValue)
        }
    }

    private func saveAndFinish() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        var descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate { $0.username == trimmedUsername }
        )
        descriptor.fetchLimit = 1

        guard let profile = try? modelContext.fetch(descriptor).first else { return }

        profile.preferredCategories = Array(selectedCategories).sorted()
        profile.preferredTags = Array(selectedTags).sorted()
        try? modelContext.save()

        session.completeOnboarding(username: trimmedUsername)
    }
}

private struct SelectableChip: View {
    let label: String
    let symbolName: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.caption2)
                }
                Text(label)
                    .font(Theme.Typography.caption().weight(.medium))
            }
            .foregroundStyle(isSelected ? Theme.Colors.textOnDarkPrimary : Theme.Colors.cream.opacity(0.9))
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(isSelected ? Theme.Colors.accentGreen : Theme.Colors.cardSurface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ? Theme.Colors.accentGreen.opacity(0.5) : Theme.Colors.cream.opacity(0.15),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
