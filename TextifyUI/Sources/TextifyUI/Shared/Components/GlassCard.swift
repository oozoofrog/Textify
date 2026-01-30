import SwiftUI

/// A glassmorphism container with frosted background and elegant shadows
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )
            .shadow(
                color: .black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 4
            )
            .accessibilityElement(children: .contain)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Glassmorphism")
                    .font(AppTheme.headlineFont)
                Text("Frosted glass effect with depth and elegance")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .padding()
    }
}
