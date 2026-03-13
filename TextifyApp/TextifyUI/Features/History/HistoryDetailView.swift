import SwiftUI

struct HistoryDetailView: View {
    @State var viewModel: HistoryDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                thumbnailSection
                textArtSection
                metadataSection
                actionsSection
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("상세 보기")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if viewModel.showCopyConfirmation {
                CopyConfirmationBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.shareURL != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.shareURL = nil
                    }
                }
            )
        ) {
            if let url = viewModel.shareURL {
                ShareSheet(items: [url])
            }
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var thumbnailSection: some View {
        Group {
            if let uiImage = UIImage(data: viewModel.entry.thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var textArtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("텍스트 아트")
                .font(AppTheme.headlineFont)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(viewModel.textArtString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textArtForeground)
                    .padding()
                    .background(AppTheme.textArtBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("텍스트 아트 결과")
            .accessibilityValue(viewModel.textArtString)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("세부 정보")
                .font(AppTheme.headlineFont)
                .foregroundStyle(.primary)

            MetadataRow(label: "생성 시각", value: viewModel.entry.createdAt.formatted(date: .long, time: .shortened))
            MetadataRow(label: "크기", value: "\(viewModel.entry.width)×\(viewModel.entry.height)")
            MetadataRow(label: "출력 폭", value: "\(viewModel.entry.outputWidth)")
            MetadataRow(label: "문자 팔레트", value: viewModel.entry.sourceCharacters)
            MetadataRow(label: "밝기 반전", value: viewModel.entry.invertBrightness ? "켜짐" : "꺼짐")
            MetadataRow(label: "대비", value: String(format: "%.1f", viewModel.entry.contrastBoost))
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.copyToClipboard()
            } label: {
                Label("텍스트 복사", systemImage: "doc.on.doc")
                    .font(AppTheme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .accessibilityHint("텍스트 아트를 클립보드로 복사합니다")

            Button {
                Task {
                    await viewModel.prepareShareImage()
                }
            } label: {
                Label(viewModel.isPreparingShare ? "공유 준비 중…" : "이미지로 공유", systemImage: "square.and.arrow.up")
                    .font(AppTheme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .disabled(viewModel.isPreparingShare)
            .accessibilityHint("텍스트 아트를 이미지 형태로 공유합니다")
        }
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.bodyFont)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundStyle(.primary)
        }
    }
}

private struct CopyConfirmationBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text("클립보드에 복사했어요")
                .font(AppTheme.bodyFont)
                .foregroundStyle(.primary)
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .padding(.top, 60)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        HistoryDetailView(
            viewModel: HistoryDetailViewModel(
                entry: HistoryEntry(
                    id: UUID(),
                    thumbnailData: Data(),
                    textArtRows: [
                        "@@@@@@@@@@",
                        "@@      @@",
                        "@@  ##  @@",
                        "@@      @@",
                        "@@@@@@@@@@"
                    ],
                    width: 100,
                    height: 50,
                    sourceCharacters: "@#",
                    createdAt: Date(),
                    outputWidth: 80,
                    invertBrightness: false,
                    contrastBoost: 1.2
                ),
                clipboardService: ClipboardService(),
                exportService: ImageExportService()
            )
        )
    }
}
