# ADR-003 — User preferences via UserDefaults

- **Status:** Accepted (MVP)
- **Date:** 2026-04-21

## Context
We need to persist lightweight preferences that change often and must not block
the UI — active modes (4 slots), active tab index, active city, appearance
override, metric units, recent searches.

## Decision
- Store preferences in **`UserDefaults`** behind `UserPreferencesService`, an
  `@Observable` facade.
- Arrays (`activeModes`, `recentSearches`) are JSON-encoded into `Data` for
  storage because `@AppStorage` does not support codable arrays.
- SwiftData is reserved for user-generated data (saved spots, collections);
  `UserDefaults` holds scalar settings only.

## Consequences
- Preference reads are synchronous and fast enough for view bodies.
- No migration layer needed for the MVP — fields are additive and defaulted.
- If preferences grow complex (profiles, multi-device sync), we revisit with a
  dedicated store (e.g. CloudKit key-value or a small SwiftData Settings model).
