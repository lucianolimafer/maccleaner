import Foundation

public struct InstalledApplication: Identifiable, Hashable, Sendable {
    public let url: URL
    public let name: String
    public let bundleIdentifier: String?
    public let version: String?
    public let allocatedSize: Int64?

    public var id: URL { url }

    public init(
        url: URL,
        name: String,
        bundleIdentifier: String?,
        version: String?,
        allocatedSize: Int64?
    ) {
        self.url = url
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.allocatedSize = allocatedSize
    }
}
