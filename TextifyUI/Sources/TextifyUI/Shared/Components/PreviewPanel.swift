import SwiftUI

/// Live text art preview with retro terminal aesthetic
struct PreviewPanel: View {
    let textArt: String?
    let isLoading: Bool

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Terminal background
            AppTheme.textArtBackground

            if isLoading {
                loadingShimmer
            } else if let textArt = textArt, !textArt.isEmpty {
                textArtContent(textArt)
            } else {
                placeholderContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .strokeBorder(AppTheme.textArtForeground.opacity(0.3), lineWidth: 1)
        )
        .accessibilityLabel("Text art preview")
        .accessibilityValue(isLoading ? "Loading" : (textArt != nil ? "Ready" : "No preview"))
    }

    private var loadingShimmer: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.textArtForeground.opacity(0.0),
                            AppTheme.textArtForeground.opacity(0.3),
                            AppTheme.textArtForeground.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: shimmerPhase * geometry.size.width * 2 - geometry.size.width)
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        shimmerPhase = 1.0
                    }
                }
        }
    }

    private func textArtContent(_ text: String) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(.system(size: 5, design: .monospaced))
                .foregroundStyle(AppTheme.textArtForeground)
                .padding(8)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textArtForeground.opacity(0.3))

            Text("No preview available")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textArtForeground.opacity(0.5))
        }
    }
}

#Preview("With Text Art") {
    PreviewPanel(
        textArt: """
        @@@@@@@@@@
        @@      @@
        @@  ##  @@
        @@      @@
        @@@@@@@@@@
        """,
        isLoading: false
    )
    .frame(height: 300)
    .padding()
}

#Preview("Loading") {
    PreviewPanel(
        textArt: nil,
        isLoading: true
    )
    .frame(height: 300)
    .padding()
}

#Preview("Empty") {
    PreviewPanel(
        textArt: nil,
        isLoading: false
    )
    .frame(height: 300)
    .padding()
}
