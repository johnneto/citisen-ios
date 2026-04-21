import SwiftUI

struct ModeSelectionScreen: View {
    @Binding var modes: [TravelMode]
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var editingSlot: Int?

    var body: some View {
        VStack(spacing: 0) {
            navBar
            header
            standardSlot
            slotList
            Spacer(minLength: 0)
            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
        }
        .padding(.top, 62)
        .background(AppColor.surfacePrimary)
        .sheet(item: slotBinding) { idx in
            ModePickerSheet(
                currentMode: modes[idx.value],
                excluded: Set(modes).union([.standard]).subtracting([modes[idx.value]])
            ) { picked in
                modes[idx.value] = picked
                editingSlot = nil
            } onCancel: {
                editingSlot = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var slotBinding: Binding<IdentifiableInt?> {
        Binding(
            get: { editingSlot.map(IdentifiableInt.init) },
            set: { editingSlot = $0?.value }
        )
    }

    private var navBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(BrandColor.sand)
            }
            Spacer()
            Text("Customize Modes")
                .font(.headline17)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Color.clear.frame(width: 26, height: 1)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 44)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Define your Travel DNA")
                .font(.title1)
                .foregroundStyle(AppColor.textPrimary)
                .kerning(-0.6)
            Text("Choose the travel styles you want to use to explore the world. These four slots define your focus.")
                .font(.subheadline15)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var standardSlot: some View {
        HStack(spacing: Spacing.sm) {
            modeBubble(.standard, background: .white)
            VStack(alignment: .leading, spacing: 2) {
                Text("STANDARD")
                    .font(.caption11Bold)
                    .tracking(0.8)
                    .foregroundStyle(BrandColor.sandDeep)
                Text("Always active · AI-curated mix across all modes.")
                    .font(.caption12)
                    .foregroundStyle(BrandColor.sandDeep)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(BrandColor.sandDeep)
        }
        .padding(Spacing.md)
        .background(BrandColor.sandTint)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(BrandColor.sand.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private var slotList: some View {
        VStack(spacing: 10) {
            ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                Button {
                    editingSlot = index
                } label: {
                    slotRow(index: index, mode: mode)
                }
                .buttonStyle(.pressableScale)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private func slotRow(index: Int, mode: TravelMode) -> some View {
        HStack(spacing: Spacing.sm) {
            modeBubble(mode, background: mode.tintColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.headline17)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Slot \(index + 1) · tap to change")
                    .font(.caption12)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
            HStack(spacing: 2) {
                Text("Change")
                    .font(.subheadline15)
                    .fontWeight(.medium)
                Image(systemName: "chevron.right")
                    .font(.caption12)
            }
            .foregroundStyle(BrandColor.sand)
        }
        .padding(Spacing.md)
        .background(AppColor.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColor.dividerSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func modeBubble(_ mode: TravelMode, background: Color) -> some View {
        ZStack {
            Circle().fill(background)
            Image(systemName: mode.iconSymbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(mode.color)
        }
        .frame(width: 44, height: 44)
    }
}

private struct IdentifiableInt: Identifiable, Hashable {
    let value: Int
    var id: Int { value }
}
