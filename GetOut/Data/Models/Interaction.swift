import Foundation
import SwiftData

@Model
final class Interaction {
    var id: UUID = UUID()
    var event: String = InteractionEvent.view.rawValue
    var contextCity: String = ""
    var createdAt: Date = Date.now

    var user: Profile?
    var spot: Spot?

    @Transient
    var eventEnum: InteractionEvent {
        get { InteractionEvent(rawValue: event) ?? .view }
        set { event = newValue.rawValue }
    }

    init() {}
}

enum InteractionEvent: String {
    case view
    case like
    case save
    case dismiss
}
