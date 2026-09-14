import Foundation

public protocol Trashing: Sendable {
    func moveToTrash(_ urls: [URL]) async throws
}

public enum TrashError: LocalizedError, Equatable {
    case unsafeLocation(URL)

    public var errorDescription: String? {
        switch self {
        case .unsafeLocation(let url): "Refusing to remove an unsafe item: \(url.path)"
        }
    }
}

public actor TrashService: Trashing {
    private let fileManager: FileManager
    private let allowedDirectory: URL
    private let trashItem: @Sendable (FileManager, URL) throws -> Void

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        trashItem: @escaping @Sendable (FileManager, URL) throws -> Void = { fileManager, url in
            _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
        }
    ) {
        self.fileManager = fileManager
        self.trashItem = trashItem
        self.allowedDirectory = homeDirectory
            .appending(path: "Library/Caches", directoryHint: .isDirectory)
            .standardizedFileURL
    }

    public func moveToTrash(_ urls: [URL]) async throws {
        let candidates = try urls.map { url in
            let candidate = url.standardizedFileURL
            guard candidate.deletingLastPathComponent() == allowedDirectory else {
                throw TrashError.unsafeLocation(url)
            }
            return candidate
        }

        for candidate in candidates {
            try trashItem(fileManager, candidate)
        }
    }
}
