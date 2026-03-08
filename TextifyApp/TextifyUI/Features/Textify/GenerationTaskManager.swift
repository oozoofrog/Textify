import Foundation

/// Manages generation tasks with automatic cancellation of stale requests
@MainActor
public final class GenerationTaskManager {
    private var currentTask: Task<Void, Never>?
    private var currentTaskID = UUID()

    public init() {}

    /// Starts a new generation task, cancelling any in-flight task
    @discardableResult
    public func startGeneration(
        priority: TaskPriority = .userInitiated,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        currentTask?.cancel()
        let taskID = UUID()
        currentTaskID = taskID

        let task = Task(priority: priority) { [weak self] in
            await operation()

            await MainActor.run {
                guard let self, self.currentTaskID == taskID else { return }
                self.currentTask = nil
            }
        }

        currentTask = task
        return task
    }

    /// Cancels the current task if any
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        currentTaskID = UUID()
    }

    /// Returns whether a task is currently running
    public var isRunning: Bool {
        currentTask != nil
    }
}
