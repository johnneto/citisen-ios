import SwiftUI

/// The travel-mode selector: a grouped bar of mode controls styled to match
/// `MapTopBar`. The five modes share one Liquid Glass surface (`strength:
/// .regular`, like the top bar); the active mode is emphasized with a capsule
/// tinted in its own `mode.color`.
struct TravelModeToolbar: View {
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(AppRouter.self)
    private var router

    @Namespace private var selectionNS

    private static let selectionSpring: Animation = .spring(
        response: 0.42,
        dampingFraction: 0.74,
        blendDuration: 0.18
    )

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(prefs.tabBarOrder.enumerated()), id: \.offset) { index, mode in
                ModeToolbarButton(
                    mode: mode,
                    isSelected: prefs.activeModeIndex == index,
                    selectionNS: selectionNS,
                    onSelect: { select(index) },
                    onCustomize: customizeAction(forOrderIndex: index)
                )
            }
        }
        .padding(6)
        .liquidGlass(corner: 28, strength: .regular, interactive: true)
        .animation(Self.selectionSpring, value: prefs.activeModeIndex)
    }

    /// Returns a closure that opens the mode picker for a customizable slot, or
    /// `nil` for the pinned `.standard` centerpiece.
    private func customizeAction(forOrderIndex index: Int) -> (() -> Void)? {
        guard let slot = TabBarLayout.slotIndex(forOrderIndex: index) else { return nil }
        return { router.present(.modePicker(slotIndex: slot)) }
    }

    private func select(_ index: Int) {
        guard prefs.activeModeIndex != index else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(Self.selectionSpring) {
            prefs.activeModeIndex = index
        }
    }
}

// MARK: - Mode button

private struct ModeToolbarButton: View {
    let mode: TravelMode
    let isSelected: Bool
    let selectionNS: Namespace.ID
    let onSelect: () -> Void
    let onCustomize: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Image(systemName: mode.iconSymbol)
                    .font(.system(size: 22, weight: .semibold))
                Text(mode.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? Color.white : AppColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selectionHighlight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(CustomizeMenu(action: onCustomize))
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    @ViewBuilder private var selectionHighlight: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(mode.color)
                .shadow(color: mode.color.opacity(0.4), radius: 8, x: 0, y: 3)
                .matchedGeometryEffect(id: "modeSelection", in: selectionNS)
        }
    }
}

/// Attaches the slot-customization context menu only to customizable modes.
private struct CustomizeMenu: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.contextMenu {
                Button("Change mode…", systemImage: "slider.horizontal.3", action: action)
            }
        } else {
            content
        }
    }
}

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
