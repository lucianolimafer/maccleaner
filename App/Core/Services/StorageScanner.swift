import Foundation

public actor StorageScanner: StorageScanning {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let largeFileThreshold: Int64

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        largeFileThreshold: Int64 = 500_000_000
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory.standardizedFileURL.resolvingSymlinksInPath()
        self.largeFileThreshold = largeFileThreshold
    }

    public func scan() async throws -> ScanResult {
        let capacity = try volumeCapacity(at: homeDirectory)
        let cachesURL = homeDirectory.appending(path: "Library/Caches", directoryHint: .isDirectory)
        let trashURL = homeDirectory.appending(path: ".Trash", directoryHint: .isDirectory)

        let cacheItems = immediateChildren(of: cachesURL).map {
            CleanupItem(url: $0, bytes: allocatedSize(of: $0), kind: .cache)
        }
        let trashBytes = allocatedSize(of: trashURL)
        let largeFiles = findLargeFiles(in: homeDirectory)
        let snapshot = DiskSnapshot(
            totalBytes: capacity.total,
            availableBytes: capacity.available,
            cacheBytes: cacheItems.reduce(0) { $0 + $1.bytes },
            trashBytes: trashBytes,
            largeFiles: largeFiles
        )
        return ScanResult(snapshot: snapshot, cleanupCandidates: cacheItems)
    }

    private func volumeCapacity(at url: URL) throws -> (total: Int64, available: Int64) {
        let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        return (Int64(values.volumeTotalCapacity ?? 0), values.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    private func immediateChildren(of directory: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ))?.filter { !isSymbolicLink($0) } ?? []
    }

    private func findLargeFiles(in directory: URL) -> [CleanupItem] {
        let excluded = ["Library", ".Trash"]
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var result: [CleanupItem] = []
        for case let url as URL in enumerator {
            if enumerator.level == 1, excluded.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else { continue }
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            if size >= largeFileThreshold {
                result.append(CleanupItem(url: url, bytes: size, kind: .largeFile))
            }
        }
        return result.sorted { $0.bytes > $1.bytes }.prefix(20).map { $0 }
    }

    private func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey]
        guard let values = try? url.resourceValues(forKeys: keys), values.isSymbolicLink != true else { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        return enumerator.reduce(into: Int64(0)) { total, element in
            guard let child = element as? URL,
                  let childValues = try? child.resourceValues(forKeys: keys),
                  childValues.isDirectory != true,
                  childValues.isSymbolicLink != true else { return }
            total += Int64(childValues.totalFileAllocatedSize ?? childValues.fileAllocatedSize ?? 0)
        }
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}
