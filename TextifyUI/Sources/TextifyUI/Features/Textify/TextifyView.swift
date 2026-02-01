import SwiftUI
import CoreGraphics
import TextifyKit

/// Textify screen - Real-time text art conversion
public struct TextifyView: View {
    @State var viewModel: TextifyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var toolbarState: ToolbarState = .main
    @State private var showFocusMode = false
    @State private var showingOriginalImage = false
    @Namespace private var imageTransition
    @State private var toastMessage: String?

    public init(viewModel: TextifyViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            // Main content area with tap-to-toggle
            TextifyContentView(
                viewModel: viewModel,
                showingOriginalImage: $showingOriginalImage,
                toolbarState: $toolbarState,
                showFocusMode: $showFocusMode,
                imageTransition: imageTransition
            )

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
                            viewModel.throttledGenerate()
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

    // MARK: - Save Image

    @MainActor
    private func saveAsImage() {
        Task {
            let result = await viewModel.saveAsImage()
            toastMessage = result.message
            HapticsService.shared.notification(type: result.isSuccess ? .success : .error)
        }
    }
}

#Preview {
    NavigationStack {
        if let cgImage = PreviewImageFactory.shared.createDefaultImage() {
            TextifyView(viewModel: TextifyViewModel(
                image: cgImage,
                generator: TextArtGenerator()
            ))
        }
    }
}
