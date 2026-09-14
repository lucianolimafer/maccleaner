import AppKit
import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var step = 0
    @State private var fullDiskAccess = PermissionManager.hasFullDiskAccess

    var body: some View {
        ZStack {
            OnboardingPalette.canvas.ignoresSafeArea()
            Circle()
                .fill(OnboardingPalette.accent.opacity(0.16))
                .frame(width: 560, height: 560)
                .blur(radius: 100)
                .offset(x: 320, y: -260)

            VStack(spacing: 0) {
                header
                TabView(selection: $step) {
                    welcome.tag(0)
                    permissions.tag(1)
                    ready.tag(2)
                }
                .tabViewStyle(.automatic)
                .animation(.easeInOut(duration: 0.25), value: step)
                footer
            }
            .padding(32)
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermission()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(OnboardingPalette.card)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "drop.triangle.fill").foregroundStyle(OnboardingPalette.gradient))
                Text("MacCleaner").font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            Spacer()
            Text("SETUP  \(step + 1) / 3")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var welcome: some View {
        onboardingPage(
            icon: "sparkles",
            eyebrow: "WELCOME TO MACCLEANER",
            title: "A cleaner, faster Mac\nstarts here.",
            subtitle: "MacCleaner finds storage you can safely reclaim and gives you a clear view of your Mac’s health. You always stay in control.",
            features: [
                ("internaldrive", "Smart storage scan", "Find caches, trash and unusually large files."),
                ("lock.shield", "Privacy first", "Analysis happens locally on this Mac."),
                ("trash", "Safe cleanup", "Items are moved to Trash, never erased immediately.")
            ]
        )
    }

    private var permissions: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(OnboardingPalette.gradient)
            VStack(spacing: 9) {
                Text("Allow Full Disk Access")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("This lets MacCleaner measure protected folders and provide complete, accurate scan results. Your files never leave your Mac.")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center).frame(maxWidth: 570)
            }

            VStack(spacing: 0) {
                permissionRow(number: "1", text: "Open Privacy & Security in System Settings", done: false)
                Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 54)
                permissionRow(number: "2", text: "Enable MacCleaner under Full Disk Access", done: fullDiskAccess)
                Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 54)
                permissionRow(number: "3", text: "Return here and verify access", done: fullDiskAccess)
            }
            .frame(maxWidth: 610)
            .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))

            HStack(spacing: 12) {
                Button("Open System Settings", systemImage: "gearshape.fill") { PermissionManager.openFullDiskAccessSettings() }
                    .buttonStyle(.borderedProminent).tint(OnboardingPalette.accent)
                Button("Check Again", systemImage: "arrow.clockwise") { refreshPermission() }
                    .buttonStyle(.bordered)
            }

            Label(
                fullDiskAccess ? "Full Disk Access is enabled" : "Waiting for Full Disk Access",
                systemImage: fullDiskAccess ? "checkmark.circle.fill" : "clock"
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(fullDiskAccess ? Color.green : Color.white.opacity(0.5))
            Spacer()
        }
    }

    private var ready: some View {
        onboardingPage(
            icon: "checkmark.seal.fill",
            eyebrow: "SETUP COMPLETE",
            title: "Ready for your\nfirst checkup.",
            subtitle: "MacCleaner has the access it needs. Start with a smart scan to understand your storage and system health.",
            features: [
                ("checkmark.circle", "Access verified", "Full Disk Access is active."),
                ("eye.slash", "Private by design", "No account, upload or tracking required."),
                ("cursorarrow.click", "You approve every action", "Nothing is cleaned without your confirmation.")
            ]
        )
    }

    private func onboardingPage(
        icon: String,
        eyebrow: String,
        title: String,
        subtitle: String,
        features: [(String, String, String)]
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon).font(.system(size: 54, weight: .light)).foregroundStyle(OnboardingPalette.gradient)
            VStack(spacing: 10) {
                Text(eyebrow).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(OnboardingPalette.primary)
                Text(title).font(.system(size: 36, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(.white.opacity(0.62)).multilineTextAlignment(.center).frame(maxWidth: 590)
            }
            HStack(spacing: 14) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                    VStack(alignment: .leading, spacing: 9) {
                        Image(systemName: feature.0).font(.system(size: 20)).foregroundStyle(OnboardingPalette.primary)
                        Text(feature.1).font(.system(size: 13, weight: .semibold))
                        Text(feature.2).font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
                    .padding(16).background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07)))
                }
            }.frame(maxWidth: 720)
            Spacer()
        }
    }

    private func permissionRow(number: String, text: String, done: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(done ? Color.green.opacity(0.16) : OnboardingPalette.accent.opacity(0.18)).frame(width: 30, height: 30)
                if done { Image(systemName: "checkmark").foregroundStyle(.green) }
                else { Text(number).foregroundStyle(OnboardingPalette.primary) }
            }.font(.system(size: 11, weight: .bold, design: .monospaced))
            Text(text).font(.system(size: 13, weight: .medium))
            Spacer()
        }.padding(.horizontal, 18).frame(height: 54)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in Capsule().fill(index == step ? OnboardingPalette.primary : Color.white.opacity(0.14)).frame(width: index == step ? 22 : 7, height: 7) }
            }
            Spacer()
            if step > 0 { Button("Back") { step -= 1 }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.62)).padding(.trailing, 10) }
            Button(step == 2 ? "Start Smart Scan" : "Continue") {
                if step == 2 { isComplete = true } else { step += 1 }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 150, height: 40)
            .background(OnboardingPalette.gradient, in: RoundedRectangle(cornerRadius: 10))
            .opacity(step == 1 && !fullDiskAccess ? 0.45 : 1)
            .disabled(step == 1 && !fullDiskAccess)
        }
    }

    private func refreshPermission() {
        fullDiskAccess = PermissionManager.hasFullDiskAccess
    }
}

private enum PermissionManager {
    static var hasFullDiskAccess: Bool {
        let protectedLocations = ["Library/Safari", "Library/Mail"]
        return protectedLocations.contains { relativePath in
            let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: relativePath, directoryHint: .isDirectory)
            guard FileManager.default.fileExists(atPath: url.path) else { return false }
            return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).isEmpty) != nil
        }
    }

    static func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}

private enum OnboardingPalette {
    static let canvas = Color(red: 9 / 255, green: 11 / 255, blue: 22 / 255)
    static let card = Color.white.opacity(0.055)
    static let accent = Color(red: 124 / 255, green: 77 / 255, blue: 255 / 255)
    static let primary = Color(red: 205 / 255, green: 189 / 255, blue: 255 / 255)
    static let gradient = LinearGradient(colors: [accent, Color(red: 37 / 255, green: 99 / 255, blue: 255 / 255), Color(red: 182 / 255, green: 44 / 255, blue: 255 / 255)], startPoint: .leading, endPoint: .trailing)
}
