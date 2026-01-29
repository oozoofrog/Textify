import SwiftUI
import TextifyKit

@main
struct TextifyApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: dependencies.makeHomeViewModel())
                .environment(dependencies)
        }
    }
}
