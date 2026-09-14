import Foundation
import Testing
@testable import MacCleaner
import MacCleanerCore

private enum TestFailure: LocalizedError {
    case scan
    case trash
    case startupItems
    case applications
    case applicationTrash

    var errorDescription: String? {
        switch self {
        case .scan: "The test scan failed."
        case .trash: "The test cleanup failed."
        case .startupItems: "The startup item lookup failed."
        case .applications: "The application lookup failed."
        case .applicationTrash: "The application could not be moved to the Trash."
        }
    }
}

private actor StartupItemDiscoveryStub: StartupItemDiscovering {
    private let result: Result<[StartupItem], Error>
    private(set) var callCount = 0

    init(result: Result<[StartupItem], Error>) { self.result = result }

    func discover() async throws -> [StartupItem] {
        callCount += 1
        return try result.get()
    }
}

private actor ApplicationInventoryStub: ApplicationInventoryProviding {
    private var results: [Result<[InstalledApplication], Error>]
    private(set) var callCount = 0

    init(results: [Result<[InstalledApplication], Error>]) { self.results = results }

    func applications() async throws -> [InstalledApplication] {
        callCount += 1
        guard !results.isEmpty else { throw TestFailure.applications }
        return try results.removeFirst().get()
    }
}

private actor ApplicationTrashStub: ApplicationTrashing {
    private let error: Error?
    private(set) var receivedURLs: [URL] = []

    init(error: Error? = nil) { self.error = error }

    func moveToTrash(_ applicationURL: URL) async throws {
        receivedURLs.append(applicationURL)
        if let error { throw error }
    }
}

private actor ScannerStub: StorageScanning {
    private var results: [Result<ScanResult, Error>]
    private(set) var callCount = 0

    init(results: [Result<ScanResult, Error>]) {
        self.results = results
    }

    func scan() async throws -> ScanResult {
        callCount += 1
        guard !results.isEmpty else { throw TestFailure.scan }
        return try results.removeFirst().get()
    }
}

