import Foundation

public struct StartupItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let label: String
    public let program: String?
    public let programArguments: [String]

    public var id: URL { url }

    public init(url: URL, label: String, program: String?, programArguments: [String]) {
        self.url = url
        self.label = label
        self.program = program
        self.programArguments = programArguments
    }
}
