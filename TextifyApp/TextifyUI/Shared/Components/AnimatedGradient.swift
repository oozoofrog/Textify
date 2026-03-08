import SwiftUI

/// An animated background gradient with continuous color shifts
struct AnimatedGradient: View {
    @State private var animationPhase: CGFloat = 0

    let colors: [Color]
    let duration: Double

    init(
        colors: [Color] = [
            Color(red: 0.2, green: 0.0, blue: 0.4),
            Color(red: 0.1, green: 0.0, blue: 0.3),
            Color(red: 0.3, green: 0.0, blue: 0.5)
        ],
        duration: Double = 8.0
    ) {
        self.colors = colors
        self.duration = duration
    }

    var body: some View {
        // Use MeshGradient for iOS 18+ if available, otherwise LinearGradient
        if #available(iOS 18.0, *) {
            meshGradientView
        } else {
            linearGradientView
        }
    }

    @available(iOS 18.0, *)
    private var meshGradientView: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: meshPoints,
            colors: meshColors
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .linear(duration: duration)
                .repeatForever(autoreverses: true)
            ) {
                animationPhase = 1.0
            }
        }
    }

    private var linearGradientView: some View {
        LinearGradient(
            colors: colors,
            startPoint: animatedStartPoint,
            endPoint: animatedEndPoint
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .linear(duration: duration)
                .repeatForever(autoreverses: true)
            ) {
                animationPhase = 1.0
            }
        }
    }

    // Animated gradient points
    private var animatedStartPoint: UnitPoint {
        UnitPoint(
            x: 0.5 + 0.3 * cos(animationPhase * .pi * 2),
            y: 0.5 + 0.3 * sin(animationPhase * .pi * 2)
        )
    }

    private var animatedEndPoint: UnitPoint {
        UnitPoint(
            x: 0.5 - 0.3 * cos(animationPhase * .pi * 2),
            y: 0.5 - 0.3 * sin(animationPhase * .pi * 2)
        )
    }

    // Mesh gradient configuration
    @available(iOS 18.0, *)
    private var meshPoints: [SIMD2<Float>] {
        let phase = Float(animationPhase)
        return [
            // Row 1
            SIMD2(0.0, 0.0),
            SIMD2(0.5 + 0.1 * sin(phase * .pi), 0.0),
            SIMD2(1.0, 0.0),
            // Row 2
            SIMD2(0.0, 0.5 + 0.1 * cos(phase * .pi)),
            SIMD2(0.5, 0.5),
            SIMD2(1.0, 0.5 - 0.1 * cos(phase * .pi)),
            // Row 3
            SIMD2(0.0, 1.0),
            SIMD2(0.5 - 0.1 * sin(phase * .pi), 1.0),
            SIMD2(1.0, 1.0)
        ]
    }

    @available(iOS 18.0, *)
    private var meshColors: [Color] {
        colors + colors + colors // Repeat for 9 mesh points
    }
}

#Preview("Animated Gradient") {
    ZStack {
        AnimatedGradient()

        Text("Textify")
            .font(.system(size: 60, weight: .black, design: .rounded))
            .foregroundStyle(.white)
    }
}

#Preview("Custom Colors") {
    AnimatedGradient(
        colors: [.blue, .purple, .pink],
        duration: 5.0
    )
}
