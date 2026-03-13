import SwiftUI

struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    @Environment(AppDependencies.self) private var dependencies
    @State private var selectedEntry: HistoryEntry?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("히스토리를 불러오는 중…")
                } else if viewModel.entries.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("최근 작업")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.entries.isEmpty {
                        Button(role: .destructive) {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Label("전체 삭제", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedEntry) { entry in
                HistoryDetailView(viewModel: dependencies.makeHistoryDetailViewModel(entry: entry))
            }
            .task {
                await viewModel.loadHistory()
            }
            .alert("히스토리 전체 삭제", isPresented: $viewModel.showDeleteConfirmation) {
                Button("취소", role: .cancel) { }
                Button("전체 삭제", role: .destructive) {
                    Task {
                        await viewModel.clearAll()
                    }
                }
            } message: {
                Text("저장된 히스토리 항목이 모두 삭제되며 복구할 수 없습니다.")
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

            Text("아직 저장된 결과가 없어요")
                .font(AppTheme.titleFont)
                .foregroundStyle(.primary)

            Text("생성된 텍스트 아트를 복사하거나 저장하면 최근 작업에 남습니다.")
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
    .environment(AppDependencies())
}

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
