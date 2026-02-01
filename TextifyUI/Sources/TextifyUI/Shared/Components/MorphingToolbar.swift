import SwiftUI

// MARK: - Toolbar State

/// Represents the state of the morphing toolbar
public enum ToolbarState: String, CaseIterable, Sendable {
    case main
    case style
    case adjust
    case share

    public var title: String {
        switch self {
        case .main: return ""
        case .style: return "Style"
        case .adjust: return "Adjust"
        case .share: return "Share"
        }
    }

    var icon: String {
        switch self {
        case .main: return ""
        case .style: return "paintbrush.pointed.fill"
        case .adjust: return "slider.horizontal.3"
        case .share: return "square.and.arrow.up"
        }
    }
}

// MARK: - Design Tokens

private enum ToolbarDesign {
    // Colors
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0xD4A574), Color(hex: 0xC49A6C)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentColor = Color(hex: 0xC49A6C)
    static let accentColorLight = Color(hex: 0xD4A574)

    // Glass
    static let glassOpacity: CGFloat = 0.85
    static let glassBorderOpacity: CGFloat = 0.15
    static let innerGlowOpacity: CGFloat = 0.08

    // Shadows
    static let shadowColor = Color.black.opacity(0.25)
    static let shadowRadius: CGFloat = 30
    static let shadowY: CGFloat = 15

    // Layout
    static let cornerRadius: CGFloat = 28
    static let innerCornerRadius: CGFloat = 16
    static let mainPadding: CGFloat = 20
    static let contentSpacing: CGFloat = 8

    // Animation
    static let morphSpring = Animation.spring(response: 0.5, dampingFraction: 0.78, blendDuration: 0)
    static let contentSpring = Animation.spring(response: 0.4, dampingFraction: 0.72)
    static let staggerDelay: Double = 0.05
}

// MARK: - Color Extension

private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Main Menu Button

public struct MainMenuButton: Identifiable, Sendable {
    public let id: ToolbarState
    public let icon: String
    public let label: String

    public static let buttons: [MainMenuButton] = [
        MainMenuButton(id: .style, icon: "paintbrush.pointed.fill", label: "Style"),
        MainMenuButton(id: .adjust, icon: "slider.horizontal.3", label: "Adjust"),
        MainMenuButton(id: .share, icon: "square.and.arrow.up", label: "Share")
    ]
}

// MARK: - Morphing Toolbar

/// A premium morphing toolbar with glassmorphism and elegant animations
@MainActor
public struct MorphingToolbar<StyleContent: View, AdjustContent: View, ShareContent: View>: View {
    @Binding var state: ToolbarState
    let styleContent: () -> StyleContent
    let adjustContent: () -> AdjustContent
    let shareContent: () -> ShareContent

    @State private var isVisible = false
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    @Namespace private var morphingNamespace

    public init(
        state: Binding<ToolbarState>,
        @ViewBuilder styleContent: @escaping () -> StyleContent,
        @ViewBuilder adjustContent: @escaping () -> AdjustContent,
        @ViewBuilder shareContent: @escaping () -> ShareContent
    ) {
        self._state = state
        self.styleContent = styleContent
        self.adjustContent = adjustContent
        self.shareContent = shareContent
    }

