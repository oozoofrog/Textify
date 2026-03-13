import SwiftUI
import TextifyUI

@main
struct TextifyApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: dependencies.makeMainViewModel())
                .environment(dependencies)
                .preferredColorScheme(dependencies.appearanceService.currentMode.colorScheme)
        }
    }
}
