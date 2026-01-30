import SwiftUI

/// History list item with thumbnail, preview, and swipe-to-delete
struct HistoryCard: View {
    let entry: HistoryEntry
    let onDelete: () -> Void
    let onTap: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDeleting = false

    private let deleteThreshold: CGFloat = -100

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail
                thumbnailView
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(.primary)

                    Text("\(entry.width)x\(entry.height)")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.secondary)

                    // Text art preview (first 2 lines)
                    if !entry.textArtRows.isEmpty {
                        Text(previewText)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(AppTheme.textArtForeground)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                AppTheme.textArtBackground,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(alignment: .trailing) {
                // Delete button revealed on swipe
                if dragOffset < -20 {
                    deleteButton
                }
            }
        }
        .buttonStyle(.plain)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width < deleteThreshold {
                        performDelete()
                    } else {
                        withAnimation(AppTheme.springAnimation) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("History entry from \(entry.createdAt.formatted())")
        .accessibilityHint("Swipe left to delete, tap to view")
        .accessibilityAddTraits(.isButton)
    }

    private var thumbnailView: some View {
        Group {
            if let uiImage = UIImage(data: entry.thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.textArtBackground

                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(AppTheme.textArtForeground.opacity(0.5))
                }
            }
        }
    }

    private var previewText: String {
        return entry.textArtRows.prefix(2).joined(separator: "\n")
    }

    private var deleteButton: some View {
        Button(action: performDelete) {
            Image(systemName: "trash.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.red)
                .clipShape(Circle())
        }
        .padding(.trailing, -dragOffset - 80)
        .accessibilityLabel("Delete")
    }

    private func performDelete() {
        guard !isDeleting else { return }
        isDeleting = true

        withAnimation(AppTheme.springAnimation) {
            dragOffset = -500
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDelete()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HistoryCard(
            entry: HistoryEntry(
                id: UUID(),
                thumbnailData: Data(),
                textArtRows: ["@@@@@@", "@@  @@", "@@@@@@"],
                width: 80,
                height: 40,
                sourceCharacters: "@",
                createdAt: Date(),
                outputWidth: 80,
                invertBrightness: false,
                contrastBoost: 1.0
            ),
            onDelete: {},
            onTap: {}
        )

        HistoryCard(
            entry: HistoryEntry(
                id: UUID(),
                thumbnailData: Data(),
                textArtRows: ["### TEXT ###"],
                width: 60,
                height: 30,
                sourceCharacters: "#",
                createdAt: Date().addingTimeInterval(-3600),
                outputWidth: 60,
                invertBrightness: true,
                contrastBoost: 1.2
            ),
            onDelete: {},
            onTap: {}
        )
    }
    .padding()
}
