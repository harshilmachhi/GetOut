import Foundation

enum CannabisPolicy {
    static let canonicalTag = "weed-friendly"

    static func isCannabisTag(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return [canonicalTag, "weed", "cannabis", "420"].contains(normalized)
    }

    static func containsCannabisTag(_ tags: some Sequence<String>) -> Bool {
        tags.contains(where: isCannabisTag)
    }

    static func isSupportedJurisdiction(countryCode: String, administrativeArea: String) -> Bool {
        let country = countryCode.uppercased()
        if country == "CA" { return true }
        return country == "US" && ["CA", "CALIFORNIA"].contains(administrativeArea.uppercased())
    }

    static func canAccess(
        ageConfirmed: Bool,
        countryCode: String,
        administrativeArea: String
    ) -> Bool {
        ageConfirmed && isSupportedJurisdiction(
            countryCode: countryCode,
            administrativeArea: administrativeArea
        )
    }
}
