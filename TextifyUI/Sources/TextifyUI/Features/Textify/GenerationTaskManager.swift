import Foundation

/// Manages generation tasks with automatic cancellation of stale requests
@MainActor
public final class GenerationTaskManager {
    private var currentTask: Task<Void, Never>?

    public init() {}

    /// Starts a new generation task, cancelling any in-flight task
    public func startGeneration(
        priority: TaskPriority = .userInitiated,
        operation: @escaping @Sendable () async -> Void
    ) {
        currentTask?.cancel()
        currentTask = Task(priority: priority) {
            await operation()
        }
    }

    /// Cancels the current task if any
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Returns whether a task is currently running
    public var isRunning: Bool {
        currentTask != nil && !currentTask!.isCancelled
    }
}
