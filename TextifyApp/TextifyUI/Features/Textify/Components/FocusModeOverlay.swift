import SwiftUI
import UIKit
import TextifyKit

/// Measures the actual font, including fallback glyphs, to fit the complete artwork.
struct FittedTextArt: View {
    let textArt: TextArt

    var body: some View {
        GeometryReader { proxy in
            let text = textArt.asString
            let referenceFont = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            let measured = (text as NSString).size(withAttributes: [.font: referenceFont])
            let scale = min(proxy.size.width / max(measured.width, 1), proxy.size.height / max(measured.height, 1))
            Text(text)
                .font(.system(size: max(10 * scale, 0.1), design: .monospaced))
                .foregroundStyle(AppTheme.canvasForeground)
                .fixedSize()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityLabel("텍스트 아트, 가로 \(textArt.width)자, 세로 \(textArt.height)줄")
        }
        .clipped()
    }
}

/// Full-screen inspection with discoverable controls as well as pinch/pan gestures.
struct FocusModeOverlay: View {
    let textArt: TextArt
    @Binding var isActive: Bool
    @State private var scale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("전체 보기").font(.headline)
                Spacer()
                Button("닫기", systemImage: "xmark") { isActive = false }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }
            FittedTextArt(textArt: textArt)
                .scaleEffect(scale * gestureScale)
                .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in state = value }
                    .onEnded { scale = min(max(scale * $0, 1), 8) })
                .simultaneousGesture(DragGesture()
                    .updating($gestureOffset) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    })
            HStack(spacing: 24) {
                Button("축소", systemImage: "minus.magnifyingglass") { scale = max(scale - 0.5, 1) }
                    .labelStyle(.iconOnly)
                    .disabled(scale <= 1)
                Button("화면에 맞춤") { scale = 1; offset = .zero }
                Button("확대", systemImage: "plus.magnifyingglass") { scale = min(scale + 0.5, 8) }
                    .labelStyle(.iconOnly)
                    .disabled(scale >= 8)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            Text("두 손가락으로 확대하고 드래그해 살펴보세요")
                .font(.caption)
                .foregroundStyle(AppTheme.canvasForeground.opacity(0.7))
        }
        .padding(20)
        .background(AppTheme.canvasBackground.ignoresSafeArea())
        .foregroundStyle(AppTheme.canvasForeground)
        .tint(AppTheme.canvasForeground)
    }
}
