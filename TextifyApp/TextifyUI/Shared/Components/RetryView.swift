import SwiftUI

/// Full screen retry state with error messaging and actions
struct RetryView: View {
    let error: AppError
    let onRetry: () -> Void
    let onCancel: (() -> Void)?

    init(
        error: AppError,
        onRetry: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Error icon with pulsing animation
            errorIcon

            // Error message
            VStack(spacing: 12) {
                Text("오류 발생")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(error.localizedDescription)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                LoadingButton(
                    title: "Try Again",
                    isLoading: false,
                    action: onRetry
                )

                if let onCancel = onCancel {
                    Button("Cancel", action: onCancel)
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error occurred")
        .accessibilityValue(error.localizedDescription)
    }

    private var errorIcon: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.1))
                .frame(width: 120, height: 120)
                .modifier(PulsingModifier())

            Image(systemName: errorIconName)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(.red)
        }
    }

    private var errorIconName: String {
        switch error {
        case .imageLoad:
            return "photo.badge.exclamationmark"
        case .generation:
            return "exclamationmark.triangle"
        case .export:
            return "externaldrive.badge.exclamationmark"
        case .clipboard:
            return "doc.on.clipboard"
        case .fileAccess:
            return "hand.raised"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .validation:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Pulsing Animation Modifier

private struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

#Preview("Image Load Error") {
    RetryView(
        error: .imageLoad(underlying: nil),
        onRetry: {},
        onCancel: {}
    )
}

#Preview("Generation Error") {
    RetryView(
        error: .generation(underlying: nil),
        onRetry: {}
    )
}

#Preview("Export Error") {
    RetryView(
        error: .export(underlying: nil),
        onRetry: {},
        onCancel: {}
    )
}
