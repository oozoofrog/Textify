import SwiftUI
import TextifyKit

struct ResultView: View {
    @State var viewModel: ResultViewModel
    let onDone: () -> Void

    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Text art display
            ScrollView([.horizontal, .vertical]) {
                Text(viewModel.textArtString)
                    .font(.system(size: 8, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .foregroundStyle(.green)

            // Info bar
            HStack {
                Label(viewModel.dimensions, systemImage: "aspectratio")
                Spacer()
                Label("\(viewModel.characterCount) chars", systemImage: "character")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))

            // Action buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Copy button
                    Button {
                        viewModel.copyToClipboard()
                    } label: {
                        Label(
                            viewModel.showCopiedFeedback ? "Copied!" : "Copy",
                            systemImage: viewModel.showCopiedFeedback ? "checkmark" : "doc.on.doc"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isCopying)

                    // Share button using ShareLink (cross-platform)
                    ShareLink(item: viewModel.textArtString) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // Save as Image button
                Button {
                    Task {
                        await viewModel.saveAsImage()
                    }
                } label: {
                    Label(
                        viewModel.showSavedFeedback ? "Saved!" : "Save Image",
                        systemImage: viewModel.showSavedFeedback ? "checkmark" : "photo.badge.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isExporting)

                // Done button
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .navigationTitle("Result")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
