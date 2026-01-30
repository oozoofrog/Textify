import SwiftUI
import CoreGraphics
import TextifyKit

struct GenerationView: View {
    @State var viewModel: GenerationViewModel
    let image: CGImage
    let text: String
    let onComplete: (TextArt, CGImage, String, Int, Bool, Float) -> Void

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isGenerating {
                // Generation in progress
                VStack(spacing: 16) {
                    ProgressView(value: viewModel.progress) {
                        Text("Generating text art...")
                    }
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 32)

                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let error = viewModel.errorMessage {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)

                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        Task {
                            await viewModel.generate(from: image, characters: text)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            } else if let textArt = viewModel.generatedTextArt {
                // Generation complete
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("Generation Complete!")
                        .font(.headline)

                    Text("\(textArt.width) x \(textArt.height) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("View Result") {
                        onComplete(
                            textArt,
                            image,
                            text,
                            viewModel.outputWidth,
                            viewModel.invertBrightness,
                            viewModel.contrastBoost
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                // Options and start
                ScrollView {
                    VStack(spacing: 24) {
                        // Image preview
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Options
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Generation Options")
                                .font(.headline)

                            // Width slider
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Output Width")
                                    Spacer()
                                    Text("\(viewModel.outputWidth) chars")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.outputWidth) },
                                        set: { viewModel.outputWidth = Int($0) }
                                    ),
                                    in: 40...200,
                                    step: 10
                                )
                            }

                            // Invert toggle
                            Toggle("Invert Brightness", isOn: $viewModel.invertBrightness)

                            // Contrast slider
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Contrast")
                                    Spacer()
                                    Text(String(format: "%.1fx", viewModel.contrastBoost))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: $viewModel.contrastBoost,
                                    in: 0.5...2.0,
                                    step: 0.1
                                )
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Generate button
                        Button {
                            Task {
                                await viewModel.generate(from: image, characters: text)
                            }
                        } label: {
                            Text("Start Generation")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Generate")
        .navigationBarBackButtonHidden(viewModel.isGenerating)
    }
}
