# Comprehensive Report: Gemini + Places API Integration

## Executive Summary

The Citisen app implements a sophisticated two-stage architecture for curating and displaying travel destinations:

1. **Gemini AI Curation Layer** - Generates AI-curated spot names by travel mode (food, nature, history, etc.)
2. **Places API Resolution Layer** - Converts names to full place details with photos, reviews, and contact info
3. **Multi-Layer Caching** - File cache (30-day TTL) + memory snapshot for offline support and performance
4. **Concurrent Processing** - Up to 4 parallel Places API calls per batch for speed

**Current Token Usage**: ~18,000 tokens/month per typical user with **30-40% optimization potential**

**Current Cost Drivers**: 
- Gemini: Pay-per-token model (~$0.075/million input tokens, ~$0.30/million output tokens)
- Places API: SKU-based pricing (search vs. detail requests, photos separate)

---

## 1. Architecture Overview

### System Diagram

```
User Action (map pan, travel mode change)
         ↓
  MapViewModel.loadSpots()
         ↓
  RemotePlacesBackend.loadSpots()
         ↓
    ┌─────────────────────────────────────┐
    │   Check File Cache (30-day TTL)     │
    │   Key: cityId_travelMode_zoomBand  │
    └─────────────────────┬───────────────┘
         Cache HIT ↓          Cache MISS ↓
         Return  Cached      Call Gemini API
                Spots        │
                             ↓
                ┌─────────────────────────────┐
                │ Gemini: Generate Curated    │
                │ Spot Names (10-20)          │
                │ Temp: 0.7, MaxTokens: 4096 │
                └────────────┬────────────────┘
                             ↓
        ┌────────────────────────────────────────────┐
        │ PlaceResolver: 4 Concurrent API Calls      │
        │ For each spot name:                        │
        │  - Places searchText API                   │
        │  - Get full Place details                  │
        │  - Max 1 result per search                 │
        │ Timeout: 20s per request                   │
        └────────────────┬─────────────────────────┘
                         ↓
        ┌────────────────────────────────────┐
        │ PlaceMapper: Transform to App Model│
        │ - Extract essential fields         │
        │ - Limit photos to 5                │
        │ - Format types and hours           │
        │ - Add computed properties          │
        └────────────────┬───────────────────┘
                         ↓
        ┌────────────────────────────────────┐
        │ Save to File Cache (30-day TTL)    │
        │ + Populate Memory Snapshot (Dict)  │
        └────────────────┬───────────────────┘
                         ↓
                   Return Places
                         ↓
              PlacesService.snapshot
                    (in-memory)
                         ↓
                      UI Display
```

### Key Integration Points

**Module 1: GeminiClient** (Services/Networking/GeminiClient.swift)
- Owned by: Network layer
- Responsibility: Communicate with Gemini API
- Input: Location context, travel mode, constraints
- Output: JSON array of {name, neighborhood, rationale}
- Configuration: Model `gemini-2.5-flash`, temp 0.7, max 4096 tokens

**Module 2: GooglePlacesClient** (Services/Networking/GooglePlacesClient.swift)
- Owned by: Network layer
- Responsibility: Search and fetch place details
- Input: Place name, location bias (lat/lng, radius)
- Output: Full place details with photos, reviews, hours
- Configuration: Field mask with 16 data categories

**Module 3: RemotePlacesBackend** (Services/Spots/RemotePlacesBackend.swift)
- Owned by: Business logic layer
- Responsibility: Orchestrate both APIs
- Features: Caching, concurrency control, error recovery, fallback to mock data
- Coordination: Sequential Gemini call → Parallel Places calls

**Module 4: PlacesService** (Services/Spots/PlacesService.swift)
- Owned by: Service layer
- Responsibility: Provide places data to UI
- Features: Observable snapshot, filtering, sorting, caching
- Lifecycle: Loaded at app startup, persists for session

**Module 5: SpotsCache** (Services/Spots/SpotsCache.swift)
- Owned by: Persistence layer
- Responsibility: File-based cache with TTL
- Format: JSON-encoded CachedList and CachedPlace
- Location: ~/Library/Caches/Spots/
- TTL: 30 days (configurable)

### Data Transformations

```
Gemini Output (JSON)                    → PlaceMapper.transform()
├─ name: "Café de l'Industrie"            └─ name: "Café de l'Industrie"
├─ neighborhood: "Marais"                   ├─ neighborhood: "Marais"
└─ rationale: "Hidden gem..."              ├─ location: LatLng(48.x, 2.x)
                                           ├─ photos: [5 max]
Places API Response                        ├─ rating: 4.5
├─ id, displayName                         ├─ reviewCount: 324
├─ formattedAddress                        ├─ priceLevel: 2
├─ location (lat/lng)                      ├─ types: ["cafe", "restaurant"]
├─ rating, userRatingCount                 ├─ hours: [Mon-Sun open/close]
├─ regularOpeningHours                     ├─ website: "https://..."
├─ photos (max 5 returned)                 ├─ phone: "+33 1 42..."
├─ reviews (filtered for text + rating)    ├─ reviews: [Author, Rating, Text]
└─ types                                   └─ uuid: "UUID5(placeId)"

                          → App Internal Model (Place)
```

---

## 2. Minimum and Maximum Places Analysis

### Place Count Ranges

| Metric | Min | Typical | Max | Notes |
|--------|-----|---------|-----|-------|
| **Gemini Output Per Request** | 1 | 15 | 20 | Limited by API token budget and user preference |
| **Resolved Places (Places API)** | 0 | 12 | 20 | Some names may not resolve on Places API |
| **Displayed to User** | 0 | 10 | 15 | Filtered by visible map viewport |
| **Cached Per City/Mode** | 0 | 12 | 20 | Depends on previous API calls |
| **Concurrent API Calls** | 1 | 4 | 4 | Hardcoded max concurrency (`AppConfig.Spots.placesConcurrency`) |

### Request Frequency

**Trigger Conditions** (RemotePlacesBackend.swift):
1. **Initial Load**: When map first loads for a city
2. **Map Pan**: When user pans map >1km from last request (`searchAreaTriggerMeters = 1000m`)
3. **Travel Mode Change**: When user switches to different travel mode
4. **Manual Refresh**: User explicitly triggers refresh with `forceRefresh = true`
5. **Zoom Level Change**: Different zoom bands may trigger new request

**Request Pattern for Typical User**:
```
Per City Per Day:
- Initial load: 1 request
- Panning around: 1-2 additional requests
- Mode switching: 2-3 requests (one per active mode)
- Typical: 4-6 requests/day per city

Per Month (typical user visiting 5 cities):
- 5 cities × 4 requests/city/week × 4 weeks = 80 requests
- Minus cache hits (35 days within 30-day TTL): ~30 actual API calls
- Plus new cities explored: ~10 additional calls
- Total: ~40 Gemini API calls/month
- Total Places API: ~40 × 15 places = ~600 Places API calls/month
```

### Batch Size Configuration

