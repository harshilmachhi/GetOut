import SwiftData
import SwiftUI

enum SearchSort: String, CaseIterable, Identifiable {
    case topRated
    case newest
    case name

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topRated: "Top rated"
        case .newest: "Newest"
        case .name: "Name"
        }
    }
}

struct SearchFiltersSheet: View {
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @Binding var selectedTags: Set<String>
    @Binding var sort: SearchSort

    @Environment(\.dismiss) private var dismiss

    @State private var draftTags: Set<String>
    @State private var draftSort: SearchSort

    init(selectedTags: Binding<Set<String>>, sort: Binding<SearchSort>) {
        _selectedTags = selectedTags
        _sort = sort
        _draftTags = State(initialValue: selectedTags.wrappedValue)
        _draftSort = State(initialValue: sort.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    tagsSection
                    sortSection
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.appBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        draftTags.removeAll()
                        draftSort = .topRated
                    }
                    .foregroundStyle(Theme.Colors.textOnDarkSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show results") {
                        applyDraft()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.accentGreen)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Tags")

            FlowLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                ForEach(allTags, id: \.id) { tag in
                    FilterTagChip(
                        name: tag.name,
                        isSelected: draftTags.contains(tag.name)
                    ) {
                        toggleTag(tag.name)
                    }
                }
            }
        }
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Sort by")

            Picker("Sort by", selection: $draftSort) {
                ForEach(SearchSort.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func toggleTag(_ name: String) {
        if draftTags.contains(name) {
            draftTags.remove(name)
        } else {
            draftTags.insert(name)
        }
    }

    private func applyDraft() {
        selectedTags = draftTags
        sort = draftSort
    }
}

private struct FilterTagChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    private var isWeedFriendly: Bool {
        name.lowercased() == "weed-friendly"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isWeedFriendly {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                }

                Text(name)
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

#Preview {
    SearchFiltersSheet(
        selectedTags: .constant(["sunset"]),
        sort: .constant(.topRated)
    )
    .modelContainer(for: [Tag.self], inMemory: true)
    .preferredColorScheme(.dark)
}
