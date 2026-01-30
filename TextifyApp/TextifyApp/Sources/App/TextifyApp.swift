import SwiftUI
import TextifyUI
import TextifyKit

@main
struct TextifyApp: App {
    @State private var generator = TextArtGenerator()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(generator: generator))
        }
    }
}
