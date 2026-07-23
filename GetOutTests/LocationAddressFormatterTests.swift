import XCTest
@testable import GetOut

final class LocationAddressFormatterTests: XCTestCase {
    func testFormatsCompleteAddressForPersistence() {
        let address = LocationAddressFormatter.make(
            street: "123 Main Street",
            city: "Toronto",
            administrativeArea: "ON",
            postalCode: "M5V 2T6",
            country: "Canada"
        )

        XCTAssertEqual(address, "123 Main Street, Toronto ON M5V 2T6, Canada")
    }

    func testOmitsEmptyAddressComponents() {
        let address = LocationAddressFormatter.make(
            street: "",
            city: "",
            administrativeArea: "",
            postalCode: "",
            country: "Canada"
        )

        XCTAssertEqual(address, "Canada")
    }
}
