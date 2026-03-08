import SwiftUI

/// A dismissible error banner with auto-dismiss and swipe gestures
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isDismissing = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text(message)
                .font(AppTheme.bodyFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding()
        .background(
            Color.red.opacity(0.9),
            in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .padding(.horizontal)
        .offset(y: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        offset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -50 {
                        dismiss()
                    } else {
                        withAnimation(AppTheme.springAnimation) {
                            offset = 0
                        }
                    }
                }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if !isDismissing {
                    dismiss()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error")
        .accessibilityValue(message)
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        withAnimation(AppTheme.springAnimation) {
            offset = -200
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

#Preview {
    VStack {
        ErrorBanner(
            message: "Failed to convert image. Please try again.",
            onDismiss: {}
        )

        Spacer()
    }
    .padding(.top, 60)
}