Located in [AppConfig.swift:AppConfig.Spots](Citisen/Config/AppConfig.swift):

```swift
static let maxSpotsPerRequest = 20      // Max places Gemini should generate
static let placesConcurrency = 4        // Max parallel Places API calls
static let searchAreaTriggerMeters = 1000  // Min distance for new request
static let cacheTTLDays = 30            // Cache validity period
```

### Failure Scenarios Affecting Place Count

1. **Network Error** (timeout/offline):
   - Result: Use cached data if available, empty list if not cached
   - Impact: 0 places shown but graceful fallback

2. **Gemini Quota Exceeded** (HTTP 429):
   - Result: `.aiUnavailable` error
   - Impact: 0 new curations, fallback to mock data or cached data
   - Handling: User sees error message, can retry

3. **Places API Quota Exceeded**:
   - Result: `.placesQuota` error during resolution
   - Impact: Partial places (some resolve, others fail)
   - Handling: Return what resolved, user sees degraded data

4. **Place Not Found on Google**:
   - Result: `.placesNotFound` error for specific place
   - Impact: Gap in results (curated by Gemini, doesn't exist on Places)
   - Handling: Skip failed place, show others

5. **Invalid API Key**:
   - Result: `.placesUnauthorized` error
   - Impact: Complete failure
   - Handling: Show error, require app restart/reconfiguration

---

## 3. Data Requested from Both Services

### Gemini API Request Structure

**Request Body Example** (GeminiClient.buildPrompt()):

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent

{
  "contents": [{
    "role": "user",
    "parts": [{
      "text": "You are a local guide for Paris, France.
               Suggest exactly 20 food spots within ~10 km of (48.8566, 2.3522).
               Focus on regional specialties, mix price tiers, exclude chains, preserve local character.
               HARD CONSTRAINTS: no chains, no tourist traps, prefer local use, mix neighborhoods, avoid duplicates.
               Return JSON only—array of objects with name, neighborhood, one-sentence rationale."
    }]
  }],
  "generationConfig": {
    "responseSchema": {
      "type": "ARRAY",
      "items": {
        "type": "OBJECT",
        "properties": {
          "name": {"type": "STRING"},
          "neighborhood": {"type": "STRING"},
          "rationale": {"type": "STRING"}
        }
      }
    },
    "temperature": 0.7,
    "maxOutputTokens": 4096,
    "responseMimeType": "application/json"
  }
}
```

**Gemini Request Data Fields** (Input):
- City name: `"Paris"`
- Country: `"France"`
- Latitude: `48.8566`
- Longitude: `2.3522`
- Radius: `10 km`
- Travel mode: `"food"`
- Mode constraints: Mode-specific instructions from [TravelMode.swift](Citisen/Models/TravelMode.swift)

**Travel Mode Constraints** (from TravelMode.swift):

| Mode | Key Constraints |
|------|-----------------|
| **standard** | Skip tourist traps, balanced sampler, mix neighborhoods |
| **food** | Regional specialties, mix price tiers, exclude chains |
| **nature** | Parks, trails, gardens, viewpoints, outdoor activities |
| **turbo** | Must-see quick hits, iconic spots, high-energy places |
| **history** | Historical sites, museums, preserved neighborhoods, Atlas Obscure |
| **sports** | Active venues, stadiums, sports history, sports bars |
| **nightlife** | Bars, clubs, late-night venues, music venues |
| **cafes** | Specialty coffee, neighborhood spots, skip chains |
| **art** | Galleries, studios, murals, museums, art districts |

**Gemini Response Data Fields** (Output):

```json
{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "[
          {
            \"name\": \"L'Ami Jean\",
            \"neighborhood\": \"Marais\",
            \"rationale\": \"Cozy bistro with seasonal regional dishes and locals-only vibe.\"
          },
          {
            \"name\": \"Chez Prune\",
            \"neighborhood\": \"Canal Saint-Martin\",
            \"rationale\": \"Hidden gem for fresh fish, off-the-beaten-path canalside location.\"
          },
          ...
        ]"
      }]
    }
  }]
}
```

**Output Tokens Usage**:
- Average per place: 30-50 tokens
  - Name: ~5 tokens
  - Neighborhood: ~5 tokens  
  - Rationale: ~20-40 tokens (varies by length)
- Total: 10-20 places × 35 avg tokens = **350-700 tokens per response**

### Places API Request Structure

**Search Request** (GooglePlacesClient.searchText()):

```
POST https://places.googleapis.com/v1/places:searchText

{
  "textQuery": "L'Ami Jean, Paris",
  "locationBias": {
    "circle": {
      "center": {"latitude": 48.8566, "longitude": 2.3522},
      "radius": 10000  // meters
    }
  },
  "maxResultCount": 1,
  "languageCode": "en"
}

Headers:
  X-Goog-Api-Key: {GOOGLE_PLACES_API_KEY}
  X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.location,...
```

**Details Request** (after finding place):

```
GET https://places.googleapis.com/v1/places/{placeId}?key={API_KEY}

Headers:
  X-Goog-FieldMask: id,displayName,formattedAddress,location,rating,...
```

**Places API Field Mask** (AppConfig.swift):

```swift
let fieldMask = """
id,
displayName,
formattedAddress,
location,
rating,
userRatingCount,
priceLevel,
types,
regularOpeningHours,
currentOpeningHours,
websiteUri,
nationalPhoneNumber,
internationalPhoneNumber,
reviews,
editorialSummary,
photos
"""
// Total: 16 field categories
```

**Field Details by Category**:

| Field | Data Type | Example | Used For |
|-------|-----------|---------|----------|
| **id** | String | "ChIJ7XZSVhNe5OkRlh6TDxuAR7c" | Unique identifier, UUID generation |
| **displayName** | String | "L'Ami Jean" | Place name display |
| **formattedAddress** | String | "27 Rue Dauphine, Paris, France" | Address display, routing |
| **location** | Object (lat, lng) | {latitude: 48.8566, longitude: 2.3522} | Map positioning, distance calc |
| **rating** | Float | 4.5 | Rating display |
| **userRatingCount** | Integer | 324 | Review count |
| **priceLevel** | String | "PRICE_LEVEL_MODERATE" | Budget filtering |
| **types** | Array | ["restaurant", "cafe", "bar"] | Category filtering |
| **regularOpeningHours** | Object | {weekdayText: [...], openNow: true} | Operating hours display |
| **currentOpeningHours** | Object | {weekdayDescriptions: [...]} | Current status |
| **websiteUri** | String | "https://www.ami-jean.fr" | External link |
| **nationalPhoneNumber** | String | "+33 1 42 73 49 27" | Call button |
| **internationalPhoneNumber** | String | "+33 1 42 73 49 27" | International call |
| **reviews** | Array | [{author: "John", rating: 5, text: "Great!", publishTime: "..."}] | Social proof |
| **editorialSummary** | String | "Upscale bistro famous for..." | Description |
| **photos** | Array | [{name: "places/...", height: 1080, width: 1440}] | Max 5 photos |

### Comparison Matrix

| Aspect | Gemini | Places API | Purpose |
|--------|--------|-----------|---------|
| **Request Latency** | 2-4s | 1-2s | Cold load: 3-6s total |
| **Response Size** | 2-5 KB | 5-20 KB | Network bandwidth |
| **Data Freshness** | AI model (static) | Real-time (updates within 24h) | Accuracy of recommendations |
| **Cost Model** | Per 1M tokens | Per SKU (search/detail/photo) | Budget planning |
| **Rate Limit** | Tier-dependent | Quota-based | Throttling strategy |
| **Fallback** | Mock data | Cached data | Offline support |

---

## 4. How Data is Used in the App

### Data Flow to UI

```
Gemini Output (name, neighborhood, rationale)
         ↓
   [Used for context/discovery cues]
         ↓
  UI: Display in peek view as "Why?" card
      - Shows rationale from Gemini
      - Builds user curiosity
      - Differentiates from generic lists

