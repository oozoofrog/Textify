import UIKit
import CoreGraphics

/// Factory for generating preview images from SF Symbols
public final class PreviewImageFactory: Sendable {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let symbolName: String
        public let pointSize: CGFloat
        public let weight: UIImage.SymbolWeight
        public let tintColor: UIColor
        public let backgroundColor: UIColor
        public let scale: CGFloat

        public init(
            symbolName: String = "face.smiling.fill",
            pointSize: CGFloat = 200,
            weight: UIImage.SymbolWeight = .regular,
            tintColor: UIColor = .black,
            backgroundColor: UIColor = .white,
            scale: CGFloat = 1
        ) {
            self.symbolName = symbolName
            self.pointSize = pointSize
            self.weight = weight
            self.tintColor = tintColor
            self.backgroundColor = backgroundColor
            self.scale = scale
        }

        public static let `default` = Configuration()
    }

    // MARK: - Singleton

    public static let shared = PreviewImageFactory()

    private init() {}

    // MARK: - Public Methods

    /// Creates a CGImage from an SF Symbol with the given configuration
    /// - Parameter configuration: The configuration for the image
    /// - Returns: A CGImage, or nil if creation fails
    public func createImage(with configuration: Configuration = .default) -> CGImage? {
        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: configuration.pointSize,
            weight: configuration.weight
        )

        guard let symbolImage = UIImage(
            systemName: configuration.symbolName,
            withConfiguration: symbolConfig
        ) else {
            return nil
        }

        let tintedImage = symbolImage.withTintColor(
            configuration.tintColor,
            renderingMode: .alwaysOriginal
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = configuration.scale

        let renderer = UIGraphicsImageRenderer(size: tintedImage.size, format: format)

        let renderedImage = renderer.image { context in
            configuration.backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: tintedImage.size))
            tintedImage.draw(in: CGRect(origin: .zero, size: tintedImage.size))
        }

        return renderedImage.cgImage
    }

    /// Creates a CGImage from an SF Symbol with default configuration
    /// - Returns: A CGImage using default settings
    public func createDefaultImage() -> CGImage? {
        createImage(with: .default)
    }

    /// Creates a CGImage from the specified SF Symbol name
    /// - Parameter symbolName: The name of the SF Symbol
    /// - Returns: A CGImage, or nil if creation fails
    public func createImage(symbolName: String) -> CGImage? {
        createImage(with: Configuration(symbolName: symbolName))
    }
}

// MARK: - Convenience Extensions

public extension PreviewImageFactory.Configuration {
    static let smilingFace = Self(symbolName: "face.smiling.fill")
    static let star = Self(symbolName: "star.fill")
    static let heart = Self(symbolName: "heart.fill")
    static let photo = Self(symbolName: "photo.fill")
}
