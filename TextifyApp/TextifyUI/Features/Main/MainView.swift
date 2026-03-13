import SwiftUI
import PhotosUI
import CoreGraphics

/// 메인 화면 - 사진 선택 + 제품 가치 제안 + 보조 진입점
@MainActor
public struct MainView: View {
    @State var viewModel: MainViewModel
    @Environment(AppDependencies.self) private var dependencies
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var navigateToTextify = false
    @State private var showHistory = false
    @State private var showSettings = false

    public init(viewModel: MainViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                BackgroundTextArtAnimation()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        heroSection
                        featureHighlights
                        primaryActionSection
                        quickActionSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToTextify) {
                if let image = viewModel.selectedImage {
                    TextifyView(
                        viewModel: dependencies.makeTextifyViewModel(image: image)
                    )
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(viewModel: dependencies.makeHistoryViewModel())
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: dependencies.makeSettingsViewModel())
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await viewModel.loadImage(from: newItem)
                if viewModel.selectedImage != nil {
                    selectedPhotoItem = nil
                    navigateToTextify = true
                }
            }
        }
        .onChange(of: navigateToTextify) { _, isPresented in
            if !isPresented {
                viewModel.clearSelection()
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

    private var heroSection: some View {
        VStack(spacing: 18) {
            Text("✦")
                .font(.system(size: 56))

            Text("Textify")
                .font(.system(size: 42, weight: .bold, design: .rounded))

            Text("사진을 ASCII 문자열 패턴의 그림으로")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("사진 한 장을 고르면 복사·공유 가능한 텍스트 아트가 바로 만들어집니다.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 24)
    }

    private var featureHighlights: some View {
        VStack(spacing: 12) {
            LaunchFeatureCard(
                icon: "bolt.fill",
                title: "빠른 첫 결과",
                description: "사진 선택 직후 기본 설정으로 즉시 생성합니다."
            )
            LaunchFeatureCard(
                icon: "paintpalette.fill",
                title: "팔레트 실험",
                description: "기본, 블록, 점, 숫자 등 다양한 문자 분위기를 비교합니다."
            )
            LaunchFeatureCard(
                icon: "square.and.arrow.up.fill",
                title: "바로 소비",
                description: "복사, 공유, 저장으로 결과를 곧바로 활용합니다."
            )
        }
    }

    private var primaryActionSection: some View {
        let isLoading = viewModel.isLoading

        return PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "photo.fill")
                        .font(.title3)
                }

                Text(isLoading ? "이미지 불러오는 중…" : "사진 선택하고 시작하기")
                    .font(.title3.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color.cyan, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: .cyan.opacity(0.25), radius: 18, x: 0, y: 10)
        }
        .disabled(isLoading)
    }

    private var quickActionSection: some View {
        HStack(spacing: 12) {
            Button {
                showHistory = true
            } label: {
                LaunchSecondaryActionButton(
                    icon: "clock.arrow.circlepath",
                    title: "최근 작업"
                )
            }
            .buttonStyle(.plain)

            Button {
                showSettings = true
            } label: {
                LaunchSecondaryActionButton(
                    icon: "gearshape.fill",
                    title: "설정"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 20)
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
        GeometryReader { _ in
            VStack(spacing: 36) {
                ForEach(0..<10, id: \.self) { row in
                    HStack(spacing: 28) {
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
                    .linear(duration: 20)
                    .repeatForever(autoreverses: false)
                ) {
                    offset = -400
                }
            }
        }
    }
}

private struct LaunchFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LaunchSecondaryActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    MainView(viewModel: MainViewModel(photoLibraryService: PhotoLibraryService()))
        .environment(AppDependencies())
}