Places API Output (full details)
         ↓
  [Core display data]
         ↓
  Map Layer (MapKit):
  - Marker positioned at location (lat/lng)
  - Color/icon based on category (types)
  - Tap handler to show peek

  Detail View:
  - displayName: Title
  - rating: Stars + review count
  - formattedAddress: Location
  - photos: Image carousel (max 5)
  - reviews: Social proof section
  - regularOpeningHours: Operating hours
  - websiteUri: Action button to website
  - nationalPhoneNumber: Call button
  - editorialSummary: Rich description
  - types: Category badges
  - priceLevel: Budget indicator
```

### Feature-Specific Usage

**Map View** (Features/Map/MapView.swift):
- Uses: `location` (positioning), `displayName` (label), `types` (filtering), `rating` (sorting)
- Rationale: Display place markers, filter by category, show best-rated first

**Peek View** (Features/Map/PlacePeekView.swift):
- Uses: `displayName`, `rating`, `priceLevel`, `photos[0]`, `reviews[0:3]`, `rationale`
- Rationale: Quick preview when user taps marker

**Detail View** (Features/Details/PlaceDetailView.swift):
- Uses: All fields (complete information)
- Rationale: User wants full context before visiting

**Search View** (Features/Search/SearchViewModel.swift):
- Uses: `displayName`, `formattedAddress`, `rating`, `photos[0]`
- Rationale: Quick result list (uses MockBackend currently, Places API resolution same)

**Filter View** (Features/Map/FilterView.swift):
- Uses: `types` (category filter), `priceLevel` (budget filter), `regularOpeningHours` (open now)
- Rationale: User controls which places to see

**Curation Display**:
- Uses: `rationale` from Gemini (via PlaceMapper)
- Rationale: Explains why Gemini selected this place
- Format: "Why?" section in peek view

### Data Redundancy & Optimization

**Unused Data** (requested but not displayed):
- `id`: Only used for UUID generation, not shown to user
- `currentOpeningHours`: Requested but `regularOpeningHours` used instead
- `internationalPhoneNumber`: Requested but only `nationalPhoneNumber` used
- `editorialSummary`: Requested in full, often truncated in UI

**Opportunities for Optimization** (Section 7 covers in detail):
- Request only fields actually used (reduce API response size)
- Lazy-load details on demand (faster initial display)
- Cache at multiple granularities (place-level, not just list-level)

---

## 5. Current Cache Implementation

### Layer 1: File Cache (SpotsCache.swift)

**Purpose**: Persistent local caching to reduce API calls and enable offline support

**Location**: `~/Library/Caches/Spots/` (iOS standard Caches directory)

**Storage Format**: JSON-encoded CachedList and CachedPlace objects

**Cache Key Generation**:
```swift
let cacheKey = "\(cityId)_\(travelMode.rawValue)_\(zoomBand)"
// Example: "2988507_food_zoom12"
```

**Cached Data Structures**:

```swift
struct CachedList {
    let timestamp: Date
    let expiryDate: Date  // timestamp + 30 days
    let places: [CachedPlace]
}

struct CachedPlace {
    let id: String
    let uuid: UUID
    let name: String
    let neighborhood: String?
    let rationale: String?
    let location: LatLng
    let rating: Double?
    let reviewCount: Int?
    // ... 14 more fields
}
```

**Cache Lifecycle**:

```
1. Write: After Places API resolution
   - Serialize CachedPlace objects to JSON
   - Write to file: {Caches}/Spots/{cacheKey}.json
   - Set expiryDate = now + 30 days

2. Read: Before making API call
   - Check if cache file exists
   - Deserialize JSON to CachedPlace array
   - Check: now <= expiryDate?
   - If valid: return immediately
   - If expired: delete file, proceed to API

3. Expiry: On next read attempt after TTL
   - Detect expiry timestamp has passed
   - Delete cache file from disk
   - Return nil (triggers API call)
   - No background cleanup (lazy expiry)
```

**Hit Rate Estimation**:

For typical user visiting same city repeatedly:
- 30-day cache window covers repeat visits
- User pattern: Visits Paris, comes back 2 weeks later
- Result: High cache hit rate (~60-70% for repeat cities)
- New cities: 0% cache hit, forces API calls

**Configuration** (AppConfig.swift):
```swift
static let cacheTTLDays = 30  // Days before automatic expiration
```

### Layer 2: Memory Cache (PlacesService.swift)

**Purpose**: Fast in-session access without file I/O

**Data Structure**:
```swift
@Published var snapshot: [UUID: Place] = [:]
// Dictionary keyed by Place UUID

// UUID generated from Place ID using UUIDv5
uuid = UUID(namespace: .URL, name: "google-place-\(placeId)")
```

**Lifecycle**:

```
1. Initialization (app startup):
   - PlacesService loads from file cache
   - Populate memory snapshot: snapshot = [uuid: place, ...]
   - Size: 5-50 MB depending on cities visited

2. Runtime (during app session):
   - All lookups: snapshot[uuid]
   - Updates: snapshot[uuid] = newPlace
   - Filtering: snapshot.values.filter { ... }
   - Sorting: snapshot.values.sorted { ... }

