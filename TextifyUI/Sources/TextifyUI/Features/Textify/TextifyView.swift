import SwiftUI
import CoreGraphics
import TextifyKit

/// 텍스티파이 화면 - 실시간 텍스트 변환
public struct TextifyView: View {
    @State var viewModel: TextifyViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: TextifyViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 상단: 원본 이미지 (작게)
            originalImageSection

            // 중앙: 텍스트 아트 결과
            textArtSection

            // 하단: 컨트롤 패널
            controlPanel
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
                Text(textArt.asString)
                    .font(.system(size: viewModel.fontSize, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
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
    }

    private var controlPanel: some View {
        VStack(spacing: 16) {
            // 프리셋 팔레트 선택
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PalettePreset.allCases, id: \.self) { preset in
                        PaletteButton(
                            preset: preset,
                            isSelected: viewModel.selectedPreset == preset
                        ) {
                            viewModel.selectPreset(preset)
                            Task { await viewModel.generate() }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // 폭 조절 슬라이더
            HStack {
                Text("폭")
                    .foregroundStyle(.secondary)
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
                Text("\(viewModel.outputWidth)")
                    .monospacedDigit()
                    .frame(width: 40)
            }
            .padding(.horizontal)

            // 추가 옵션
            HStack(spacing: 20) {
                Toggle("반전", isOn: $viewModel.invertBrightness)
                    .onChange(of: viewModel.invertBrightness) { _, _ in
                        Task { await viewModel.generate() }
                    }

                Spacer()

                // 폰트 크기 조절
                HStack(spacing: 8) {
                    Button {
                        viewModel.decreaseFontSize()
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                    }
                    .disabled(viewModel.fontSize <= 4)

                    Text("\(Int(viewModel.fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 40)

                    Button {
                        viewModel.increaseFontSize()
                    } label: {
                        Image(systemName: "textformat.size.larger")
                    }
                    .disabled(viewModel.fontSize >= 20)
                }
            }
            .padding(.horizontal)

            // 복사 버튼
            Button {
                viewModel.copyToClipboard()
            } label: {
                Label(
                    viewModel.copied ? "복사됨!" : "텍스트 복사",
                    systemImage: viewModel.copied ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.copied ? Color.green : Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .disabled(viewModel.textArt == nil)
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
    }
}

/// 팔레트 프리셋 버튼
struct PaletteButton: View {
    let preset: PalettePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(preset.preview)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(width: 50, height: 30)
                Text(preset.name)
                    .font(.caption2)
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
