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

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.allowedDirectory = homeDirectory
            .appending(path: "Library/Caches", directoryHint: .isDirectory)
            .standardizedFileURL
    }

    public func moveToTrash(_ urls: [URL]) async throws {
        for url in urls {
            let candidate = url.standardizedFileURL
            guard candidate.deletingLastPathComponent() == allowedDirectory else {
                throw TrashError.unsafeLocation(url)
            }
            _ = try fileManager.trashItem(at: candidate, resultingItemURL: nil)
        }
    }
}
