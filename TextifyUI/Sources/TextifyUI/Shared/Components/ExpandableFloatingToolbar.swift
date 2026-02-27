import SwiftUI

// Ensure FloatingToolbarItem is accessible
// It's defined in FloatingToolbar.swift in the same module

/// A floating toolbar that can expand upward to show control content
@MainActor
public struct ExpandableFloatingToolbar<ControlContent: View>: View {
    let items: [FloatingToolbarItem]
    @Binding var activeItem: String?
    let controlContent: (String) -> ControlContent

    @State private var isExpanded = false
    @State private var isVisible = false

    public init(
        items: [FloatingToolbarItem],
        activeItem: Binding<String?>,
        @ViewBuilder controlContent: @escaping (String) -> ControlContent
    ) {
        self.items = items
        self._activeItem = activeItem
        self.controlContent = controlContent
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Expanded control area (slides up from toolbar)
            if isExpanded, let itemId = activeItem {
                controlContent(itemId)
                    .frame(maxHeight: 120)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: 12,
                        x: 0,
                        y: 5
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                .white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main toolbar
            mainToolbar
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            let animation = Animation.spring(response: 0.3, dampingFraction: 0.7)
            withAnimation(animation.delay(0.1)) {
                isVisible = true
            }
        }
        .onChange(of: activeItem) { _, newValue in
            // Expand when item becomes active, collapse when cleared
            isExpanded = newValue != nil
        }
    }

    @ViewBuilder
    private var mainToolbar: some View {
        HStack(spacing: 24) {
            ForEach(items) { item in
                toolbarButton(for: item)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: Capsule()
        )
        .shadow(
            color: .black.opacity(0.15),
            radius: 20,
            x: 0,
            y: 10
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    .white.opacity(0.2),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func toolbarButton(for item: FloatingToolbarItem) -> some View {
        let isActive = activeItem == item.id

        Button {
            let haptics = HapticsService.shared
            haptics.selection()

            let animation = Animation.spring(response: 0.3, dampingFraction: 0.7)
            withAnimation(animation) {
                // Toggle: if tapping same button, collapse; otherwise switch
                if activeItem == item.id {
                    activeItem = nil
                } else {
                    activeItem = item.id
                }
            }

            // Always call action (let the action handler decide what to do)
            item.action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        isActive ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: Circle()
                    )
                    .scaleEffect(isActive ? 1.1 : 1.0)
            }
        }
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()

            ExpandableFloatingToolbar(
                items: [
                    FloatingToolbarItem(
                        id: "palette",
                        icon: "paintpalette",
                        label: "Palette"
                    ) {},
                    FloatingToolbarItem(
                        id: "settings",
                        icon: "gearshape.fill",
                        label: "Settings"
                    ) {},
                    FloatingToolbarItem(
                        id: "fontSize",
                        icon: "textformat.size",
                        label: "Font Size"
                    ) {},
                    FloatingToolbarItem(
                        id: "copy",
                        icon: "doc.on.doc",
                        label: "Copy"
                    ) {}
                ],
                activeItem: .constant("palette")
            ) { itemId in
                // Sample control content
                VStack(spacing: 8) {
                    Text("Control for: \(itemId)")
                        .font(.headline)

                    HStack {
                        ForEach(0..<5) { _ in
                            Circle()
                                .fill(Color.random)
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
}

// Preview helper
private extension Color {
    static var random: Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
