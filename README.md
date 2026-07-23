# GetOut

GetOut helps you discover authentic, non-touristy local spots — hidden rooftops, quiet cafés, and neighborhood gems. Build a social profile, save spots you love, plan collaborative trips with friends, and filter by tags like weed-friendly, quiet, or views. Personalized recommendations surface the places locals actually go.

## Getting started

**Prerequisites**

- Xcode 15+ from the App Store
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

**Run the app**

```bash
xcodegen generate
open GetOut.xcodeproj
```

Open the project in Xcode and run on an iOS 17+ simulator.

## Stack

- **SwiftUI** — UI framework
- **SwiftData** — local persistence (coming in a later milestone)
- **CloudKit** — iCloud identity, private sync, and the public social feed
