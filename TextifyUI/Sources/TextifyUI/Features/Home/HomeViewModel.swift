import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// Navigation destinations for the app
public enum AppDestination: Hashable {
    case imageSelection
    case textInput(ImageWrapper)
    case generation(ImageWrapper, String)
    case result(TextArtWrapper)
    case settings
    case history
}

/// Wrapper to make CGImage Hashable for navigation
public struct ImageWrapper: Hashable {
    public let image: CGImage
    private let id = UUID()

    public init(image: CGImage) {
        self.image = image
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ImageWrapper, rhs: ImageWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

/// Wrapper to make TextArt Hashable for navigation
public struct TextArtWrapper: Hashable {
    public let textArt: TextArt
    public let sourceImage: CGImage?
    public let sourceCharacters: String
    public let outputWidth: Int
    public let invertBrightness: Bool
    public let contrastBoost: Float
    private let id = UUID()

    public init(
        textArt: TextArt,
        sourceImage: CGImage? = nil,
        sourceCharacters: String = "",
        outputWidth: Int = 80,
        invertBrightness: Bool = false,
        contrastBoost: Float = 1.0
    ) {
        self.textArt = textArt
        self.sourceImage = sourceImage
        self.sourceCharacters = sourceCharacters
        self.outputWidth = outputWidth
        self.invertBrightness = invertBrightness
        self.contrastBoost = contrastBoost
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: TextArtWrapper, rhs: TextArtWrapper) -> Bool {
        lhs.id == rhs.id
    }
}

/// ViewModel for the home screen
@Observable
@MainActor
public final class HomeViewModel {
    public var navigationPath = NavigationPath()

    public init() {}

    public func startNewProject() {
        navigationPath.append(AppDestination.imageSelection)
    }

    public func navigateToTextInput(with image: CGImage) {
        navigationPath.append(AppDestination.textInput(ImageWrapper(image: image)))
    }

    public func navigateToGeneration(image: CGImage, text: String) {
        navigationPath.append(AppDestination.generation(ImageWrapper(image: image), text))
    }

    public func navigateToResult(
        textArt: TextArt,
        sourceImage: CGImage? = nil,
        sourceCharacters: String = "",
        outputWidth: Int = 80,
        invertBrightness: Bool = false,
        contrastBoost: Float = 1.0
    ) {
        navigationPath.append(AppDestination.result(TextArtWrapper(
            textArt: textArt,
            sourceImage: sourceImage,
            sourceCharacters: sourceCharacters,
            outputWidth: outputWidth,
            invertBrightness: invertBrightness,
            contrastBoost: contrastBoost
        )))
    }

    public func returnToHome() {
        navigationPath.removeLast(navigationPath.count)
    }

    public func showSettings() {
        navigationPath.append(AppDestination.settings)
    }

    public func showHistory() {
        navigationPath.append(AppDestination.history)
    }
}
