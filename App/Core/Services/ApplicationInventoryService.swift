import Foundation

public protocol ApplicationInventoryProviding: Sendable {
    func applications() async throws -> [InstalledApplication]
}

public actor ApplicationInventoryService: ApplicationInventoryProviding {
    private let fileManager: FileManager
    private let roots: [URL]
    private let includesAllocatedSize: Bool

    public init(
        fileManager: FileManager = .default,
        roots: [URL] = ApplicationInventoryService.defaultRoots(),
        includesAllocatedSize: Bool = true
    ) {
        self.fileManager = fileManager
        self.roots = roots.map(\.standardizedFileURL)
        self.includesAllocatedSize = includesAllocatedSize
    }

    public func applications() async throws -> [InstalledApplication] {
        roots.flatMap(applications(in:)).sorted {
            if $0.name == $1.name { return $0.url.path < $1.url.path }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public static func defaultRoots(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appending(path: "Applications", directoryHint: .isDirectory)
        ]
    }

    private func applications(in root: URL) -> [InstalledApplication] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "app",
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else {
                return nil
            }

            let infoURL = url.appending(path: "Contents/Info.plist", directoryHint: .notDirectory)
            let info = (try? Data(contentsOf: infoURL))
                .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) }
                as? [String: Any]
            let displayName = info?["CFBundleDisplayName"] as? String
            let bundleName = info?["CFBundleName"] as? String
            let name = [displayName, bundleName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? url.deletingPathExtension().lastPathComponent
            let version = (info?["CFBundleShortVersionString"] as? String)
                ?? (info?["CFBundleVersion"] as? String)

            return InstalledApplication(
                url: url.standardizedFileURL,
                name: name,
                bundleIdentifier: info?["CFBundleIdentifier"] as? String,
                version: version,
                allocatedSize: includesAllocatedSize ? allocatedSize(of: url) : nil
            )
        }
    }

    private func allocatedSize(of root: URL) -> Int64? {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return nil
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true
            else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
