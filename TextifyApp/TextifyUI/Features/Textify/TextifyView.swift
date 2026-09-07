import SwiftUI
import CoreGraphics
import TextifyKit
import UIKit

/// A result-first studio with one canvas and directly accessible styles.
public struct TextifyView: View {
    @State var viewModel: TextifyViewModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var comparisonMode: ComparisonMode = .ascii
    @State private var comparisonReveal: Double = 0.5
    @State private var showOptions = false
    @State private var showFocusMode = false
    @State private var showHistory = false

    public init(viewModel: TextifyViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                canvasSection
                styleSection
                resultInformation
            }
            .frame(maxWidth: 800)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.studioBackground)
        .tint(AppTheme.accent)
        .navigationTitle("텍스트 스튜디오")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("최근 작업", systemImage: "clock.arrow.circlepath") { showHistory = true }
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .sheet(isPresented: $showOptions) {
            optionsSheet.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(viewModel: dependencies.makeHistoryViewModel()).environment(dependencies)
        }
        .fullScreenCover(isPresented: $showFocusMode) {
            if let textArt = viewModel.textArt {
                FocusModeOverlay(textArt: textArt, isActive: $showFocusMode)
            }
        }
        .task {
            if !viewModel.canExportResult { await viewModel.generate() }
        }
        .onDisappear { viewModel.cancelGeneration() }
        .alert("작업 안내", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            if viewModel.errorAction == .openSettings {
                Button("설정 열기") { openAppSettings(); viewModel.dismissError() }
            }
            Button("확인", role: .cancel) { viewModel.dismissError() }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    private var canvasSection: some View {
        VStack(spacing: 14) {
            Picker("미리보기", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("preview-mode")

            artworkCanvas
                .frame(height: 320)
                .background(AppTheme.canvasBackground, in: RoundedRectangle(cornerRadius: 22))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        if viewModel.isGenerating { ProgressView().tint(AppTheme.canvasForeground) }
                        Text(viewModel.isGenerating ? "옵션 반영 중" : "TEXT ART")
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.canvasForeground)
                    .padding(12)
                    .background(AppTheme.canvasBackground.opacity(0.92), in: Capsule())
                    .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.hasResult {
                        Button { showFocusMode = true } label: {
                            Label("확대", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .padding(10)
                                .foregroundStyle(AppTheme.canvasForeground)
                                .background(AppTheme.canvasBackground.opacity(0.9), in: Capsule())
                        }
                        .padding(12)
                        .accessibilityIdentifier("expand-artwork")
                    }
                }

            if comparisonMode == .split {
                HStack(spacing: 12) {
                    Text("원본")
                    Slider(value: $comparisonReveal, in: 0...1)
                        .accessibilityLabel("텍스트 아트 비교 비율")
                        .accessibilityValue("\(Int(comparisonReveal * 100))퍼센트")
                    Text("텍스트")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if viewModel.canRetryGeneration {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.hasResult ? "옵션을 반영하지 못해 이전 결과를 표시하고 있어요." : "사진을 변환하지 못했어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("현재 옵션으로 다시 시도") { Task { await viewModel.generate() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var artworkCanvas: some View {
        GeometryReader { proxy in
            let available = CGSize(width: max(proxy.size.width - 32, 1), height: max(proxy.size.height - 72, 1))
            let ratio = CGFloat(viewModel.image.width) / CGFloat(max(viewModel.image.height, 1))
            let width = min(available.width, available.height * ratio)
            let height = width / ratio
            ZStack {
                if comparisonMode != .ascii {
                    Image(decorative: viewModel.image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: width, height: height)
                        .accessibilityLabel("원본 이미지")
                }
                if comparisonMode != .original {
                    Group {
                        if let textArt = viewModel.textArt {
                            FittedTextArt(textArt: textArt)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: viewModel.canRetryGeneration ? "exclamationmark.triangle" : "text.below.photo")
                                    .font(.largeTitle)
                                Text(viewModel.canRetryGeneration ? "다시 시도해 주세요" : "문자로 그리는 중…")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(AppTheme.canvasForeground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: width, height: height)
                    .background(AppTheme.canvasBackground)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: comparisonMode == .split ? width * comparisonReveal : width)
                    }
                }
                if comparisonMode == .split {
                    Rectangle()
                        .fill(AppTheme.canvasForeground)
                        .frame(width: 2, height: height)
                        .offset(x: width * (comparisonReveal - 0.5))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("분위기 고르기").font(.headline)
                Spacer()
                Button("세부 조정", systemImage: "slider.horizontal.3") { showOptions = true }
                    .font(.subheadline)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 140), spacing: 10)], spacing: 10) {
                ForEach(TextArtStyle.allCases) { style in
                    Button { viewModel.applyStyle(style) } label: {
                        HStack(spacing: 8) {
                            Text(style.characterPreview)
                                .font(.system(.title3, design: .monospaced).weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 32)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(style.title).font(.subheadline.weight(.semibold))
                                Text(style.subtitle).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(viewModel.selectedStyle == style ? AppTheme.accent : Color.clear, lineWidth: 1.5)
                        }
                        .overlay(alignment: .topTrailing) {
                            if viewModel.selectedStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accent)
                                    .background(AppTheme.studioBackground, in: Circle())
                                    .offset(x: 4, y: -4)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(style.title), \(style.subtitle)")
                    .accessibilityAddTraits(viewModel.selectedStyle == style ? .isSelected : [])
                    .accessibilityIdentifier("style-\(style.rawValue)")
                }
            }
        }
    }

    private var resultInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.alignleft")
                Text(viewModel.resultStatistics)
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            Text(viewModel.optionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("붙여넣는 곳에서도 고정폭 글꼴을 쓰면 그림이 잘 유지돼요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            if viewModel.copied || viewModel.showSavedFeedback {
                Label(viewModel.copied ? "텍스트를 복사했어요" : "사진 앱에 저장했어요", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            HStack(spacing: 10) {
                Button { viewModel.copyToClipboard() } label: {
                    Label(viewModel.copied ? "복사됨" : "텍스트 복사", systemImage: viewModel.copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!viewModel.canExportResult)
                .opacity(viewModel.canExportResult ? 1 : 0.45)
                .accessibilityIdentifier("copy-artwork")
                ShareLink(item: viewModel.shareText) {
                    actionLabel("공유", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.canExportResult)
                Button { Task { await viewModel.saveAsImage() } } label: {
                    actionLabel(viewModel.isSavingImage ? "저장 중" : "이미지 저장", systemImage: "square.and.arrow.down")
                }
                .disabled(!viewModel.canExportResult || viewModel.isSavingImage)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title).font(.caption2)
        }
        .frame(minWidth: 60, minHeight: 50)
    }

    private var optionsSheet: some View {
        NavigationStack {
            Form {
                Section("문자 팔레트") {
                    VisualPalettePicker(selectedPreset: $viewModel.selectedPreset) { preset in
                        viewModel.selectPreset(preset)
                        viewModel.generateFinal()
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                    if viewModel.selectedPreset.usesCustomInput {
                        TextField("예: @#*:. TEXTIFY", text: viewModel.customCharactersBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                        Text("중복은 정리하고 공백을 더해요. 최대 24자까지 입력할 수 있어요.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    LabeledContent("출력 폭", value: "\(viewModel.outputWidth)자")
                    Slider(value: viewModel.outputWidthBinding, in: 30...150, step: 10,
                           onEditingChanged: viewModel.handleOutputWidthEditingChanged)
                        .accessibilityLabel("출력 폭")
                    LabeledContent("대비", value: viewModel.contrastDisplayText)
                    Slider(value: viewModel.contrastBoostBinding, in: 0...2, step: 0.1)
                        .accessibilityLabel("대비")
                    Toggle("밝기 반전", isOn: viewModel.invertBrightnessBinding)
                } header: { Text("그림 조정") }
                footer: { Text("폭이 좁으면 짧게 공유하기 좋고, 넓으면 디테일이 살아나요.") }
                Section {
                    Button("기본 설정으로 되돌리기", systemImage: "arrow.counterclockwise") {
                        viewModel.resetOptions()
                    }
                }
            }
            .navigationTitle("세부 조정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { showOptions = false }
                }
            }
        }
        .tint(AppTheme.accent)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private enum ComparisonMode: String, CaseIterable, Identifiable {
    case ascii, original, split
    var id: Self { self }
    var title: String {
        switch self {
        case .ascii: "텍스트 아트"
        case .original: "원본"
        case .split: "비교"
        }
    }
}
