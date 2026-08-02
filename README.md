# Citisen

A map-first travel companion for iOS. Pick a city and a travel mode (food, nature,
history, …) and Citisen curates a short list of places worth your time, pins them on
the map, and lets you save the ones you like into collections.

- **Platform:** iOS 17.6+, SwiftUI, SwiftData
- **Language:** Swift 5
- **Bundle id:** `com.joaocaetano.Citisen`
- **Dependencies:** none — no SPM packages, no CocoaPods

## How it works

Curation runs in two stages behind a single `PlacesService`:

1. **Gemini** generates candidate place names for the active city + travel mode.
2. **Google Places API (New)** resolves each name into a full place — location,
   rating, opening hours, photos, reviews.

Results are cached on disk (30-day TTL) with a memory snapshot on top, so a
revisited city/mode combination costs nothing. Photos have their own cache with a
3-day TTL and disk/memory caps. Everything sits behind the `PlacesBackend` protocol,
so `FeatureFlags.googlePlacesEnabled` / `aiCurationEnabled` can drop the app back to
`MockPlacesBackend` (seeded data for Tallinn, Tartu, Helsinki, Riga) without touching
view code.

`GEMINI_PLACES_API_REPORT.md` has the deep dive on the pipeline, token usage and API
cost drivers.

## Project layout

```
Citisen/
├── App/              RootView
├── Config/           AppConfig (endpoints, tuning, feature flags), Secrets.xcconfig
├── Data/             SwiftData entities + schema, mock seeds
├── DesignSystem/     tokens, branding, shared components and modifiers
├── Features/         Map, Search, POISheet, Saved, Onboarding, Profile, …
├── Models/           domain types (Place, City, TravelMode, SubFilter, …)
├── Services/
│   ├── Networking/   GeminiClient, GooglePlacesClient, HTTPClient, photo cache
│   ├── Security/     Keychain + secret loading
│   └── Spots/        curation pipeline, mappers, cache, scoring
└── Views/
CitisenTests/         unit tests
CitisenUITests/       UI tests
docs/ADRs/            architecture decision records
fastlane/             TestFlight lane
```

Persistence splits three ways: **SwiftData** for user-generated data (saved spots,
collections), **UserDefaults** behind `UserPreferencesService` for scalar settings,
and a **file cache** for curated places and photos. See `docs/ADRs/` for the
reasoning.

## Getting started

### 1. Requirements

- Xcode 16+ with an iOS 17.6+ simulator
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`) — CI runs
  it in `--strict` mode, so warnings fail the build

### 2. API keys

Copy the example config and fill in your own keys:

```bash
cp Citisen/Config/Secrets.example.xcconfig Citisen/Config/Secrets.xcconfig
```

```
GEMINI_API_KEY = <your key>
GOOGLE_PLACES_API_KEY = <your key>
```

`Secrets.xcconfig` is gitignored — never commit real keys. The values flow
`xcconfig → Info.plist → Keychain` at first launch (`KeychainService.bootstrap`), so
they are not read from the bundle at runtime after that. Without keys the app still
runs; turn the feature flags off in `AppConfig.swift` to use the mock backend.

Both keys come from Google Cloud: enable the **Generative Language API** and
**Places API (New)**.

### 3. Build and run

Open `Citisen.xcodeproj` and run, or from the command line:

```bash
xcodebuild build -project Citisen.xcodeproj -scheme Citisen -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The project uses file-system-synchronized groups, so new `.swift` files are picked up
without editing `project.pbxproj`.

## Testing and linting

```bash
xcodebuild test -project Citisen.xcodeproj -scheme Citisen -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

```bash
swiftlint lint --strict
```

App logs go to the OSLog subsystem `app.citisen` (categories: `ai`, `places`, `app`,
`location`). To follow debug-level lines on a booted simulator:

```bash
xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "app.citisen"'
```

## Distribution

TestFlight uploads run through fastlane:

```bash
bundle exec fastlane beta
```

The lane bumps the build number from the latest TestFlight build, builds with
automatic signing and uploads. Set `APP_IDENTIFIER` / `APPLE_TEAM_ID` in
`fastlane/Fastfile` and `fastlane/Appfile`, and provide App Store Connect API key
credentials via environment variables (see the comments at the top of the `Fastfile`).

## Contributing

Full workflow in [CONTRIBUTING.md](CONTRIBUTING.md). The short version:

- Never commit directly to `develop` or `main`. Cut a branch off `develop` for every
  change and merge it back by PR.
- Branch names follow `feat/…`, `fix/…`, `refactor/…`, `chore/…`, `docs/…`.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(map): …`, `fix(spots): …`.
- Open PRs against `develop` (`gh pr create --base develop` — `gh` otherwise defaults
  to `main`) using the [pull request template](.github/pull_request_template.md).
  SwiftLint must pass in strict mode before merge.

```bash
git checkout develop && git pull --ff-only origin develop && git checkout -b feat/short-description
```