    public var body: some View {
        toolbarContainer
            .offset(y: isVisible ? 0 : 100)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(ToolbarDesign.morphSpring.delay(0.15)) {
                    isVisible = true
                }
            }
            .onChange(of: state) { oldValue, newValue in
                // Reset content animation state
                contentOpacity = 0
                contentOffset = 20

                // Animate content in
                withAnimation(ToolbarDesign.contentSpring.delay(0.15)) {
                    contentOpacity = 1
                    contentOffset = 0
                }
            }
    }

    // MARK: - Container

    @ViewBuilder
    private var toolbarContainer: some View {
        ZStack {
            // Main menu stays in place, dimmed when submenu shown
            mainMenuView
                .opacity(state == .main ? 1 : 0.3)
                .animation(ToolbarDesign.morphSpring, value: state)

            // Submenu slides from right
            if state != .main {
                submenuView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .animation(ToolbarDesign.morphSpring, value: state)
    }

    // MARK: - Main Menu

    @ViewBuilder
    private var mainMenuView: some View {
        HStack(spacing: 0) {
            ForEach(Array(MainMenuButton.buttons.enumerated()), id: \.element.id) { index, button in
                if index > 0 {
                    verticalDivider
                }
                MainMenuButtonView(button: button, namespace: morphingNamespace) {
                    let haptics = HapticsService.shared
                    haptics.impact(style: .medium)
                    withAnimation(ToolbarDesign.morphSpring) {
                        state = button.id
                    }
                }
            }
        }
        .padding(.horizontal, ToolbarDesign.mainPadding)
        .padding(.vertical, 16)
        .background(premiumGlassBackground)
    }

    // MARK: - Submenu

    @ViewBuilder
    private var submenuView: some View {
        HStack(spacing: 0) {
            // Content area
            submenuContent
                .frame(maxWidth: .infinity)
                .opacity(contentOpacity)
                .offset(x: contentOffset)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(premiumGlassBackground)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe right threshold (50pt rightward)
                    if value.translation.width > 50 {
                        let haptics = HapticsService.shared
                        haptics.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state = .main
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private var submenuContent: some View {
        switch state {
        case .main:
            EmptyView()
        case .style:
            styleContent()
        case .adjust:
            adjustContent()
        case .share:
            shareContent()
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var premiumGlassBackground: some View {
        ZStack {
            // Base blur layer
            RoundedRectangle(cornerRadius: ToolbarDesign.cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(ToolbarDesign.glassOpacity)

            // Inner glow
            RoundedRectangle(cornerRadius: ToolbarDesign.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(ToolbarDesign.innerGlowOpacity),
                            .clear,
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Border
            RoundedRectangle(cornerRadius: ToolbarDesign.cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(ToolbarDesign.glassBorderOpacity),
                            .white.opacity(ToolbarDesign.glassBorderOpacity * 0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: ToolbarDesign.shadowColor, radius: ToolbarDesign.shadowRadius, x: 0, y: ToolbarDesign.shadowY)
    }

    @ViewBuilder
    private var verticalDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .primary.opacity(0.08),
                        .primary.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1, height: 44)
    }
}

// MARK: - Main Menu Button View

private struct MainMenuButtonView: View {
    let button: MainMenuButton
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Icon with container
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(isPressed ? 0.08 : 0.04))
                        .frame(width: 48, height: 48)

                    Image(systemName: button.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .scaleEffect(isPressed ? 0.92 : 1.0)

                // Label
                Text(button.label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .accessibilityLabel(button.label)
        .accessibilityHint("Opens \(button.label) options")
    }
}

// MARK: - Back Button

private struct BackButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Chevron with subtle animation
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ToolbarDesign.accentColor)
                    .offset(x: isPressed ? -2 : 0)

                // Divider line
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1, height: 20)

                // Section icon and title
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))

                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: ToolbarDesign.innerCornerRadius)
                    .fill(Color.primary.opacity(isPressed ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ToolbarDesign.innerCornerRadius)
                    .strokeBorder(
                        ToolbarDesign.accentColor.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("Back to main menu")
        .accessibilityHint("Returns to the main toolbar options")
    }
}

// MARK: - Pressable Button Style

private struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                withAnimation(.easeOut(duration: 0.15)) {
                    isPressed = newValue
                }
            }
    }
}

// MARK: - Convenience Initializer

public extension MorphingToolbar where StyleContent == EmptyView, AdjustContent == EmptyView, ShareContent == EmptyView {
    init(state: Binding<ToolbarState>) {
        self.init(
            state: state,
            styleContent: { EmptyView() },
            adjustContent: { EmptyView() },
            shareContent: { EmptyView() }
        )
    }
}

// MARK: - Premium Style Picker

/// A horizontal style picker with visual palette thumbnails
public struct PremiumStylePicker: View {
    @Binding var selectedPreset: PalettePreset
    @Binding var invertBrightness: Bool
    let onPresetChange: () -> Void
    let onInvertChange: () -> Void

