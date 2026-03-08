import Foundation

/// Throttles rapid invocations, executing at most once per interval
public actor Throttler {
    private var lastExecutionTime: ContinuousClock.Instant?
    private let interval: Duration

    public init(interval: Duration) {
        self.interval = interval
    }

    public func throttle(_ operation: @Sendable () async -> Void) async {
        let now = ContinuousClock.now
        if let last = lastExecutionTime, now - last < interval {
            return
        }
        lastExecutionTime = now
        await operation()
    }

    public func reset() {
        lastExecutionTime = nil
    }
}

/// Debounces invocations, executing only after delay with no new calls
public actor Debouncer {
    private var pendingTask: Task<Void, Never>?
    private let delay: Duration

    public init(delay: Duration) {
        self.delay = delay
    }

    public func debounce(_ operation: @escaping @Sendable () async -> Void) {
        pendingTask?.cancel()
        pendingTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    public func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
