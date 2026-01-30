import SwiftUI
import TextifyKit

public struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(AppDependencies.self) private var dependencies

    public init(viewModel: HomeViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            VStack(spacing: 32) {
                Spacer()

                // App Icon/Logo area
                Image(systemName: "text.below.photo")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                // Title
                Text("Textify")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Transform images into text art")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Start button
                Button {
                    viewModel.startNewProject()
                } label: {
                    Label("Create New", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.showHistory()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSettings()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .imageSelection:
            ImageSelectionView(
                viewModel: dependencies.makeImageSelectionViewModel(),
                onImageSelected: { image in
                    viewModel.navigateToTextInput(with: image)
                }
            )
        case .textInput(let imageWrapper):
            TextInputView(
                viewModel: dependencies.makeTextInputViewModel(),
                selectedImage: imageWrapper.image,
                onTextConfirmed: { text in
                    viewModel.navigateToGeneration(image: imageWrapper.image, text: text)
                }
            )
        case .generation(let imageWrapper, let text):
            GenerationView(
                viewModel: dependencies.makeGenerationViewModel(),
                image: imageWrapper.image,
                text: text,
                onComplete: { textArt, sourceImage, sourceChars, width, invert, contrast in
                    viewModel.navigateToResult(
                        textArt: textArt,
                        sourceImage: sourceImage,
                        sourceCharacters: sourceChars,
                        outputWidth: width,
                        invertBrightness: invert,
                        contrastBoost: contrast
                    )
                }
            )
        case .result(let textArtWrapper):
            ResultView(
                viewModel: dependencies.makeResultViewModel(
                    textArt: textArtWrapper.textArt,
                    sourceImage: textArtWrapper.sourceImage,
                    sourceCharacters: textArtWrapper.sourceCharacters,
                    outputWidth: textArtWrapper.outputWidth,
                    invertBrightness: textArtWrapper.invertBrightness,
                    contrastBoost: textArtWrapper.contrastBoost
                ),
                onDone: {
                    viewModel.returnToHome()
                }
            )
        case .settings:
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
        case .history:
            HistoryView(viewModel: dependencies.makeHistoryViewModel())
        }
    }
}
