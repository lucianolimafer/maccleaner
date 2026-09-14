import Foundation

public actor StartupItemDiscoveryService: StartupItemDiscovering {
    private let fileManager: FileManager
    private let roots: [URL]

    public init(
        fileManager: FileManager = .default,
        roots: [URL] = StartupItemDiscoveryService.defaultRoots()
    ) {
        self.fileManager = fileManager
        self.roots = roots.map(\.standardizedFileURL)
    }

    public func discover() async throws -> [StartupItem] {
        roots.flatMap(items(in:)).sorted {
            if $0.label == $1.label { return $0.url.path < $1.url.path }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    public static func defaultRoots(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        [
            homeDirectory.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory),
            URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/LaunchAgents", isDirectory: true)
        ]
    }

    private func items(in root: URL) -> [StartupItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "plist",
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let data = try? Data(contentsOf: url),
                  let propertyList = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dictionary = propertyList as? [String: Any],
                  let label = dictionary["Label"] as? String,
                  !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            let program = dictionary["Program"] as? String
            let arguments = dictionary["ProgramArguments"] as? [String] ?? []
            return StartupItem(
                url: url.standardizedFileURL,
                label: label,
                program: program,
                programArguments: arguments
            )
        }
    }
}
