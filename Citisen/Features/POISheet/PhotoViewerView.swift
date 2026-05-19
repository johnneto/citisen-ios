import SwiftUI

struct PhotoViewerView: View {
    let photoNames: [String]
    let initialIndex: Int
    let mode: TravelMode

    @Environment(\.dismiss)
    private var dismiss
    @State private var index: Int
    @State private var visibleCount: Int

    init(photoNames: [String], initialIndex: Int, mode: TravelMode) {
        let clampedIndex = max(0, min(initialIndex, max(0, photoNames.count - 1)))
        self.photoNames = photoNames
        self.initialIndex = clampedIndex
        self.mode = mode
        _index = State(initialValue: clampedIndex)

        let batch = AppConfig.Spots.initialPhotoBatchSize
        let target = max(batch, clampedIndex + 1)
        _visibleCount = State(initialValue: min(photoNames.count, target))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(photoNames.prefix(visibleCount).enumerated()), id: \.offset) { idx, name in
                    ZoomablePhoto(name: name, mode: mode)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photoNames.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: index) { _, newIndex in
                if newIndex >= visibleCount - 1 {
                    let next = visibleCount + AppConfig.Spots.photoBatchIncrement
                    visibleCount = min(next, photoNames.count)
                }
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
            .accessibilityLabel("Close")
        }
        .statusBarHidden()
    }
}

private struct ZoomablePhoto: View {
    let name: String
    let mode: TravelMode

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                imageContent
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            // Only attach pan when zoomed so TabView's horizontal swipe receives
            // events at scale == 1. Magnification doesn't conflict with paging.
            .gesture(scale > 1 ? pan : nil)
            .gesture(magnify)
            .onTapGesture(count: 2) { resetOrZoom() }
        }
    }

    @ViewBuilder private var imageContent: some View {
        CachedPlacePhoto(
            photoName: name,
            contentMode: .fit,
            transitionDuration: 0.2
        ) {
            ProgressView().tint(.white)
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, min(lastScale * value, 5))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.02 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { reset() }
                }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func resetOrZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if scale > 1 {
                reset()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
