import MacCleanerCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: CleanerViewModel

    var body: some View {
        NavigationSplitView {
            List {
                Label("Overview", systemImage: "chart.pie")
                Label("Cleanup", systemImage: "sparkles")
                Label("Large Files", systemImage: "doc.fill")
            }
            .navigationTitle("MacCleaner")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    storageSummary
                    cleanupList
                    largeFiles
                }
                .padding(28)
            }
        }
        .task { model.scan() }
        .alert("MacCleaner", isPresented: alertBinding) {
            Button("OK") { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Storage overview").font(.largeTitle.bold())
                if let date = model.lastScannedAt {
                    Text("Last scanned \(date.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Scan", systemImage: "arrow.clockwise", action: model.scan)
                .disabled(model.isScanning)
        }
    }

    private var storageSummary: some View {
        GroupBox("Disk usage") {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: model.snapshot.usedFraction)
                Text("\(format(model.snapshot.usedBytes)) used of \(format(model.snapshot.totalBytes))")
                HStack {
                    metric("Caches", model.snapshot.cacheBytes)
                    metric("Trash", model.snapshot.trashBytes)
                    metric("Available", model.snapshot.availableBytes)
                }
            }
            .padding(.top, 8)
        }
    }

    private var cleanupList: some View {
        GroupBox("Safe cleanup") {
            VStack(alignment: .leading, spacing: 12) {
                if model.cleanupCandidates.isEmpty {
                    ContentUnavailableView("No cache items found", systemImage: "checkmark.circle")
                } else {
                    ForEach(model.cleanupCandidates) { item in
                        Toggle(isOn: selectionBinding(for: item.id)) {
                            HStack {
                                Text(item.name).lineLimit(1)
                                Spacer()
                                Text(format(item.bytes)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                HStack {
                    Text("Selected: \(format(model.selectedBytes))").foregroundStyle(.secondary)
                    Spacer()
                    Button("Move to Trash", systemImage: "trash", action: model.cleanSelected)
                        .disabled(model.selectedIDs.isEmpty)
                }
            }
            .padding(.top, 8)
        }
    }

    private var largeFiles: some View {
        GroupBox("Large files — review only") {
            VStack(spacing: 8) {
                ForEach(model.snapshot.largeFiles) { item in
                    HStack {
                        Text(item.name).lineLimit(1)
                        Spacer()
                        Text(format(item.bytes)).foregroundStyle(.secondary)
                    }
                }
                if model.snapshot.largeFiles.isEmpty {
                    Text("No large files found").foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        }
    }

    private func metric(_ title: String, _ bytes: Int64) -> some View {
        VStack(alignment: .leading) {
            Text(title).foregroundStyle(.secondary)
            Text(format(bytes)).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionBinding(for id: CleanupItem.ID) -> Binding<Bool> {
        Binding(
            get: { model.selectedIDs.contains(id) },
            set: { selected in
                if selected { model.selectedIDs.insert(id) } else { model.selectedIDs.remove(id) }
            }
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
