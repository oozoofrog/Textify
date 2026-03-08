import SwiftUI

struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    @State private var selectedEntry: HistoryEntry?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading history...")
                } else if viewModel.entries.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.entries.isEmpty {
                        Button(role: .destructive) {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedEntry) { entry in
                HistoryDetailView(entry: entry)
            }
            .task {
                await viewModel.loadHistory()
            }
            .alert("Clear All History", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    Task {
                        await viewModel.clearAll()
                    }
                }
            } message: {
                Text("This will permanently delete all history entries. This action cannot be undone.")
            }
        }
        .overlay {
            if let error = viewModel.error {
                ErrorBanner(message: error.localizedDescription) {
                    viewModel.error = nil
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("No History Yet")
                .font(AppTheme.titleFont)
                .foregroundStyle(.primary)

            Text("Your text art creations will appear here")
                .font(AppTheme.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.entries) { entry in
                    HistoryCard(
                        entry: entry,
                        onDelete: {
                            Task {
                                await viewModel.deleteEntry(entry)
                            }
                        },
                        onTap: {
                            selectedEntry = entry
                        }
                    )
                }
            }
            .padding()
        }
        .background(AppTheme.background)
    }
}

#Preview {
    HistoryView(
        viewModel: HistoryViewModel(
            historyService: PreviewHistoryService()
        )
    )
}

// Preview helper
private actor PreviewHistoryService: HistoryServiceProtocol {
    func add(_ entry: HistoryEntry) async throws {}
    func delete(id: UUID) async throws {}
    func clear() async throws {}
    func list() async throws -> [HistoryEntry] {
        return [
            HistoryEntry(
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
            HistoryEntry(
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
            )
        ]
    }
}
