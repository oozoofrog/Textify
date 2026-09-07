import SwiftUI

/// Accessible buttons keep selection explicit without decorative animations.
public struct VisualPalettePicker: View {
    @Binding var selectedPreset: PalettePreset
    let onSelect: (PalettePreset) -> Void

    public init(selectedPreset: Binding<PalettePreset>, onSelect: @escaping (PalettePreset) -> Void) {
        self._selectedPreset = selectedPreset
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 10)], spacing: 10) {
            ForEach(PalettePreset.allCases, id: \.self) { preset in
                Button {
                    selectedPreset = preset
                    onSelect(preset)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(preset.preview)
                            .font(.system(.headline, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(AppTheme.accent)
                        HStack {
                            Text(preset.name).font(.caption.weight(.semibold))
                            Spacer(minLength: 0)
                            if preset == selectedPreset {
                                Image(systemName: "checkmark.circle.fill").font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(preset == selectedPreset ? AppTheme.accent : .clear, lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.name)
                .accessibilityAddTraits(preset == selectedPreset ? .isSelected : [])
            }
        }
    }
}
