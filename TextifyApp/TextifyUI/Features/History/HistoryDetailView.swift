import SwiftUI
import UIKit

struct HistoryDetailView: View {
    let entry: HistoryEntry

    @State private var showShareSheet = false
    @State private var showCopyConfirmation = false
    @State private var renderedImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Thumbnail
                thumbnailSection

                // Text art display
                textArtSection

                // Metadata
                metadataSection

                // Actions
                actionsSection
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showCopyConfirmation {
                CopyConfirmationBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
    }

    private var thumbnailSection: some View {
        Group {
            if let uiImage = UIImage(data: entry.thumbnailData) {
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
            Text("Text Art")
                .font(AppTheme.headlineFont)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(entry.textArtRows.joined(separator: "\n"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textArtForeground)
                    .padding()
                    .background(AppTheme.textArtBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Text art output")
            .accessibilityValue(entry.textArtRows.joined(separator: "\n"))
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(AppTheme.headlineFont)
                .foregroundStyle(.primary)

            MetadataRow(label: "Created", value: entry.createdAt.formatted(date: .long, time: .shortened))
            MetadataRow(label: "Dimensions", value: "\(entry.width)×\(entry.height)")
            MetadataRow(label: "Output Width", value: "\(entry.outputWidth)")
            MetadataRow(label: "Characters", value: entry.sourceCharacters)
            MetadataRow(label: "Inverted", value: entry.invertBrightness ? "Yes" : "No")
            MetadataRow(label: "Contrast", value: String(format: "%.1f", entry.contrastBoost))
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                copyToClipboard()
            } label: {
                Label("Copy Text Art", systemImage: "doc.on.doc")
                    .font(AppTheme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .accessibilityHint("Copies the text art to clipboard")

            Button {
                saveAsImage()
            } label: {
                Label("Save as Image", systemImage: "square.and.arrow.down")
                    .font(AppTheme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .accessibilityHint("Saves the text art as an image")
        }
    }

    private func copyToClipboard() {
        let textArt = entry.textArtRows.joined(separator: "\n")
        UIPasteboard.general.string = textArt

        withAnimation(AppTheme.springAnimation) {
            showCopyConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(AppTheme.springAnimation) {
                showCopyConfirmation = false
            }
        }
    }

    private func saveAsImage() {
        // Render text art to image
        let textArt = entry.textArtRows.joined(separator: "\n")
        let renderer = ImageRenderer(
            content: Text(textArt)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.textArtForeground)
                .padding()
                .background(AppTheme.textArtBackground)
        )

        if let image = renderer.uiImage {
            renderedImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Supporting Views

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

            Text("Copied to clipboard")
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
            )
        )
    }
}
