# ADR-002 — Persistence with SwiftData

- **Status:** Accepted (MVP)
- **Date:** 2026-04-21

## Context
Saved spots (ratings) and collections must survive app launches and tolerate
schema evolution as we add more fields (notes, collection icons, covers).

## Decision
- Adopt **SwiftData** (`@Model`) for `SavedSpotEntity` and `CollectionEntity`.
- Inject a single `ModelContainer` at app root, seeded with a default
  "Tallinn Favourites" collection on first launch.
- Wrap mutations behind **`SavedSpotsService`** (MainActor) so views never
  touch `ModelContext` directly, which makes future schema migrations
  localised.

## Consequences
- No Core Data ceremony, type-safe queries via `#Predicate`.
- Requires iOS 17.6+ (already a plan constraint).
- Testing mutations requires an in-memory container — acceptable, handled in
  unit tests for `SavedSpotsService`.
