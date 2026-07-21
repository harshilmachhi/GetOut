import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let nycCenter = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    static let userCenterSpan = MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
    private static let maxAcceptableHorizontalAccuracy: CLLocationAccuracy = 100

    static var defaultRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: nycCenter, span: defaultSpan)
    }

    private let manager = CLLocationManager()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var lastLocation: CLLocation?

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
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location unavailable — keep last known or fall back to default region.
    }
}
