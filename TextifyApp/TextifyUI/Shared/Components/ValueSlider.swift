import SwiftUI
import UIKit

/// A custom slider with floating value bubble and haptic feedback
struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?

    @State private var isDragging = false
    @State private var lastHapticValue: Double = 0

    private let hapticGenerator = UISelectionFeedbackGenerator()

    init(
        title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(AppTheme.headlineFont)

                Spacer()

                // Value bubble
                Text(formattedValue)
                    .font(AppTheme.monoFont)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.2))
                    )
                    .foregroundStyle(isDragging ? .white : .primary)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(AppTheme.springAnimation, value: isDragging)
            }

            // Custom styled slider
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        if let step = step {
                            value = round(newValue / step) * step
                        } else {
                            value = newValue
                        }
                        triggerHapticIfNeeded()
                    }
                ),
                in: range,
                onEditingChanged: { editing in
                    withAnimation(AppTheme.springAnimation) {
                        isDragging = editing
                    }
                    if editing {
                        hapticGenerator.prepare()
                    }
                }
            )
            .tint(.accentColor)
            .accessibilityLabel(title)
            .accessibilityValue(formattedValue)
        }
    }

    private var formattedValue: String {
        if let step = step, step == 1.0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func triggerHapticIfNeeded() {
        let threshold: Double = step ?? 0.1

        if abs(value - lastHapticValue) >= threshold {
            hapticGenerator.selectionChanged()
            lastHapticValue = value
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        ValueSlider(
            title: "Width",
            value: .constant(80),
            in: 40...120,
            step: 1
        )

        ValueSlider(
            title: "Contrast",
            value: .constant(1.2),
            in: 0.5...2.0,
            step: 0.1
        )
    }
    .padding()
}
