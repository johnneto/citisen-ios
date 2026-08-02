import Foundation

/// Where a `Place` came from. Drives the "keep this spot?" offer and the
/// provenance badge on the POI card — neither can be inferred reliably from
/// `descriptionIsCurated` or `detailsFetchedAt`, which are both set for
/// unrelated reasons (a curated place with no Gemini rationale, or an AI place
/// upgraded by `enrichPlace`).
enum PlaceSource: String, Codable, Hashable {
    /// Resolved through the Gemini curation pipeline. Also the decoding default,
    /// so every cache entry written before this field existed reads correctly.
    case aiCurated
    /// Resolved from a search-autocomplete tap and not (yet) kept by the user.
    case userSearch
    /// A searched place the user chose to keep alongside the AI suggestions.
    case userSaved
}