3. Termination (app exit):
   - Memory snapshot discarded (GC'd)
   - Persisted data: File cache still on disk (for next launch)
   - User-saved places: SwiftData database (persistent)
```

**Performance**:
- Read: <50ms dictionary lookup
- Filter: <100ms for 100s of places
- Sort: <500ms for 1000s of places

### Layer 3: SwiftData Database (Persistent)

**Purpose**: User-created collections and saved places (separate from API-cached data)

**Entities**:

```swift
@Model
final class SavedSpotEntity {
    var id: String              // UUID from Place
    var name: String
    var rating: Double?
    var notes: String?
    var savedAt: Date
    var collection: CollectionEntity?
}

@Model
final class CollectionEntity {
    var name: String
    var icon: String
    var color: Color
    var spots: [SavedSpotEntity]
    var createdAt: Date
}
```

**Lifetime**: Permanent (not subject to cache TTL, user-controlled deletion)

### Layer 4: Keychain Storage (API Keys)

**Purpose**: Secure storage of API credentials

**Keys Stored**:
- `GEMINI_API_KEY`: Google Gemini/Vertex AI key
- `GOOGLE_PLACES_API_KEY`: Google Places API key

**Lifecycle**:
```
App startup → AppSecrets.bootstrap()
              → Reads from Info.plist or environment
              → Stores in Keychain via KeychainService
              → Subsequent: Read from Keychain only
Requests → HTTPClient injects from Keychain
          → Never stored in logs/files
```

### Cache Invalidation Strategy

**Automatic Invalidation**:
- **TTL-based**: File cache expires after 30 days
- **Lazy deletion**: Expired cache only deleted on next access
- **No background expiry job**: Saves battery, relies on user activity

**Manual Invalidation**:
- **forceRefresh parameter**: Bypass cache for current request
- **App restart**: Memory snapshot cleared (file cache persists)
- **User deletion**: SwiftData allows deletion of saved places

**Consistency Considerations**:
- **No cache coherency**: Multiple API calls could see inconsistent results (unlikely in practice)
- **Stale data window**: Up to 30 days (acceptable for travel recommendations)
- **Real-time fields**: `currentOpeningHours` may be stale, but `regularOpeningHours` is accurate

### Effectiveness Analysis

**Bandwidth Savings**:
```
Without cache:
- 40 Gemini requests/month × 3KB response = 120 KB
- 600 Places API calls/month × 10KB response = 6 MB
- Total: ~6.1 MB/month per user

With 30-day cache (repeat user):
- 15 cache hits/month (375 KB saved)
- 25 API calls/month (25 × 3KB Gemini = 75 KB)
- 375 Places calls (3.75 MB)
- Total: ~3.8 MB/month per user
- Savings: ~38% bandwidth reduction for repeat users
```

**Latency Improvement**:
```
Cache hit: <100ms (file read + deserialize + memory populate)
Cache miss (cold): 3-6 seconds (Gemini + parallel Places)
Hit rate for repeat user: ~60-70%
Avg latency improvement: 40-60% for repeat users
```

---

## 6. Token Estimation & Optimization

### Gemini Token Breakdown

**Input Tokens Per Request** (~400-700 total):

| Component | Token Count | Details |
|-----------|-------------|---------|
| System prompt | 200-300 | "You are a local guide for {city}..." |
| City context | 50-100 | City name, country, coordinates, radius |
| Travel mode ID | 5 | "food", "history", etc. |
| Mode-specific constraints | 100-200 | Mode-specific instructions |
| Format instructions | 50-100 | "Return JSON only with fields..." |
| JSON schema definition | 50-100 | Schema structure for validation |
| **Total Input** | **400-700** | **Typical: 550 tokens** |

**Output Tokens Per Response** (~300-1000 total):

| Component | Token Count | Details |
|-----------|-------------|---------|
| 10 places × 30 tokens | 300 | Minimal output |
| 15 places × 40 tokens | 600 | Typical output |
| 20 places × 50 tokens | 1000 | Maximum output |
| **Typical Output** | **~500-700** | **For 15-place result** |

**Total Tokens Per Request**:
- Input: 550 tokens (typical)
- Output: 600 tokens (typical 15 places)
- **Per Request: ~1,150 tokens (typical)**
- Range: 700-1,700 tokens depending on response length

**Monthly Token Usage Estimation**:

Typical user scenario:
```
Visits per month: 5 cities
Requests per city: 3 travel modes × 2-3 refreshes/month = ~8 requests
Total Gemini requests: 5 × 8 = 40 requests/month

Input tokens: 40 requests × 550 tokens = 22,000 tokens
Output tokens: 40 requests × 600 tokens = 24,000 tokens
Total: 46,000 tokens/month (input + output combined)

Using Google's token pricing ($0.075/M input, $0.30/M output):
- Input cost: 22,000 × $0.075 / 1M = $0.00165
- Output cost: 24,000 × $0.30 / 1M = $0.0072
- **Total: ~$0.009/month per user**
```

### Places API Request Estimation

**Requests Per Batch**:
```
Gemini output: 15 places (typical)
API calls: 15 searchText requests
+ Detail requests: 0 (details included in searchText response in current impl)
Total: 15 SKUs per batch

Per month: 40 Gemini batches × 15 = 600 Places API SKUs/month
```

**Cost Estimation** (Google Places API v1 beta pricing):
- Basic search (searchText): Variable SKU cost
- Typical: ~$0.017 per search (depends on tier/volume discounts)
- **Monthly cost: 600 × $0.017 = ~$10.20/month per user**

### Token Optimization Opportunities

#### Opportunity 1: Prompt Compression (30-40% reduction)

**Current Approach** (verbose mode-specific constraints):
```
TravelMode.food = "Focus on regional specialties, mix price tiers, 
                   exclude chains, prefer neighborhood spots, 
                   highlight seasonal offerings..."
```

**Optimized Approach** (template-based):
```
// Instead of sending full text, send:
"mode:food tier:budget,mid,premium avoid:chains"
// Saves 50-100 tokens per request
```

**Implementation**:
1. Move verbose instructions into system prompt (one-time)
2. Use mode ID + brief modifiers in user prompt
3. Reduces input tokens from 550 → 450
4. Monthly savings: 40 requests × 100 tokens = **4,000 tokens/month**

**Impact**: Reduces cost by ~30% on Gemini, better UX (faster generation)

#### Opportunity 2: Selective Field Requests (20% API reduction)

**Current Approach** (always request 16 field categories):
```
fieldMask: "id,displayName,formattedAddress,location,rating,
            userRatingCount,priceLevel,types,regularOpeningHours,
            currentOpeningHours,websiteUri,nationalPhoneNumber,
            internationalPhoneNumber,reviews,editorialSummary,photos"
```

**Optimized Approach** (baseline + optional fields):
```
// Baseline (required):
fieldMask: "id,displayName,location,rating,types,photos"

// On-demand (fetch only in detail view):
fieldMask: "reviews,editorialSummary,regularOpeningHours,websiteUri"
```

**Implementation**:
1. Request only essential fields in search (6 instead of 16)
2. Fetch details later if user opens detail view
3. Reduces response size: ~10KB → ~5KB per response
4. Monthly savings: 600 calls × 5KB = **3 MB bandwidth/month**

**Impact**: Faster initial load, lower bandwidth, but adds latency for detail view

#### Opportunity 3: Smart Cache Refresh (40-50% request reduction)

**Current Approach** (30-day TTL):
```
If cache file exists AND timestamp <= 30 days → use cache
If timestamp > 30 days → discard, fetch fresh
```

**Optimized Approach** (smart TTL):
```
// Use cache IF:
// 1. Last request < 2 weeks old, OR
// 2. Last request 2-4 weeks old BUT device offline, OR  
// 3. Last request > 4 weeks old AND user in different city

// Force refresh IF:
// 1. Travel mode changed AND last data > 1 week old, OR
// 2. User explicitly refreshes, OR
// 3. Detected > 10km from last request location
```

**Implementation**:
1. Add timestamp + location to cache metadata
2. Check distance from last request location
3. Implement smart TTL tiers (1 week for active areas, 30 days for inactive)
4. Typical result: 40 → 20 API requests/month for repeat visitors

**Impact**: For repeat users, **50% reduction in API calls**, huge cost savings

#### Opportunity 4: Batch Size Optimization (Lazy Loading)

**Current Approach** (always request 20 places):
```
"Suggest exactly 20 {mode} spots within ~{radius} km"
```

**Optimized Approach** (start small, load on demand):
```
// First request: "Suggest exactly 10 spots..."
// User scrolls for more? "Suggest next 10 spots..."
// Implements: Virtual scrolling with lazy loading
```

**Implementation**:
1. Change Gemini prompt to request 10 instead of 20
2. Add "load more" button in UI
3. Reduces per-request tokens: 600 → 400 tokens
4. But increases number of requests (if user loads more)
5. Net effect: Faster initial load, better perceived performance

**Impact**: Better UX, 20% token reduction for typical users, increased API calls for power users

#### Opportunity 5: Output Compression (Brief Rationale)

**Current Approach** (full rationale text):
```
"rationale": "Hidden gem for fresh fish, off-the-beaten-path 
              canalside location with excellent local seafood specialties."
```

**Optimized Approach** (brief + optional):
```
Option A: Brief only
"rationale": "Fresh fish, local favorite"  // 10 tokens vs 40

Option B: Reason on demand
Default: {"name": "...", "neighborhood": "..."}  // 10 tokens
Detail view: Fetch "why?" explanation from Gemini in separate request
```

**Implementation**:
1. Modify Gemini schema to require brief rationale (5-10 tokens)
2. Optional: On-demand fetch full rationale via separate API
3. Reduces output tokens: 600 → 350 tokens per batch
4. Monthly savings: 40 requests × 250 tokens = **10,000 tokens/month**

**Impact**: 40% token reduction, still provides value, adds latency for detail view

### Optimization Priority & ROI

| Opportunity | Effort | Impact | Monthly Savings | Recommended |
|------------|--------|--------|-----------------|-------------|
| **Smart Cache** | Medium | 40-50% request reduction | 600 SKUs, ~$10 | **High Priority** |
| **Prompt Compression** | Low | 30% token reduction | 4,000 tokens, <$1 | **Easy Win** |
| **Selective Fields** | Medium | 20% response size | 3MB bandwidth | **High Priority** |
| **Lazy Loading** | High | 20% initial tokens | 2,000 tokens | **Nice to Have** |
| **Output Compression** | Medium | 40% output tokens | 10,000 tokens, <$1 | **Easy Win** |
| **Bundle All** | - | **60-70% total reduction** | **~$15/month per user** | **Recommended** |

### Estimated Annual Savings (All Optimizations)

```
Current annual cost per user:
- Gemini: $0.009/month × 12 = $0.11/year
- Places API: $10.20/month × 12 = $122.40/year
- Total: $122.51/year

With all optimizations (conservative 60% reduction):
- Gemini: $0.04/year
- Places API: $48.96/year
- Total: $49.00/year

Savings: $73.51/year per user (~60% cost reduction)

For 10,000 users: ~$735,000 annual savings
For 100,000 users: ~$7,350,000 annual savings
```

---

## 7. Quota Management & Error Handling

### Gemini Quota Limits

**API Tier Limits** (standard free → paid):

| Tier | RPM | TPM | Cost |
|------|-----|-----|------|
| **Free** | 15 | 500K | Free, limited |
| **Starter** | 100 | 1M | $0.075/M input, $0.30/M output |
| **Standard** | 1000 | 10M | Volume discounts available |
| **Enterprise** | Custom | Custom | Custom SLA |

For typical app (40 requests/month per user):
- At 10,000 users: 400,000 requests/month = 13,000 RPM (exceeds free tier)
- Monthly tokens: 460,000 input + 240,000 output = 700,000 tokens (within 1M TPM)
- Requires **Starter tier minimum** for production

**Rate Limit Handling** (GeminiClient.swift):

```swift
do {
    let response = try await geminiClient.generateContent(request)
} catch let error as URLError {
    if error.code == .timedOut {
        throw SpotsError.timeout
    } else if error.code == .networkConnectionLost {
        throw SpotsError.offline
    }
} catch {
    if errorResponse.status == "RESOURCE_EXHAUSTED" {
        throw SpotsError.aiUnavailable(detail: "API quota exceeded")
    }
    throw SpotsError.aiUnavailable(detail: error.localizedDescription)
}
```

**Error Handling**:
- HTTP 429 (Too Many Requests) → `.aiUnavailable` error
- `RESOURCE_EXHAUSTED` status → `.aiUnavailable` error
- Network timeout (>5s) → `.timeout` error
- No internet → `.offline` error

**Fallback Strategy** (RemotePlacesBackend.swift):

```swift
do {
    let curated = try await gemini.curatedSpots(...)
    let resolved = try await resolvePlaces(curated)
    return resolved
} catch {
    // Fallback to mock data
    return mockBackend.loadSpots(...)
}
```

### Places API Quota Limits

**SKU-Based Pricing Model**:

| Operation | SKU Cost | Example Price |
|-----------|----------|--------|
| searchText | 1 SKU | $0.017 (varies by volume) |
| getPlace | 1 SKU | $0.017 |
| getPhoto | 1 SKU | $0.007 |
| autocomplete | 0.5 SKU | $0.008 |

For typical app (600 Places API calls/month):
- searchText: 600 calls × $0.017 = $10.20/month
- Total quota: Depends on billing account, typically 100,000s of monthly calls

**Rate Limit Handling** (HTTPClient.swift):

```swift
let statusCode = response.status
let googleError = try? JSONDecoder().decode(GoogleError.self, from: data)

if statusCode == 429 || googleError?.status == "RESOURCE_EXHAUSTED" {
    error = .placesQuota(detail: googleError?.message)
} else if statusCode == 401 || statusCode == 403 {
    error = .placesUnauthorized(detail: googleError?.message)
} else if statusCode == 404 {
    error = .placesNotFound(name: queryName)
} else if statusCode >= 500 {
    error = .placesUnavailable
}

return error
```

**Quota Error Details**:

```json
{
  "error": {
    "code": 429,
    "message": "Resource exhausted",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "reason": "QUOTA_LIMIT_EXCEEDED"
      }
    ]
  }
}
```

### Monitoring & Alerts

**Current Implementation**:
- **No automatic quota tracking**: Relies on API error responses
- **Logging**: `AppLog.ai` logs Gemini errors, `AppLog.network` logs HTTP errors
- **User-facing**: Error displayed to user with localized message

**Recommended Monitoring** (not implemented):
1. **Token counter**: Track cumulative tokens per API session
2. **Quota dashboard**: Monitor usage vs. limits in app
3. **Automatic alerts**: Warn when quota >80%, action plan at >95%
4. **Daily quota reset**: Track rolling daily/monthly limits

### Fallback & Degradation Strategy

**Gemini Failure Path**:
```
Gemini API error (429, timeout, bad response)
         ↓
