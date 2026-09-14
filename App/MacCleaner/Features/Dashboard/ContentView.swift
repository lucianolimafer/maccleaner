import AppKit
import MacCleanerCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: CleanerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var navigationHighlight
    @State private var selection: AppDestination = .smartScan
    @State private var navigationDirection: NavigationDirection = .none

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 238)
            ZStack {
                detail
                    .id(selection)
                    .transition(detailTransition)
            }
            .clipped()
        }
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
        .task { model.scan() }
        .alert("MacCleaner", isPresented: alertBinding) {
            Button("OK") { model.alertMessage = nil }
        } message: { Text(model.alertMessage ?? "") }
        .confirmationDialog(
            "Move application to Trash?",
            isPresented: removalBinding,
            titleVisibility: .visible,
            presenting: model.applicationPendingRemoval
        ) { _ in
            Button("Move to Trash", role: .destructive) { model.confirmRemoval() }
            Button("Cancel", role: .cancel) { model.cancelRemoval() }
        } message: { application in
            Text("\(application.name) will be moved to the Trash. Its related data may remain on this Mac.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.panel)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.border))
                    Image(systemName: "drop.triangle.fill").font(.system(size: 18)).foregroundStyle(Palette.gradient)
                }
                .frame(width: 38, height: 38)
                Text("MacCleaner").font(.system(size: 19, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 28)

            navigationSection("OVERVIEW", [.smartScan])
            navigationSection("CLEANING", [.cleanup, .storage])
            navigationSection("APPLICATIONS", [.startupItems, .uninstaller])
            Spacer()
        }
        .foregroundStyle(Palette.text).background(Palette.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.035)).frame(width: 1) }
    }

    private func navigationSection(_ title: String, _ items: [AppDestination]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).sectionLabel().padding(.horizontal, 23).padding(.top, 6).padding(.bottom, 4)
            ForEach(items) { item in
                Button { select(item) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: item.icon).frame(width: 18)
                        Text(item.title).font(.system(size: 13, weight: selection == item ? .semibold : .regular))
                        Spacer()
                    }
                    .foregroundStyle(selection == item ? .white : Palette.secondary)
                    .padding(.horizontal, 13).frame(height: 36)
                    .background {
                        if selection == item {
                            if reduceMotion {
                                RoundedRectangle(cornerRadius: 9).fill(Palette.gradient)
                            } else {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Palette.gradient)
                                    .matchedGeometryEffect(id: "navigation-highlight", in: navigationHighlight)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .smartScan: smartScan
        case .cleanup: cleanup
        case .storage: storage
        case .startupItems: startupItems
        case .uninstaller: uninstaller
        }
    }

    private var smartScan: some View {
        page(title: "Smart Scan", subtitle: "Review storage usage and find cache items that can be removed.") {
            VStack(spacing: 24) {
                ScanOrbitVisual(
                    state: scanVisualState,
                    cleanableBytes: model.snapshot.cacheBytes,
                    largeFileCount: model.snapshot.largeFiles.count,
                    motionPolicy: motionPolicy
                )
                .frame(maxWidth: .infinity, minHeight: 330, maxHeight: 330)
                VStack(spacing: 6) {
                    Text(scanVisualState.headline).font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(scanSummary).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.secondary)
                }
                primaryButton(model.isScanning ? "Scanning" : "Scan Mac", icon: model.isScanning ? "hourglass" : "play.fill") { model.scan() }
                    .disabled(model.isScanning)
                if let date = model.lastScannedAt {
                    Label("Last scanned \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(28).background(Palette.hero, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border))
        }
    }

    private var cleanup: some View {
        page(title: "Cleanup", subtitle: "Choose cache items to move to the Trash.") {
            summaryCard(icon: "paintbrush.fill", label: "SELECTED", value: format(model.selectedBytes)) {
                primaryButton("Move Selected to Trash", icon: "trash") { model.cleanSelected() }
                    .disabled(model.selectedIDs.isEmpty || model.isScanning)
            }
            itemList(items: model.cleanupCandidates, emptyTitle: model.isScanning ? "Scanning for cache files…" : "No cache folders found", emptyMessage: "Run Smart Scan to refresh the cleanup list.") { item in
                Toggle(isOn: selectionBinding(for: item)) { fileRow(item) }.toggleStyle(.checkbox)
            }
        }
    }

    private var storage: some View {
        page(title: "Storage", subtitle: "Inspect disk usage and large files found in your home folder.") {
            HStack(spacing: 16) {
                summaryCard(icon: "internaldrive.fill", label: "AVAILABLE", value: format(model.snapshot.availableBytes))
                summaryCard(icon: "chart.pie.fill", label: "USED", value: format(model.snapshot.usedBytes))
                summaryCard(icon: "doc.fill", label: "LARGE FILES", value: "\(model.snapshot.largeFiles.count)")
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DISK USAGE").sectionLabel(); Spacer()
                    Text("\(Int(model.snapshot.usedFraction * 100))% used").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
                }
                ProgressView(value: model.snapshot.usedFraction).tint(Palette.primary)
            }
            .cardStyle()
            itemList(items: model.snapshot.largeFiles, emptyTitle: model.isScanning ? "Scanning for large files…" : "No large files found", emptyMessage: "Files larger than 500 MB appear here after a scan.") { fileRow($0) }
        }
    }

    private var startupItems: some View {
        page(title: "Startup Items", subtitle: "Review launch agents found in standard macOS locations.") {
            HStack {
                Text("\(model.startupItems.count) items found").foregroundStyle(Palette.secondary)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { model.loadStartupItems() }.disabled(model.isLoadingStartupItems)
                Button("Open Login Items", systemImage: "arrow.up.forward.app") {
                    openSystemSettings("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
                }
            }
            .buttonStyle(.bordered)
            startupItemList
        }
        .task {
            if model.startupItems.isEmpty { model.loadStartupItems() }
        }
    }

    private var startupItemList: some View {
        VStack(spacing: 0) {
            if model.startupItems.isEmpty {
                ContentUnavailableView(
                    model.isLoadingStartupItems ? "Loading startup items…" : "No launch agents found",
                    systemImage: "paperplane",
                    description: Text("Login items managed directly by macOS can be reviewed in System Settings.")
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                ForEach(model.startupItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.fill").foregroundStyle(Palette.primary).frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label).lineLimit(1)
                            Text(item.program ?? item.programArguments.first ?? item.url.path)
                                .font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                        Spacer()
                        Text(item.url.deletingLastPathComponent().lastPathComponent)
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.secondary)
                    }
                    .padding(.horizontal, 18).frame(minHeight: 58)
                    if item.id != model.startupItems.last?.id { Divider().overlay(Palette.border) }
                }
            }
        }
        .listCardStyle()
    }

    private var uninstaller: some View {
        page(title: "Uninstaller", subtitle: "Review installed applications and move one to the Trash.") {
            HStack {
                Text("\(model.installedApplications.count) apps found").foregroundStyle(Palette.secondary)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { model.loadApplications() }.disabled(model.isLoadingApplications)
                Button("Open Applications", systemImage: "folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
                }
            }
            .buttonStyle(.bordered)
            applicationList
        }
        .task {
            if model.installedApplications.isEmpty { model.loadApplications() }
        }
    }

    private var applicationList: some View {
        VStack(spacing: 0) {
            if model.installedApplications.isEmpty {
                ContentUnavailableView(
                    model.isLoadingApplications ? "Loading applications…" : "No applications found",
                    systemImage: "app.dashed",
                    description: Text("Applications in standard macOS folders appear here.")
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                ForEach(model.installedApplications) { application in
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: application.url.path))
                            .resizable().scaledToFit().frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(application.name).lineLimit(1)
                            Text(applicationDetail(application)).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                        Spacer()
                        if let bytes = application.allocatedSize {
                            Text(format(bytes)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.secondary)
                        }
                        Button("Move to Trash") { model.requestRemoval(of: application) }
                            .buttonStyle(.bordered).tint(.red)
                    }
                    .padding(.horizontal, 18).frame(minHeight: 64)
                    if application.id != model.installedApplications.last?.id { Divider().overlay(Palette.border) }
                }
            }
        }
        .listCardStyle()
    }

    private func page<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                }
                .padding(.top, 22)
                content()
            }
            .padding(.horizontal, 28).padding(.bottom, 28)
        }
        .foregroundStyle(Palette.text).background(Palette.canvas)
    }

    private func summaryCard<Accessory: View>(icon: String, label: String, value: String, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Palette.primary).frame(width: 38, height: 38)
                .background(Palette.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) { Text(label).sectionLabel(); Text(value).font(.system(size: 19, weight: .semibold, design: .rounded)) }
            Spacer(); accessory()
        }
        .cardStyle().frame(maxWidth: .infinity)
    }

    private func itemList<Row: View>(items: [CleanupItem], emptyTitle: String, emptyMessage: String, @ViewBuilder row: @escaping (CleanupItem) -> Row) -> some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "tray", description: Text(emptyMessage)).frame(maxWidth: .infinity, minHeight: 240)
            } else {
                ForEach(items) { item in
                    row(item).padding(.horizontal, 18).frame(minHeight: 58)
                    if item.id != items.last?.id { Divider().overlay(Palette.border) }
                }
            }
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))
    }

    private func fileRow(_ item: CleanupItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind == .cache ? "folder.fill" : "doc.fill").foregroundStyle(Palette.primary).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent).lineLimit(1)
                Text(item.url.deletingLastPathComponent().path).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer()
            Text(format(item.bytes)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
        }
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 24).frame(height: 44)
                .foregroundStyle(.white).background(Palette.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func selectionBinding(for item: CleanupItem) -> Binding<Bool> {
        Binding(get: { model.selectedIDs.contains(item.id) }, set: { selected in
            if selected { model.selectedIDs.insert(item.id) } else { model.selectedIDs.remove(item.id) }
        })
    }

    private var scanVisualState: ScanVisualState {
        ScanVisualState(
            isScanning: model.isScanning,
            hasScanned: model.lastScannedAt != nil,
            cleanupItemCount: model.cleanupCandidates.count,
            cleanableBytes: model.snapshot.cacheBytes
        )
    }

    private var scanSummary: String {
        guard model.lastScannedAt != nil else { return "Scan storage usage, cache folders, and large files." }
        return "\(model.cleanupCandidates.count) cache items · \(format(model.snapshot.cacheBytes)) potentially cleanable"
    }

    private var detailTransition: AnyTransition {
        guard motionPolicy.animatesTabTransitions else { return .opacity }
        let offset = motionPolicy.tabTransitionDistance * navigationDirection.horizontalSign
        return .asymmetric(
            insertion: .offset(x: offset).combined(with: .opacity),
            removal: .offset(x: -offset).combined(with: .opacity)
        )
    }

    private var motionPolicy: MotionPolicy { MotionPolicy(reduceMotion: reduceMotion) }

    private func select(_ destination: AppDestination) {
        guard destination != selection else { return }
        navigationDirection = motionPolicy.tabTransitionDirection(from: selection, to: destination)
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .snappy(duration: 0.34, extraBounce: 0.04)) {
            selection = destination
        }
    }

    private var alertBinding: Binding<Bool> { Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } }) }
    private var removalBinding: Binding<Bool> { Binding(get: { model.applicationPendingRemoval != nil }, set: { if !$0 { model.cancelRemoval() } }) }
    private func applicationDetail(_ application: InstalledApplication) -> String {
        [application.version.map { "Version \($0)" }, application.bundleIdentifier].compactMap { $0 }.joined(separator: " · ")
    }
    private func format(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    private func openSystemSettings(_ address: String) { if let url = URL(string: address) { NSWorkspace.shared.open(url) } }
}

