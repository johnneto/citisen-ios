import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(AppRouter.self)
    private var router

    @Namespace private var selectionRingNS
    @State private var tabBarWidth: CGFloat = 0

    private static let coordinateSpaceName = "LiquidGlassTabBar"
    private static let horizontalInset: CGFloat = 4

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(prefs.tabBarOrder.enumerated()), id: \.offset) { index, mode in
                tab(for: mode, index: index)
            }
        }
        .padding(.horizontal, Self.horizontalInset)
        .frame(height: 76)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { tabBarWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        tabBarWidth = newWidth
                    }
            }
        )
        .coordinateSpace(name: Self.coordinateSpaceName)
        .simultaneousGesture(slideGesture)
        .liquidGlassPill(strength: .regular, interactive: true)
    }

    private var slideGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(Self.coordinateSpaceName))
            .onChanged { value in
                updateIndex(forDragLocationX: value.location.x)
            }
    }

    private func updateIndex(forDragLocationX x: CGFloat) {
        let count = prefs.tabBarOrder.count
        guard count > 0, tabBarWidth > 0 else { return }
        let innerWidth = max(tabBarWidth - Self.horizontalInset * 2, 1)
        let innerX = min(max(x - Self.horizontalInset, 0), innerWidth)
        let raw = Int((innerX / innerWidth) * CGFloat(count))
        let index = min(max(raw, 0), count - 1)
        guard prefs.activeModeIndex != index else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        @Bindable var prefs = prefs
        prefs.activeModeIndex = index
    }

    private func tab(for mode: TravelMode, index: Int) -> some View {
        let isActive = prefs.activeModeIndex == index
        let isStandard = mode == .standard

        return Button {
            tap(index: index)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: mode.iconSymbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isActive ? AppColor.textPrimary : AppColor.textSecondary)
                Text(mode.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(isActive ? AppColor.textPrimary : AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background {
                if isActive {
                    activeHighlight(for: mode)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    guard !isStandard else { return }
                    longPress(mode: mode)
                }
        )
        .animation(
            .interactiveSpring(response: 0.3, dampingFraction: 0.75, blendDuration: 0.2),
            value: prefs.activeModeIndex
        )
    }

    @ViewBuilder
    private func activeHighlight(for mode: TravelMode) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(
                    Glass.regular.tint(mode.color.opacity(0.28)).interactive(),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
                .padding(.vertical, 4)
                .padding(.horizontal, 0)
                .matchedGeometryEffect(id: "activeRing", in: selectionRingNS)
        } else {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.dynamic(
                    light: mode.color.opacity(0.22),
                    dark: mode.color.opacity(0.38)
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(mode.color.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: mode.color.opacity(0.30), radius: 8, x: 0, y: 3)
                .padding(.vertical, 4)
                .padding(.horizontal, 0)
                .matchedGeometryEffect(id: "activeRing", in: selectionRingNS)
        }
    }

    private func tap(index: Int) {
        @Bindable var prefs = prefs
        guard prefs.activeModeIndex != index else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        prefs.activeModeIndex = index
    }

    private func longPress(mode: TravelMode) {
        // Map active tab-bar index back to the slot (0..3) in prefs.activeModes.
        let order = prefs.tabBarOrder
        guard let orderIndex = order.firstIndex(of: mode) else { return }
        let slotIndex: Int = {
            switch orderIndex {
            case 0, 1: return orderIndex
            case 3, 4: return orderIndex - 1
            default: return -1
            }
        }()
        guard slotIndex >= 0 else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        router.present(.modePicker(slotIndex: slotIndex))
    }
}
