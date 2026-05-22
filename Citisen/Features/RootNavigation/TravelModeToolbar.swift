import SwiftUI

// MARK: - Pure layout helper (testable)

enum TabBarLayout {
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

// MARK: - Travel mode toolbar

/// Attaches the travel-mode switcher as a grouped Liquid Glass bottom toolbar.
/// Selecting a mode tints its toolbar button with the mode's own color.
/// Long-pressing a customizable mode opens the mode picker.
struct TravelModeToolbarModifier: ViewModifier {
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(AppRouter.self)
    private var router

    static let selectionSpring: Animation = .spring(
        response: 0.42,
        dampingFraction: 0.74,
        blendDuration: 0.18
    )

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                ForEach(Array(prefs.tabBarOrder.enumerated()), id: \.offset) { index, mode in
                    TravelModeToolbarButton(
                        mode: mode,
                        isSelected: prefs.activeModeIndex == index,
                        onSelect: { select(index: index) },
                        onCustomize: { customize(mode: mode) }
                    )
                }
            }
        }
    }

    private func select(index: Int) {
        guard prefs.activeModeIndex != index else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(Self.selectionSpring) {
            prefs.activeModeIndex = index
        }
    }

    private func customize(mode: TravelMode) {
        guard mode != .standard else { return }
        guard let orderIndex = prefs.tabBarOrder.firstIndex(of: mode),
              let slotIndex = TabBarLayout.slotIndex(forOrderIndex: orderIndex) else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        router.present(.modePicker(slotIndex: slotIndex))
    }
}

extension View {
    func travelModeToolbar() -> some View {
        modifier(TravelModeToolbarModifier())
    }
}

// MARK: - Mode button

private struct TravelModeToolbarButton: View {
    let mode: TravelMode
    let isSelected: Bool
    let onSelect: () -> Void
    let onCustomize: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Image(systemName: mode.iconSymbol)
                .font(.system(size: 24, weight: .semibold))
//                .fixedSize()
                .foregroundStyle(isSelected ? Color.white : AppColor.textSecondary)
        }
        .modifier(TravelModeButtonStyleModifier(mode: mode, isSelected: isSelected))
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in onCustomize() }
        )
    }
}

/// Highlights the selected mode with Liquid Glass color — a prominent glass
/// capsule tinted with the mode's color. Unselected modes stay plain glyphs.
private struct TravelModeButtonStyleModifier: ViewModifier {
    let mode: TravelMode
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSelected {
            if #available(iOS 26.0, *) {
                content
                    .buttonStyle(.glassProminent)
                    .tint(mode.color)
            } else {
                content
                    .buttonStyle(.borderedProminent)
                    .tint(mode.color)
            }
        } else {
            content
        }
    }
}
