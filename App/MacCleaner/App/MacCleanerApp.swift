import SwiftUI

@available(iOS 14.0, *)
@main
struct MacCleanerApp: App {
    @State private var model = CleanerViewModel()
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    ContentView(model: model)
                } else {
                    OnboardingView(isComplete: $onboardingCompleted)
                }
            }
                .frame(minWidth: 1040, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Run Setup Again…") { onboardingCompleted = false }
            }
        }
    }
}
