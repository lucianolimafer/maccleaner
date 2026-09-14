import Testing
@testable import MacCleanerCore

@Test func usedFractionIsClampedAndHandlesEmptyVolumes() {
    #expect(DiskSnapshot().usedFraction == 0)
    #expect(DiskSnapshot(totalBytes: 100, availableBytes: 25).usedFraction == 0.75)
    #expect(DiskSnapshot(totalBytes: 100, availableBytes: -20).usedFraction == 1)
    #expect(DiskSnapshot(totalBytes: 100, availableBytes: 120).usedFraction == 0)
}

@Test func usedBytesNeverFallsBelowZero() {
    #expect(DiskSnapshot(totalBytes: 100, availableBytes: 25).usedBytes == 75)
    #expect(DiskSnapshot(totalBytes: 100, availableBytes: 120).usedBytes == 0)
    #expect(DiskSnapshot(totalBytes: -1, availableBytes: 0).usedBytes == 0)
}
