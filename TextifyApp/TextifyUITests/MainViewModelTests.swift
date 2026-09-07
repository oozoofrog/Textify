import Testing
import Foundation
import CoreGraphics
import PhotosUI
import SwiftUI
@testable import TextifyUI

/// Deliberately ignores cancellation so tests can complete requests in any order.
private actor ControlledPhotoLoader: PhotoLibraryLoading {
    private var pending: [String: CheckedContinuation<CGImage, Error>] = [:]
    private(set) var started: Set<String> = []

    func loadImage(from item: PhotosPickerItem) async throws -> CGImage {
        try await load(key: item.itemIdentifier ?? "photo")
    }

    func loadImage(fromFile url: URL) async throws -> CGImage {
        try await load(key: url.lastPathComponent)
    }

    private func load(key: String) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            pending[key] = continuation
            started.insert(key)
        }
    }

    func finish(_ key: String, result: Result<CGImage, Error>) {
        pending.removeValue(forKey: key)?.resume(with: result)
    }
}

@Suite("Main image loading")
@MainActor
struct MainViewModelTests {
    private func image(width: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        return try #require(context.makeImage())
    }

    private func waitFor(_ key: String, in loader: ControlledPhotoLoader) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !(await loader.started.contains(key)) {
            guard ContinuousClock.now < deadline else { throw CocoaError(.coderInvalidValue) }
            await Task.yield()
        }
    }

    @Test("File selection publishes the loaded image")
    func fileSuccess() async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let task = Task { await viewModel.loadImage(fromFile: URL(filePath: "/image.png")) }
        try await waitFor("image.png", in: loader)
        #expect(viewModel.isLoading)
        #expect(viewModel.selectedImage == nil)
        await loader.finish("image.png", result: .success(try image(width: 20)))
        #expect(await task.value)
        #expect(viewModel.selectedImage?.width == 20)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(await viewModel.loadImage(from: nil) == false)
        #expect(viewModel.selectedImage?.width == 20)
    }

    @Test("Photo selection retains its existing public entry point")
    func photoSuccess() async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let task = Task { await viewModel.loadImage(from: PhotosPickerItem(itemIdentifier: "photo")) }
        try await waitFor("photo", in: loader)
        await loader.finish("photo", result: .success(try image(width: 30)))
        #expect(await task.value)
        #expect(viewModel.selectedImage?.width == 30)
        #expect(!viewModel.isLoading)
    }

    @Test("File failures become a visible error and end loading")
    func fileFailure() async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let task = Task { await viewModel.loadImage(fromFile: URL(filePath: "/missing.png")) }
        try await waitFor("missing.png", in: loader)
        await loader.finish("missing.png", result: .failure(PhotoLibraryError.fileLoadFailed))
        #expect(await task.value == false)
        #expect(viewModel.errorMessage?.contains("파일을 읽지 못했습니다") == true)
        #expect(viewModel.selectedImage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Cancelled loading does not display an error")
    func cancellation() async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let task = Task { await viewModel.loadImage(fromFile: URL(filePath: "/cancel.png")) }
        try await waitFor("cancel.png", in: loader)
        task.cancel()
        // Even an uncooperative successful response must not publish after cancellation.
        await loader.finish("cancel.png", result: .success(try image(width: 20)))
        #expect(await task.value == false)
        #expect(viewModel.selectedImage == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Provider cancellation is silent", arguments: [true, false])
    func providerCancellation(cocoaError: Bool) async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let task = Task { await viewModel.loadImage(fromFile: URL(filePath: "/cancel.png")) }
        try await waitFor("cancel.png", in: loader)
        let error: any Error = cocoaError ? CocoaError(.userCancelled) : CancellationError()
        await loader.finish("cancel.png", result: .failure(error))
        #expect(await task.value == false)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Late photo completion cannot overwrite a newer file selection", arguments: [true, false])
    func latestSelectionWins(oldFails: Bool) async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let old = Task { await viewModel.loadImage(from: PhotosPickerItem(itemIdentifier: "old")) }
        try await waitFor("old", in: loader)
        let latest = Task { await viewModel.loadImage(fromFile: URL(filePath: "/latest.png")) }
        try await waitFor("latest.png", in: loader)
        await loader.finish("latest.png", result: .success(try image(width: 40)))
        #expect(await latest.value)
        let result: Result<CGImage, Error> = oldFails
            ? .failure(PhotoLibraryError.loadFailed) : .success(try image(width: 20))
        await loader.finish("old", result: result)
        #expect(await old.value == false)
        #expect(viewModel.selectedImage?.width == 40)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("Old file completion does not end a newer photo loading state")
    func staleCompletionKeepsLoading() async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let old = Task { await viewModel.loadImage(fromFile: URL(filePath: "/old.png")) }
        try await waitFor("old.png", in: loader)
        let latest = Task { await viewModel.loadImage(from: PhotosPickerItem(itemIdentifier: "latest")) }
        try await waitFor("latest", in: loader)
        await loader.finish("old.png", result: .success(try image(width: 20)))
        #expect(await old.value == false)
        #expect(viewModel.isLoading)
        #expect(viewModel.selectedImage == nil)
        await loader.finish("latest", result: .success(try image(width: 40)))
        #expect(await latest.value)
        #expect(viewModel.selectedImage?.width == 40)
    }

    @Test("Clearing selection invalidates an in-flight request")
    func clearSelection() async throws {
        let loader = ControlledPhotoLoader()
        let viewModel = MainViewModel(photoLibraryService: loader)
        let task = Task { await viewModel.loadImage(fromFile: URL(filePath: "/image.png")) }
        try await waitFor("image.png", in: loader)
        viewModel.clearSelection()
        #expect(!viewModel.isLoading)
        await loader.finish("image.png", result: .success(try image(width: 20)))
        #expect(await task.value == false)
        #expect(viewModel.selectedImage == nil)
        #expect(viewModel.errorMessage == nil)
    }
}
