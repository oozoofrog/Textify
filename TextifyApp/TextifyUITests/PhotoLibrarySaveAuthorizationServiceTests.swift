import Foundation
import Testing
@testable import TextifyUI

final class PhotoLibrarySaveAuthorizerSpy: PhotoLibrarySaveAuthorizing, @unchecked Sendable {
    private(set) var currentStatusCallCount = 0
    private(set) var requestAuthorizationCallCount = 0
    private let current: PhotoLibrarySaveAuthorizationStatus
    private let requested: PhotoLibrarySaveAuthorizationStatus

    init(
        current: PhotoLibrarySaveAuthorizationStatus,
        requested: PhotoLibrarySaveAuthorizationStatus? = nil
    ) {
        self.current = current
        self.requested = requested ?? current
    }

    func currentStatus() -> PhotoLibrarySaveAuthorizationStatus {
        currentStatusCallCount += 1
        return current
    }

    func requestAuthorization() async -> PhotoLibrarySaveAuthorizationStatus {
        requestAuthorizationCallCount += 1
        return requested
    }
}

@Suite("PhotoLibrarySaveAuthorizationService Tests")
struct PhotoLibrarySaveAuthorizationServiceTests {

    @Test("Authorized status passes without requesting again")
    func testEnsureAuthorizedWithAuthorizedStatus() async throws {
        let authorizer = PhotoLibrarySaveAuthorizerSpy(current: .authorized)
        let service = PhotoLibrarySaveAuthorizationService(authorizer: authorizer)

        try await service.ensureAuthorized()

        #expect(authorizer.currentStatusCallCount == 1)
        #expect(authorizer.requestAuthorizationCallCount == 0)
    }

    @Test("Not determined status requests permission and throws denied error")
    func testEnsureAuthorizedRequestsPermissionWhenNotDetermined() async throws {
        let authorizer = PhotoLibrarySaveAuthorizerSpy(current: .notDetermined, requested: .denied)
        let service = PhotoLibrarySaveAuthorizationService(authorizer: authorizer)

        do {
            try await service.ensureAuthorized()
            Issue.record("Expected permissionDenied error")
        } catch let error as ImageExportError {
            #expect(error == .permissionDenied)
        }

        #expect(authorizer.currentStatusCallCount == 1)
        #expect(authorizer.requestAuthorizationCallCount == 1)
    }

    @Test("Restricted status throws restricted error")
    func testEnsureAuthorizedWithRestrictedStatus() async throws {
        let authorizer = PhotoLibrarySaveAuthorizerSpy(current: .restricted)
        let service = PhotoLibrarySaveAuthorizationService(authorizer: authorizer)

        do {
            try await service.ensureAuthorized()
            Issue.record("Expected permissionRestricted error")
        } catch let error as ImageExportError {
            #expect(error == .permissionRestricted)
        }

        #expect(authorizer.requestAuthorizationCallCount == 0)
    }
}