    @State private var appearAnimationComplete = false

    public init(
        selectedPreset: Binding<PalettePreset>,
        invertBrightness: Binding<Bool>,
        onPresetChange: @escaping () -> Void,
        onInvertChange: @escaping () -> Void
    ) {
        self._selectedPreset = selectedPreset
        self._invertBrightness = invertBrightness
        self.onPresetChange = onPresetChange
        self.onInvertChange = onInvertChange
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Palette scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(PalettePreset.allCases.enumerated()), id: \.element) { index, preset in
                        PaletteChip(
                            preset: preset,
                            isSelected: selectedPreset == preset,
                            delay: Double(index) * ToolbarDesign.staggerDelay,
                            appearAnimationComplete: appearAnimationComplete
                        ) {
                            let haptics = HapticsService.shared
                            haptics.selection()
                            withAnimation(ToolbarDesign.contentSpring) {
                                selectedPreset = preset
                            }
                            onPresetChange()
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 8)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 8)
                }
            )

            // Invert toggle
            InvertToggle(isOn: $invertBrightness) {
                let haptics = HapticsService.shared
                haptics.impact(style: .light)
                onInvertChange()
            }
        }
        .onAppear {
            withAnimation(ToolbarDesign.contentSpring.delay(0.1)) {
                appearAnimationComplete = true
            }
        }
    }
}

// MARK: - Palette Chip

private struct PaletteChip: View {
    let preset: PalettePreset
    let isSelected: Bool
    let delay: Double
    let appearAnimationComplete: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Character preview
                Text(preset.preview)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? ToolbarDesign.accentColor : .primary.opacity(0.7))
                    .frame(width: 52, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(isSelected ? 0.12 : 0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? ToolbarDesign.accentColor : Color.clear,
                                lineWidth: 1.5
                            )
                    )

                // Selection indicator dot
                Circle()
                    .fill(isSelected ? ToolbarDesign.accentGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 5, height: 5)
                    .scaleEffect(isSelected ? 1 : 0)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .opacity(appearAnimationComplete ? 1 : 0)
            .offset(y: appearAnimationComplete ? 0 : 10)
            .animation(ToolbarDesign.contentSpring.delay(delay), value: appearAnimationComplete)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("\(preset.name) style")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Invert Toggle

private struct InvertToggle: View {
    @Binding var isOn: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(ToolbarDesign.contentSpring) {
                isOn.toggle()
            }
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(isOn ? 0.12 : 0.04))
                        .frame(width: 44, height: 44)

                    // Icon
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isOn ? ToolbarDesign.accentColor : .primary.opacity(0.5))
                        .rotationEffect(.degrees(isOn ? 180 : 0))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isOn ? ToolbarDesign.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )

                // Label
                Text("Invert")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(0.8)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("Invert brightness")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Premium Adjust Controls

/// Elegant slider controls for adjustments
public struct PremiumAdjustControls: View {
    @Binding var outputWidth: Int
    @Binding var fontSize: CGFloat
    let onWidthChange: () -> Void

    public init(
        outputWidth: Binding<Int>,
        fontSize: Binding<CGFloat>,
        onWidthChange: @escaping () -> Void
    ) {
        self._outputWidth = outputWidth
        self._fontSize = fontSize
        self.onWidthChange = onWidthChange
    }

    public var body: some View {
        VStack(spacing: 14) {
            PremiumSlider(
                icon: "arrow.left.and.right",
                label: "Width",
                value: Binding(
                    get: { Double(outputWidth) },
                    set: { outputWidth = Int($0) }
                ),
                range: 30...150,
                step: 10,
                unit: "",
                onChange: onWidthChange
            )

            PremiumSlider(
                icon: "textformat.size",
                label: "Size",
                value: Binding(
                    get: { Double(fontSize) },
                    set: { fontSize = CGFloat($0) }
                ),
                range: 4...20,
                step: 1,
                unit: "pt",
                onChange: {}
            )
        }
    }
}

// MARK: - Premium Slider

