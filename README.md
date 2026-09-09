# GetOut

GetOut helps you discover authentic, non-touristy local spots — hidden rooftops, quiet cafés, and neighborhood gems. Build a social profile, save spots you love, plan collaborative trips with friends, and filter by tags like weed-friendly, quiet, or views. Personalized recommendations surface the places locals actually go.

## Getting started

**Prerequisites**

- Node.js 22.13 or newer
- Android Studio for Android builds and Xcode for iOS builds
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) when applying local migrations

**Run the app**

```bash
npm install
npm start
```

Press `a` for Android or `i` for iOS in the Expo terminal. For native development builds:

```bash
npm run android
npm run ios
```

The checked-in `.env.example` documents the Supabase environment variables. The current publishable key remains available as an app-safe fallback; RLS remains the authorization boundary. Google OAuth must allow `getout://login-callback` in Supabase. Apple Sign In is shown on iOS, while Google OAuth works on both platforms.

Before running against a hosted project, apply the checked-in database migrations. See [`design/SUPABASE_SETUP.md`](design/SUPABASE_SETUP.md).

## Build and validation

```bash
npm run typecheck
npx expo-doctor
npx expo export --platform android
```

Preview APK and production builds are configured in `eas.json` (`eas build --platform android --profile preview`).

## Stack

- **Expo SDK 57 + React Native + TypeScript** — shared Android and iOS app
- **Expo Router** — tab, modal, and detail navigation
- **Supabase Auth, Postgres, Storage** — identity, durable app data, public discovery, and photos
- **Expo SQLite localStorage + AsyncStorage** — durable auth and offline public-feed cache
- **Expo Location, Image Picker, and React Native Maps** — cross-platform device integrations

The original SwiftUI source is intentionally retained under `GetOut/` as a visual and behavior reference during rollout. The Expo app is rooted at `app/`, with shared code in `src/`.
