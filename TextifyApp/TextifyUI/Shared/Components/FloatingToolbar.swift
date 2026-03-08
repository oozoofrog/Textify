import SwiftUI

/// A floating toolbar item with icon, label, and action
public struct FloatingToolbarItem: Identifiable, Sendable {
    public let id: String
    public let icon: String
    public let label: String
    public let action: @Sendable @MainActor () -> Void

    public init(
        id: String,
        icon: String,
        label: String,
        action: @escaping @Sendable @MainActor () -> Void
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.action = action
    }
}

/// A glassmorphic floating toolbar with icon buttons
@MainActor
public struct FloatingToolbar: View {
    let items: [FloatingToolbarItem]
    @Binding var activeItem: String?
    @State private var isVisible = false

    public init(
        items: [FloatingToolbarItem],
        activeItem: Binding<String?>
    ) {
        self.items = items
        self._activeItem = activeItem
    }

    public var body: some View {
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
        .offset(y: isVisible ? 0 : 100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            let animation = Animation.spring(response: 0.3, dampingFraction: 0.7)
            withAnimation(animation.delay(0.1)) {
                isVisible = true
            }
        }
    }

    @ViewBuilder
    private func toolbarButton(for item: FloatingToolbarItem) -> some View {
        let isActive = activeItem == item.id

        Button {
            let haptics = HapticsService.shared
            haptics.selection()
            let animation = Animation.spring(response: 0.3, dampingFraction: 0.7)
            withAnimation(animation) {
                activeItem = item.id
            }
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

            FloatingToolbar(
                items: [
                    FloatingToolbarItem(
                        id: "generate",
                        icon: "wand.and.stars",
                        label: "Generate"
                    ) {},
                    FloatingToolbarItem(
                        id: "edit",
                        icon: "pencil",
                        label: "Edit"
                    ) {},
                    FloatingToolbarItem(
                        id: "share",
                        icon: "square.and.arrow.up",
                        label: "Share"
                    ) {},
                    FloatingToolbarItem(
                        id: "settings",
                        icon: "gearshape.fill",
                        label: "Settings"
                    ) {}
                ],
                activeItem: .constant("generate")
            )
            .padding(.bottom, 40)
        }
    }
}
