import Foundation
import Testing
@testable import MacCleanerCore

@Test func startupItemDiscoveryReadsOnlyValidDirectPlists() async throws {
    let root = try makeStartupItemsTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    try writeStartupPlist(
        [
            "Label": "com.example.worker",
            "Program": "/usr/bin/example",
            "ProgramArguments": ["/usr/bin/example", "--quiet"]
        ],
        to: root.appending(path: "worker.plist")
    )
    try Data("not a plist".utf8).write(to: root.appending(path: "broken.plist"))
    try writeStartupPlist(["Program": "/usr/bin/missing-label"], to: root.appending(path: "missing.plist"))
    try writeStartupPlist(["Label": "ignored"], to: root.appending(path: "ignored.txt"))

    let nested = root.appending(path: "Nested", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try writeStartupPlist(["Label": "nested"], to: nested.appending(path: "nested.plist"))

    let service = StartupItemDiscoveryService(roots: [root])
    let items = try await service.discover()

    #expect(items.count == 1)
    #expect(items.first?.label == "com.example.worker")
    #expect(items.first?.program == "/usr/bin/example")
    #expect(items.first?.programArguments == ["/usr/bin/example", "--quiet"])
}

@Test func startupItemDiscoverySkipsSymbolicLinksAndMissingRoots() async throws {
    let root = try makeStartupItemsTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let target = root.appending(path: "target.plist")
    try writeStartupPlist(["Label": "target"], to: target)
    let link = root.appending(path: "linked.plist")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

    let missing = root.appending(path: "Missing", directoryHint: .isDirectory)
    let items = try await StartupItemDiscoveryService(roots: [root, missing]).discover()

    #expect(items.map(\.label) == ["target"])
}

private func makeStartupItemsTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "StartupItemDiscoveryServiceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeStartupPlist(_ value: [String: Any], to url: URL) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
    try data.write(to: url)
}
