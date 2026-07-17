import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""

    var spots: [Spot]?

    init() {}
}
