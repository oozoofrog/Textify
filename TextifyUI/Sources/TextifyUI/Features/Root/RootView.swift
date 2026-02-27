import SwiftUI
import PhotosUI
import CoreGraphics
import TextifyKit
import UniformTypeIdentifiers

/// 앱의 루트 화면 - 앱 실행 시 바로 이미지 선택 또는 TextifyView로 이동
public struct RootView: View {
    @State private var viewModel: RootViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var isLoadingImage = false
    @State private var showPhotoPicker = false

    public init(generator: TextArtGenerator) {
        self._viewModel = State(initialValue: RootViewModel(generator: generator))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                Color.black.ignoresSafeArea()

                // 선택된 이미지가 있으면 TextifyView로
                if let image = viewModel.selectedImage {
                    TextifyView(
                        viewModel: TextifyViewModel(
                            image: image,
                            generator: viewModel.generator
                        ),
                        onChangeImage: {
                            viewModel.clearSelection()
                            showPhotoPicker = true
                        }
                    )
                } else {
                    // 이미지 선택 대기 화면 (최소한의 UI)
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("이미지를 선택하세요")
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)
                    }
                    // PhotosPicker 자동 표시
                    .photosPicker(
                        isPresented: $showPhotoPicker,
                        selection: $selectedPhotoItem,
                        matching: .images
                    )
                    // 파일 임포터
                    .fileImporter(
                        isPresented: $showingFileImporter,
                        allowedContentTypes: [.image],
                        allowsMultipleSelection: false
                    ) { result in
                        handleFileImport(result: result)
                    }
                    // 앱 실행 시 바로 사진 선택 화면 표시
                    .onAppear {
                        showPhotoPicker = true
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        HapticsService.shared.impact(style: .medium)
                        guard newItem != nil else {
                            // 사용자가 취소한 경우 → 파일 선택으로 전환
                            showingFileImporter = true
                            return
                        }
                        isLoadingImage = true
                        Task {
                            await viewModel.loadImage(from: newItem)
                            isLoadingImage = false
                        }
                    }
                }

                // Loading overlay
                if isLoadingImage {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") {
                viewModel.errorMessage = nil
                showPhotoPicker = true
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        HapticsService.shared.impact(style: .medium)

        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                showPhotoPicker = true
                return
            }

            isLoadingImage = true
            Task {
                await viewModel.loadImage(from: url)
                isLoadingImage = false
            }

        case .failure:
            viewModel.errorMessage = "파일을 불러올 수 없습니다"
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
public final class RootViewModel {
    public var selectedImage: CGImage?
    public var isLoading = false
    public var errorMessage: String?

    let generator: TextArtGenerator

    public init(generator: TextArtGenerator) {
        self.generator = generator
    }

    public func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoading = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ImageError.loadFailed
            }

            guard let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                throw ImageError.invalidFormat
            }

            selectedImage = cgImage
        } catch {
            errorMessage = "이미지를 불러올 수 없습니다: \(error.localizedDescription)"
            selectedImage = nil
        }

        isLoading = false
    }

    public func loadImage(from url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw ImageError.loadFailed
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)

            guard let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                throw ImageError.invalidFormat
            }

            selectedImage = cgImage
        } catch {
            errorMessage = "파일을 불러올 수 없습니다: \(error.localizedDescription)"
            selectedImage = nil
        }

        isLoading = false
    }

    public func clearSelection() {
        selectedImage = nil
        errorMessage = nil
    }
}

enum ImageError: LocalizedError {
    case loadFailed
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "이미지를 불러오는데 실패했습니다"
        case .invalidFormat:
            return "지원하지 않는 이미지 형식입니다"
        }
    }
}

#Preview {
    RootView(generator: TextArtGenerator())
}
