import Foundation
import Testing
@testable import MacCleanerCore

private final class ApplicationTrashRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedURLs: [URL] = []

    var urls: [URL] { lock.withLock { storedURLs } }

    func record(_ url: URL) {
        lock.withLock { storedURLs.append(url) }
    }
}

@Test func applicationTrashAcceptsOnlyDirectApplicationBundles() async throws {
    let root = try makeApplicationTrashTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let application = root.appending(path: "Remove Me.app", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)

    let recorder = ApplicationTrashRecorder()
    let service = ApplicationTrashService(
        allowedRoots: [root],
        currentApplicationURL: root.appending(path: "MacCleaner.app")
    ) { _, url in
        recorder.record(url)
    }

    try await service.moveToTrash(application)

    #expect(recorder.urls == [application.standardizedFileURL])
    #expect(FileManager.default.fileExists(atPath: application.path))
}

@Test func applicationTrashRejectsNestedAndNonApplicationItems() async throws {
    let root = try makeApplicationTrashTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let nestedRoot = root.appending(path: "Nested", directoryHint: .isDirectory)
    let nestedApplication = nestedRoot.appending(path: "Nested.app", directoryHint: .isDirectory)
    let document = root.appending(path: "Document.txt")
    try FileManager.default.createDirectory(at: nestedApplication, withIntermediateDirectories: true)
    try Data().write(to: document)

    let service = ApplicationTrashService(
        allowedRoots: [root],
        currentApplicationURL: root.appending(path: "MacCleaner.app")
    )

    await #expect(throws: ApplicationTrashError.unsafeLocation(nestedApplication)) {
        try await service.moveToTrash(nestedApplication)
    }
    await #expect(throws: ApplicationTrashError.notApplicationBundle(document)) {
        try await service.moveToTrash(document)
    }
}

@Test func applicationTrashRejectsSymbolicLinksAndCurrentApplication() async throws {
    let root = try makeApplicationTrashTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let current = root.appending(path: "MacCleaner.app", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
    let link = root.appending(path: "Alias.app")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: current)

    let service = ApplicationTrashService(allowedRoots: [root], currentApplicationURL: current)

    await #expect(throws: ApplicationTrashError.symbolicLink(link)) {
        try await service.moveToTrash(link)
    }
    await #expect(throws: ApplicationTrashError.currentApplication(current)) {
        try await service.moveToTrash(current)
    }
}

@Test func applicationTrashDefaultRootsExcludeSystemApplications() {
    let roots = ApplicationTrashService.defaultAllowedRoots(
        homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true)
    )

    #expect(roots == [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/Users/example/Applications", isDirectory: true)
    ])
    #expect(!roots.contains(URL(fileURLWithPath: "/System/Applications", isDirectory: true)))
}

private func makeApplicationTrashTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "ApplicationTrashServiceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