private struct ScanOrbitVisual: View {
    let state: ScanVisualState
    let cleanableBytes: Int64
    let largeFileCount: Int
    let motionPolicy: MotionPolicy

    private var isScanning: Bool { state == .scanning }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: isScanning ? 1.0 / 30.0 : 1.0 / 12.0,
            paused: !motionPolicy.animatesOrbits
        )) { timeline in
            let seconds = motionPolicy.animatesOrbits ? timeline.date.timeIntervalSinceReferenceDate : 0
            let phase = seconds * (isScanning ? 1.0 : 0.18)

            GeometryReader { proxy in
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Palette.primary.opacity(isScanning ? 0.34 : 0.22), .clear],
                            center: .center,
                            startRadius: 14,
                            endRadius: 210
                        ))
                        .frame(width: 440, height: 340)
                        .scaleEffect(motionPolicy.animatesScanPulse ? 1 + sin(phase * 2.2) * (isScanning ? 0.035 : 0.012) : 1)

                    orbit(width: 238, height: 126, rotation: phase * 16)
                    orbit(width: 304, height: 150, rotation: -26 - phase * 10)
                    orbit(width: 368, height: 176, rotation: 28 + phase * 7)
                    orbit(width: 330, height: 248, rotation: 78 - phase * 5, dashed: true)

                    orbitParticle(center: center, width: 238, height: 126, angle: phase * 1.8, rotation: phase * 16)
                    orbitParticle(center: center, width: 304, height: 150, angle: phase * -1.25 + 2.2, rotation: -26 - phase * 10)
                    orbitParticle(center: center, width: 368, height: 176, angle: phase * 0.85 + 4.1, rotation: 28 + phase * 7)

                    scanCore(phase: phase)

                    orbitBadge(
                        icon: "paintbrush.fill",
                        label: "CACHE ITEMS",
                        value: ByteCountFormatter.string(fromByteCount: cleanableBytes, countStyle: .file)
                    )
                    .position(x: center.x - 142, y: center.y + 108)

                    orbitBadge(
                        icon: "doc.fill",
                        label: "LARGE FILES",
                        value: "\(largeFileCount) found"
                    )
                    .position(x: center.x + 148, y: center.y - 102)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.headline)
        .accessibilityValue("\(largeFileCount) large files and \(ByteCountFormatter.string(fromByteCount: cleanableBytes, countStyle: .file)) in cache items")
    }

    private func orbit(width: CGFloat, height: CGFloat, rotation: Double, dashed: Bool = false) -> some View {
        Ellipse()
            .stroke(
                Palette.primary.opacity(dashed ? 0.13 : 0.22),
                style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 8] : [])
            )
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
    }

    private func orbitParticle(center: CGPoint, width: CGFloat, height: CGFloat, angle: Double, rotation: Double) -> some View {
        let point = pointOnEllipse(center: center, width: width, height: height, angle: angle, rotation: rotation)
        return Circle()
            .fill(Color.white)
            .frame(width: isScanning ? 7 : 5, height: isScanning ? 7 : 5)
            .shadow(color: Palette.primary, radius: isScanning ? 8 : 4)
            .position(point)
    }

    private func pointOnEllipse(center: CGPoint, width: CGFloat, height: CGFloat, angle: Double, rotation: Double) -> CGPoint {
        let x = cos(angle) * width / 2
        let y = sin(angle) * height / 2
        let radians = rotation * .pi / 180
        return CGPoint(
            x: center.x + x * cos(radians) - y * sin(radians),
            y: center.y + x * sin(radians) + y * cos(radians)
        )
    }

    private func scanCore(phase: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x090B17))
                .shadow(color: Palette.primary.opacity(isScanning ? 0.35 : 0.16), radius: isScanning ? 26 : 14)
            Circle().stroke(Palette.primary.opacity(0.28), lineWidth: 1)
            Circle()
                .trim(from: 0.06, to: isScanning ? 0.62 : 0.28)
                .stroke(Palette.gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(motionPolicy.animatesOrbits ? phase * 110 - 90 : -90))
            VStack(spacing: 10) {
                Image(systemName: isScanning ? "magnifyingglass" : "internaldrive.fill")
                    .font(.system(size: 39, weight: .medium))
                    .foregroundStyle(Palette.primary)
                    .symbolEffect(.pulse, options: .repeating, isActive: isScanning && motionPolicy.animatesScanPulse)
                Text(state.statusLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
            }
        }
        .frame(width: 154, height: 154)
        .scaleEffect(motionPolicy.animatesScanPulse ? 1 + sin(phase * 2.6) * (isScanning ? 0.025 : 0.006) : 1)
    }

    private func orbitBadge(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(Palette.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.muted)
                Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.text)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Palette.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border))
    }
}

private enum Palette {
    static let canvas = Color(hex: 0x090B16), sidebar = Color(hex: 0x11131E), panel = Color(hex: 0x191B2A)
    static let card = Color.white.opacity(0.055), border = Color.white.opacity(0.07), text = Color(hex: 0xF2EFFF)
    static let secondary = Color.white.opacity(0.68), muted = Color.white.opacity(0.42), primary = Color(hex: 0xCDBDFF)
    static let hero = LinearGradient(colors: [Color(hex: 0x121526), Color(hex: 0x151329)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let gradient = LinearGradient(colors: [Color(hex: 0x7C4DFF), Color(hex: 0x2563FF), Color(hex: 0xB62CFF)], startPoint: .leading, endPoint: .trailing)
}

private extension View {
    func cardStyle() -> some View { padding(18).background(Palette.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border)) }
    func listCardStyle() -> some View { background(Palette.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border)) }
    func sectionLabel() -> some View { font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(0.8).foregroundStyle(Palette.muted) }
}

private extension Color {
    init(hex: UInt) { self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1) }
}
