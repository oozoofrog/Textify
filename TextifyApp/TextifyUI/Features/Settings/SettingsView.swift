import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("테마", selection: $viewModel.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("외형 모드")
                    .accessibilityHint("시스템, 라이트, 다크 중 하나를 선택합니다")
                } header: {
                    Text("외형")
                } footer: {
                    Text("앱의 전반적인 표시 모드를 설정합니다")
                }

                Section {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("앱 버전 \(appVersion)")

                    if let githubURL = URL(string: "https://github.com/oozoofrog/Textify") {
                        Link(destination: githubURL) {
                            HStack {
                                Label("GitHub", systemImage: "link")
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("GitHub 저장소 열기")
                    }
                } header: {
                    Text("정보")
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.requestClearHistory()
                    } label: {
                        if viewModel.isClearingHistory {
                            Label("히스토리 삭제 중…", systemImage: "hourglass")
                        } else {
                            Label("히스토리 전체 삭제", systemImage: "trash")
                        }
                    }
                    .disabled(viewModel.isClearingHistory)
                    .accessibilityLabel("히스토리 전체 삭제")
                    .accessibilityHint("저장된 히스토리 항목을 모두 삭제합니다")
                } header: {
                    Text("데이터")
                } footer: {
                    Text("이 작업은 되돌릴 수 없습니다")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "히스토리를 삭제할까요?",
                isPresented: $viewModel.showClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("전체 삭제", role: .destructive) {
                    Task {
                        await viewModel.confirmClearHistory()
                    }
                }
                Button("취소", role: .cancel) {
                    viewModel.cancelClearHistory()
                }
            } message: {
                Text("저장된 히스토리 항목이 모두 삭제되며 복구할 수 없습니다.")
            }
            .alert(
                "오류",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("확인", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

#Preview("Settings View") {
    SettingsView(
        viewModel: SettingsViewModel(
            appearanceService: AppearanceService(),
            historyService: HistoryService()
        )
    )
}
