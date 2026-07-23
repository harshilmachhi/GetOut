import CoreLocation
import MapKit
import SwiftUI

struct PinLocationPicker: View {
    @Environment(\.dismiss) private var dismiss

    private let onConfirm: (CLLocationCoordinate2D) -> Void

    @State private var cameraPosition: MapCameraPosition
    @State private var draftCoordinate: CLLocationCoordinate2D?

    init(
        initialCoordinate: CLLocationCoordinate2D?,
        onConfirm: @escaping (CLLocationCoordinate2D) -> Void
    ) {
        let center = initialCoordinate ?? LocationManager.nycCenter
        let region = MKCoordinateRegion(
            center: center,
            span: initialCoordinate == nil ? LocationManager.defaultSpan : LocationManager.userCenterSpan
        )
        self.onConfirm = onConfirm
        _cameraPosition = State(initialValue: .region(region))
        _draftCoordinate = State(initialValue: initialCoordinate)
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let draftCoordinate {
                        Marker("Selected location", coordinate: draftCoordinate)
                            .tint(Theme.Colors.accentGreen)
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .onTapGesture { position in
                    guard let coordinate = proxy.convert(position, from: .local) else { return }
                    draftCoordinate = coordinate
                }
                .overlay(alignment: .top) {
                    Text(draftCoordinate == nil ? "Tap the map to place a pin" : "Tap again to adjust the pin")
                        .font(Theme.Typography.caption().weight(.medium))
                        .foregroundStyle(Theme.Colors.textOnDarkPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, Theme.Spacing.sm)
                }
            }
            .navigationTitle("Pin a location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this pin") {
                        guard let draftCoordinate else { return }
                        onConfirm(draftCoordinate)
                        dismiss()
                    }
                    .disabled(draftCoordinate == nil)
                }
            }
        }
        .presentationDetents([.large])
    }
}
