public protocol StartupItemDiscovering: Sendable {
    func discover() async throws -> [StartupItem]
}
