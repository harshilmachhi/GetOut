# CloudKit Setup (Future)

CloudKit is designed into the SwiftData models but **not enabled** in the current build. Follow these steps when ready to turn on sync.

## 1. Apple Developer Portal

- Enable **iCloud** capability for App ID `com.getout.app`
- Create CloudKit container **`iCloud.com.getout.app`**
- Enable **Push Notifications** (development) if using remote notifications

## 2. Xcode / project.yml

Set your team in `project.yml`:

```yaml
settings:
  DEVELOPMENT_TEAM: YOUR_TEAM_ID
  CODE_SIGN_ENTITLEMENTS: GetOut/GetOut.entitlements
```

Add background mode for remote notifications to Info.plist keys in `project.yml`:

```yaml
INFOPLIST_KEY_UIBackgroundModes: remote-notification
```

The entitlements file already exists at `GetOut/GetOut.entitlements` with:

- `iCloud.com.getout.app` container
- CloudKit service
- `aps-environment: development`

## 3. App code

In `GetOutApp.swift`, set:

```swift
let useCloudKit = true
```

Uncomment the `ModelConfiguration` block that uses:

```swift
cloudKitDatabase: .private("iCloud.com.getout.app")
```

## 4. Verify

- Sign with a development provisioning profile that includes iCloud + CloudKit
- Run on device; confirm records appear in CloudKit Dashboard
- Test multi-device sync before shipping

Until these steps are complete, the app uses **local-only** SwiftData persistence.
