import SwiftUI

/// Loads a Places API (New) photo by resource name. Falls back to a mode-tinted
/// gradient placeholder while loading or on failure.
struct PlacePhotoView: View {
    let photoName: String
    let mode: TravelMode
    let seed: String
    var height: CGFloat = 160
    var cornerRadius: CGFloat = Radius.md
    var maxWidthPx: Int = AppConfig.Spots.photoMaxWidthPx
    var maxHeightPx: Int = AppConfig.Spots.photoMaxHeightPx

    private static let client = GooglePlacesClient()

    private var url: URL? {
        Self.client.photoMediaURL(name: photoName, maxWidthPx: maxWidthPx, maxHeightPx: maxHeightPx)
    }

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AppColor.dividerSoft, lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        PlaceholderPhoto(seed: seed, mode: mode, height: height, cornerRadius: cornerRadius)
    }
}
