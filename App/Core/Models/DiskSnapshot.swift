public struct DiskSnapshot: Equatable, Sendable {
    public let totalBytes: Int64
    public let availableBytes: Int64
    public let cacheBytes: Int64
    public let trashBytes: Int64
    public let largeFiles: [CleanupItem]

    public var usedBytes: Int64 { max(0, totalBytes - availableBytes) }
    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    public init(
        totalBytes: Int64 = 0,
        availableBytes: Int64 = 0,
        cacheBytes: Int64 = 0,
        trashBytes: Int64 = 0,
        largeFiles: [CleanupItem] = []
    ) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.cacheBytes = cacheBytes
        self.trashBytes = trashBytes
        self.largeFiles = largeFiles
    }
}
