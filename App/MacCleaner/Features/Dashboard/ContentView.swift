import MacCleanerCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: CleanerViewModel
    @State private var selection = "Smart Scan"
    @State private var deepAudit = false

    var body: some View {
        HStack(spacing: 0) { sidebar.frame(width: 238); dashboard }
            .background(Palette.canvas).preferredColorScheme(.dark)
            .task { model.scan() }
            .alert("MacCleaner", isPresented: alertBinding) { Button("OK") { model.alertMessage = nil } } message: { Text(model.alertMessage ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.panel).overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.border))
                    Image(systemName: "drop.triangle.fill").font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.gradient)
                }.frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacCleaner").font(.system(size: 19, weight: .semibold, design: .rounded))
                    Text("V2.4 PRO").font(.system(size: 10, weight: .bold, design: .monospaced)).padding(.horizontal, 7).padding(.vertical, 3).background(Palette.card, in: RoundedRectangle(cornerRadius: 4))
                }
            }.padding(.horizontal, 20).padding(.top, 48).padding(.bottom, 28)

            navigationSection("OVERVIEW", [("Smart Scan", "scope")])
            navigationSection("MAINTENANCE", [("Cleanup", "paintbrush"), ("Storage", "internaldrive"), ("Applications", "circle.grid.3x3"), ("Performance", "gauge.with.dots.needle.67percent")])
            navigationSection("SECURITY", [("Privacy", "lock"), ("Protection", "shield")])
            navigationSection("TOOLS", [("Large Files", "archivebox"), ("Startup Items", "paperplane"), ("Uninstaller", "rectangle.3.group"), ("Duplicate Finder", "square.on.square")])
            Spacer(minLength: 12)
            HStack(spacing: 7) {
                Circle().fill(Palette.primary).frame(width: 8, height: 8); Text("HEALTH 98%"); Spacer(); Text("Optimal").foregroundStyle(Palette.primary)
            }.font(.system(size: 10, weight: .semibold, design: .monospaced)).padding(11).background(Palette.card, in: RoundedRectangle(cornerRadius: 9)).padding(.horizontal, 12)
            sidebarRow("Settings", "gearshape")
            sidebarRow("Help", "questionmark.circle").padding(.bottom, 16)
        }.foregroundStyle(Palette.text).background(Palette.sidebar)
            .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.035)).frame(width: 1) }
    }

    private func navigationSection(_ title: String, _ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.1).foregroundStyle(Palette.muted).padding(.horizontal, 23).padding(.top, 6).padding(.bottom, 4)
            ForEach(items, id: \.0) { sidebarRow($0.0, $0.1) }
        }.padding(.bottom, 10)
    }

    private func sidebarRow(_ title: String, _ icon: String) -> some View {
        Button { selection = title } label: {
            HStack(spacing: 13) { Image(systemName: icon).frame(width: 18); Text(title).font(.system(size: 13, weight: selection == title ? .semibold : .regular)); Spacer() }
                .foregroundStyle(selection == title ? .white : Palette.secondary).padding(.horizontal, 13).frame(height: 36)
                .background(selection == title ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 9)).padding(.horizontal, 12)
        }.buttonStyle(.plain)
    }

    private var dashboard: some View {
        ScrollView { VStack(spacing: 20) { topBar; hero; metricCards; maintenanceBar }.padding(.horizontal, 26).padding(.bottom, 26) }.background(Palette.canvas)
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good morning, Luciano").font(.system(size: 23, weight: .semibold, design: .rounded))
                Text("Your Mac is running well. Let’s keep it that way.").font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            Label("Apple M3 Max  •  36GB", systemImage: "circle.fill").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Palette.primary).padding(.horizontal, 13).frame(height: 30).background(Palette.card, in: Capsule())
            Image(systemName: "gearshape.fill").frame(width: 34, height: 34).background(Palette.card, in: RoundedRectangle(cornerRadius: 9))
            Circle().fill(LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)).frame(width: 34, height: 34).overlay(Image(systemName: "person.fill")).overlay(alignment: .bottomTrailing) { Circle().fill(Palette.primary).frame(width: 9, height: 9) }
        }.foregroundStyle(Palette.text).frame(height: 64)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) { Circle().fill(Palette.primary).frame(width: 7, height: 7); Text("ENGINE CORE V3.8.4"); Text(model.isScanning ? "Telemetry: Scanning" : "Telemetry: Realtime").foregroundStyle(Palette.muted) }.font(.system(size: 10, weight: .semibold, design: .monospaced))
                Spacer()
                Picker("Audit mode", selection: $deepAudit) { Text("Quick").tag(false); Text("Deep Audit").tag(true) }.labelsHidden().pickerStyle(.segmented).frame(width: 150)
            }.padding(.horizontal, 20).padding(.top, 20)
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0x7048FF).opacity(0.30), .clear], center: .center, startRadius: 10, endRadius: 190)).frame(width: 380, height: 300)
                ForEach([230.0, 280.0, 330.0], id: \.self) { width in
                    Ellipse().stroke(Palette.primary.opacity(0.18), lineWidth: 1).frame(width: width, height: width * 0.48).rotationEffect(.degrees(width == 280 ? -26 : width == 330 ? 28 : 0))
                }
                Circle().stroke(Palette.primary.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [5, 8])).frame(width: 230, height: 230)
                Circle().fill(Color(hex: 0x0B0D19)).frame(width: 154, height: 154).overlay(Circle().stroke(Palette.primary.opacity(0.15))).overlay(VStack(spacing: 8) { Image(systemName: "laptopcomputer").font(.system(size: 44)).foregroundStyle(Palette.primary); Text("M3 MAX • 16 CORES").font(.system(size: 10, weight: .bold, design: .monospaced)) })
                statusChip("Security", "Zero Threats", "shield", -145, -105)
                statusChip("Speed", "Turbo Ready", "gauge.with.dots.needle.67percent", 150, -70)
                statusChip("Storage", format(model.snapshot.availableBytes) + " Free", "internaldrive", -140, 100)
                statusChip("Privacy", "Guarded", "lock", 145, 112)
            }.frame(height: 320)
            Text(model.isScanning ? "Scanning your Mac…" : "Your Mac is ready for a checkup").font(.system(size: 27, weight: .semibold, design: .rounded))
            Text("Scan your system for junk files, performance issues, privacy risks, and unnecessary apps.").font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).padding(.top, 5)
            Button(action: model.scan) {
                HStack(spacing: 14) { Image(systemName: model.isScanning ? "hourglass" : "play.fill"); Text(model.isScanning ? "Scanning" : "Scan Mac").font(.system(size: 15, weight: .semibold)); Text("⌘ + RETURN").font(.system(size: 10, weight: .bold, design: .monospaced)).padding(.horizontal, 9).padding(.vertical, 5).background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 6)) }
                    .frame(width: 280, height: 48).foregroundStyle(.white).background(Palette.gradient, in: Capsule()).shadow(color: Palette.primary.opacity(0.22), radius: 18)
            }.buttonStyle(.plain).disabled(model.isScanning).padding(.top, 18)
            Label(lastScanText, systemImage: "clock").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary).padding(.horizontal, 13).padding(.vertical, 7).background(Palette.card, in: Capsule()).padding(.vertical, 12)
        }.foregroundStyle(Palette.text).background(LinearGradient(colors: [Color(hex: 0x121526), Color(hex: 0x151329)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border))
    }

    private func statusChip(_ title: String, _ value: String, _ icon: String, _ x: CGFloat, _ y: CGFloat) -> some View {
        HStack(spacing: 9) { Image(systemName: icon).foregroundStyle(Palette.primary); VStack(alignment: .leading, spacing: 0) { Text(title).foregroundStyle(.white); Text(value).foregroundStyle(Palette.primary) } }
            .font(.system(size: 10, weight: .medium, design: .monospaced)).padding(.horizontal, 12).padding(.vertical, 8).background(Palette.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 9)).offset(x: x, y: y)
    }

    private var metricCards: some View {
        HStack(spacing: 16) {
            metricCard("internaldrive.fill", "STORAGE", format(model.snapshot.availableBytes) + " free", "\(Int(model.snapshot.usedFraction * 100))% used", Color(hex: 0x7652D9)) { ProgressView(value: model.snapshot.usedFraction).tint(Palette.primary) }
            metricCard("memorychip.fill", "MEMORY", "6.2 GB available", "No memory pressure", Color(hex: 0x174892)) { HStack { Gauge(value: 0.78) { }.gaugeStyle(.accessoryCircularCapacity).tint(Palette.primary); Text("21.4 GB app memory").font(.caption).foregroundStyle(Palette.secondary) } }
            metricCard("bolt.fill", "PERFORMANCE", "Excellent", "Thermal state nominal", Color(hex: 0x5C177B)) { HStack(alignment: .bottom, spacing: 5) { ForEach([0.2, 0.35, 0.3, 0.55, 0.72, 0.62, 0.82], id: \.self) { Capsule().fill(Palette.primary).frame(width: 8, height: 28 * $0 + 5) } } }
            metricCard("checkmark.shield.fill", "PROTECTION", "Protected", "0 threats detected", Color(hex: 0x4C4C68)) { Label("Live Shield Active", systemImage: "checkmark.circle").font(.caption).foregroundStyle(Palette.secondary) }
        }
    }

    private func metricCard<Content: View>(_ icon: String, _ label: String, _ value: String, _ detail: String, _ color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) { Image(systemName: icon).foregroundStyle(Palette.primary).frame(width: 34, height: 34).background(color, in: RoundedRectangle(cornerRadius: 9)); VStack(alignment: .leading, spacing: 2) { Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.muted); Text(value).font(.system(size: 16, weight: .semibold, design: .rounded)).lineLimit(2) }; Spacer() }
            content().frame(maxHeight: 38); Spacer(minLength: 0)
            HStack(spacing: 6) { Circle().fill(Palette.primary).frame(width: 6, height: 6); Text(detail).font(.system(size: 10)).foregroundStyle(Palette.secondary) }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading).foregroundStyle(Palette.text).background(Palette.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))
    }

    private var maintenanceBar: some View {
        HStack(spacing: 10) { Image(systemName: "sparkles").foregroundStyle(Palette.primary); Text("Auto-maintenance scheduler active").foregroundStyle(Palette.text); Text("•  Next pass in 6 hours").foregroundStyle(Palette.muted); Spacer(); Text("Estimated cleanable space:").foregroundStyle(Palette.muted); Text(format(model.snapshot.cacheBytes + model.snapshot.trashBytes)).foregroundStyle(Palette.primary); Button("Preferences") { selection = "Settings" }.buttonStyle(.bordered) }
            .font(.system(size: 11, design: .monospaced)).padding(.horizontal, 16).frame(height: 50).background(Palette.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
    }

    private var lastScanText: String { guard let date = model.lastScannedAt else { return "Preparing first checkup  •  System state: Good" }; return "Last checked \(date.formatted(date: .abbreviated, time: .shortened))  •  System state: Good" }
    private var alertBinding: Binding<Bool> { Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } }) }
    private func format(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

private enum Palette {
    static let canvas = Color(hex: 0x090B16), sidebar = Color(hex: 0x11131E), panel = Color(hex: 0x191B2A)
    static let card = Color.white.opacity(0.055), border = Color.white.opacity(0.07), text = Color(hex: 0xF2EFFF)
    static let secondary = Color.white.opacity(0.68), muted = Color.white.opacity(0.42), primary = Color(hex: 0xCDBDFF)
    static let gradient = LinearGradient(colors: [Color(hex: 0x7C4DFF), Color(hex: 0x2563FF), Color(hex: 0xB62CFF)], startPoint: .leading, endPoint: .trailing)
}

private extension Color {
    init(hex: UInt) { self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1) }
}
