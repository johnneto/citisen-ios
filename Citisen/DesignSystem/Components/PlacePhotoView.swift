import SwiftUI
import UIKit

/// Loads a Places API (New) photo by resource name through `PlacePhotoCache`
/// (memory + 3-day disk). Falls back to a mode-tinted gradient placeholder
/// while loading or on failure.
struct PlacePhotoView: View {
    let photoName: String
    let mode: TravelMode
    let seed: String
    var height: CGFloat = 160
    var cornerRadius: CGFloat = Radius.md
    var maxWidthPx: Int = AppConfig.Spots.photoMaxWidthPx
    var maxHeightPx: Int = AppConfig.Spots.photoMaxHeightPx

    var body: some View {
        CachedPlacePhoto(
            photoName: photoName,
            maxWidthPx: maxWidthPx,
            maxHeightPx: maxHeightPx,
            contentMode: .fill,
            transitionDuration: 0.2
        ) {
            placeholder
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

/// Shared SwiftUI wrapper around `PlacePhotoCache`. Shows the supplied
/// placeholder while loading; swaps in the resolved `UIImage` on success.
struct CachedPlacePhoto<Placeholder: View>: View {
    let photoName: String
    var maxWidthPx: Int = AppConfig.Spots.photoMaxWidthPx
    var maxHeightPx: Int = AppConfig.Spots.photoMaxHeightPx
    var contentMode: ContentMode = .fill
    var transitionDuration: Double = 0.2
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .animation(.easeInOut(duration: transitionDuration), value: image)
        .task(id: photoName) {
            let result = await PlacePhotoCache.shared.image(
                for: photoName,
                maxWidthPx: maxWidthPx,
                maxHeightPx: maxHeightPx
            )
            if !Task.isCancelled {
                image = result
            }
        }
    }
}
