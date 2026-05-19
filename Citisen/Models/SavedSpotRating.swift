import SwiftUI

enum SavedSpotRating: String, CaseIterable, Codable, Identifiable {
    case wantToVisit
    case betterThanExpected
    case good
    case skippable
    case dontGo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wantToVisit: return "Want to visit"
        case .betterThanExpected: return "Better than expected"
        case .good: return "Good"
        case .skippable: return "Skippable"
        case .dontGo: return "Don't go"
        }
    }

    var emoji: String {
        switch self {
        case .wantToVisit: return "🔖"
        case .betterThanExpected: return "⭐️"
        case .good: return "👍"
        case .skippable: return "⏭️"
        case .dontGo: return "🚫"
        }
    }

    var iconSymbol: String {
        switch self {
        case .wantToVisit: return "bookmark.fill"
        case .betterThanExpected: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .skippable: return "forward.fill"
        case .dontGo: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .wantToVisit: return BrandColor.sand
        case .betterThanExpected: return AppColor.warning
        case .good: return AppColor.success
        case .skippable: return Color(hex: "8C8C8C")
        case .dontGo: return AppColor.danger
        }
    }
}
