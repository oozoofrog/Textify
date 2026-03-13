import Foundation
import CoreGraphics
import UIKit
import Testing
@testable import TextifyUI
@testable import TextifyKit

@Suite("TextArtHistoryRecorder Tests")
struct TextArtHistoryRecorderTests {

    private func makeRequest() -> TextArtHistoryRecordRequest {
        TextArtHistoryRecordRequest(
            sourceImage: Self.createTestImage(),
            textArt: TextArt(
                rows: ["@@", "##"],
                width: 2,
                height: 2,
                sourceCharacters: "@#",
                createdAt: Date(timeIntervalSince1970: 1_234)
            ),
            sourceCharacters: "@#",
            outputWidth: 96,
            invertBrightness: true,
            contrastBoost: 1.6
        )
    }

    @Test("Deduplication key includes generation options")
    func testDeduplicationKeyIncludesGenerationOptions() {
        let request = makeRequest()

        #expect(request.deduplicationKey.contains("@@\n##"))
        #expect(request.deduplicationKey.contains("@#"))
        #expect(request.deduplicationKey.contains("96"))
        #expect(request.deduplicationKey.contains("true"))
        #expect(request.deduplicationKey.contains("1.6"))
    }

    @Test("Recorder persists fully populated history entry")
    func testRecorderPersistsEntry() async throws {
        let historyService = MockHistoryService()
        let recorder = TextArtHistoryRecorder(historyService: historyService)
        let request = makeRequest()

        try await recorder.record(request)

        let entries = await historyService.addedEntries
        #expect(entries.count == 1)

        let entry = try #require(entries.first)
        #expect(entry.textArtRows == ["@@", "##"])
        #expect(entry.width == 2)
        #expect(entry.height == 2)
        #expect(entry.sourceCharacters == "@#")
        #expect(entry.outputWidth == 96)
        #expect(entry.invertBrightness == true)
        #expect(abs(entry.contrastBoost - 1.6) < 0.0001)
        #expect(entry.thumbnailData.isEmpty == false)
    }
}

private extension TextArtHistoryRecorderTests {
    static func createTestImage() -> CGImage {
        let size = CGSize(width: 10, height: 10)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Failed to create test context")
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        guard let image = context.makeImage() else {
            fatalError("Failed to create test image")
        }

        return image
    }
}
