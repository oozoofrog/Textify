import SwiftUI
import PhotosUI
import CoreGraphics
import TextifyKit

/// 메인 화면 - 사진 선택 + 배경 텍스트 아트 애니메이션
public struct MainView: View {
    @State var viewModel: MainViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var navigateToTextify = false
    @State private var isLoadingImage = false

    public init(viewModel: MainViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // 배경: 흐릿한 텍스트 아트 애니메이션
                BackgroundTextArtAnimation()
                    .ignoresSafeArea()

                // 메인 콘텐츠
                VStack(spacing: 40) {
                    Spacer()

                    // 로고 영역
                    VStack(spacing: 12) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 48))
                            .foregroundStyle(.primary)

                        Text("Textify")
                            .font(.system(size: 40, weight: .bold, design: .rounded))

                        Text("이미지를 텍스트 아트로")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("선명한 사진이 좋은 결과를 만듭니다")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    // 사진 선택 버튼
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                            Text("사진 선택")
                                .font(.title3.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }

                // Loading overlay
                if isLoadingImage {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationDestination(isPresented: $navigateToTextify) {
                if let image = viewModel.selectedImage {
                    TextifyView(
                        viewModel: TextifyViewModel(
                            image: image,
                            generator: viewModel.generator
                        )
                    )
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            HapticsService.shared.impact(style: .medium)
            guard newItem != nil else { return }
            isLoadingImage = true
            Task {
                await viewModel.loadImage(from: newItem)
                isLoadingImage = false
                if viewModel.selectedImage != nil {
                    navigateToTextify = true
                }
            }
        }
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

/// 배경 텍스트 아트 애니메이션
struct BackgroundTextArtAnimation: View {
    @State private var offset: CGFloat = 0

    private let sampleTextArts = [
        """
        @@@@@@@@@@@@@@@@@@
        @@##**++==--::..@@
        @@##  HELLO   ##@@
        @@##  WORLD   ##@@
        @@##**++==--::..@@
        @@@@@@@@@@@@@@@@@@
        """,
        """
        ....::--==++**##@@
        ..              ..
        ::    ♥♥♥♥♥    ::
        --   ♥♥♥♥♥♥♥   --
        ==    ♥♥♥♥♥    ==
        ++     ♥♥♥     ++
        ....::--==++**##@@
        """,
        """
        ████████████████
        █░░░░░░░░░░░░░░█
        █░██░░██░░░░░░░█
        █░░░░░░░░░░░░░░█
        █░░████████░░░░█
        █░░░░░░░░░░░░░░█
        ████████████████
        """
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 40) {
                ForEach(0..<10, id: \.self) { row in
                    HStack(spacing: 30) {
                        ForEach(0..<3, id: \.self) { col in
                            Text(sampleTextArts[(row + col) % sampleTextArts.count])
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.08))
                                .fixedSize()
                        }
                    }
                }
            }
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 20)
                    .repeatForever(autoreverses: true)
                ) {
                    offset = -400
                }
            }
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel(generator: TextArtGenerator()))
}
