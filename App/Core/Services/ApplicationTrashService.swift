import Foundation

public protocol ApplicationTrashing: Sendable {
    func moveToTrash(_ applicationURL: URL) async throws
}

public enum ApplicationTrashError: LocalizedError, Equatable {
    case unsafeLocation(URL)
    case notApplicationBundle(URL)
    case symbolicLink(URL)
    case currentApplication(URL)

    public var errorDescription: String? {
        switch self {
        case .unsafeLocation(let url):
            "Refusing to remove an application outside an allowed folder: \(url.path)"
        case .notApplicationBundle(let url):
            "The selected item is not an application bundle: \(url.path)"
        case .symbolicLink(let url):
            "Refusing to remove an application through a symbolic link: \(url.path)"
        case .currentApplication(let url):
            "MacCleaner cannot remove itself: \(url.path)"
        }
    }
}

public actor ApplicationTrashService: ApplicationTrashing {
    private let fileManager: FileManager
    private let allowedRoots: [URL]
    private let currentApplicationURL: URL
    private let trashItem: @Sendable (FileManager, URL) throws -> Void

    public init(
        fileManager: FileManager = .default,
        allowedRoots: [URL] = ApplicationTrashService.defaultAllowedRoots(),
        currentApplicationURL: URL = Bundle.main.bundleURL,
        trashItem: @escaping @Sendable (FileManager, URL) throws -> Void = { fileManager, url in
            _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
        }
    ) {
        self.fileManager = fileManager
        self.allowedRoots = allowedRoots.map(\.standardizedFileURL)
        self.currentApplicationURL = currentApplicationURL.standardizedFileURL
        self.trashItem = trashItem
    }

    public static func defaultAllowedRoots(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appending(path: "Applications", directoryHint: .isDirectory)
        ]
    }

    public func moveToTrash(_ applicationURL: URL) async throws {
        let candidate = applicationURL.standardizedFileURL
        guard allowedRoots.contains(candidate.deletingLastPathComponent()) else {
            throw ApplicationTrashError.unsafeLocation(applicationURL)
        }
        guard candidate.pathExtension.lowercased() == "app" else {
            throw ApplicationTrashError.notApplicationBundle(applicationURL)
        }
        guard let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            throw ApplicationTrashError.notApplicationBundle(applicationURL)
        }
        guard values.isSymbolicLink != true else {
            throw ApplicationTrashError.symbolicLink(applicationURL)
        }
        guard values.isDirectory == true else {
            throw ApplicationTrashError.notApplicationBundle(applicationURL)
        }
        guard candidate != currentApplicationURL else {
            throw ApplicationTrashError.currentApplication(applicationURL)
        }

        try trashItem(fileManager, candidate)
    }
}
