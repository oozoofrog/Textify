import SwiftUI
import CoreGraphics
import TextifyKit

/// Represents the different control sections accessible via the floating toolbar
enum ControlType: String, CaseIterable {
    case palette    // Opens VisualPalettePicker
    case settings   // Opens width slider + invert toggle
    case fontSize   // Opens font size controls
    case focus      // Enters focus mode
    case copy       // Triggers copy action (no sheet)

    var icon: String {
        switch self {
        case .palette: return "paintpalette"
        case .settings: return "slider.horizontal.3"
        case .fontSize: return "textformat.size"
        case .focus: return "eye.fill"
        case .copy: return "doc.on.doc"
        }
    }

    var label: String {
        switch self {
        case .palette: return "Palette"
        case .settings: return "Settings"
        case .fontSize: return "Font Size"
        case .focus: return "Focus"
        case .copy: return "Copy"
        }
    }

    var opensSheet: Bool {
        switch self {
        case .copy, .focus: return false
        default: return true
        }
    }
}

/// 텍스티파이 화면 - 실시간 텍스트 변환
public struct TextifyView: View {
    @State var viewModel: TextifyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var activeControl: ControlType?
    @State private var showBottomSheet = false
    @State private var showFocusMode = false
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var baseFontSize: CGFloat?

    public init(viewModel: TextifyViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 상단: 원본 이미지 (작게)
                originalImageSection

                // 중앙: 텍스트 아트 결과
                textArtSection
            }

            // 하단: FloatingToolbar
            VStack {
                Spacer()
                FloatingToolbar(
                    items: makeToolbarItems(),
                    activeItem: Binding(
                        get: { activeControl?.rawValue },
                        set: { newValue in
                            activeControl = newValue.flatMap { ControlType(rawValue: $0) }
                        }
                    )
                )
                .padding(.bottom, 40)
            }

            // Bottom sheet overlay
            if showBottomSheet, let control = activeControl {
                ControlBottomSheet(isPresented: $showBottomSheet) {
                    bottomSheetContent(for: control)
                }
            }

            // Focus mode overlay
            if showFocusMode, let textArt = viewModel.textArt {
                FocusModeOverlay(
                    textArt: textArt,
                    fontSize: viewModel.fontSize,
                    isActive: $showFocusMode
                )
                .transition(.opacity)
            }
        }
        .navigationTitle("Textify")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.textArt != nil {
                    ShareLink(item: viewModel.textArt?.asString ?? "") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await viewModel.generate()
        }
    }

    // MARK: - Sections

    private var originalImageSection: some View {
        Image(decorative: viewModel.image, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            .background(.ultraThinMaterial)
    }

    private var textArtSection: some View {
        ScrollView([.horizontal, .vertical]) {
            if viewModel.isGenerating {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let textArt = viewModel.textArt {
                TypingEffectText(
                    text: textArt.asString,
                    charactersPerSecond: 500,
                    shouldAnimate: viewModel.shouldAnimateNextResult
                )
                .font(.system(size: viewModel.fontSize, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .onChange(of: textArt.asString) { _, _ in
                    // Reset animation flag after text changes (animation played)
                    if viewModel.shouldAnimateNextResult {
                        viewModel.shouldAnimateNextResult = false
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("다시 시도") {
                        Task { await viewModel.generate() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onTapGesture(count: 2) {
            // Double-tap to enter focus mode
            if viewModel.textArt != nil {
                HapticsService.shared.impact(style: .medium)
                withAnimation(.easeInOut(duration: 0.25)) {
                    showFocusMode = true
                }
            }
        }
        .gesture(
            MagnificationGesture()
                .updating($pinchScale) { value, state, _ in
                    state = value
                }
                .onChanged { value in
                    // Initialize base font size on gesture start
                    if baseFontSize == nil {
                        baseFontSize = viewModel.fontSize
                    }
                    // Calculate new font size based on pinch scale
                    let newSize = (baseFontSize ?? viewModel.fontSize) * value
                    // Clamp between 4 and 20, with haptic at boundaries
                    let clampedSize = min(max(newSize, 4), 20)
                    if clampedSize != viewModel.fontSize {
                        if clampedSize == 4 || clampedSize == 20 {
                            HapticsService.shared.impact(style: .light)
                        }
                        viewModel.fontSize = clampedSize
                    }
                }
                .onEnded { _ in
                    // Reset base font size
                    baseFontSize = nil
                }
        )
    }

    // MARK: - Toolbar & Bottom Sheet

    private func makeToolbarItems() -> [FloatingToolbarItem] {
        ControlType.allCases.map { controlType in
            FloatingToolbarItem(
                id: controlType.rawValue,
                icon: controlType.icon,
                label: controlType.label
            ) {
                handleToolbarAction(controlType)
            }
        }
    }

    private func handleToolbarAction(_ controlType: ControlType) {
        switch controlType {
        case .copy:
            // Direct action, no sheet
            viewModel.copyToClipboard()
            activeControl = nil

        case .focus:
            // Enter focus mode
            if viewModel.textArt != nil {
                HapticsService.shared.impact(style: .medium)
                withAnimation(.easeInOut(duration: 0.25)) {
                    showFocusMode = true
                }
            }
            activeControl = nil

        case .palette, .settings, .fontSize:
            // Open bottom sheet
            activeControl = controlType
            showBottomSheet = true
        }
    }

    @ViewBuilder
    private func bottomSheetContent(for controlType: ControlType) -> some View {
        switch controlType {
        case .palette:
            VStack(spacing: 16) {
                Text("Palette")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VisualPalettePicker(
                    selectedPreset: $viewModel.selectedPreset,
                    onSelect: { preset in
                        viewModel.selectPreset(preset)
                        viewModel.generateFinal()
                    }
                )
            }

        case .settings:
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Width slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("폭")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.outputWidth)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: viewModel.outputWidthBinding,
                        in: 30...150,
                        step: 10
                    ) {
                        Text("출력 폭")
                    } onEditingChanged: { editing in
                        if !editing {
                            viewModel.generateFinal()
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

                // Invert toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("반전")
                            .font(.headline)
                        Text("밝기를 반전합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.invertBrightness)
                        .labelsHidden()
                        .onChange(of: viewModel.invertBrightness) { _, _ in
                            viewModel.generateFinal()
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }

        case .fontSize:
            VStack(spacing: 24) {
                Text("Font Size")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 16) {
                    Text("\(Int(viewModel.fontSize))pt")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    HStack(spacing: 20) {
                        Button {
                            viewModel.decreaseFontSize()
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                                .font(.title2)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                        }
                        .disabled(viewModel.fontSize <= 4)

                        Button {
                            viewModel.increaseFontSize()
                        } label: {
                            Image(systemName: "textformat.size.larger")
                                .font(.title2)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                        }
                        .disabled(viewModel.fontSize >= 20)
                    }
                }
                .frame(maxWidth: .infinity)
            }

        default:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        if let uiImage = UIImage(systemName: "star.fill"),
           let cgImage = uiImage.cgImage {
            TextifyView(viewModel: TextifyViewModel(
                image: cgImage,
                generator: TextArtGenerator()
            ))
        }
    }
}
