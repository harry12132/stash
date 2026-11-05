import SwiftUI
import ServiceManagement
import AppKit

private struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.24), lineWidth: 0.7))
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.7))
        }
    }
}

private struct ClipboardThumbnail: View {
    let item: ClipboardItem
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if item.type == .image, let data = item.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.type == .image ? "photo" : item.type.symbol)
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundStyle(item.type == .image ? Color.secondary : Color.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(item.type == .image ? Color.primary.opacity(0.045) : Color.accentColor.opacity(0.09))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 0.7)
        }
        .accessibilityHidden(true)
    }
}

private func highlightedText(_ text: String, matching query: String) -> AttributedString {
    var result = AttributedString(text)
    guard !query.isEmpty else { return result }

    var searchRange = text.startIndex..<text.endIndex
    while let match = text.range(
        of: query,
        options: [.caseInsensitive, .diacriticInsensitive],
        range: searchRange
    ) {
        if let attributedRange = Range(match, in: result) {
            result[attributedRange].foregroundColor = .accentColor
            result[attributedRange].backgroundColor = Color.accentColor.opacity(0.2)
        }
        searchRange = match.upperBound..<text.endIndex
    }

    return result
}

struct HUDView: View {
    @ObservedObject var manager: ClipboardManager
    var onSelect: (ClipboardItem) -> Void
    @State private var hoveredItemID: ClipboardItem.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                if let logo = StashLogo.image {
                    Image(nsImage: logo)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "clipboard")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                        .accessibilityLabel("Stash")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stash")
                        .font(.system(size: 16, weight: .semibold))
                    Text(manager.history.count == 1 ? "1 item saved" : "\(manager.history.count) items saved")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("⌥ 1–5")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.primary.opacity(0.055), in: Capsule())
            }

            if manager.visibleHistory.isEmpty {
                ContentUnavailableView(
                    "Nothing copied yet",
                    systemImage: "clipboard",
                    description: Text("Copy text or an image in any app to see it here.")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(spacing: 5) {
                    ForEach(Array(manager.visibleHistory.prefix(5).enumerated()), id: \.element.id) { index, item in
                        Button { onSelect(item) } label: {
                            HStack(spacing: 11) {
                                ClipboardThumbnail(item: item, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.preview)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(.primary)
                                    Text(item.createdAt.formatted(.relative(presentation: .named)))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 4)
                                if item.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                            .background(
                                hoveredItemID == item.id ? Color.primary.opacity(0.075) : .clear,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            hoveredItemID = isHovered ? item.id : nil
                        }
                        .accessibilityLabel("\(item.type.label), \(item.preview)")
                        .accessibilityHint("Select to copy")
                    }
                }
            }

            HStack {
                Text("⌥ Space  Library")
                Spacer()
                Text("Esc  Close")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 376)
        .modifier(GlassSurface(cornerRadius: 25))
        .shadow(color: .black.opacity(0.13), radius: 28, y: 14)
        .animation(.snappy(duration: 0.18), value: manager.history)
    }
}

struct LibraryView: View {
    @ObservedObject var manager: ClipboardManager
    @State private var searchText = ""
    @State private var selectedItem: ClipboardItem?
    @State private var showingClearConfirmation = false

    private var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return manager.visibleHistory }
        return manager.visibleHistory.filter {
            $0.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(filteredItems) { item in
                    ClipboardRow(item: item, searchText: searchText)
                        .tag(item)
                        .contextMenu {
                            Button(item.isPinned ? "Unpin" : "Pin") { manager.togglePinned(item) }
                            Button("Copy to Clipboard") { _ = manager.writeToPasteboard(item) }
                            Divider()
                            Button("Delete", role: .destructive) { manager.delete(item) }
                        }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search clipboard")
            .navigationTitle("History")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        manager.setPaused(!manager.isMonitoringPaused)
                    } label: {
                        Label(manager.isMonitoringPaused ? "Resume" : "Pause",
                              systemImage: manager.isMonitoringPaused ? "play.fill" : "pause.fill")
                    }
                    Button {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog("Clear clipboard history?", isPresented: $showingClearConfirmation) {
                Button("Clear unpinned items", role: .destructive) { manager.clearUnpinned() }
                Button("Clear everything", role: .destructive) { manager.clearAll() }
            }
        } detail: {
            if let selectedItem {
                ClipboardDetailView(item: selectedItem, manager: manager)
                    .id(selectedItem.id)
            } else {
                ContentUnavailableView("Select an item", systemImage: "doc.on.clipboard",
                                       description: Text("Choose an entry to preview its contents."))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .bottom) {
            if let error = manager.persistenceError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .padding(12)
                    .modifier(GlassSurface(cornerRadius: 14))
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    var searchText = ""

    var body: some View {
        HStack(spacing: 11) {
            ClipboardThumbnail(item: item, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(highlightedText(item.preview, matching: searchText))
                    .lineLimit(item.type == .image ? 1 : 2)
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 5) {
                    Text(item.type.label)
                    Text("·")
                    Text(item.createdAt.formatted(.relative(presentation: .named)))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

struct ClipboardDetailView: View {
    let item: ClipboardItem
    @ObservedObject var manager: ClipboardManager

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 14) {
                Group {
                    if item.type == .image {
                        if let data = item.imageData, let image = NSImage(data: data) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(20)
                        } else {
                            ContentUnavailableView(
                                "Image unavailable",
                                systemImage: "photo",
                                description: Text("The saved image file could not be loaded.")
                            )
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(item.content)
                                    .font(item.type == .code ? .system(.body, design: .monospaced) : .body)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                    .padding(.bottom, 16)
                                    .id("clipboard-preview")
                            }
                            .onAppear {
                                proxy.scrollTo("clipboard-preview", anchor: .top)
                            }
                            .onChange(of: item.id) { _, _ in
                                proxy.scrollTo("clipboard-preview", anchor: .top)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.primary.opacity(0.06), lineWidth: 0.7)
                }
                Button {
                    _ = manager.writeToPasteboard(item)
                } label: {
                    Label(item.type == .image ? "Copy Image" : "Copy to Clipboard", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(22)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct SettingsRootView: View {
    @ObservedObject var manager: ClipboardManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Clipboard") {
                Toggle("Monitor clipboard", isOn: Binding(
                    get: { !manager.isMonitoringPaused },
                    set: { manager.setPaused(!$0) }
                ))
                Toggle("Save history between launches", isOn: Binding(
                    get: { manager.persistHistory },
                    set: { manager.setPersistence($0) }
                ))
                Picker("Maximum unpinned items", selection: Binding(
                    get: { manager.maximumHistoryCount },
                    set: { manager.setHistoryLimit($0) }
                )) {
                    ForEach([25, 50, 100, 200, 500], id: \.self) { Text("\($0)").tag($0) }
                }
            }

            Section("Privacy") {
                Text("Excluded application bundle IDs")
                    .font(.headline)
                Text("One bundle identifier per line. Clipboard changes made while an excluded app is frontmost will not be saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $manager.excludedBundleIDsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 90)
                Button("Save excluded apps") { manager.saveExcludedApps() }
                Button("Clear all clipboard history", role: .destructive) { manager.clearAll() }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            manager.permissionMessage = "Could not update Login Item: \(error.localizedDescription)"
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Text("Shortcuts: hold Option for the HUD, Option–1 through Option–5 to paste, Option–Space for the library, Escape to close.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = manager.permissionMessage {
                Section("Permission") {
                    Text(message).foregroundStyle(.secondary)
                    Button("Open Keyboard Access Settings") {
                        guard let url = URL(
                            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                        ) else { return }
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 650)
        .padding()
    }
}
