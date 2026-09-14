import Foundation
import Testing
@testable import MacCleanerCore

@Test func applicationInventoryReadsDirectApplicationMetadata() async throws {
    let root = try makeApplicationInventoryTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let app = root.appending(path: "Example.app", directoryHint: .isDirectory)
    try writeApplicationBundle(
        at: app,
        info: [
            "CFBundleDisplayName": "Example Editor",
            "CFBundleIdentifier": "com.example.editor",
            "CFBundleShortVersionString": "2.4"
        ]
    )
    try Data("ignored".utf8).write(to: root.appending(path: "Notes.txt"))
    let nestedRoot = root.appending(path: "Nested", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: nestedRoot, withIntermediateDirectories: true)
    try writeApplicationBundle(at: nestedRoot.appending(path: "Nested.app"), info: [:])

    let applications = try await ApplicationInventoryService(
        roots: [root],
        includesAllocatedSize: false
    ).applications()

    #expect(applications.count == 1)
    #expect(applications.first?.name == "Example Editor")
    #expect(applications.first?.bundleIdentifier == "com.example.editor")
    #expect(applications.first?.version == "2.4")
    #expect(applications.first?.url == app.standardizedFileURL)
    #expect(applications.first?.allocatedSize == nil)
}

@Test func applicationInventoryFallsBackToBundleNameAndCalculatesSize() async throws {
    let root = try makeApplicationInventoryTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let app = root.appending(path: "Fallback.app", directoryHint: .isDirectory)
    try writeApplicationBundle(at: app, info: ["CFBundleVersion": "19"])
    try Data(repeating: 1, count: 256).write(to: app.appending(path: "Contents/payload.bin"))

    let applications = try await ApplicationInventoryService(
        roots: [root],
        includesAllocatedSize: true
    ).applications()

    #expect(applications.first?.name == "Fallback")
    #expect(applications.first?.version == "19")
    #expect((applications.first?.allocatedSize ?? 0) > 0)
}

@Test func applicationInventorySkipsSymbolicApplicationBundles() async throws {
    let root = try makeApplicationInventoryTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let app = root.appending(path: "Original.app", directoryHint: .isDirectory)
    try writeApplicationBundle(at: app, info: ["CFBundleName": "Original"])
    try FileManager.default.createSymbolicLink(
        at: root.appending(path: "Alias.app"),
        withDestinationURL: app
    )

    let applications = try await ApplicationInventoryService(roots: [root]).applications()

    #expect(applications.map(\.name) == ["Original"])
}

@Test func applicationInventoryDefaultRootsExcludeSystemApplications() {
    let roots = ApplicationInventoryService.defaultRoots(
        homeDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true)
    )

    #expect(roots == [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/Users/example/Applications", isDirectory: true)
    ])
}

private func makeApplicationInventoryTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "ApplicationInventoryServiceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeApplicationBundle(at url: URL, info: [String: Any]) throws {
    let contents = url.appending(path: "Contents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: contents.appending(path: "Info.plist"))
}
