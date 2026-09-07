import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreGraphics

/// Entry points into a single photo-to-text workspace.
@MainActor
public struct MainView: View {
    @State var viewModel: MainViewModel
    @Environment(AppDependencies.self) private var dependencies
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var navigateToTextify = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showFileImporter = false

    public init(viewModel: MainViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    introduction
                    sampleArtwork
                    importActions
                    Label("사진과 결과는 기기 안에서만 처리해요", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.studioBackground)
            .navigationTitle("Textify")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("최근 작업", systemImage: "clock.arrow.circlepath") { showHistory = true }
                    Button("설정", systemImage: "gearshape") { showSettings = true }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToTextify) {
                if let image = viewModel.selectedImage {
                    TextifyView(viewModel: dependencies.makeTextifyViewModel(image: image))
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(viewModel: dependencies.makeHistoryViewModel())
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: dependencies.makeSettingsViewModel())
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url):
                    Task {
                        if await viewModel.loadImage(fromFile: url) { navigateToTextify = true }
                    }
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError {
                        viewModel.errorMessage = "파일을 열지 못했습니다. 다시 선택해 주세요."
                    }
                }
            }
        }
        .tint(AppTheme.accent)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if await viewModel.loadImage(from: newItem) {
                    navigateToTextify = true
                }
                selectedPhotoItem = nil
            }
        }
        .onChange(of: navigateToTextify) { _, isPresented in
            if !isPresented { viewModel.clearSelection() }
        }
        .alert("이미지를 불러오지 못했어요", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHOTO → TEXT ART")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(2)
                .foregroundStyle(AppTheme.accent)
            Text("사진을,\n문자로 그리다.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
            Text("한 장을 고르고, 분위기를 바꾸고,\n나만의 텍스트 아트를 나눠 보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sampleArtwork: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 5) {
                    ForEach(0..<3) { _ in Circle().frame(width: 5, height: 5) }
                }
                .foregroundStyle(AppTheme.canvasForeground.opacity(0.4))
                Spacer()
                Text("문자로 그린 풍경 · 예시")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(AppTheme.canvasForeground.opacity(0.7))
            }
            Text(Self.sampleArt)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineSpacing(1)
                .foregroundStyle(AppTheme.canvasForeground)
                .fixedSize()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("문자로 그린 산과 해의 예시")
            HStack {
                Text("@ # + : .")
                Spacer()
                Text("사진 속 풍경이 문자가 되는 순간")
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(AppTheme.canvasForeground.opacity(0.65))
        }
        .padding(20)
        .background(AppTheme.canvasBackground, in: RoundedRectangle(cornerRadius: 24))
    }

    private var importActions: some View {
        let isLoading = viewModel.isLoading
        return VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 10) {
                    if isLoading { ProgressView().tint(.white) }
                    else { Image(systemName: "photo.on.rectangle.angled") }
                    Text(isLoading ? "이미지 불러오는 중…" : "사진으로 시작")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(18)
                .foregroundStyle(.white)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 18))
            }
            .disabled(isLoading)
            .accessibilityIdentifier("import-photo")

            Button {
                showFileImporter = true
            } label: {
                Label("파일에서 이미지 가져오기", systemImage: "folder")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isLoading)
            .accessibilityIdentifier("import-file")
        }
    }

    private static let sampleArt = #"""
                       .:---:.
                      :+@@@@@+:
                       ':---:'
              /\
             /##\       /\
            /####\     /##\
       /\  /##++##\   /####\
      /##\/##+..+##\ /##++##\
     /#######....+###/##+..+##\
    /########+....+####+....+##\
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      . : .   . : .   . : .   . : .
    """#
}

#Preview {
    MainView(viewModel: MainViewModel(photoLibraryService: PhotoLibraryService()))
        .environment(AppDependencies())
}
