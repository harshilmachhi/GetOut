import SwiftData
import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Profile> { $0.username == "harshil" }) private var demoProfiles: [Profile]
    @Query private var allProfiles: [Profile]

    @State private var title = ""
    @State private var summary = ""
    @State private var setDates = false
    @State private var startDate = Date.now
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date.now) ?? Date.now
    @State private var selectedCover: TripCoverStyle = .travel

    var onCreated: ((Trip) -> Void)?

    private var demoProfile: Profile? {
        demoProfiles.first ?? allProfiles.first
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    coverPreview

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Cover")
                            .font(Theme.Typography.caption().weight(.semibold))
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(TripCoverStyle.allCases) { style in
                                    Button {
                                        selectedCover = style
                                    } label: {
                                        ZStack {
                                            CategoryGradientView(
                                                category: style.category,
                                                fallbackIndex: style.fallbackIndex
                                            )

                                            Image(systemName: style.systemImage)
                                                .font(.title3)
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                                .stroke(
                                                    selectedCover == style
                                                        ? Theme.Colors.accentGreen
                                                        : Color.clear,
                                                    lineWidth: 2
                                                )
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Name your trip")
                            .font(Theme.Typography.caption().weight(.semibold))
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                        TextField("Weekend in Brooklyn", text: $title)
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Summary")
                            .font(Theme.Typography.caption().weight(.semibold))
                            .foregroundStyle(Theme.Colors.textOnDarkSecondary)

                        TextField("What kind of trip is this?", text: $summary, axis: .vertical)
                            .lineLimit(3...6)
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }

                    Toggle(isOn: $setDates) {
                        Text("Set dates")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                    }
                    .tint(Theme.Colors.accentGreen)

                    if setDates {
                        VStack(spacing: Theme.Spacing.md) {
                            DatePicker("Start", selection: $startDate, displayedComponents: .date)
                            DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                        }
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.appBackground)
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTrip() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var coverPreview: some View {
        ZStack(alignment: .bottomLeading) {
            CategoryGradientView(
                category: selectedCover.category,
                fallbackIndex: selectedCover.fallbackIndex,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(title.isEmpty ? "Your trip" : title)
                .font(Theme.Typography.serifDisplay(size: 24))
                .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                .padding(Theme.Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func saveTrip() {
        guard let profile = demoProfile else { return }

        let trip = Trip()
        trip.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.coverSystemImage = selectedCover.systemImage
        trip.owner = profile

        if setDates {
            trip.startDate = startDate
            trip.endDate = endDate
        }

        modelContext.insert(trip)
        try? modelContext.save()

        onCreated?(trip)
        dismiss()
    }
}

#Preview {
    CreateTripView()
        .modelContainer(for: [Profile.self, Trip.self], inMemory: true)
}
