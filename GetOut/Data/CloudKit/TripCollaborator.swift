import CloudKit
import Foundation

struct TripCollaborator: Identifiable, Equatable {
    let id: String
    let displayName: String
    let statusLabel: String
    let isOwner: Bool

    static func fromShare(_ share: CKShare) -> [TripCollaborator] {
        share.participants.map { participant in
            let name = participant.userIdentity.nameComponents?.formatted(.name(style: .medium))
                ?? participant.userIdentity.lookupInfo?.emailAddress
                ?? "Collaborator"

            let status: String
            switch participant.acceptanceStatus {
            case .pending:
                status = "Invite pending"
            case .accepted:
                status = participant.role == .owner ? "Owner" : "Can edit"
            case .removed:
                status = "Removed"
            case .unknown:
                status = "Collaborator"
            @unknown default:
                status = "Collaborator"
            }

            let recordName = participant.userIdentity.lookupInfo?.userRecordID?.recordName
            return TripCollaborator(
                id: recordName ?? UUID().uuidString,
                displayName: name,
                statusLabel: status,
                isOwner: participant.role == .owner
            )
        }
    }
}
