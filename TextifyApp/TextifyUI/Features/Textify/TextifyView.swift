import SwiftUI
import CoreGraphics
import TextifyKit
#if canImport(UIKit)
import UIKit
#endif

/// 텍스티파이 화면 - 결과 중심 작업공간
public struct TextifyView: View {
    @State var viewModel: TextifyViewModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL

    @State private var comparisonMode: ComparisonMode = .split
    @State private var comparisonReveal: CGFloat = 0.5
    @State private var showOptions = false
    @State private var showFocusMode = false
    @State private var showHistory = false
    @State private var baseFontSize: CGFloat?

    public init(viewModel: TextifyViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                sourcePreviewSection
                resultSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("작업공간")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("최근 작업")
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: viewModel.shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasResult)
                .accessibilityLabel("공유")
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .sheet(isPresented: $showOptions) {
            optionsSheet
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(viewModel: dependencies.makeHistoryViewModel())
                .environment(dependencies)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if viewModel.copied {
                    FeedbackBadge(text: "결과를 복사했어요", systemImage: "checkmark.circle.fill")
                }
                if viewModel.showSavedFeedback {
                    FeedbackBadge(text: "이미지로 저장했어요", systemImage: "photo.badge.checkmark")
                }
            }
            .padding(.top, 12)
        }
        .overlay {
            if showFocusMode, let textArt = viewModel.textArt {
                FocusModeOverlay(
                    textArt: textArt,
                    fontSize: viewModel.fontSize,
                    isActive: $showFocusMode
                )
                .transition(.opacity)
            }
        }
        .task {
            await viewModel.generateWithAnimation()
        }
        .onDisappear {
            viewModel.cancelGeneration()
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissError()
                    }
                }
            )
        ) {
            if viewModel.errorAction == .openSettings {
                Button("설정 열기") {
                    openAppSettings()
                    viewModel.dismissError()
                }
            }

            Button("확인", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var sourcePreviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("비교 미리보기")
                    .font(.headline)

                Spacer()

                Picker("비교 모드", selection: $comparisonMode) {
                    ForEach(ComparisonMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            comparisonPreviewContent

            VStack(alignment: .leading, spacing: 8) {
                Label("자동 생성 준비 완료", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(viewModel.optionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("원본과 ASCII 결과를 번갈아 보거나 슬라이더로 비교하면서, 팔레트·폭·대비를 빠르게 조정하세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("저장은 사용자가 요청할 때만 사진 앱에 기록됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var comparisonPreviewContent: some View {
        switch comparisonMode {
        case .original:
            sourceImagePreviewCard(height: 220)
        case .ascii:
            asciiPreviewCard(height: 220)
        case .split:
            comparisonSliderCard(height: 240)
        }
    }

    private func sourceImagePreviewCard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("원본")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Image(decorative: viewModel.image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func asciiPreviewCard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASCII")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            PreviewPanel(
                textArt: viewModel.textArt?.asString,
                isLoading: viewModel.isGenerating
            )
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comparisonSliderCard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("슬라이더 비교")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((comparisonReveal * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let revealX = width * comparisonReveal

                ZStack(alignment: .leading) {
                    comparisonSourceLayer(height: height)

                    comparisonASCIILayer(height: height)
                        .frame(width: max(revealX, 0), alignment: .leading)
                        .clipped()

                    comparisonSliderDivider(x: revealX, height: height)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let nextValue = value.location.x / max(width, 1)
                            comparisonReveal = min(max(nextValue, 0), 1)
                        }
                )
            }
            .frame(height: height)

            HStack(spacing: 12) {
                Text("원본")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(comparisonReveal) },
                        set: { comparisonReveal = CGFloat($0) }
                    ),
                    in: 0...1
                )

                Text("ASCII")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("미리보기 위를 좌우로 드래그하거나 슬라이더를 움직여 차이를 확인하세요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func comparisonSourceLayer(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.04)

            Image(decorative: viewModel.image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: height)
                .clipped()

            comparisonCornerBadge(title: "원본", trailing: false)
        }
    }

    private func comparisonASCIILayer(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            AppTheme.textArtBackground

            if viewModel.isGenerating && viewModel.textArt == nil {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(AppTheme.textArtForeground)
                    Text("생성 중…")
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.textArtForeground.opacity(0.85))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let textArt = viewModel.textArt?.asString, !textArt.isEmpty {
                Text(textArt)
                    .font(.system(size: 4, design: .monospaced))
                    .foregroundStyle(AppTheme.textArtForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                    .clipped()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.below.photo")
                        .font(.title2)
                        .foregroundStyle(AppTheme.textArtForeground.opacity(0.6))
                    Text("결과 대기 중")
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.textArtForeground.opacity(0.75))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            comparisonCornerBadge(title: "ASCII", trailing: true)
        }
    }

    private func comparisonSliderDivider(x: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.95))
                .frame(width: 2, height: height)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .offset(x: x - 17)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func comparisonCornerBadge(title: String, trailing: Bool) -> some View {
        HStack {
            if trailing { Spacer() }
            Text(title)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            if !trailing { Spacer() }
        }
        .padding(10)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("결과")
                    .font(.headline)
                Spacer()
                Text(viewModel.optionSummary)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }

            Group {
                if viewModel.isGenerating && viewModel.textArt == nil {
                    terminalLoadingView
                } else if let textArt = viewModel.textArt {
                    terminalResultView(textArt)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "생성 실패",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .overlay(alignment: .bottom) {
                        Button("다시 시도") {
                            Task {
                                await viewModel.generateWithAnimation()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 24)
                    }
                } else {
                    ContentUnavailableView(
                        "결과를 준비 중이에요",
                        systemImage: "text.below.photo",
                        description: Text("곧 텍스트 아트가 여기에 표시됩니다.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.green.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private var terminalLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.green)
            Text("사진을 문자열 패턴으로 변환하는 중…")
                .font(.body.monospaced())
                .foregroundStyle(.green.opacity(0.85))
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func terminalResultView(_ textArt: TextArt) -> some View {
        ScrollView([.horizontal, .vertical]) {
            TypingEffectText(
                text: textArt.asString,
                charactersPerSecond: 500,
                shouldAnimate: viewModel.shouldAnimateNextResult
            )
            .font(.system(size: viewModel.fontSize, design: .monospaced))
            .foregroundStyle(.green)
            .textSelection(.enabled)
            .padding(20)
            .onChange(of: textArt.asString) { _, _ in
                if viewModel.shouldAnimateNextResult {
                    viewModel.shouldAnimateNextResult = false
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard viewModel.hasResult else { return }
            dependencies.hapticsService.impact(style: .medium)
            withAnimation(.easeInOut(duration: 0.25)) {
                showFocusMode = true
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    if baseFontSize == nil {
                        baseFontSize = viewModel.fontSize
                    }
                    let newSize = (baseFontSize ?? viewModel.fontSize) * value
                    viewModel.fontSize = min(max(newSize, 4), 20)
                }
                .onEnded { _ in
                    baseFontSize = nil
                }
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            WorkspaceActionButton(
                title: viewModel.copied ? "복사됨" : "복사",
                systemImage: viewModel.copied ? "checkmark.circle.fill" : "doc.on.doc",
                isProminent: true,
                isDisabled: !viewModel.hasResult
            ) {
                viewModel.copyToClipboard()
            }

            ShareLink(item: viewModel.shareText) {
                WorkspaceActionButtonLabel(
                    title: "공유",
                    systemImage: "square.and.arrow.up",
                    isProminent: false
                )
            }
            .disabled(!viewModel.hasResult)

            WorkspaceActionButton(
                title: viewModel.isSavingImage ? "저장 중" : "저장",
                systemImage: viewModel.showSavedFeedback ? "photo.badge.checkmark" : "square.and.arrow.down",
                isProminent: false,
                isDisabled: !viewModel.hasResult || viewModel.isSavingImage
            ) {
                Task {
                    await viewModel.saveAsImage()
                }
            }

            WorkspaceActionButton(
                title: "옵션",
                systemImage: "slider.horizontal.3",
                isProminent: false,
                isDisabled: false
            ) {
                showOptions = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var optionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("팔레트")
                            .font(.headline)
                        VisualPalettePicker(
                            selectedPreset: $viewModel.selectedPreset,
                            onSelect: { preset in
                                viewModel.selectPreset(preset)
                                viewModel.generateFinal()
                            }
                        )
                    }

                    if viewModel.selectedPreset.usesCustomInput {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("커스텀 문자")
                                .font(.headline)

                            TextField("예: @#*:. TEXTIFY", text: viewModel.customCharactersBinding, axis: .vertical)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .padding(12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Text("중복 문자는 자동으로 정리되며, 최대 24자까지 입력할 수 있습니다.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("출력 폭")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.outputWidth)")
                                .font(.headline.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: viewModel.outputWidthBinding,
                            in: 30...150,
                            step: 10,
                            onEditingChanged: { isEditing in
                                viewModel.handleOutputWidthEditingChanged(isEditing)
                            }
                        )

                        Text("값이 커질수록 디테일은 늘고 문자열 길이도 길어집니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("대비")
                                .font(.headline)
                            Spacer()
                            Text(viewModel.contrastDisplayText)
                                .font(.headline.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: viewModel.contrastBoostBinding, in: 0.0...2.0, step: 0.1)

                        Text("값이 커질수록 어두움과 밝음의 차이가 더 강하게 반영됩니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("밝기 반전", isOn: viewModel.invertBrightnessBinding)
                            .font(.headline)

                        Text("어두운 배경에서 더 잘 보이는 결과가 필요할 때 사용합니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("보기 크기")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(viewModel.fontSize.rounded()))")
                                .font(.headline.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: viewModel.fontSizeBinding, in: 4...20, step: 1)

                        Text("작업공간에서만 보이는 글자 크기입니다. 결과물 자체는 바뀌지 않습니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("옵션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        showOptions = false
                    }
                }
            }
        }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }
}

private struct WorkspaceActionButton: View {
    let title: String
    let systemImage: String
    let isProminent: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WorkspaceActionButtonLabel(
                title: title,
                systemImage: systemImage,
                isProminent: isProminent
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

private enum ComparisonMode: String, CaseIterable, Identifiable {
    case original
    case ascii
    case split

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "원본"
        case .ascii:
            return "ASCII"
        case .split:
            return "비교"
        }
    }
}

private struct WorkspaceActionButtonLabel: View {
    let title: String
    let systemImage: String
    let isProminent: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .foregroundStyle(isProminent ? Color.white : Color.primary)
        .background {
            if isProminent {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
    }
}

private struct FeedbackBadge: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}
