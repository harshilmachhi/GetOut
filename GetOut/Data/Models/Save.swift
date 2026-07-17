import Foundation
import SwiftData

@Model
final class Save {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var list: String = "saved"

    var user: Profile?
    var spot: Spot?

    init() {}
}

enum SaveList: String {
    case saved
    case beenThere

    var rawValueString: String { rawValue }
}
