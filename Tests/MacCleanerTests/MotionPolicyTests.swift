import Testing
@testable import MacCleaner

@Test func destinationsPreserveProductNavigationOrder() {
    #expect(AppDestination.allCases == [
        .smartScan,
        .cleanup,
        .storage,
        .startupItems,
        .uninstaller
    ])
}

@Test func destinationsExposeEnglishLabelsAndIcons() {
    #expect(AppDestination.allCases.map(\.title) == [
        "Smart Scan",
        "Cleanup",
        "Storage",
        "Startup Items",
        "Uninstaller"
    ])
    #expect(AppDestination.allCases.allSatisfy { !$0.icon.isEmpty })
}

@Test func destinationDirectionFollowsSidebarOrder() {
    #expect(AppDestination.smartScan.direction(to: .cleanup) == .forward)
    #expect(AppDestination.cleanup.direction(to: .uninstaller) == .forward)
    #expect(AppDestination.uninstaller.direction(to: .storage) == .backward)
    #expect(AppDestination.storage.direction(to: .storage) == .none)
    #expect(NavigationDirection.backward.horizontalSign == -1)
    #expect(NavigationDirection.none.horizontalSign == 0)
    #expect(NavigationDirection.forward.horizontalSign == 1)
}

@Test func standardMotionEnablesAnimatedVisualDecisions() {
    let policy = MotionPolicy(reduceMotion: false)

    #expect(policy.animatesOrbits)
    #expect(policy.animatesScanPulse)
    #expect(policy.animatesTabTransitions)
    #expect(policy.tabTransitionDistance == 22)
    #expect(policy.tabTransitionDirection(from: .cleanup, to: .storage) == .forward)
    #expect(policy.tabTransitionDirection(from: .storage, to: .cleanup) == .backward)
}

@Test func reducedMotionDisablesContinuousAndSpatialMovement() {
    let policy = MotionPolicy(reduceMotion: true)

    #expect(!policy.animatesOrbits)
    #expect(!policy.animatesScanPulse)
    #expect(!policy.animatesTabTransitions)
    #expect(policy.tabTransitionDistance == 0)
    #expect(policy.tabTransitionDirection(from: .smartScan, to: .uninstaller) == .none)
}

@Test(arguments: [
    (false, false, 0, Int64(0), ScanVisualState.ready),
    (true, false, 0, Int64(0), ScanVisualState.scanning),
    (true, true, 3, Int64(2_048), ScanVisualState.scanning),
    (false, true, 0, Int64(0), ScanVisualState.complete),
    (false, true, 3, Int64(2_048), ScanVisualState.cleanupAvailable(itemCount: 3, bytes: 2_048))
])
func scanVisualStateReflectsRealScanData(
    isScanning: Bool,
    hasScanned: Bool,
    cleanupItemCount: Int,
    cleanableBytes: Int64,
    expected: ScanVisualState
) {
    #expect(ScanVisualState(
        isScanning: isScanning,
        hasScanned: hasScanned,
        cleanupItemCount: cleanupItemCount,
        cleanableBytes: cleanableBytes
    ) == expected)
}

@Test func scanVisualCopyMatchesItsState() {
    #expect(ScanVisualState.ready.statusLabel == "READY")
    #expect(ScanVisualState.ready.headline == "Ready to scan")
    #expect(ScanVisualState.scanning.statusLabel == "SCANNING")
    #expect(ScanVisualState.scanning.headline == "Scanning your Mac…")
    #expect(ScanVisualState.complete.statusLabel == "COMPLETE")
    #expect(ScanVisualState.complete.headline == "Scan complete")
    #expect(ScanVisualState.cleanupAvailable(itemCount: 1, bytes: 10).statusLabel == "REVIEW")
    #expect(ScanVisualState.cleanupAvailable(itemCount: 1, bytes: 10).headline == "Cleanup items found")
}