private actor TrashStub: Trashing {
    private let error: Error?
    private(set) var receivedURLs: [[URL]] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func moveToTrash(_ urls: [URL]) async throws {
        receivedURLs.append(urls)
        if let error { throw error }
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    condition: @escaping @MainActor () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !(await condition()) {
        guard clock.now < deadline else {
            Issue.record("Timed out waiting for asynchronous state change")
            return
        }
        await Task.yield()
    }
}

@Test @MainActor func scanPublishesResultsAndPreservesValidSelection() async throws {
    let first = CleanupItem(url: URL(fileURLWithPath: "/tmp/first"), bytes: 10, kind: .cache)
    let second = CleanupItem(url: URL(fileURLWithPath: "/tmp/second"), bytes: 25, kind: .cache)
    let snapshot = DiskSnapshot(totalBytes: 100, availableBytes: 40, cacheBytes: 35)
    let scanner = ScannerStub(results: [.success(ScanResult(snapshot: snapshot, cleanupCandidates: [first, second]))])
    let viewModel = CleanerViewModel(scanner: scanner, trashService: TrashStub())
    viewModel.selectedIDs = [first.id, URL(fileURLWithPath: "/tmp/stale")]

    viewModel.scan()
    #expect(viewModel.isScanning)
    try await waitUntil { !viewModel.isScanning }

    #expect(viewModel.snapshot == snapshot)
    #expect(viewModel.cleanupCandidates == [first, second])
    #expect(viewModel.selectedIDs == [first.id])
    #expect(viewModel.selectedBytes == 10)
    #expect(viewModel.lastScannedAt != nil)
    #expect(viewModel.alertMessage == nil)
}

@Test @MainActor func scanFailurePublishesErrorAndKeepsExistingData() async throws {
    let scanner = ScannerStub(results: [.failure(TestFailure.scan)])
    let viewModel = CleanerViewModel(scanner: scanner, trashService: TrashStub())

    viewModel.scan()
    try await waitUntil { !viewModel.isScanning }

    #expect(viewModel.snapshot == DiskSnapshot())
    #expect(viewModel.cleanupCandidates.isEmpty)
    #expect(viewModel.lastScannedAt == nil)
    #expect(viewModel.alertMessage == TestFailure.scan.localizedDescription)
}

@Test @MainActor func scanIgnoresConcurrentRequests() async throws {
    let scanner = ScannerStub(results: [.success(ScanResult(snapshot: DiskSnapshot(), cleanupCandidates: []))])
    let viewModel = CleanerViewModel(scanner: scanner, trashService: TrashStub())

    viewModel.scan()
    viewModel.scan()
    try await waitUntil { !viewModel.isScanning }

    #expect(await scanner.callCount == 1)
}

@Test @MainActor func cleanupSendsSelectionThenClearsAndRescans() async throws {
    let first = CleanupItem(url: URL(fileURLWithPath: "/tmp/first"), bytes: 10, kind: .cache)
    let second = CleanupItem(url: URL(fileURLWithPath: "/tmp/second"), bytes: 25, kind: .cache)
    let initial = ScanResult(snapshot: DiskSnapshot(cacheBytes: 35), cleanupCandidates: [first, second])
    let refreshed = ScanResult(snapshot: DiskSnapshot(), cleanupCandidates: [])
    let scanner = ScannerStub(results: [.success(initial), .success(refreshed)])
    let trash = TrashStub()
    let viewModel = CleanerViewModel(scanner: scanner, trashService: trash)

    viewModel.scan()
    try await waitUntil { !viewModel.isScanning }
    viewModel.selectedIDs = [second.id]
    viewModel.cleanSelected()
    try await waitUntil { await scanner.callCount == 2 && !viewModel.isScanning }

    #expect(await trash.receivedURLs == [[second.url]])
    #expect(viewModel.selectedIDs.isEmpty)
    #expect(viewModel.cleanupCandidates.isEmpty)
}

@Test @MainActor func cleanupFailureKeepsSelectionAndPublishesError() async throws {
    let item = CleanupItem(url: URL(fileURLWithPath: "/tmp/cache"), bytes: 10, kind: .cache)
    let scanner = ScannerStub(results: [.success(ScanResult(snapshot: DiskSnapshot(), cleanupCandidates: [item]))])
    let trash = TrashStub(error: TestFailure.trash)
    let viewModel = CleanerViewModel(scanner: scanner, trashService: trash)

    viewModel.scan()
    try await waitUntil { !viewModel.isScanning }
    viewModel.selectedIDs = [item.id]
    viewModel.cleanSelected()
    try await waitUntil { viewModel.alertMessage != nil }

    #expect(viewModel.selectedIDs == [item.id])
    #expect(viewModel.alertMessage == TestFailure.trash.localizedDescription)
    #expect(await scanner.callCount == 1)
}

@Test @MainActor func cleanupWithoutSelectionDoesNothing() async {
    let scanner = ScannerStub(results: [])
    let trash = TrashStub()
    let viewModel = CleanerViewModel(scanner: scanner, trashService: trash)

    viewModel.cleanSelected()
    await Task.yield()

    #expect(await trash.receivedURLs.isEmpty)
    #expect(await scanner.callCount == 0)
}

@Test @MainActor func startupItemLoadingPublishesDiscoveredItems() async throws {
    let item = StartupItem(
        url: URL(fileURLWithPath: "/Library/LaunchAgents/com.example.helper.plist"),
        label: "com.example.helper",
        program: "/Applications/Example.app/Contents/MacOS/Helper",
        programArguments: []
    )
    let discovery = StartupItemDiscoveryStub(result: .success([item]))
    let viewModel = CleanerViewModel(
        scanner: ScannerStub(results: []),
        trashService: TrashStub(),
        startupItemDiscovery: discovery
    )

    viewModel.loadStartupItems()
    #expect(viewModel.isLoadingStartupItems)
    try await waitUntil { !viewModel.isLoadingStartupItems }

    #expect(viewModel.startupItems == [item])
    #expect(viewModel.alertMessage == nil)
    #expect(await discovery.callCount == 1)
}

@Test @MainActor func startupItemLoadingFailurePublishesError() async throws {
    let discovery = StartupItemDiscoveryStub(result: .failure(TestFailure.startupItems))
    let viewModel = CleanerViewModel(
        scanner: ScannerStub(results: []),
        trashService: TrashStub(),
        startupItemDiscovery: discovery
    )

    viewModel.loadStartupItems()
    try await waitUntil { !viewModel.isLoadingStartupItems }

    #expect(viewModel.startupItems.isEmpty)
    #expect(viewModel.alertMessage == TestFailure.startupItems.localizedDescription)
}

@Test @MainActor func applicationLoadingPublishesInventory() async throws {
    let application = testApplication(named: "Example")
    let inventory = ApplicationInventoryStub(results: [.success([application])])
    let viewModel = CleanerViewModel(
        scanner: ScannerStub(results: []),
        trashService: TrashStub(),
        applicationInventory: inventory
    )

    viewModel.loadApplications()
    #expect(viewModel.isLoadingApplications)
    try await waitUntil { !viewModel.isLoadingApplications }

    #expect(viewModel.installedApplications == [application])
    #expect(viewModel.alertMessage == nil)
}

@Test @MainActor func applicationLoadingFailurePublishesError() async throws {
    let inventory = ApplicationInventoryStub(results: [.failure(TestFailure.applications)])
    let viewModel = CleanerViewModel(
        scanner: ScannerStub(results: []),
        trashService: TrashStub(),
        applicationInventory: inventory
    )

    viewModel.loadApplications()
    try await waitUntil { !viewModel.isLoadingApplications }

    #expect(viewModel.installedApplications.isEmpty)
    #expect(viewModel.alertMessage == TestFailure.applications.localizedDescription)
}

@Test @MainActor func applicationRemovalRequiresConfirmationAndRefreshesInventory() async throws {
    let application = testApplication(named: "Example")
    let inventory = ApplicationInventoryStub(results: [.success([application]), .success([])])
    let applicationTrash = ApplicationTrashStub()
    let viewModel = CleanerViewModel(
        scanner: ScannerStub(results: []),
        trashService: TrashStub(),
        applicationInventory: inventory,
        applicationTrashService: applicationTrash
    )

    viewModel.loadApplications()
    try await waitUntil { !viewModel.isLoadingApplications }
    viewModel.requestRemoval(of: application)

    #expect(viewModel.applicationPendingRemoval == application)
    #expect(await applicationTrash.receivedURLs.isEmpty)

    viewModel.confirmRemoval()
    try await waitUntil { await inventory.callCount == 2 && !viewModel.isLoadingApplications }

    #expect(viewModel.applicationPendingRemoval == nil)
    #expect(await applicationTrash.receivedURLs == [application.url])
    #expect(viewModel.installedApplications.isEmpty)
}

@Test @MainActor func cancellingApplicationRemovalDoesNotTrashApplication() async throws {
    let application = testApplication(named: "Example")
    let inventory = ApplicationInventoryStub(results: [.success([application])])
    let applicationTrash = ApplicationTrashStub()
    let viewModel = CleanerViewModel(
        scanner: ScannerStub(results: []),
        trashService: TrashStub(),
        applicationInventory: inventory,
        applicationTrashService: applicationTrash
    )

    viewModel.loadApplications()
    try await waitUntil { !viewModel.isLoadingApplications }
    viewModel.requestRemoval(of: application)
    viewModel.cancelRemoval()
    await Task.yield()

    #expect(viewModel.applicationPendingRemoval == nil)
    #expect(await applicationTrash.receivedURLs.isEmpty)
    #expect(await inventory.callCount == 1)
}

@Test @MainActor func failedApplicationRemovalKeepsInventoryAndPublishesError() async throws {
    let application = testApplication(named: "Example")
    let inventory = ApplicationInventoryStub(results: [.success([application])])
    let applicationTrash = ApplicationTrashStub(error: TestFailure.applicationTrash)
    let viewModel = CleanerViewModel(
        scanner: ScannerStub(results: []),
        trashService: TrashStub(),
        applicationInventory: inventory,
        applicationTrashService: applicationTrash
    )

    viewModel.loadApplications()
    try await waitUntil { !viewModel.isLoadingApplications }
    viewModel.requestRemoval(of: application)
    viewModel.confirmRemoval()
    try await waitUntil { viewModel.alertMessage != nil }

    #expect(viewModel.installedApplications == [application])
    #expect(viewModel.alertMessage == TestFailure.applicationTrash.localizedDescription)
    #expect(await inventory.callCount == 1)
}

@Test @MainActor func removalRequestIgnoresApplicationOutsideCurrentInventory() async {
    let viewModel = CleanerViewModel(scanner: ScannerStub(results: []), trashService: TrashStub())

    viewModel.requestRemoval(of: testApplication(named: "Unknown"))

    #expect(viewModel.applicationPendingRemoval == nil)
}

private func testApplication(named name: String) -> InstalledApplication {
    InstalledApplication(
        url: URL(fileURLWithPath: "/Applications/\(name).app", isDirectory: true),
        name: name,
        bundleIdentifier: "com.example.\(name.lowercased())",
        version: "1.0",
        allocatedSize: 1_024
    )
}
