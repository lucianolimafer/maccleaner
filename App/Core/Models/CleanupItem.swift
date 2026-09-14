import Foundation

public struct CleanupItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case cache = "Cache"
        case trash = "Trash"
        case largeFile = "Large file"
    }

    public let url: URL
    public let bytes: Int64
    public let kind: Kind

    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    public init(url: URL, bytes: Int64, kind: Kind) {
        self.url = url
        self.bytes = bytes
        self.kind = kind
    }
}