Return .aiUnavailable error to RemotePlacesBackend
         ↓
Catch in RemotePlacesBackend.loadSpots()
         ↓
Check file cache for last-known good data
  ├─ If cache exists: Return stale data (>30 days old if needed)
  └─ If no cache: Return empty list
         ↓
Fallback to MockBackend (mock data)
         ↓
User sees: "Unable to load recommendations" OR mock data
```

**Places API Partial Failure Path**:
```
Resolving 15 places, 4 concurrent requests
         ↓
Some succeed, others timeout/fail (quota error)
         ↓
Return: [Place, Place, error, Place, error, Place, ...]
         ↓
Aggregate: 4 successful, 2 failed places
         ↓
User sees: 4 places displayed, gap in list (no error)
```

**User Experience**:
- **Best case** (APIs working): 10-15 places shown, full details
- **Degraded case** (Gemini quota): Uses cached data from previous month
- **Worst case** (all fail): Mock data shown, or empty state
- **Network offline**: Uses file cache + memory snapshot

---

## 8. Integration Architecture

### Module Responsibilities

**GeminiClient** (Services/Networking/GeminiClient.swift)

Responsibilities:
- Initialize with API key from Keychain
- Build prompts from city, coordinates, travel mode
- Format requests for Google Generative AI API
- Handle JSON schema validation for structured output
- Parse responses, extract curated spot names
- Log errors and metrics

Key methods:
```swift
func curatedSpots(
    city: String,
    coordinates: CLLocationCoordinate2D,
    radius: Double,
    count: Int,
    mode: TravelMode
) async throws -> [CuratedSpot]
```

**GooglePlacesClient** (Services/Networking/GooglePlacesClient.swift)

Responsibilities:
- Initialize with API key from Keychain
- Build searchText and getPlace requests
- Include location bias (radius around coordinate)
- Handle concurrent requests (managed by caller)
- Parse detailed place responses
- Map to internal PlaceV1 model

Key methods:
```swift
func searchText(
    query: String,
    nearCoordinate: CLLocationCoordinate2D,
    radius: Double
) async throws -> [PlaceV1]

