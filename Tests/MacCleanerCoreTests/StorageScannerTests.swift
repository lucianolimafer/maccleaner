import Foundation
import Testing
@testable import MacCleanerCore

private struct TemporaryHome {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

private func writeFile(named name: String, bytes: Int, in directory: URL) throws -> URL {
    let url = directory.appending(path: name)
    try Data(repeating: 0x41, count: bytes).write(to: url)
    return url
}

@Test func scannerFindsCacheCandidatesAndLargeFiles() async throws {
    let home = try TemporaryHome()
    defer { home.remove() }

    let caches = home.url.appending(path: "Library/Caches", directoryHint: .isDirectory)
    let documents = home.url.appending(path: "Documents", directoryHint: .isDirectory)
    let trash = home.url.appending(path: ".Trash", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)

    let cacheFile = try writeFile(named: "browser.cache", bytes: 8_192, in: caches)
    _ = try writeFile(named: "large.bin", bytes: 16_384, in: documents)
    _ = try writeFile(named: "deleted.bin", bytes: 16_384, in: trash)

    let result = try await StorageScanner(homeDirectory: home.url, largeFileThreshold: 1).scan()

    #expect(result.snapshot.totalBytes > 0)
    #expect(result.snapshot.availableBytes > 0)
    #expect(result.snapshot.cacheBytes > 0)
    #expect(result.snapshot.trashBytes > 0)
    #expect(result.cleanupCandidates.count == 1)
    #expect(result.cleanupCandidates.first?.url.lastPathComponent == cacheFile.lastPathComponent)
    #expect(result.cleanupCandidates.first?.kind == .cache)
    #expect(result.snapshot.largeFiles.map(\.name) == ["large.bin"])
}

@Test func scannerSkipsCacheSymlinksAndHiddenLargeFiles() async throws {
    let home = try TemporaryHome()
    defer { home.remove() }

    let caches = home.url.appending(path: "Library/Caches", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    let target = try writeFile(named: "target.bin", bytes: 8_192, in: home.url)
    try FileManager.default.createSymbolicLink(
        at: caches.appending(path: "linked.cache"),
        withDestinationURL: target
    )
    _ = try writeFile(named: ".hidden.bin", bytes: 8_192, in: home.url)

    let result = try await StorageScanner(homeDirectory: home.url, largeFileThreshold: 1).scan()

    #expect(result.cleanupCandidates.isEmpty)
    #expect(!result.snapshot.largeFiles.map(\.url).contains(home.url.appending(path: ".hidden.bin")))
}

@Test func scannerReturnsAtMostTwentyLargestFilesInDescendingOrder() async throws {
    let home = try TemporaryHome()
    defer { home.remove() }

    for index in 1...25 {
        _ = try writeFile(named: "file-\(index).bin", bytes: index * 4_096, in: home.url)
    }

    let result = try await StorageScanner(homeDirectory: home.url, largeFileThreshold: 1).scan()
    let sizes = result.snapshot.largeFiles.map(\.bytes)

    #expect(sizes.count == 20)
    #expect(sizes == sizes.sorted(by: >))
}
