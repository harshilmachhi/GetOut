import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let nycCenter = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    static let userCenterSpan = MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
    nonisolated private static let maxAcceptableHorizontalAccuracy: CLLocationAccuracy = 100

    static var defaultRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: nycCenter, span: defaultSpan)
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastJurisdictionLocation: CLLocation?

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var lastLocation: CLLocation?
    private(set) var countryCode = ""
    private(set) var administrativeArea = ""
    private(set) var isResolvingJurisdiction = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .otherNavigation
        authorizationStatus = manager.authorizationStatus
        beginLocationUpdatesIfAuthorized()
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    var defaultMapRegion: MKCoordinateRegion {
        if let coordinate = lastLocation?.coordinate {
            return MKCoordinateRegion(center: coordinate, span: Self.defaultSpan)
        }
        return Self.defaultRegion
    }

    func centerOnUser() -> MKCoordinateRegion? {
        guard let coordinate = lastLocation?.coordinate else { return nil }
        return MKCoordinateRegion(center: coordinate, span: Self.userCenterSpan)
    }

    private func beginLocationUpdatesIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            beginLocationUpdatesIfAuthorized()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let accurateSamples = locations.filter {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= Self.maxAcceptableHorizontalAccuracy
        }
        let bestLocation = accurateSamples.min { $0.horizontalAccuracy < $1.horizontalAccuracy }
            ?? locations.last { $0.horizontalAccuracy >= 0 }

        guard let location = bestLocation else { return }
        Task { @MainActor in
            lastLocation = location
            await resolveJurisdictionIfNeeded(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location unavailable — keep last known or fall back to default region.
    }

    private func resolveJurisdictionIfNeeded(for location: CLLocation) async {
        if let lastJurisdictionLocation,
           location.distance(from: lastJurisdictionLocation) < 1_000,
           !countryCode.isEmpty {
            return
        }

        lastJurisdictionLocation = location
        isResolvingJurisdiction = true
        defer { isResolvingJurisdiction = false }

        do {
            let placemark = try await geocoder.reverseGeocodeLocation(location).first
            countryCode = placemark?.isoCountryCode?.uppercased() ?? ""
            administrativeArea = placemark?.administrativeArea?.uppercased() ?? ""
        } catch {
            countryCode = ""
            administrativeArea = ""
        }
    }
}
