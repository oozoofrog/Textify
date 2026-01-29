import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// Navigation destinations for the app
enum AppDestination: Hashable {
    case imageSelection
    case textInput(ImageWrapper)
    case generation(ImageWrapper, String)
    case result(TextArtWrapper)
}

/// Wrapper to make CGImage Hashable for navigation
struct ImageWrapper: Hashable {
    let image: CGImage
    private let id = UUID()

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ImageWrapper, rhs: ImageWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

/// Wrapper to make TextArt Hashable for navigation
struct TextArtWrapper: Hashable {
    let textArt: TextArt
    private let id = UUID()

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TextArtWrapper, rhs: TextArtWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

/// ViewModel for the home screen
@Observable
@MainActor
final class HomeViewModel {
    var navigationPath = NavigationPath()

    func startNewProject() {
        navigationPath.append(AppDestination.imageSelection)
    }

    func navigateToTextInput(with image: CGImage) {
        navigationPath.append(AppDestination.textInput(ImageWrapper(image: image)))
    }

    func navigateToGeneration(image: CGImage, text: String) {
        navigationPath.append(AppDestination.generation(ImageWrapper(image: image), text))
    }

    func navigateToResult(textArt: TextArt) {
        navigationPath.append(AppDestination.result(TextArtWrapper(textArt: textArt)))
    }

    func returnToHome() {
        navigationPath.removeLast(navigationPath.count)
    }
}
