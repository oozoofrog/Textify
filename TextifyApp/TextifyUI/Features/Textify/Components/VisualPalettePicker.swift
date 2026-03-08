import SwiftUI

/// Visual palette picker with retro-futuristic terminal aesthetic
/// Features grid of cards with character previews and smooth selection animations
public struct VisualPalettePicker: View {
    @Binding var selectedPreset: PalettePreset
    let onSelect: (PalettePreset) -> Void

    @Namespace private var selectionNamespace

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public init(
        selectedPreset: Binding<PalettePreset>,
        onSelect: @escaping (PalettePreset) -> Void
    ) {
        self._selectedPreset = selectedPreset
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PalettePreset.allCases, id: \.self) { preset in
                PaletteCard(
                    preset: preset,
                    isSelected: preset == selectedPreset,
                    namespace: selectionNamespace
                )
                .onTapGesture {
                    selectPreset(preset)
                }
            }
        }
    }

    private func selectPreset(_ preset: PalettePreset) {
        let haptics = HapticsService.shared
        haptics.selection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
            selectedPreset = preset
        }
        onSelect(preset)
    }
}

// MARK: - Palette Card

private struct PaletteCard: View {
    let preset: PalettePreset
    let isSelected: Bool
    let namespace: Namespace.ID

    @State private var isPressed = false

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                // Character preview with retro terminal styling
                ZStack {
                    // Glow effect background
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.cyan.opacity(0.3),
                                        Color.cyan.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 50
                                )
                            )
                            .blur(radius: 8)
                    }

                    // Preview text container
                    ZStack {
                        // Scanline effect
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.02), location: 0.5),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(isSelected ? 1 : 0)

                        // Character preview
                        Text(preset.preview)
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundStyle(
                                isSelected
                                    ? LinearGradient(
                                        colors: [.cyan, .green],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [.primary.opacity(0.8), .primary.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .shadow(
                                color: isSelected ? .cyan.opacity(0.5) : .clear,
                                radius: 8,
                                x: 0,
                                y: 0
                            )
                            .padding(.vertical, 12)
                    }
                }
                .frame(height: 60)

                // Palette name with bold typography
                Text(preset.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        isSelected
                            ? Color.primary
                            : Color.secondary
                    )
                    .tracking(0.5)
                    .textCase(.uppercase)
            }
            .padding(12)
        }
        .overlay {
            // Selection border with neon accent
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .matchedGeometryEffect(id: "selection", in: namespace)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Checkmark indicator
            if isSelected {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .shadow(
                            color: .cyan.opacity(0.6),
                            radius: 8,
                            x: 0,
                            y: 0
                        )

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                }
                .offset(x: -8, y: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.68), value: isSelected)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    struct PreviewWrapper: View {
        @State private var selected = PalettePreset.blocks

        var body: some View {
            ZStack {
                // Retro gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.1, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("PALETTE SELECTION")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.9))

                        VisualPalettePicker(
                            selectedPreset: $selected,
                            onSelect: { _ in }
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 40)
                }
            }
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}

#Preview("All Palettes") {
    struct PreviewWrapper: View {
        @State private var selected = PalettePreset.standard

        var body: some View {
            ZStack {
                // Dark terminal background
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(PalettePreset.allCases, id: \.self) { preset in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(preset.name)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.green)

                                Text(preset.preview)
                                    .font(.system(size: 20, design: .monospaced))
                                    .foregroundStyle(.cyan)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.green.opacity(0.05))
                            .cornerRadius(8)
                        }

                        Divider()
                            .background(.green.opacity(0.3))

                        VisualPalettePicker(
                            selectedPreset: $selected,
                            onSelect: { _ in }
                        )
                    }
                    .padding()
                }
            }
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
