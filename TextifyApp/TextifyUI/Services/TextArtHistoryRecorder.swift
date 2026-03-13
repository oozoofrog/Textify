import Foundation
import CoreGraphics
import ImageIO
import TextifyKit

public struct TextArtHistoryRecordRequest: @unchecked Sendable {
    public let sourceImage: CGImage
    public let textArt: TextArt
    public let sourceCharacters: String
    public let outputWidth: Int
    public let invertBrightness: Bool
    public let contrastBoost: Float

    public init(
        sourceImage: CGImage,
        textArt: TextArt,
        sourceCharacters: String,
        outputWidth: Int,
        invertBrightness: Bool,
        contrastBoost: Float
    ) {
        self.sourceImage = sourceImage
        self.textArt = textArt
        self.sourceCharacters = sourceCharacters
        self.outputWidth = outputWidth
        self.invertBrightness = invertBrightness
        self.contrastBoost = contrastBoost
    }

    public var deduplicationKey: String {
        [
            textArt.asString,
            sourceCharacters,
            String(outputWidth),
            String(invertBrightness),
            String(contrastBoost)
        ].joined(separator: "|")
    }
}

public protocol TextArtHistoryRecording: Sendable {
    func record(_ request: TextArtHistoryRecordRequest) async throws
}

public final class TextArtHistoryRecorder: TextArtHistoryRecording, Sendable {
    private let historyService: any HistoryServiceProtocol
    private let thumbnailQueue = DispatchQueue(
        label: "com.textify.history.thumbnail",
        qos: .userInitiated
    )

    public init(historyService: any HistoryServiceProtocol) {
        self.historyService = historyService
    }

    public func record(_ request: TextArtHistoryRecordRequest) async throws {
        let entry = try await makeEntry(from: request)
        try await historyService.add(entry)
    }

    private func makeEntry(from request: TextArtHistoryRecordRequest) async throws -> HistoryEntry {
        try await withCheckedThrowingContinuation { continuation in
            thumbnailQueue.async {
                do {
                    let thumbnailData = try Self.createThumbnail(from: request.sourceImage)
                    let entry = HistoryEntry(
                        thumbnailData: thumbnailData,
                        textArtRows: request.textArt.rows,
                        width: request.textArt.width,
                        height: request.textArt.height,
                        sourceCharacters: request.sourceCharacters,
                        outputWidth: request.outputWidth,
                        invertBrightness: request.invertBrightness,
                        contrastBoost: request.contrastBoost
                    )
                    continuation.resume(returning: entry)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func createThumbnail(from image: CGImage) throws -> Data {
        let maxSize: CGFloat = 200
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(maxSize / width, maxSize / height)
        let newWidth = max(1, Int(width * scale))
        let newHeight = max(1, Int(height * scale))

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw HistoryError.saveFailed(NSError(domain: "TextArtHistoryRecorder", code: -1))
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(newWidth), height: CGFloat(newHeight)))

        guard let thumbnail = context.makeImage() else {
            throw HistoryError.saveFailed(NSError(domain: "TextArtHistoryRecorder", code: -2))
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            throw HistoryError.saveFailed(NSError(domain: "TextArtHistoryRecorder", code: -3))
        }

        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw HistoryError.saveFailed(NSError(domain: "TextArtHistoryRecorder", code: -4))
        }

        return data as Data
    }
}
