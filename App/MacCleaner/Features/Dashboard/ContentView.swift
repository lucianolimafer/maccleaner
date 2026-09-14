import AppKit
import MacCleanerCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: CleanerViewModel
    @State private var selection: Destination = .smartScan

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 238)
            detail
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

    private func navigationSection(_ title: String, _ items: [Destination]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).sectionLabel().padding(.horizontal, 23).padding(.top, 6).padding(.bottom, 4)
            ForEach(items) { item in
                Button { selection = item } label: {
                    HStack(spacing: 13) {
                        Image(systemName: item.icon).frame(width: 18)
                        Text(item.title).font(.system(size: 13, weight: selection == item ? .semibold : .regular))
                        Spacer()
                    }
                    .foregroundStyle(selection == item ? .white : Palette.secondary)
                    .padding(.horizontal, 13).frame(height: 36)
                    .background(selection == item ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 9))
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
                ZStack {
                    Circle().fill(RadialGradient(colors: [Palette.primary.opacity(0.32), .clear], center: .center, startRadius: 10, endRadius: 220)).frame(width: 440, height: 360)
                    ForEach([250.0, 310.0, 370.0], id: \.self) { width in
                        Ellipse().stroke(Palette.primary.opacity(0.18), lineWidth: 1).frame(width: width, height: width * 0.48)
                            .rotationEffect(.degrees(width == 310 ? -26 : width == 370 ? 28 : 0))
                    }
                    Circle().fill(Color(hex: 0x0B0D19)).frame(width: 164, height: 164)
                        .overlay(Circle().stroke(Palette.primary.opacity(0.18)))
                        .overlay {
                            VStack(spacing: 10) {
                                Image(systemName: "internaldrive.fill").font(.system(size: 42)).foregroundStyle(Palette.primary)
                                Text(model.isScanning ? "SCANNING" : "READY").font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                        }
                }
                .frame(height: 330)
                VStack(spacing: 6) {
                    Text(model.isScanning ? "Scanning your Mac…" : scanHeadline).font(.system(size: 28, weight: .semibold, design: .rounded))
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

    private var scanHeadline: String {
        guard model.lastScannedAt != nil else { return "Ready to scan" }
        return model.cleanupCandidates.isEmpty ? "Scan complete" : "Cleanup items found"
    }

    private var scanSummary: String {
        guard model.lastScannedAt != nil else { return "Scan storage usage, cache folders, and large files." }
        return "\(model.cleanupCandidates.count) cache items · \(format(model.snapshot.cacheBytes)) potentially cleanable"
    }

    private var alertBinding: Binding<Bool> { Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } }) }
    private var removalBinding: Binding<Bool> { Binding(get: { model.applicationPendingRemoval != nil }, set: { if !$0 { model.cancelRemoval() } }) }
    private func applicationDetail(_ application: InstalledApplication) -> String {
        [application.version.map { "Version \($0)" }, application.bundleIdentifier].compactMap { $0 }.joined(separator: " · ")
    }
    private func format(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    private func openSystemSettings(_ address: String) { if let url = URL(string: address) { NSWorkspace.shared.open(url) } }
}

private enum Destination: String, Identifiable {
    case smartScan, cleanup, storage, startupItems, uninstaller
    var id: String { rawValue }
    var title: String {
        switch self {
        case .smartScan: "Smart Scan"; case .cleanup: "Cleanup"; case .storage: "Storage"
        case .startupItems: "Startup Items"; case .uninstaller: "Uninstaller"
        }
    }
    var icon: String {
        switch self {
        case .smartScan: "scope"; case .cleanup: "paintbrush"; case .storage: "internaldrive"
        case .startupItems: "paperplane"; case .uninstaller: "rectangle.3.group"
        }
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
