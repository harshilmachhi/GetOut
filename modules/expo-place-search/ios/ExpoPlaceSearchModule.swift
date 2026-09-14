import Contacts
import ExpoModulesCore
import MapKit

public final class ExpoPlaceSearchModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoPlaceSearch")

    AsyncFunction("search") { (query: String, latitude: Double, longitude: Double) async throws -> [[String: Any]] in
      let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.count >= 2 else { return [] }

      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = trimmed
      request.resultTypes = [.pointOfInterest, .address]
      request.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        latitudinalMeters: 150_000,
        longitudinalMeters: 150_000
      )

      let response = try await MKLocalSearch(request: request).start()
      return response.mapItems.prefix(15).enumerated().map { index, item in
        let placemark = item.placemark
        let postalAddress = placemark.postalAddress
        let formattedAddress: String
        if let postalAddress {
          formattedAddress = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
            .replacingOccurrences(of: "\n", with: ", ")
        } else {
          formattedAddress = placemark.title ?? ""
        }

        return [
          "id": "apple-\(index)-\(placemark.coordinate.latitude)-\(placemark.coordinate.longitude)",
          "name": item.name ?? placemark.name ?? "Location",
          "formattedAddress": formattedAddress,
          "latitude": placemark.coordinate.latitude,
          "longitude": placemark.coordinate.longitude,
          "city": placemark.locality ?? "",
          "district": placemark.subLocality ?? "",
          "region": placemark.administrativeArea ?? "",
          "country": placemark.country ?? "",
          "countryCode": placemark.isoCountryCode ?? ""
        ]
      }
    }
  }
}
