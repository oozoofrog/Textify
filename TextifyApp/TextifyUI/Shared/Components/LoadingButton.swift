import SwiftUI
import UIKit

/// A button with loading state, haptic feedback, and spring animation
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(AppTheme.headlineFont)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isLoading ? Color.secondary : Color.accentColor,
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )
            .foregroundStyle(.white)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AppTheme.springAnimation, value: isPressed)
        }
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
        .accessibilityHint(isLoading ? "Loading" : "")
    }

    private func handleTap() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Press animation
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
        }

        action()
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingButton(title: "Convert Image", isLoading: false) {
            print("Tapped")
        }

        LoadingButton(title: "Converting...", isLoading: true) {
            print("Tapped")
        }
    }
    .padding()
}
