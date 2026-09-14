import Foundation
import MacCleanerCore
import Observation

@MainActor
@Observable
final class CleanerViewModel {
    private let scanner: any StorageScanning
    private let trashService: any Trashing
    private let startupItemDiscovery: any StartupItemDiscovering
    private let applicationInventory: any ApplicationInventoryProviding
    private let applicationTrashService: any ApplicationTrashing

    private(set) var snapshot = DiskSnapshot()
    private(set) var cleanupCandidates: [CleanupItem] = []
    private(set) var isScanning = false
    private(set) var lastScannedAt: Date?
    private(set) var startupItems: [StartupItem] = []
    private(set) var installedApplications: [InstalledApplication] = []
    private(set) var isLoadingStartupItems = false
    private(set) var isLoadingApplications = false
    private(set) var applicationPendingRemoval: InstalledApplication?
    var selectedIDs = Set<CleanupItem.ID>()
    var alertMessage: String?

    var selectedBytes: Int64 {
        cleanupCandidates.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.bytes }
    }

    init(
        scanner: any StorageScanning = StorageScanner(),
        trashService: any Trashing = TrashService(),
        startupItemDiscovery: any StartupItemDiscovering = StartupItemDiscoveryService(),
        applicationInventory: any ApplicationInventoryProviding = ApplicationInventoryService(),
        applicationTrashService: any ApplicationTrashing = ApplicationTrashService()
    ) {
        self.scanner = scanner
        self.trashService = trashService
        self.startupItemDiscovery = startupItemDiscovery
        self.applicationInventory = applicationInventory
        self.applicationTrashService = applicationTrashService
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        alertMessage = nil
        Task {
            defer { isScanning = false }
            do {
                let result = try await scanner.scan()
                snapshot = result.snapshot
                cleanupCandidates = result.cleanupCandidates
                selectedIDs.formIntersection(Set(result.cleanupCandidates.map(\.id)))
                lastScannedAt = .now
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func cleanSelected() {
        let selected = cleanupCandidates.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        Task {
            do {
                try await trashService.moveToTrash(selected.map(\.url))
                selectedIDs.removeAll()
                scan()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func loadStartupItems() {
        guard !isLoadingStartupItems else { return }
        isLoadingStartupItems = true
        alertMessage = nil
        Task {
            defer { isLoadingStartupItems = false }
            do {
                startupItems = try await startupItemDiscovery.discover()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func loadApplications() {
        guard !isLoadingApplications else { return }
        isLoadingApplications = true
        alertMessage = nil
        Task {
            defer { isLoadingApplications = false }
            do {
                installedApplications = try await applicationInventory.applications()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func requestRemoval(of application: InstalledApplication) {
        guard installedApplications.contains(application) else { return }
        applicationPendingRemoval = application
    }

    func cancelRemoval() {
        applicationPendingRemoval = nil
    }

    func confirmRemoval() {
        guard let application = applicationPendingRemoval else { return }
        applicationPendingRemoval = nil
        Task {
            do {
                try await applicationTrashService.moveToTrash(application.url)
                loadApplications()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }
}
