import SwiftUI
import CoreGraphics
import TextifyKit
import Photos

/// Textify screen - Real-time text art conversion
public struct TextifyView: View {
    @State var viewModel: TextifyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var toolbarState: ToolbarState = .main
    @State private var showFocusMode = false
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var baseFontSize: CGFloat?
    @State private var showingOriginalImage = false
    @Namespace private var imageTransition
    @State private var toastMessage: String?

    public init(viewModel: TextifyViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            // Main content area with tap-to-toggle
            mainContentArea

            // Bottom: MorphingToolbar
            VStack {
                Spacer()
                MorphingToolbar(state: $toolbarState) {
                    // Style content
                    PremiumStylePicker(
                        selectedPreset: $viewModel.selectedPreset,
                        invertBrightness: $viewModel.invertBrightness,
                        onPresetChange: {
                            viewModel.generateFinal()
                        },
                        onInvertChange: {
                            viewModel.generateFinal()
                        }
                    )
                } adjustContent: {
                    // Adjust content
                    PremiumAdjustControls(
                        outputWidth: $viewModel.outputWidth,
                        fontSize: $viewModel.fontSize,
                        onWidthChange: {
                            viewModel.generateFinal()
                        }
                    )
                } shareContent: {
                    // Share content
                    PremiumShareActions(
                        onCopy: {
                            viewModel.copyToClipboard()
                            withAnimation {
                                toastMessage = "Copied to clipboard"
                                toolbarState = .main
                            }
                        },
                        onSave: {
                            saveAsImage()
                            withAnimation {
                                toolbarState = .main
                            }
                        },
                        onFocus: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showFocusMode = true
                                toolbarState = .main
                            }
                        }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
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
        .overlay(alignment: .top) {
            if let message = toastMessage {
                toastView(message: message)
            }
        }
        .task {
            await viewModel.generate()
        }
    }

    // MARK: - Toast View

    @ViewBuilder
    private func toastView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.65, blue: 0.45))

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.3)) {
                    toastMessage = nil
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var mainContentArea: some View {
        ZStack {
            if showingOriginalImage {
                Image(decorative: viewModel.image, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .matchedGeometryEffect(id: "content", in: imageTransition)
            } else {
                textifyContentView
                    .matchedGeometryEffect(id: "content", in: imageTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            if toolbarState != .main {
                let haptics = HapticsService.shared
                haptics.impact(style: .light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    toolbarState = .main
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showingOriginalImage.toggle()
                }
                HapticsService.shared.impact(style: .light)
            }
        }
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

    @ViewBuilder
    private var textifyContentView: some View {
        if viewModel.isGenerating {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let textArt = viewModel.textArt {
            ScrollView([.horizontal, .vertical]) {
                Text(textArt.asString)
                    .font(.system(size: viewModel.fontSize, design: .monospaced))
                    .minimumScaleFactor(0.1)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: false)
                    .textSelection(.enabled)
                    .padding()
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.generate() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Save Image

    @MainActor
    private func saveAsImage() {
        guard let textArt = viewModel.textArt else { return }

        let renderer = ImageRenderer(
            content: Text(textArt.asString)
                .font(.system(size: 12, design: .monospaced))
                .padding(16)
                .background(Color.white)
        )
        renderer.scale = 3.0  // High resolution

        guard let uiImage = renderer.uiImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    toastMessage = "Photo access required"
                    HapticsService.shared.notification(type: .error)
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, error in
                Task { @MainActor in
                    if success {
                        toastMessage = "Saved to Photos"
                        HapticsService.shared.notification(type: .success)
                    } else {
                        toastMessage = "Save failed"
                        HapticsService.shared.notification(type: .error)
                    }
                }
            }
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
