import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PublicSocialCoordinator {
    static let shared = PublicSocialCoordinator()

    private(set) var isLoadingFeed = false
    private(set) var isLoadingProfileSocial = false
    private(set) var feedError: String?
    private(set) var profileSocialError: String?
    private(set) var currentUserRecordName: String?
    private(set) var feedCursor: PublicFeedCursor?
    private(set) var hasMoreFeed = false
    private(set) var followStates: [String: FollowToggleState] = [:]
    private(set) var followErrors: [String: String] = [:]
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
        guard isEnabled, !session.hasCompletedOnboarding else { return }
        do {
            guard let userRecordName = try await service.currentUserRecordName() else { return }
            currentUserRecordName = userRecordName
            let localProfiles = try context.fetch(FetchDescriptor<Profile>())
            if let localProfile = localProfiles.first(where: {
                $0.cloudKitUserRecordName == userRecordName
            }) {
                session.completeOnboarding(username: localProfile.username)
                return
            }
            guard let dto = try await service.fetchPublicProfile(userRecordName: userRecordName) else { return }
            let profile = PublicSocialCacheStore.upsertProfile(dto, in: context)
            try context.save()
            session.completeOnboarding(username: profile.username)
        } catch {
            // Public browsing remains available when iCloud is unavailable.
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

            let profile = Profile()
            profile.username = normalizedUsername
            profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profile.citiesVisited = [city.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
            profile.cloudKitUserRecordName = userRecordName

            let dto = try await service.upsertPublicProfile(profile, userRecordName: userRecordName)
            PublicRecordMapping.apply(dto, to: profile)
            context.insert(profile)
            try context.save()
            return profile
        } catch {
            accountError = socialErrorMessage(from: error)
            return nil
        }
    }

    func refreshFeed(in context: ModelContext, loadMore: Bool = false) async {
        guard isEnabled else { return }
        isLoadingFeed = true
        feedError = nil
        defer { isLoadingFeed = false }

        do {
            let cursor = loadMore ? feedCursor : nil
            let page = try await service.fetchPublicFeed(cursor: cursor, pageSize: PublicFeedPager.defaultPageSize)
            PublicSocialCacheStore.syncFeedPage(page, in: context)
            feedCursor = page.nextCursor
            hasMoreFeed = page.nextCursor != nil
        } catch let error as PublicSocialError {
            feedError = error.errorDescription
        } catch {
            feedError = error.localizedDescription
        }
    }

    func refreshProfileSocial(for profile: Profile, in context: ModelContext) async {
        guard isEnabled, let userRecordName = profile.cloudKitUserRecordName.nilIfEmpty ?? currentUserRecordName else {
            await bootstrapIdentity(for: profile, in: context)
            guard let linkedName = profile.cloudKitUserRecordName.nilIfEmpty ?? currentUserRecordName else { return }
            await loadProfileSocial(userRecordName: linkedName, profile: profile, in: context)
            return
        }
        await loadProfileSocial(userRecordName: userRecordName, profile: profile, in: context)
    }

    private func loadProfileSocial(userRecordName: String, profile: Profile, in context: ModelContext) async {
        isLoadingProfileSocial = true
        profileSocialError = nil
        defer { isLoadingProfileSocial = false }

        do {
            let counts = try await service.socialCounts(for: userRecordName)
            PublicSocialCacheStore.updateSocialCounts(for: profile, counts: counts, in: context)

            let followersPage = try await service.fetchFollowers(for: userRecordName, cursor: nil, pageSize: 50)
            for followerProfile in followersPage.profiles {
                _ = PublicSocialCacheStore.upsertProfile(followerProfile, in: context)
                let dto = PublicFollowDTO(
                    recordName: PublicCloudKitSchema.followRecordName(
                        follower: followerProfile.userRecordName,
                        followee: userRecordName
                    ),
                    followerUserRecordName: followerProfile.userRecordName,
                    followeeUserRecordName: userRecordName,
                    createdAt: .now
                )
                PublicSocialCacheStore.upsertFollow(dto, in: context)
            }

            let followingPage = try await service.fetchFollowing(for: userRecordName, cursor: nil, pageSize: 50)
            for followingProfile in followingPage.profiles {
                _ = PublicSocialCacheStore.upsertProfile(followingProfile, in: context)
                let dto = PublicFollowDTO(
                    recordName: PublicCloudKitSchema.followRecordName(
                        follower: userRecordName,
                        followee: followingProfile.userRecordName
                    ),
                    followerUserRecordName: userRecordName,
                    followeeUserRecordName: followingProfile.userRecordName,
                    createdAt: .now
                )
                PublicSocialCacheStore.upsertFollow(dto, in: context)
            }
        } catch let error as PublicSocialError {
            profileSocialError = error.errorDescription
        } catch {
            profileSocialError = error.localizedDescription
        }
    }

    func cachedFeedSpots(in context: ModelContext, allowCannabis: Bool = false) -> [Spot] {
        PublicSocialCacheStore.cachedPublicFeedSpots(in: context, allowCannabis: allowCannabis)
    }

    func canFollow(targetUserRecordName: String) -> Bool {
        guard isEnabled, !targetUserRecordName.isEmpty else { return false }
        if let current = currentUserRecordName, current == targetUserRecordName { return false }
        return true
    }

    func followState(for targetUserRecordName: String) -> FollowToggleState {
        followStates[targetUserRecordName] ?? .notFollowing
    }

    func followError(for targetUserRecordName: String) -> String? {
        followErrors[targetUserRecordName]
    }

    func loadFollowState(for targetUserRecordName: String) async {
        guard isEnabled, canFollow(targetUserRecordName: targetUserRecordName) else { return }

        if currentUserRecordName == nil {
            currentUserRecordName = try? await service.currentUserRecordName()
        }
        guard let currentUserRecordName else { return }

        do {
            let following = try await service.isFollowing(
                userRecordName: targetUserRecordName,
                currentUserRecordName: currentUserRecordName
            )
            followStates[targetUserRecordName] = following ? .following : .notFollowing
        } catch {
            followErrors[targetUserRecordName] = socialErrorMessage(from: error)
        }
    }

    func toggleFollow(targetUserRecordName: String, in context: ModelContext) async {
        guard isEnabled, canFollow(targetUserRecordName: targetUserRecordName) else { return }

        if currentUserRecordName == nil {
            currentUserRecordName = try? await service.currentUserRecordName()
        }
        guard let currentUserRecordName else {
            followErrors[targetUserRecordName] = PublicSocialError.noAccount.errorDescription
            return
        }

        let previousState = followStates[targetUserRecordName] ?? .notFollowing
        let wasFollowing = previousState == .following

        followStates[targetUserRecordName] = .pending
        followErrors[targetUserRecordName] = nil
        followStates[targetUserRecordName] = wasFollowing ? .notFollowing : .following

        do {
            if wasFollowing {
                try await service.unfollow(
                    userRecordName: targetUserRecordName,
                    currentUserRecordName: currentUserRecordName
                )
                PublicSocialCacheStore.removeFollow(
                    follower: currentUserRecordName,
                    followee: targetUserRecordName,
                    in: context
                )
                followStates[targetUserRecordName] = FollowToggleState.afterUnfollow(
                    from: .pending,
                    success: true
                )
            } else {
                try await service.follow(
                    userRecordName: targetUserRecordName,
                    currentUserRecordName: currentUserRecordName
                )
                let dto = PublicFollowDTO(
                    recordName: PublicCloudKitSchema.followRecordName(
                        follower: currentUserRecordName,
                        followee: targetUserRecordName
                    ),
                    followerUserRecordName: currentUserRecordName,
                    followeeUserRecordName: targetUserRecordName,
                    createdAt: .now
                )
                PublicSocialCacheStore.upsertFollow(dto, in: context)
                followStates[targetUserRecordName] = FollowToggleState.afterToggle(
                    from: .pending,
                    success: true
                )
            }
        } catch {
            followStates[targetUserRecordName] = wasFollowing ? .following : .notFollowing
            followErrors[targetUserRecordName] = socialErrorMessage(from: error)
        }
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
            for item in (try? context.fetch(FetchDescriptor<Follow>())) ?? [] { context.delete(item) }
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
