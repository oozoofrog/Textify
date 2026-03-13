import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

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
                        linkRow(
                            title: "GitHub",
                            systemImage: "link",
                            url: githubURL
                        )
                        .accessibilityLabel("GitHub 저장소 열기")
                    }

                    if let feedbackURL = URL(string: "https://github.com/oozoofrog/Textify/issues") {
                        linkRow(
                            title: "피드백 및 문제 제보",
                            systemImage: "bubble.left.and.exclamationmark.bubble.right",
                            url: feedbackURL
                        )
                    }
                } header: {
                    Text("정보")
                }

                Section {
                    LabeledContent("사진 저장 권한", value: viewModel.photoPermissionTitle)
                        .accessibilityElement(children: .combine)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("선택한 사진은 서버로 업로드하지 않고 기기 안에서 변환합니다.", systemImage: "lock.shield")
                        Label("이미지 저장은 사용자가 저장 버튼을 눌렀을 때만 사진 앱에 기록합니다.", systemImage: "photo.on.rectangle")
                        Label(viewModel.photoPermissionGuidance, systemImage: "gearshape.2")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 4)

                    Button {
                        openAppSettings()
                    } label: {
                        Label(
                            viewModel.recommendsOpeningSettings ? "설정에서 권한 변경" : "앱 설정 열기",
                            systemImage: "gear"
                        )
                    }
                    .accessibilityHint("iPhone 설정에서 Textify 권한을 조정합니다")
                } header: {
                    Text("개인정보 및 권한")
                } footer: {
                    Text("Textify는 사진 접근과 저장 외에 별도의 계정이나 서버 연결을 요구하지 않습니다.")
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
            .task {
                await viewModel.refreshPhotoSavePermission()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await viewModel.refreshPhotoSavePermission()
                }
            }
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

    @ViewBuilder
    private func linkRow(title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }
}

#Preview("Settings View") {
    SettingsView(
        viewModel: SettingsViewModel(
            appearanceService: AppearanceService(),
            historyService: HistoryService(),
            photoLibrarySaveAuthorizer: PhotoLibraryAuthorizationService()
        )
    )
}