private struct PremiumSlider: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let onChange: () -> Void

    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDragging ? ToolbarDesign.accentColor : .secondary)
                .frame(width: 20)
                .animation(.easeOut(duration: 0.15), value: isDragging)

            // Slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)

                    // Filled track
                    Capsule()
                        .fill(ToolbarDesign.accentGradient)
                        .frame(width: filledWidth(in: geometry.size.width), height: 6)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
                        .shadow(color: ToolbarDesign.shadowColor, radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .strokeBorder(ToolbarDesign.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .offset(x: thumbOffset(in: geometry.size.width))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    if !isDragging {
                                        isDragging = true
                                        let haptics = HapticsService.shared
                                        haptics.impact(style: .light)
                                    }
                                    updateValue(from: gesture, in: geometry.size.width)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    let haptics = HapticsService.shared
                                    haptics.impact(style: .soft)
                                    onChange()
                                }
                        )
                }
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .frame(height: 24)

            // Value display
            HStack(spacing: 2) {
                Text("\(Int(value))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 28, alignment: .trailing)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)")
        .accessibilityValue("\(Int(value)) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + step, range.upperBound)
            case .decrement:
                value = max(value - step, range.lowerBound)
            @unknown default:
                break
            }
            onChange()
        }
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return totalWidth * CGFloat(percentage)
    }

    private func thumbOffset(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let thumbRadius: CGFloat = isDragging ? 10 : 8
        return (totalWidth - thumbRadius * 2) * CGFloat(percentage)
    }

    private func updateValue(from gesture: DragGesture.Value, in totalWidth: CGFloat) {
        let thumbRadius: CGFloat = isDragging ? 10 : 8
        let percentage = max(0, min(1, gesture.location.x / totalWidth))
        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(percentage)
        let steppedValue = round(newValue / step) * step
        let clampedValue = max(range.lowerBound, min(range.upperBound, steppedValue))

        if clampedValue != value {
            value = clampedValue
            let haptics = HapticsService.shared
            haptics.selection()
        }
    }
}

// MARK: - Premium Share Actions

/// Elegant share action buttons
public struct PremiumShareActions: View {
    let onCopy: () -> Void
    let onSave: () -> Void
    let onFocus: () -> Void

    @State private var appearAnimationComplete = false

    public init(
        onCopy: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onFocus: @escaping () -> Void
    ) {
        self.onCopy = onCopy
        self.onSave = onSave
        self.onFocus = onFocus
    }

    private let actions: [(icon: String, label: String, index: Int)] = [
        ("doc.on.doc.fill", "Copy", 0),
        ("arrow.down.to.line", "Save", 1),
        ("eye.fill", "Focus", 2)
    ]

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(actions, id: \.index) { action in
                if action.index > 0 {
                    Spacer()
                }

                ShareActionButton(
                    icon: action.icon,
                    label: action.label,
                    delay: Double(action.index) * ToolbarDesign.staggerDelay,
                    appearAnimationComplete: appearAnimationComplete
                ) {
                    let haptics = HapticsService.shared
                    haptics.impact(style: .medium)
                    switch action.index {
                    case 0: onCopy()
                    case 1: onSave()
                    case 2: onFocus()
                    default: break
                    }
                }

                if action.index < actions.count - 1 {
                    Spacer()
                }
            }
        }
        .onAppear {
            withAnimation(ToolbarDesign.contentSpring.delay(0.1)) {
                appearAnimationComplete = true
            }
        }
    }
}

// MARK: - Share Action Button

