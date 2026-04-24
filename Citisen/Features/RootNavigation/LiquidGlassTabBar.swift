import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(AppRouter.self)
    private var router

    @Namespace private var selectionRingNS

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(prefs.tabBarOrder.enumerated()), id: \.offset) { index, mode in
                tab(for: mode, index: index)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 76)
        .liquidGlassPill(strength: .thin)
    }

    private func tab(for mode: TravelMode, index: Int) -> some View {
        let isActive = prefs.activeModeIndex == index
        let isStandard = mode == .standard

        return Button {
            tap(index: index)
        } label: {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(mode.color.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .strokeBorder(mode.color.opacity(0.28), lineWidth: 1)
                        )
                        .padding(2)
                        .matchedGeometryEffect(id: "activeRing", in: selectionRingNS)
                }

                VStack(spacing: 2) {
                    Image(systemName: mode.iconSymbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isActive ? mode.color : AppColor.textTertiary)
                    Text(mode.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(isActive ? mode.color : AppColor.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: prefs.activeModeIndex)
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
