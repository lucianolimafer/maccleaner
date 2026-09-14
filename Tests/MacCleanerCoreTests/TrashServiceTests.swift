import Foundation
import Testing
@testable import MacCleanerCore

private final class TrashedURLRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedURLs: [URL] = []

    var urls: [URL] {
        lock.withLock { storedURLs }
    }

    func record(_ url: URL) {
        lock.withLock { storedURLs.append(url) }
    }
}

@Test func trashServiceRejectsItemsOutsideTopLevelCacheDirectory() async {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let service = TrashService(homeDirectory: home)
    let unsafeURL = home.appending(path: "Documents/important.txt")

    await #expect(throws: TrashError.unsafeLocation(unsafeURL)) {
        try await service.moveToTrash([unsafeURL])
    }
    #expect(
        TrashError.unsafeLocation(unsafeURL).errorDescription
            == "Refusing to remove an unsafe item: /Users/example/Documents/important.txt"
    )
}

@Test func trashServiceRejectsNestedCacheItems() async {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let service = TrashService(homeDirectory: home)
    let nestedURL = home.appending(path: "Library/Caches/vendor/item")

    await #expect(throws: TrashError.unsafeLocation(nestedURL)) {
        try await service.moveToTrash([nestedURL])
    }
}

@Test func trashServicePassesOnlyTopLevelCacheItemsToTrashOperation() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let cacheDirectory = home.appending(path: "Library/Caches", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let first = cacheDirectory.appending(path: "first.cache")
    let second = cacheDirectory.appending(path: "second.cache")
    try Data("first".utf8).write(to: first)
    try Data("second".utf8).write(to: second)

    let recorder = TrashedURLRecorder()
    let service = TrashService(homeDirectory: home) { _, url in
        recorder.record(url)
    }

    try await service.moveToTrash([first, second])

    #expect(recorder.urls == [first.standardizedFileURL, second.standardizedFileURL])
    #expect(FileManager.default.fileExists(atPath: first.path))
    #expect(FileManager.default.fileExists(atPath: second.path))
}

@Test func trashServiceRejectsEntireRequestBeforeMovingAnyItem() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let cacheDirectory = home.appending(path: "Library/Caches", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let safe = cacheDirectory.appending(path: "safe.cache")
    let unsafe = home.appending(path: "Documents/important.txt")
    let recorder = TrashedURLRecorder()
    let service = TrashService(homeDirectory: home) { _, url in recorder.record(url) }

    await #expect(throws: TrashError.unsafeLocation(unsafe)) {
        try await service.moveToTrash([safe, unsafe])
    }
    #expect(recorder.urls.isEmpty)
}

@Test func trashServiceDefaultOperationReportsMissingCacheItem() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let cacheDirectory = home.appending(path: "Library/Caches", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let missingItem = cacheDirectory.appending(path: "missing.cache")
    let service = TrashService(homeDirectory: home)

    do {
        try await service.moveToTrash([missingItem])
        Issue.record("Expected the default trash operation to reject a missing item")
    } catch {
        #expect(!FileManager.default.fileExists(atPath: missingItem.path))
    }
}

@Test func trashServiceAcceptsAnEmptyRequest() async throws {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let service = TrashService(homeDirectory: home)

    try await service.moveToTrash([])
}
