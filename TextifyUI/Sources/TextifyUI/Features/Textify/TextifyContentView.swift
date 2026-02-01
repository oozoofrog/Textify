import SwiftUI

/// 텍스트 아트 컨텐츠 영역 뷰
public struct TextifyContentView: View {
    // MARK: - Properties

    @Bindable var viewModel: TextifyViewModel
    @Binding var showingOriginalImage: Bool
    @Binding var toolbarState: ToolbarState
    @Binding var showFocusMode: Bool

    let imageTransition: Namespace.ID

    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var baseFontSize: CGFloat?

    // MARK: - Body

    public var body: some View {
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
            handleTap()
        }
        .onTapGesture(count: 2) {
            handleDoubleTap()
        }
        .gesture(pinchGesture)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var textifyContentView: some View {
        if viewModel.isGenerating {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let textArt = viewModel.textArt {
            GeometryReader { geometry in
                ScrollViewReader { scrollProxy in
                    ScrollView([.horizontal, .vertical]) {
                        Text(textArt.asString)
                            .font(.system(size: viewModel.fontSize, design: .monospaced))
                            .minimumScaleFactor(0.1)
                            .lineLimit(nil)
                            .fixedSize(horizontal: true, vertical: true)
                            .textSelection(.enabled)
                            .scaleEffect(pinchScale)
                            .padding()
                            .frame(
                                minWidth: geometry.size.width,
                                minHeight: geometry.size.height
                            )
                            .id("textArtContent")
                    }
                    .defaultScrollAnchor(.center)
                    .onChange(of: viewModel.outputWidth) { _, _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            scrollProxy.scrollTo("textArtContent", anchor: .center)
                        }
                    }
                    .onChange(of: viewModel.fontSize) { _, _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            scrollProxy.scrollTo("textArtContent", anchor: .center)
                        }
                    }
                }
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

    // MARK: - Gestures

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onChanged { value in
                if baseFontSize == nil {
                    baseFontSize = viewModel.fontSize
                }
            }
            .onEnded { value in
                let newSize = (baseFontSize ?? viewModel.fontSize) * value
                let clampedSize = min(max(newSize, 4), 20)
                viewModel.fontSize = clampedSize
                HapticsService.shared.impact(style: .light)
                baseFontSize = nil
            }
    }

    // MARK: - Actions

    private func handleTap() {
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

    private func handleDoubleTap() {
        if viewModel.textArt != nil {
            HapticsService.shared.impact(style: .medium)
            withAnimation(.easeInOut(duration: 0.25)) {
                showFocusMode = true
            }
        }
    }
}
