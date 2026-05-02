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
