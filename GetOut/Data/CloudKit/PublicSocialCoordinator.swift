import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PublicSocialCoordinator {
    static let shared = PublicSocialCoordinator()

    private(set) var isLoadingFeed = false
    private(set) var feedError: String?
    private(set) var currentUserRecordName: String?
    private(set) var isPublishingSpot = false
    private(set) var publishError: String?
    private(set) var accountError: String?
    private(set) var isCreatingProfile = false
    private(set) var isDeletingAccount = false
    private(set) var socialActionMessage: String?

    let service: CloudKitPublicService

    private init(service: CloudKitPublicService? = nil) {
        if let service {
            self.service = service
        } else {
            self.service = CloudKitPublicServiceFactory.makeLive()
        }
    }

    var isEnabled: Bool { FeatureFlags.publicSocialEnabled }

    func bootstrapIdentity(for profile: Profile, in context: ModelContext) async {
        guard isEnabled else { return }
        guard let userRecordName = try? await service.currentUserRecordName() else { return }
        currentUserRecordName = userRecordName
        PublicSocialIdentityService.linkIdentity(to: profile, userRecordName: userRecordName)
        try? context.save()
        _ = try? await service.upsertPublicProfile(profile, userRecordName: userRecordName)
    }

    func restoreCurrentProfile(in context: ModelContext, session: SessionStore) async {
        guard isEnabled else {
            session.finishAccountResolutionAfterFailure()
            return
        }
        do {
            guard let userRecordName = try await service.currentUserRecordName() else {
                currentUserRecordName = nil
                session.clearLocalProfileState()
                accountError = PublicSocialError.noAccount.errorDescription
                return
            }

            let identityChanged = session.currentCloudKitUserRecordName != userRecordName
            if identityChanged {
                session.beginAccountResolution(clearPersistedProfile: true)
            }
            currentUserRecordName = userRecordName
            accountError = nil

            // The deterministic public profile is authoritative. It prevents an unrelated
            // profile left in the local/private cache from becoming the signed-in user.
            if let dto = try await service.fetchPublicProfile(userRecordName: userRecordName) {
                let profile = PublicSocialCacheStore.upsertProfile(dto, in: context)
                try context.save()
                session.completeOnboarding(
                    username: profile.username,
                    userRecordName: userRecordName
                )
                await backfillOwnedPublicSpotPhotosIfNeeded(
                    userRecordName: userRecordName,
                    in: context
                )
                return
            }

            let localProfiles = try context.fetch(FetchDescriptor<Profile>())
            if let localProfile = localProfiles.first(where: {
                $0.cloudKitUserRecordName == userRecordName
            }) {
                // Recover a public profile after a development-environment reset while the
                // matching private SwiftData profile is still available.
                _ = try await service.upsertPublicProfile(
                    localProfile,
                    userRecordName: userRecordName
                )
                session.completeOnboarding(
                    username: localProfile.username,
                    userRecordName: userRecordName
                )
                await backfillOwnedPublicSpotPhotosIfNeeded(
                    userRecordName: userRecordName,
                    in: context
                )
                return
            }

            session.showOnboarding(for: userRecordName)
        } catch {
            accountError = socialErrorMessage(from: error)
            session.finishAccountResolutionAfterFailure()
        }
    }

    func createProfile(
        displayName: String,
        username: String,
        bio: String,
        city: String,
        in context: ModelContext
    ) async -> Profile? {
        isCreatingProfile = true
        accountError = nil
        defer { isCreatingProfile = false }

        let normalizedUsername = PublicContentPolicy.normalizedUsername(username)
        if let validationError = PublicContentPolicy.profileError(
            displayName: displayName,
            username: normalizedUsername,
            bio: bio
        ) {
            accountError = validationError
            return nil
        }

        do {
            guard let userRecordName = try await service.currentUserRecordName() else {
                throw PublicSocialError.noAccount
            }
            currentUserRecordName = userRecordName

            if let match = try await service.fetchPublicProfile(username: normalizedUsername),
               match.userRecordName != userRecordName {
                accountError = "That username is already taken."
                return nil
            }

            let existingProfiles = try context.fetch(FetchDescriptor<Profile>())
            let profile = existingProfiles.first(where: {
                $0.cloudKitUserRecordName == userRecordName
            }) ?? Profile()
            let isNewProfile = profile.modelContext == nil
            profile.username = normalizedUsername
            profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profile.citiesVisited = [city.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
            profile.cloudKitUserRecordName = userRecordName

            let dto = try await service.upsertPublicProfile(profile, userRecordName: userRecordName)
            PublicRecordMapping.apply(dto, to: profile)
            if isNewProfile {
                context.insert(profile)
            }
            try context.save()
            return profile
        } catch {
            accountError = socialErrorMessage(from: error)
            return nil
        }
    }

    func refreshFeed(in context: ModelContext) async {
        guard isEnabled else { return }
        isLoadingFeed = true
        feedError = nil
        defer { isLoadingFeed = false }

        do {
            var cursor: PublicFeedCursor?
            var allSpots: [PublicSpotDTO] = []

            repeat {
                let page = try await service.fetchPublicFeed(
                    cursor: cursor,
                    pageSize: PublicFeedPager.defaultPageSize
                )
                allSpots.append(contentsOf: page.spots)
                cursor = page.nextCursor
            } while cursor != nil

            PublicSocialCacheStore.reconcilePublicFeed(allSpots, in: context)
        } catch let error as PublicSocialError {
            feedError = error.errorDescription
        } catch {
            feedError = error.localizedDescription
        }
    }

    func cachedFeedSpots(in context: ModelContext, allowCannabis: Bool = false) -> [Spot] {
        PublicSocialCacheStore.cachedPublicFeedSpots(in: context, allowCannabis: allowCannabis)
    }

    @discardableResult
    func publishSpot(_ spot: Spot, owner: Profile, in context: ModelContext) async -> Bool {
        guard isEnabled else { return false }

        isPublishingSpot = true
        publishError = nil
        defer { isPublishingSpot = false }

        if currentUserRecordName == nil {
            currentUserRecordName = try? await service.currentUserRecordName()
        }
        guard let currentUserRecordName else {
            publishError = PublicSocialError.noAccount.errorDescription
            return false
        }

        PublicSocialIdentityService.linkIdentity(to: owner, userRecordName: currentUserRecordName)

        let tagNames = Array(Set((spot.tags?.map(\.name) ?? []) + spot.publicTagNames)).sorted()
        if let validationError = PublicContentPolicy.spotError(
            title: spot.title,
            details: spot.details,
            tags: tagNames
        ) {
            publishError = validationError
            return false
        }
        if CannabisPolicy.containsCannabisTag(tagNames),
           !CannabisPolicy.isSupportedJurisdiction(
                countryCode: spot.countryCode,
                administrativeArea: spot.administrativeArea
           ) {
            publishError = "Cannabis-tagged spots can only be published in Canada or California."
            return false
        }

        do {
            let dto = try await service.publishSpot(
                spot,
                owner: owner,
                ownerUserRecordName: currentUserRecordName
            )
            PublicRecordMapping.apply(dto, to: spot)
            PublicSocialCacheStore.syncFeedPage(PublicFeedPage(spots: [dto], nextCursor: nil), in: context)
            return true
        } catch {
            publishError = socialErrorMessage(from: error)
            return false
        }
    }

    func unpublishSpot(_ spot: Spot, in context: ModelContext) async -> Bool {
        guard !spot.publicRecordName.isEmpty else { return true }
        publishError = nil
        do {
            try await service.deletePublicSpot(recordName: spot.publicRecordName)
            spot.publicRecordName = ""
            spot.publisherUserRecordName = ""
            try context.save()
            socialActionMessage = "Removed from the public feed."
            return true
        } catch {
            publishError = socialErrorMessage(from: error)
            return false
        }
    }

    func report(_ draft: PublicReportDraft) async -> Bool {
        accountError = nil
        do {
            if currentUserRecordName == nil {
                currentUserRecordName = try await service.currentUserRecordName()
            }
            guard let currentUserRecordName else { throw PublicSocialError.noAccount }
            try await service.submitReport(draft, reporterUserRecordName: currentUserRecordName)
            socialActionMessage = "Report sent. Thank you for helping keep GetOut useful."
            return true
        } catch {
            accountError = socialErrorMessage(from: error)
            return false
        }
    }

    func block(userRecordName: String, in context: ModelContext) {
        PublicSocialCacheStore.block(userRecordName: userRecordName, in: context)
        socialActionMessage = "Blocked. Their spots are now hidden."
    }

    func unblock(userRecordName: String, in context: ModelContext) {
        PublicSocialCacheStore.unblock(userRecordName: userRecordName, in: context)
        socialActionMessage = "Unblocked. Their public spots can appear again."
    }

    func deleteCurrentAccount(in context: ModelContext, session: SessionStore) async -> Bool {
        isDeletingAccount = true
        accountError = nil
        defer { isDeletingAccount = false }

        do {
            if currentUserRecordName == nil {
                currentUserRecordName = try await service.currentUserRecordName()
            }
            guard let currentUserRecordName else { throw PublicSocialError.noAccount }
            try await service.deleteAccountData(userRecordName: currentUserRecordName)

            for item in (try? context.fetch(FetchDescriptor<Interaction>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<Like>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<Save>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<TripStop>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<Trip>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<Spot>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<Tag>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<Profile>())) ?? [] { context.delete(item) }
            for item in (try? context.fetch(FetchDescriptor<UserBlock>())) ?? [] { context.delete(item) }
            try context.save()

            self.currentUserRecordName = nil
            session.clearLocalProfileState()
            socialActionMessage = "Your GetOut profile and data were deleted."
            return true
        } catch {
            accountError = socialErrorMessage(from: error)
            return false
        }
    }

    private func socialErrorMessage(from error: Error) -> String {
        if let error = error as? PublicSocialError {
            return error.errorDescription ?? "Something went wrong."
        }
        return error.localizedDescription
    }

    /// Records published by builds before public photo support contain all spot metadata but no
    /// CKAsset. The creator's private SwiftData record still owns the original bytes, so migrate
    /// those records once from that creator's device without touching anyone else's content.
    private func backfillOwnedPublicSpotPhotosIfNeeded(
        userRecordName: String,
        in context: ModelContext
    ) async {
        let completionKey = "cloudkit.publicSpotPhotoBackfill.v1.\(userRecordName)"
        guard !UserDefaults.standard.bool(forKey: completionKey) else { return }

        let spots = ((try? context.fetch(FetchDescriptor<Spot>())) ?? []).filter {
            $0.publisherUserRecordName == userRecordName
                && !$0.publicRecordName.isEmpty
                && $0.photoData != nil
        }
        guard !spots.isEmpty else { return }

        var allUploadsSucceeded = true
        for spot in spots {
            guard let owner = spot.owner else {
                allUploadsSucceeded = false
                continue
            }
            do {
                let dto = try await service.publishSpot(
                    spot,
                    owner: owner,
                    ownerUserRecordName: userRecordName
                )
                PublicRecordMapping.apply(dto, to: spot)
            } catch {
                allUploadsSucceeded = false
            }
        }

        try? context.save()
        if allUploadsSucceeded {
            UserDefaults.standard.set(true, forKey: completionKey)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
