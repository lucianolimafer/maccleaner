import SwiftUI

@available(iOS 14.0, *)
@main
struct MacCleanerApp: App {
    @State private var model = CleanerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 900, minHeight: 620)
        }
    }
}
