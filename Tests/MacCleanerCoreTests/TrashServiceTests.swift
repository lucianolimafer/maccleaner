import Foundation
import Testing
@testable import MacCleanerCore

@Test func trashServiceRejectsItemsOutsideTopLevelCacheDirectory() async {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let service = TrashService(homeDirectory: home)
    let unsafeURL = home.appending(path: "Documents/important.txt")

    await #expect(throws: TrashError.unsafeLocation(unsafeURL)) {
        try await service.moveToTrash([unsafeURL])
    }
}

@Test func trashServiceRejectsNestedCacheItems() async {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let service = TrashService(homeDirectory: home)
    let nestedURL = home.appending(path: "Library/Caches/vendor/item")

    await #expect(throws: TrashError.unsafeLocation(nestedURL)) {
        try await service.moveToTrash([nestedURL])
    }
}
