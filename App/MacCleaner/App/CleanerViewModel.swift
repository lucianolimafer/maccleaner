import Foundation
import MacCleanerCore
import Observation

@MainActor
@Observable
final class CleanerViewModel {
    private let scanner: any StorageScanning
    private let trashService: any Trashing

    private(set) var snapshot = DiskSnapshot()
    private(set) var cleanupCandidates: [CleanupItem] = []
    private(set) var isScanning = false
    private(set) var lastScannedAt: Date?
    var selectedIDs = Set<CleanupItem.ID>()
    var alertMessage: String?

    var selectedBytes: Int64 {
        cleanupCandidates.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.bytes }
    }

    init(scanner: any StorageScanning = StorageScanner(), trashService: any Trashing = TrashService()) {
        self.scanner = scanner
        self.trashService = trashService
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
}
