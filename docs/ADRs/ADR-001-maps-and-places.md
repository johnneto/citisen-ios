# ADR-001 — Maps & Places data source

- **Status:** Accepted (MVP)
- **Date:** 2026-04-21

## Context
Citisen is a map-first travel companion. The MVP needs to render pins and POI
details for Tallinn, Tartu, Helsinki and Riga without any paid data dependency.
The design and plan also keep the door open to a future curated or AI-ranked
places backend.

## Decision
- Use **Apple MapKit** for the map surface (iOS 17 `Map(position:)` + `Annotation`).
- Use a local **`MockPlacesService`** seeded from `MockSeed*.swift` as the data
  source for MVP. Places are filtered by mode and sub-filters at query time.
- Keep the `places` surface behind a thin, swappable service interface so
  Stage 5 can swap it for a Google Places / Overpass / curated backend without
  touching view code.

## Consequences
- Zero infra and zero API keys for MVP.
- Data volume is capped by the seed; good enough to demo every surface.
- Swapping to a real backend later requires introducing a protocol on top of
  `MockPlacesService` and wiring the new implementation via `.environment`.

## Update — 2026-05-16: Places API (New)

The Google Places integration now targets **Places API (New)** at
`places.googleapis.com/v1/...` instead of the legacy
`maps.googleapis.com/maps/api/place/...` endpoints. Three concrete changes:

- **One call per spot.** `RemotePlacesBackend.resolveOne()` previously made
  `findPlaceFromText` → `details` (two calls). The new Text Search endpoint
  returns full Place objects gated by a field mask, so the same data is fetched
  in a single `POST /v1/places:searchText` with `maxResultCount: 1`. Halves
  latency and billed SKUs on the spot-resolution hot path.
- **Auth & field mask via headers.** API key moves from the `?key=` query
  parameter to the `X-Goog-Api-Key` header. The required `X-Goog-FieldMask`
  header pins the response shape; `AppConfig.Endpoints.searchTextFieldMask`
  enumerates every field `PlaceMapper` consumes.
- **No more `status` envelope.** Errors surface as HTTP status codes; the
  existing `HTTPClient` mapping (401/403 → unauthorized, 429 → quota) covers
  them without special-casing.

The architectural decision is unchanged: Places resolution still sits behind
the `PlacesBackend` protocol and is toggled by `FeatureFlags.googlePlacesEnabled`,
which falls back to `MockPlacesBackend` if the new API misbehaves.
