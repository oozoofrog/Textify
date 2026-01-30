import SwiftUI
import TextifyKit

/// Fullscreen overlay that displays text art in focus mode with zoom and pan controls.
/// Hides all UI chrome to provide an immersive viewing experience.
struct FocusModeOverlay: View {
    let textArt: TextArt
    let fontSize: CGFloat
    @Binding var isActive: Bool

    @State private var showHint = true
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero

    private var currentScale: CGFloat {
        baseScale * gestureScale
    }

    private var currentOffset: CGSize {
        CGSize(
            width: offset.width + gestureOffset.width,
            height: offset.height + gestureOffset.height
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text(textArt.asString)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(currentScale)
                    .offset(currentOffset)

                Spacer()
            }
            .gesture(magnificationGesture)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(singleTapGesture)
            .simultaneousGesture(doubleTapGesture)

            if showHint {
                VStack {
                    Spacer()

                    Text("Tap to exit")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(2.0)) {
                showHint = false
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                baseScale *= value

                // Clamp scale between 0.5x and 5x
                baseScale = min(max(baseScale, 0.5), 5.0)
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }

    private var singleTapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded {
                dismiss()
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                resetZoom()
            }
    }

    private func dismiss() {
        Task { @MainActor in
            HapticsService.shared.impact(style: .light)
            withAnimation(.easeOut(duration: 0.25)) {
                isActive = false
            }
        }
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            baseScale = 1.0
            offset = .zero
        }
    }
}