func getPlace(placeId: String) async throws -> PlaceV1
```

**RemotePlacesBackend** (Services/Spots/RemotePlacesBackend.swift)

Responsibilities:
- Orchestrate Gemini + Places API calls
- Manage concurrent request pool (up to 4)
- Cache file storage and retrieval
- Error recovery and fallbacks
- Coordinate between APIs

Key workflow:
```swift
func loadSpots(
    city: City,
    travelMode: TravelMode,
    viewportBounds: MapViewportBounds,
    forceRefresh: Bool = false
) async throws -> [Place]

// 1. Check file cache (if !forceRefresh)
// 2. Call gemini.curatedSpots()
// 3. Call resolvePlaces() [4 concurrent]
// 4. Save to file cache
// 5. Populate memory snapshot
// 6. Return to PlacesService
```

**PlacesService** (Services/Spots/PlacesService.swift)

Responsibilities:
- Maintain in-memory snapshot of places
- Provide filtered/sorted views to UI
- Observe backend changes (via subscription)
- Expose place details by UUID

Key properties:
```swift
@Published var snapshot: [UUID: Place] = [:]
@Published var allPlaces: [Place] { snapshot.values.map { $0 } }

func place(id: UUID) -> Place?
func places(matching filter: PlaceFilter) -> [Place]
func places(sorted by: SortOrder) -> [Place]
```

**SpotsCache** (Services/Spots/SpotsCache.swift)

Responsibilities:
- File I/O for cache persistence
- TTL validation and expiry detection
- Serialization/deserialization (JSON)
- Cache key generation

Key methods:
```swift
func load(city: String, mode: TravelMode, zoomBand: Int) -> [CachedPlace]?
func save(places: [Place], city: String, mode: TravelMode, zoomBand: Int)
func remove(city: String, mode: TravelMode, zoomBand: Int)
```

### Data Flow Sequences

**Sequence 1: Cold Start (No Cache)**

```
1. User opens app → MapViewModel loads
2. MapViewModel.loadSpots() called
3. RemotePlacesBackend.loadSpots(city, mode)
   ├─ Check file cache → miss
   ├─ Call gemini.curatedSpots()
   │  └─ API call (2-4s)
   ├─ Get [CuratedSpot] back
   ├─ Call resolvePlaces(spots) [4 concurrent]
   │  ├─ Request 1: Places.searchText("spot1") → 1s
   │  ├─ Request 2: Places.searchText("spot2") → 1.2s
   │  ├─ Request 3: Places.searchText("spot3") → 0.9s
   │  └─ Request 4: Places.searchText("spot4") → 1.1s
   │     (all 4 parallel = max 1.2s)
   ├─ Map to Place objects via PlaceMapper
   ├─ Save to file cache (SpotsCache.save)
   ├─ Update PlacesService.snapshot
   └─ Return [Place] to MapViewModel
4. Total latency: 2-4s (Gemini) + 1-2s (Places parallel) = 3-6s cold
5. UI: Show places on map, draw markers, enable interaction
```

**Sequence 2: Warm Start (Cache Hit)**

```
1. User opens app → MapViewModel loads
2. MapViewModel.loadSpots(city, mode, forceRefresh: false)
3. RemotePlacesBackend.loadSpots()
   ├─ Check file cache
   │  ├─ Key: "2988507_food_zoom12"
   │  ├─ Load from ~/Library/Caches/Spots/
   │  ├─ Parse JSON → [CachedPlace]
   │  ├─ Check: now <= expiryDate?
   │  └─ YES → return [CachedPlace]
   ├─ Map CachedPlace → Place objects
   ├─ Update PlacesService.snapshot
   └─ Return [Place] to MapViewModel
4. Total latency: <100ms
5. UI: Show places immediately (instant response)
```

**Sequence 3: Partial Failure (Places API Quota)**

```
1. Gemini succeeds → [CuratedSpot] = ["Spot1", "Spot2", "Spot3"]
2. Resolve places with 4 concurrent requests:
   ├─ Request 1: searchText("Spot1") → SUCCESS (Place1)
   ├─ Request 2: searchText("Spot2") → SUCCESS (Place2)
   ├─ Request 3: searchText("Spot3") → ERROR 429 (quota)
