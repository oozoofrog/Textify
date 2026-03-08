//
//  ControlBottomSheet.swift
//  TextifyUI
//
//  Created by Claude on 2026-01-31.
//

import SwiftUI

/// A draggable bottom sheet that slides up to reveal controls
///
/// Features:
/// - Spring-based slide animations
/// - Velocity-based drag-to-dismiss
/// - Haptic feedback on state changes
/// - Dimmed background overlay
/// - Scrollable content area
public struct ControlBottomSheet<Content: View>: View {
    // MARK: - Properties

    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    @GestureState private var dragOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    private let maxHeight: CGFloat = 600
    private let cornerRadius: CGFloat = 24
    private let grabHandleWidth: CGFloat = 36
    private let grabHandleHeight: CGFloat = 4
    private let dismissThreshold: CGFloat = 150
    private let velocityThreshold: CGFloat = 500

    // MARK: - Initialization

    public init(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background dimmer
            if isPresented {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                    .transition(.opacity)
            }

            // Bottom sheet
            if isPresented {
                VStack(spacing: 0) {
                    // Grab handle
                    grabHandle
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // Content
                    ScrollView {
                        content()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            contentHeight = geometry.size.height
                                        }
                                        .onChange(of: geometry.size.height) { oldValue, newValue in
                                            contentHeight = newValue
                                        }
                                }
                            )
                    }
                    .frame(maxHeight: maxHeight)
                }
                .background(sheetBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 20,
                    x: 0,
                    y: -5
                )
                .offset(y: dragOffset)
                .gesture(dragGesture)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
    }

    // MARK: - View Components

    private var grabHandle: some View {
        RoundedRectangle(cornerRadius: grabHandleHeight / 2)
            .fill(Color.gray.opacity(0.3))
            .frame(width: grabHandleWidth, height: grabHandleHeight)
    }

    private var sheetBackground: some View {
        ZStack {
            // Base layer
            Color(uiColor: .systemBackground)

            // Subtle gradient overlay for depth
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.02)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            // Noise texture for premium feel
            Rectangle()
                .fill(
                    Color.white.opacity(0.01)
                )
                .blendMode(.overlay)
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                // Only allow dragging down
                if value.translation.height > 0 {
                    state = value.translation.height
                }
            }
            .onEnded { value in
                let velocity = value.predictedEndLocation.y - value.location.y
                let translation = value.translation.height

                // Dismiss if dragged past threshold or high downward velocity
                if translation > dismissThreshold || velocity > velocityThreshold {
                    dismiss()
                }
            }
    }

    // MARK: - Actions

    private func dismiss() {
        let haptics = HapticsService.shared
        haptics.impact(style: .light)
        isPresented = false
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    Button("Show Controls") {
                        isPresented.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 100)
                }
            }
            .overlay {
                ControlBottomSheet(isPresented: $isPresented) {
                    VStack(spacing: 24) {
                        Text("Controls")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(0..<5) { index in
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Setting \(index + 1)")
                                        .font(.body)
                                        .fontWeight(.medium)

                                    Text("Adjust this parameter")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: .constant(index % 2 == 0))
                                    .labelsHidden()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                        }
                    }
                }
            }
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    Button("Show Controls") {
                        isPresented.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 100)
                }
            }
            .overlay {
                ControlBottomSheet(isPresented: $isPresented) {
                    VStack(spacing: 24) {
                        Text("Controls")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(0..<8) { index in
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Setting \(index + 1)")
                                        .font(.body)
                                        .fontWeight(.medium)

                                    Text("Adjust this parameter")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: .constant(index % 2 == 0))
                                    .labelsHidden()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                        }
                    }
                }
            }
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
