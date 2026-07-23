import CoreLocation
import Foundation
import MapKit
import Observation

/// A place selected from Apple Maps, normalized for the Add Spot flow.
struct ResolvedLocation {
    let name: String?
    let coordinate: CLLocationCoordinate2D
    let address: String
    let city: String
    let neighborhood: String
    let countryCode: String
    let administrativeArea: String
}

enum LocationAddressFormatter {
    static func make(
        street: String,
        city: String,
        administrativeArea: String,
        postalCode: String,
        country: String
    ) -> String {
        let locality = [city, administrativeArea, postalCode]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [street, locality, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

struct LocationSearchSuggestion: Identifiable {
    let completion: MKLocalSearchCompletion

    var id: String { "\(completion.title)|\(completion.subtitle)" }
    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

/// Wraps MapKit's delegate-based autocomplete API so views only deal with
/// displayable suggestions and resolved locations.
@MainActor
@Observable
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()

    private(set) var suggestions: [LocationSearchSuggestion] = []
    private(set) var searchError: String?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String, near region: MKCoordinateRegion) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            clear()
            return
        }

        completer.region = region
        completer.queryFragment = trimmedQuery
    }

    func clear() {
        completer.cancel()
        suggestions = []
        searchError = nil
    }

    func resolve(_ suggestion: LocationSearchSuggestion) async throws -> ResolvedLocation {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw LocationSearchError.noPlaceFound
        }

        let placemark = item.placemark
        let address = placemark.postalAddress.map {
            LocationAddressFormatter.make(
                street: $0.street,
                city: $0.city,
                administrativeArea: $0.state,
                postalCode: $0.postalCode,
                country: $0.country
            )
        } ?? placemark.title ?? suggestion.subtitle

        return ResolvedLocation(
            name: item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
            coordinate: placemark.coordinate,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            city: placemark.locality ?? placemark.administrativeArea ?? "",
            neighborhood: placemark.subLocality ?? placemark.locality ?? "",
            countryCode: placemark.isoCountryCode ?? "",
            administrativeArea: placemark.administrativeArea ?? ""
        )
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.map(LocationSearchSuggestion.init)
        Task { @MainActor in
            self.suggestions = suggestions
            self.searchError = nil
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.searchError = "Places search is unavailable right now. You can still pin the location manually."
        }
    }
}

enum LocationSearchError: LocalizedError {
    case noPlaceFound

    var errorDescription: String? {
        "We couldn't find that place. Try another result or pin it on the map."
    }
}
