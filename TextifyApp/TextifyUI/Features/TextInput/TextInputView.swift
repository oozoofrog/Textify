import SwiftUI
import CoreGraphics

struct TextInputView: View {
    @State var viewModel: TextInputViewModel
    let selectedImage: CGImage
    let onTextConfirmed: (String) -> Void

    @State private var showingFileImporter = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Image thumbnail
                Image(decorative: selectedImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Preset selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Character Palette")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.presetPalettes.enumerated()), id: \.offset) { index, preset in
                                Button {
                                    viewModel.selectPreset(at: index)
                                } label: {
                                    Text(preset.name)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            viewModel.selectedPresetIndex == index
                                                ? Color.accentColor
                                                : Color.secondary.opacity(0.2)
                                        )
                                        .foregroundStyle(
                                            viewModel.selectedPresetIndex == index
                                                ? .white
                                                : .primary
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Characters (light to dark)")
                            .font(.headline)

                        Spacer()

                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Import", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    TextField("Enter characters...", text: $viewModel.inputText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: viewModel.inputText) { _, _ in
                            // Switch to custom when manually editing
                            if viewModel.selectedPresetIndex != viewModel.presetPalettes.count - 1 {
                                let currentPreset = viewModel.presetPalettes[viewModel.selectedPresetIndex]
                                if viewModel.inputText != currentPreset.characters {
                                    viewModel.selectedPresetIndex = viewModel.presetPalettes.count - 1
                                }
                            }
                        }

                    Text("Characters are used from left (lightest) to right (darkest)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                // Continue button
                Button {
                    onTextConfirmed(viewModel.inputText)
                } label: {
                    Text("Generate Text Art")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isValidInput ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.isValidInput)
            }
            .padding()
        }
        .navigationTitle("Character Palette")
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.plainText]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await viewModel.importFromFile(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}
