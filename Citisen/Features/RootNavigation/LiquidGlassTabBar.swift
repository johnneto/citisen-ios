import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(AppRouter.self)
    private var router

    @Namespace private var bubbleNS
    @State private var tabBarWidth: CGFloat = 0
    @State private var pressedIndex: Int?
    @State private var lastHapticIndex: Int?

    static let barHeight: CGFloat = 76
    static let horizontalInset: CGFloat = 4
    private static let coordinateSpaceName = "LiquidGlassTabBar"

    static let selectionSpring: Animation = .spring(
        response: 0.42,
        dampingFraction: 0.74,
        blendDuration: 0.18
    )
    private static let pressSpring: Animation = .spring(
        response: 0.28,
        dampingFraction: 0.7
    )

    private var displayedIndex: Int { pressedIndex ?? prefs.activeModeIndex }

    var body: some View {
        ZStack {
            bubbleLayer
            contentLayer
        }
        .padding(.horizontal, Self.horizontalInset)
        .frame(height: Self.barHeight)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { tabBarWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in tabBarWidth = new }
            }
        )
        .coordinateSpace(name: Self.coordinateSpaceName)
        .contentShape(Rectangle())
        .gesture(pressGesture)
        .animation(Self.selectionSpring, value: displayedIndex)
        .animation(Self.pressSpring, value: pressedIndex)
        .liquidGlassPill(strength: .regular, interactive: true)
    }

    // MARK: - Layers

    @ViewBuilder private var bubbleLayer: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 0) {
                    bubbleRow
                }
            } else {
                bubbleRow
            }
        }
        .allowsHitTesting(false)
    }

    private var bubbleRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(prefs.tabBarOrder.enumerated()), id: \.offset) { index, mode in
                ZStack {
                    if displayedIndex == index {
                        SelectionBubble(
                            mode: mode,
                            isPressing: pressedIndex == index,
                            bubbleNS: bubbleNS
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var contentLayer: some View {
        HStack(spacing: 0) {
            ForEach(Array(prefs.tabBarOrder.enumerated()), id: \.offset) { index, mode in
                tabContent(for: mode, index: index)
            }
        }
    }

    private func tabContent(for mode: TravelMode, index: Int) -> some View {
        let isDisplayed = displayedIndex == index
        let isPressed = pressedIndex == index
        let scale: CGFloat = isPressed ? 0.94 : (isDisplayed ? 1.04 : 1.0)

        return VStack(spacing: 2) {
            Image(systemName: mode.iconSymbol)
                .font(.system(size: 22, weight: .bold))
            Text(mode.displayName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(isDisplayed ? Color.white : AppColor.textSecondary)
        .shadow(color: isDisplayed ? .black.opacity(0.45) : .clear, radius: 1.5, x: 0, y: 0.5)
        .scaleEffect(scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .hoverEffect(.lift)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityAddTraits(prefs.activeModeIndex == index ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction { commit(index: index) }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    guard mode != .standard else { return }
                    longPress(mode: mode)
                }
        )
    }

    // MARK: - Gesture (hold + slide preview, commit on release)

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpaceName))
            .onChanged { value in
                guard let idx = TabBarLayout.index(
                    forLocationX: value.location.x,
                    barWidth: tabBarWidth,
                    inset: Self.horizontalInset,
                    tabCount: prefs.tabBarOrder.count
                ) else { return }
                if pressedIndex != idx {
                    pressedIndex = idx
                    if lastHapticIndex != idx {
                        lastHapticIndex = idx
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        #endif
                    }
                }
            }
            .onEnded { value in
                defer {
                    pressedIndex = nil
                    lastHapticIndex = nil
                }
                guard let idx = TabBarLayout.index(
                    forLocationX: value.location.x,
                    barWidth: tabBarWidth,
                    inset: Self.horizontalInset,
                    tabCount: prefs.tabBarOrder.count
                ) else { return }
                commit(index: idx)
            }
    }

    // MARK: - Actions

    private func commit(index: Int) {
        @Bindable var prefs = prefs
        guard prefs.activeModeIndex != index else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(Self.selectionSpring) {
            prefs.activeModeIndex = index
        }
    }

    private func longPress(mode: TravelMode) {
        guard let slotIndex = TabBarLayout.slotIndex(forOrderIndex: prefs.tabBarOrder.firstIndex(of: mode) ?? -1) else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        router.present(.modePicker(slotIndex: slotIndex))
    }
}

// MARK: - Pure layout helpers (testable)

enum TabBarLayout {
    /// Maps a horizontal touch location (in the bar's coordinate space, including the
    /// outer inset) to a tab index in `0..<tabCount`. Returns nil if the bar has not
    /// yet been laid out or there are no tabs.
    static func index(forLocationX x: CGFloat, barWidth: CGFloat, inset: CGFloat, tabCount: Int) -> Int? {
        guard tabCount > 0, barWidth > 0 else { return nil }
        let innerWidth = max(barWidth - inset * 2, 1)
        let innerX = min(max(x - inset, 0), innerWidth)
        let raw = Int((innerX / innerWidth) * CGFloat(tabCount))
        return min(max(raw, 0), tabCount - 1)
    }

    /// Maps a tab-bar order index (5 visual slots, middle one is the centerpiece) to a
    /// stored mode-picker slot index (0...3). Returns nil for the centerpiece slot.
    static func slotIndex(forOrderIndex orderIndex: Int) -> Int? {
        switch orderIndex {
        case 0, 1: return orderIndex
        case 3: return 2
        case 4: return 3
        default: return nil
        }
    }
}

// MARK: - Selection bubble

private struct SelectionBubble: View {
    let mode: TravelMode
    let isPressing: Bool
    let bubbleNS: Namespace.ID

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let glow = mode.color.opacity(isPressing ? 0.55 : 0.32)
        let glowRadius: CGFloat = isPressing ? 16 : 9
        let glowY: CGFloat = isPressing ? 6 : 3
        let squish: CGFloat = isPressing ? 0.94 : 1.0

        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(
                        Glass.regular.tint(mode.color.opacity(0.38)).interactive(),
                        in: shape
                    )
                    .overlay(shape.strokeBorder(mode.color.opacity(0.65), lineWidth: 1))
                    .glassEffectID("selectionBubble", in: bubbleNS)
            } else {
                shape
                    .fill(Color.dynamic(
                        light: mode.color.opacity(0.45),
                        dark: mode.color.opacity(0.55)
                    ))
                    .overlay(shape.strokeBorder(mode.color.opacity(0.7), lineWidth: 1))
            }
        }
        .shadow(color: glow, radius: glowRadius, x: 0, y: glowY)
        .padding(.vertical, 4)
        .scaleEffect(squish)
        .matchedGeometryEffect(id: "selectionBubble", in: bubbleNS)
    }
}