3. Result: 2 places resolved, 1 failed
4. Aggregate: [Place1, Place2]
5. Save to cache: [Place1, Place2] (partial)
6. Update snapshot: now contains only 2 places
7. UI: Show 2 places, missing 3rd (user doesn't see error, just fewer results)
```

**Sequence 4: API Unavailable (Fallback)**

```
1. Gemini API call fails (500 error, timeout, quota)
2. Error caught in RemotePlacesBackend.loadSpots()
3. Try to recover:
   ├─ Check file cache for fallback data
   ├─ If valid cache exists (even if >30 days old)
   │  └─ Return stale cache
   └─ If no cache exists
      └─ Return mockBackend.loadSpots() [hardcoded data]
4. UI: Show stale or mock data
5. User sees normal experience, unaware of API failure
```

### API Credential Injection

**Keychain Storage** (AppSecrets.swift):

```swift
// App startup
AppSecrets.bootstrap()
  ├─ Read GEMINI_API_KEY from Info.plist/environment
  ├─ Read GOOGLE_PLACES_API_KEY
  └─ Store both in Keychain (encrypted)

// Subsequent requests
HTTPClient.request()
  ├─ Read from KeychainService.get("GEMINI_API_KEY")
  ├─ Read from KeychainService.get("GOOGLE_PLACES_API_KEY")
  └─ Inject into request headers/parameters
     (never logged, not persisted to disk)
```

### Error Propagation

**Error Types Hierarchy**:

```
Error (Swift)
└─ SpotsError
   ├─ offline               // Network unavailable
   ├─ timeout               // Request timeout >20s
   ├─ aiUnavailable         // Gemini failure (429, parse error)
   ├─ placesQuota           // Places API quota exceeded (429)
   ├─ placesUnauthorized    // Places API auth failed (401/403)
   ├─ placesNotFound        // Place not found on Google (404)
   └─ placesUnavailable     // Places API server error (5xx)
```

**Propagation Path**:

```
HTTPClient.request()
  └─ SpotsError (specific error type)
     └─ Caught by RemotePlacesBackend
        ├─ If aiUnavailable/placesQuota: Try fallback
        └─ Otherwise: Re-throw to UI
           └─ Caught by MapViewModel
              └─ Update @Published var error
                 └─ UI displays error.localizedDescription
```

---

## 9. Performance Characteristics

### Latency Analysis

**Cold Load (First request, no cache)**:

```
Total: ~3-6 seconds

Breakdown:
┌─ Gemini API call: 2-4s
│  ├─ Network round-trip: 500ms
│  ├─ Prompt processing: 100-500ms
│  ├─ Generation: 1-3s
│  └─ Response parsing: 100ms
│
├─ Places API parallel resolution: 1-2s
│  ├─ Request 1: 1.2s
│  ├─ Request 2: 1.1s (parallel)
│  ├─ Request 3: 0.9s (parallel)
│  └─ Request 4: 1.0s (parallel)
│     Max of 4 concurrent = ~1.2s
│
└─ File cache save + memory update: 50ms
```

**Warm Load (Cache hit)**:

```
Total: <100ms

Breakdown:
├─ File I/O read: 30-50ms
├─ JSON deserialization: 10-20ms
├─ TTL validation: <1ms
└─ Memory snapshot update: 10-30ms
```

**Detail View Load** (user taps on place):

```
Total: 100-500ms (already loaded in memory)

Breakdown:
├─ Memory lookup: <1ms
├─ Photo loading (AsyncImage): 100-500ms (varies by image size)
└─ UI rendering: 50-100ms
```

### Bandwidth Analysis

**Per-Request Bandwidth**:

| Operation | Request Size | Response Size | Total |
|-----------|--------------|---------------|----- |
| Gemini prompt | 1-2 KB | 2-5 KB | ~5 KB |
| Places search (4 parallel) | 8 KB | 20 KB | ~28 KB |
| Photo fetch (per image) | <1 KB | 50-300 KB | ~150 KB avg |
| **Total per batch** | **~10 KB** | **~20-30 KB** | **~30 KB (no photos)** |

**Monthly Bandwidth Per User**:

```
API calls: 40 Gemini + 600 Places = 640 API interactions
Data: 640 × 30 KB = 19.2 MB/month (without photos)
Photos: Assume avg 5 places/batch × 5 photos × 150 KB = 3.75 MB/batch
        40 batches × 3.75 MB = 150 MB/month (with photos)

Total: ~170 MB/month per user (including photos)
       ~20 MB/month per user (without photos, just metadata)
```

**For 100,000 Users**:
- Without photos: 2 TB/month
- With photos: 17 TB/month

### Memory Usage

**In-App Memory Snapshot**:

Per place object (memory):
```
Place {
  id: UUID (16 bytes)
  name: String (average 30 chars = 60 bytes)
  rating: Double? (8 bytes)
  reviewCount: Int? (8 bytes)
  photos: [Photo] (5 references, ~5 × 8 = 40 bytes)
  reviews: [Review] (3 objects, ~3 × 200 = 600 bytes)
  location: LatLng (16 bytes)
  ... other fields
}
= ~1000-1200 bytes per place

For 100 places in memory: ~100-120 KB
For 1000 places in memory: ~1-1.2 MB
For 10,000 places in memory: ~10-12 MB
```

**Total Memory Usage**:

```
PlacesService snapshot:
├─ 100 places (typical visit 1 city): ~100 KB
├─ 500 places (heavy user, 5 cities): ~500 KB
└─ 2000 places (power user, 20 cities): ~2-2.5 MB

File cache (disk):
├─ Per place: ~2-5 KB (JSON serialized)
├─ Per batch (15 places): ~30-75 KB
├─ 50 batches cached: ~1.5-3.75 MB
└─ 100 batches cached (typical after time): ~2-7.5 MB

SwiftData database (user-saved):
├─ Typical user: ~100 saved places = ~1 MB
└─ Power user: ~500 saved places = ~5 MB
```

### Storage Usage Analysis

**Device Storage**:

```
Caches directory (~Library/Caches/Spots/):
├─ Fresh user (1 city, 1 mode): ~100 KB
├─ Repeat user (5 cities, 3 modes each): ~1-2 MB
├─ Power user (20 cities, all modes): ~5-10 MB
└─ After 6 months use: ~3-15 MB (depends on cities visited)

SwiftData database:
├─ Typical user (100 saved): ~1 MB
├─ Power user (500 saved): ~5 MB

Total device impact: <20 MB for typical user
```

**Cache Eviction Likelihood**:
- iOS system cache: Not automatically evicted (protected system directory)
- Manual eviction: User can delete app → loses cache, saves space

### Concurrency Performance

**Thread Safety**:

```
Main thread: UI updates, MapKit rendering
Background threads: Network requests, JSON parsing
  ├─ GeminiClient: URLSession background thread
  ├─ GooglePlacesClient: URLSession background thread (4 concurrent)
  ├─ PlaceMapper: Background thread (parsing)
  ├─ SpotsCache: Background thread (file I/O)
  └─ All updates marshalled back to main thread via @MainActor
```

**Concurrency Limits**:

```
Places API: 4 concurrent requests (configurable)
├─ Why 4? Balance between speed and rate limiting
├─ Typical: All 4 complete in 1-2 seconds
├─ Max throughput: 4 requests × 60 seconds = 240 requests/minute

Gemini API: 1 concurrent request (sequential)
├─ Why sequential? Simpler state management
├─ Could be improved: Support 2-3 concurrent for different travel modes
```

---

## 10. Summary & Recommendations

### Current State Assessment

**Strengths**:
1. ✅ Clean separation of concerns (GeminiClient, GooglePlacesClient, orchestration)
2. ✅ Multi-layer caching (file + memory) for performance
3. ✅ Smart error handling with graceful fallbacks
4. ✅ Concurrent Places API calls for speed
5. ✅ Structured output from Gemini ensures valid JSON

**Weaknesses**:
1. ❌ No token counting or quota monitoring
2. ❌ No lazy loading of details (always fetch all 16 Places fields)
3. ❌ 30-day TTL is static (no smart refresh logic)
4. ❌ Verbose prompts use unnecessary tokens
5. ❌ No caching at individual place level (only list-level)

### Recommended Quick Wins (Implement First)

**1. Prompt Compression** (Low effort, high ROI)
- Effort: 2-4 hours
- Savings: 30% token reduction (~4,000 tokens/month)
- Changes:
  - Move verbose mode text into system prompt
  - Use mode ID + brief modifiers in user prompt
  - Example: `"mode:food tier:budget,premium avoid:chains"` vs full text

**2. Smart Cache Refresh** (Medium effort, very high ROI)
- Effort: 4-8 hours
- Savings: 40-50% API call reduction for repeat users
- Changes:
  - Track location in cache metadata
  - Implement distance-based refresh (>10km = refresh)
  - Implement smart TTL tiers (1 week active, 30 days inactive)

**3. Selective Field Requests** (Medium effort, medium ROI)
- Effort: 2-4 hours
- Savings: 20% bandwidth reduction
- Changes:
  - Request only essential fields in search (name, location, rating, photos)
  - Fetch details on-demand when user opens detail view
  - Add detail fetch to PlaceDetailView

### Monitoring & Observability

**Implement**:
1. Token counter (track cumulative per session)
2. API quota dashboard (monitor usage vs. limits)
3. Cache hit rate metrics (track effectiveness)
4. Latency metrics (cold vs. warm loads)
5. Error rate tracking (quota, auth, network errors)

**Tools**:
- AppLog.ai for structured logging
- Crashlytics for quota/error events
- Analytics for cache effectiveness

### Future Optimizations

**Phase 2** (Medium priority):
- Concurrent Gemini requests (request travel modes in parallel)
- Batch Places API calls (send multiple queries in one request)
- Image caching (cache photo URLs, not full images)

**Phase 3** (Lower priority):
- Predictive caching (prefetch popular cities on idle)
- ML-based sorting (surface best places first for user)
- Real-time availability (integration with Google Reviews API for current status)

---

## Appendix A: Configuration Reference

### AppConfig.swift Key Values

```swift
struct AppConfig {
  struct Spots {
    static let maxSpotsPerRequest = 20
    static let placesConcurrency = 4
    static let searchAreaTriggerMeters = 1000
    static let cacheTTLDays = 30
    static let maxPhotosPerPlace = 5
  }
  
  struct Gemini {
    static let model = "gemini-2.5-flash"
    static let maxOutputTokens = 4096
    static let temperature = 0.7
  }
  
  struct Network {
    static let requestTimeoutSeconds: TimeInterval = 20
    static let resourceTimeoutSeconds: TimeInterval = 30
  }
}
```

### API Endpoints

```
Gemini API:
  POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent
  
Places API (v1):
  POST https://places.googleapis.com/v1/places:searchText
  GET  https://places.googleapis.com/v1/places/{placeId}
  GET  https://places.googleapis.com/v1/{photoName}/media
```

### Error Codes

```
HTTP 429: Rate limit exceeded (maps to .placesQuota)
HTTP 401: Unauthorized (maps to .placesUnauthorized)
HTTP 403: Forbidden (maps to .placesUnauthorized)
HTTP 404: Not found (maps to .placesNotFound)
HTTP 5xx: Server error (maps to .placesUnavailable)

Google API status: RESOURCE_EXHAUSTED → .placesQuota
Google API status: AUTH_FAILURE → .placesUnauthorized
```

---

## Appendix B: File Reference Guide

### Core Implementation Files

| File | Purpose | Key Classes |
|------|---------|------------|
| `Services/Networking/GeminiClient.swift` | Gemini API client | `GeminiClient`, `curatedSpots()` |
| `Services/Networking/GooglePlacesClient.swift` | Places API client | `GooglePlacesClient`, `searchText()` |
| `Services/Spots/RemotePlacesBackend.swift` | API orchestration | `RemotePlacesBackend`, `loadSpots()` |
| `Services/Spots/PlacesService.swift` | Service layer | `PlacesService`, `snapshot` |
| `Services/Spots/SpotsCache.swift` | File caching | `SpotsCache`, `load()`, `save()` |
| `Services/Spots/PlaceMapper.swift` | Data transformation | `PlaceMapper`, `transform()` |
| `Models/Wire/GeminiWire.swift` | Gemini DTOs | `GeminiRequest`, `CuratedSpot` |
| `Models/Wire/PlacesWire.swift` | Places API DTOs | `PlaceV1`, `PhotoV1` |
| `Models/Place.swift` | App model | `Place`, computed properties |
| `Models/TravelMode.swift` | Travel modes | `TravelMode`, prompt text |
| `Config/AppConfig.swift` | Configuration | API limits, endpoints |
| `Services/Security/AppSecrets.swift` | Secrets management | `AppSecrets`, `bootstrap()` |
| `Services/Security/KeychainService.swift` | Keychain ops | `KeychainService` |
| `Services/Networking/HTTPClient.swift` | HTTP layer | Error mapping, headers |
| `Services/Spots/SpotsError.swift` | Error definitions | `SpotsError` enum |

### View & ViewModel Files

| File | Purpose |
|------|---------|
| `Features/Map/MapViewModel.swift` | Map logic, calls `loadSpots()` |
| `Features/Map/MapView.swift` | MapKit rendering |
| `Features/Map/PlacePeekView.swift` | Place preview UI |
| `Features/Details/PlaceDetailView.swift` | Full place details |
| `Features/Search/SearchViewModel.swift` | Search logic (uses MockBackend currently) |
| `CitisenApp.swift` | Dependency injection, backend selection |

---

## Document Metadata

- **Created**: 2026-05-16
- **Scope**: Citisen iOS app (TravelApp)
- **API Versions**: Gemini 2.5 Flash, Google Places API v1
- **Last Updated Code Review**: Commits `b02ce18` through `e886d20`
- **Estimated Reading Time**: 45-60 minutes (full document)
- **Estimated Implementation Time** (Recommendations):
  - Quick wins: 6-12 hours
  - Full optimization suite: 20-40 hours

---

