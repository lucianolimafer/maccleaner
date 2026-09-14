import Foundation

enum AppDestination: String, CaseIterable, Identifiable, Sendable {
    case smartScan
    case cleanup
    case storage
    case startupItems
    case uninstaller

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartScan: "Smart Scan"
        case .cleanup: "Cleanup"
        case .storage: "Storage"
        case .startupItems: "Startup Items"
        case .uninstaller: "Uninstaller"
        }
    }

    var icon: String {
        switch self {
        case .smartScan: "scope"
        case .cleanup: "paintbrush"
        case .storage: "internaldrive"
        case .startupItems: "paperplane"
        case .uninstaller: "rectangle.3.group"
        }
    }

    private var navigationIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    func direction(to destination: Self) -> NavigationDirection {
        if navigationIndex < destination.navigationIndex { return .forward }
        if navigationIndex > destination.navigationIndex { return .backward }
        return .none
    }
}

enum NavigationDirection: Equatable, Sendable {
    case backward
    case none
    case forward

    var horizontalSign: Double {
        switch self {
        case .backward: -1
        case .none: 0
        case .forward: 1
        }
    }
}

enum ScanVisualState: Equatable, Sendable {
    case ready
    case scanning
    case complete
    case cleanupAvailable(itemCount: Int, bytes: Int64)

    init(isScanning: Bool, hasScanned: Bool, cleanupItemCount: Int, cleanableBytes: Int64) {
        if isScanning {
            self = .scanning
        } else if !hasScanned {
            self = .ready
        } else if cleanupItemCount > 0 {
            self = .cleanupAvailable(itemCount: cleanupItemCount, bytes: cleanableBytes)
        } else {
            self = .complete
        }
    }

    var statusLabel: String {
        switch self {
        case .ready: "READY"
        case .scanning: "SCANNING"
        case .complete: "COMPLETE"
        case .cleanupAvailable: "REVIEW"
        }
    }

    var headline: String {
        switch self {
        case .ready: "Ready to scan"
        case .scanning: "Scanning your Mac…"
        case .complete: "Scan complete"
        case .cleanupAvailable: "Cleanup items found"
        }
    }
}

struct MotionPolicy: Equatable, Sendable {
    let reduceMotion: Bool

    var animatesOrbits: Bool { !reduceMotion }
    var animatesScanPulse: Bool { !reduceMotion }
    var animatesTabTransitions: Bool { !reduceMotion }
    var tabTransitionDistance: Double { reduceMotion ? 0 : 22 }

    func tabTransitionDirection(from source: AppDestination, to destination: AppDestination) -> NavigationDirection {
        guard animatesTabTransitions else { return .none }
        return source.direction(to: destination)
    }
}