private struct ShareActionButton: View {
    let icon: String
    let label: String
    let delay: Double
    let appearAnimationComplete: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon container
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.primary.opacity(isPressed ? 0.12 : 0.06))
                        .frame(width: 52, height: 52)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isPressed ? ToolbarDesign.accentColor : .primary.opacity(0.8))
                }
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.primary.opacity(isPressed ? 0.15 : 0.08),
                            lineWidth: 1
                        )
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)

                // Label
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .opacity(appearAnimationComplete ? 1 : 0)
            .offset(y: appearAnimationComplete ? 0 : 15)
            .animation(ToolbarDesign.contentSpring.delay(delay), value: appearAnimationComplete)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .frame(minWidth: 70)
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#Preview("Main State") {
    @Previewable @State var toolbarState: ToolbarState = .main
    @Previewable @State var selectedPreset: PalettePreset = .blocks
    @Previewable @State var invertBrightness: Bool = false
    @Previewable @State var outputWidth: Int = 80
    @Previewable @State var fontSize: CGFloat = 10

    ZStack {
        // Dark gradient background
        LinearGradient(
            colors: [
                Color(hex: 0x1A1A2E),
                Color(hex: 0x16213E)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()

            // State indicator
            Text("State: \(toolbarState.rawValue)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding()

            Spacer()

            MorphingToolbar(state: $toolbarState) {
                PremiumStylePicker(
                    selectedPreset: $selectedPreset,
                    invertBrightness: $invertBrightness,
                    onPresetChange: {},
                    onInvertChange: {}
                )
            } adjustContent: {
                PremiumAdjustControls(
                    outputWidth: $outputWidth,
                    fontSize: $fontSize,
                    onWidthChange: {}
                )
            } shareContent: {
                PremiumShareActions(
                    onCopy: {},
                    onSave: {},
                    onFocus: {}
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview("Style State") {
    @Previewable @State var toolbarState: ToolbarState = .style
    @Previewable @State var selectedPreset: PalettePreset = .standard
    @Previewable @State var invertBrightness: Bool = false
    @Previewable @State var outputWidth: Int = 80
    @Previewable @State var fontSize: CGFloat = 10

    ZStack {
        LinearGradient(
            colors: [Color(hex: 0x2D3436), Color(hex: 0x636E72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()

            MorphingToolbar(state: $toolbarState) {
                PremiumStylePicker(
                    selectedPreset: $selectedPreset,
                    invertBrightness: $invertBrightness,
                    onPresetChange: {},
                    onInvertChange: {}
                )
            } adjustContent: {
                PremiumAdjustControls(
                    outputWidth: $outputWidth,
                    fontSize: $fontSize,
                    onWidthChange: {}
                )
            } shareContent: {
                PremiumShareActions(
                    onCopy: {},
                    onSave: {},
                    onFocus: {}
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview("Adjust State") {
    @Previewable @State var toolbarState: ToolbarState = .adjust
    @Previewable @State var selectedPreset: PalettePreset = .blocks
    @Previewable @State var invertBrightness: Bool = true
    @Previewable @State var outputWidth: Int = 100
    @Previewable @State var fontSize: CGFloat = 12

    ZStack {
        Color(hex: 0x0F0F0F)
            .ignoresSafeArea()

        VStack {
            Spacer()

            MorphingToolbar(state: $toolbarState) {
                PremiumStylePicker(
                    selectedPreset: $selectedPreset,
                    invertBrightness: $invertBrightness,
                    onPresetChange: {},
                    onInvertChange: {}
                )
            } adjustContent: {
                PremiumAdjustControls(
                    outputWidth: $outputWidth,
                    fontSize: $fontSize,
                    onWidthChange: {}
                )
            } shareContent: {
                PremiumShareActions(
                    onCopy: {},
                    onSave: {},
                    onFocus: {}
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview("Share State") {
    @Previewable @State var toolbarState: ToolbarState = .share
    @Previewable @State var selectedPreset: PalettePreset = .dots
    @Previewable @State var invertBrightness: Bool = false
    @Previewable @State var outputWidth: Int = 80
    @Previewable @State var fontSize: CGFloat = 10

    ZStack {
        LinearGradient(
            colors: [Color(hex: 0x0F2027), Color(hex: 0x203A43), Color(hex: 0x2C5364)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()

            MorphingToolbar(state: $toolbarState) {
                PremiumStylePicker(
                    selectedPreset: $selectedPreset,
                    invertBrightness: $invertBrightness,
                    onPresetChange: {},
                    onInvertChange: {}
                )
            } adjustContent: {
                PremiumAdjustControls(
                    outputWidth: $outputWidth,
                    fontSize: $fontSize,
                    onWidthChange: {}
                )
            } shareContent: {
                PremiumShareActions(
                    onCopy: {},
                    onSave: {},
                    onFocus: {}
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
