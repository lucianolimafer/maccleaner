public struct ScanResult: Sendable {
    public let snapshot: DiskSnapshot
    public let cleanupCandidates: [CleanupItem]

    public init(snapshot: DiskSnapshot, cleanupCandidates: [CleanupItem]) {
        self.snapshot = snapshot
        self.cleanupCandidates = cleanupCandidates
    }
}

public protocol StorageScanning: Sendable {
    func scan() async throws -> ScanResult
}
