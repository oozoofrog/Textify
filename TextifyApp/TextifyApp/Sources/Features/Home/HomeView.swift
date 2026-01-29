import SwiftUI
import TextifyKit

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
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
                onComplete: { textArt in
                    viewModel.navigateToResult(textArt: textArt)
                }
            )
        case .result(let textArtWrapper):
            ResultView(
                viewModel: dependencies.makeResultViewModel(textArt: textArtWrapper.textArt),
                onDone: {
                    viewModel.returnToHome()
                }
            )
        }
    }
}
