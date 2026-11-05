import AppKit
import Combine

@MainActor
final class ClipboardManager: ObservableObject {
    @Published private(set) var history: [ClipboardItem] = []
    @Published var isMonitoringPaused = false
    @Published var persistHistory = true
    @Published var maximumHistoryCount = 100
    @Published var excludedBundleIDsText = ""
    @Published var permissionMessage: String?
    @Published private(set) var persistenceError: String?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let storageKey = "Stash.clipboardHistory.v1"
    private let defaults = UserDefaults.standard
    private var expectedInternalChangeCount: Int?
    private let maximumItemCharacters = 50_000
    private let imageDirectory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    )[0]
        .appendingPathComponent("Stash", isDirectory: true)
        .appendingPathComponent("Images", isDirectory: true)

    init() {
        lastChangeCount = pasteboard.changeCount
        persistHistory = defaults.object(forKey: "Stash.persistHistory") as? Bool ?? true
        maximumHistoryCount = defaults.object(forKey: "Stash.maximumHistoryCount") as? Int ?? 100
        excludedBundleIDsText = defaults.string(forKey: "Stash.excludedBundleIDs") ?? ""
        loadHistory()
    }

    var excludedBundleIDs: Set<String> {
        Set(excludedBundleIDsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    var visibleHistory: [ClipboardItem] {
        history.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkClipboard() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func setPaused(_ paused: Bool) {
        isMonitoringPaused = paused
        lastChangeCount = pasteboard.changeCount
    }

    func setPersistence(_ enabled: Bool) {
        persistHistory = enabled
        defaults.set(enabled, forKey: "Stash.persistHistory")
        if enabled { saveHistory() }
        else {
            defaults.removeObject(forKey: storageKey)
            do {
                if FileManager.default.fileExists(atPath: imageDirectory.path) {
                    try FileManager.default.removeItem(at: imageDirectory)
                }
                persistenceError = nil
            } catch {
                persistenceError = "Could not remove saved images: \(error.localizedDescription)"
            }
        }
    }

    func setHistoryLimit(_ limit: Int) {
        maximumHistoryCount = min(max(limit, 10), 500)
        defaults.set(maximumHistoryCount, forKey: "Stash.maximumHistoryCount")
        trimHistory()
        saveHistory()
    }

    func saveExcludedApps() {
        defaults.set(excludedBundleIDsText, forKey: "Stash.excludedBundleIDs")
    }

    func item(atVisibleIndex index: Int) -> ClipboardItem? {
        let items = visibleHistory
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    func record(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= maximumItemCharacters else { return }

        if let existingIndex = history.firstIndex(where: { $0.content == cleaned }) {
            var existing = history.remove(at: existingIndex)
            existing.createdAt = .now
            history.insert(existing, at: 0)
        } else {
            history.insert(ClipboardItem(content: cleaned), at: 0)
        }

        trimHistory()
        saveHistory()
    }

    func recordImage(_ data: Data) {
        guard NSImage(data: data) != nil else { return }

        if let existingIndex = history.firstIndex(where: { $0.type == .image && $0.imageData == data }) {
            var existing = history.remove(at: existingIndex)
            existing.createdAt = .now
            history.insert(existing, at: 0)
        } else {
            history.insert(ClipboardItem(imageData: data), at: 0)
        }

        trimHistory()
        saveHistory()
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let index = history.firstIndex(where: { $0.id == item.id }) else { return }
        history[index].isPinned.toggle()
        saveHistory()
    }

    func delete(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearUnpinned() {
        history.removeAll { !$0.isPinned }
        saveHistory()
    }

    func clearAll() {
        history.removeAll()
        saveHistory()
    }

    @discardableResult
    func writeToPasteboard(_ item: ClipboardItem) -> Bool {
        if item.type == .image {
            guard let imageData = item.imageData, NSImage(data: imageData) != nil else { return false }
            pasteboard.clearContents()
            guard pasteboard.setData(imageData, forType: .png) else { return false }
        } else {
            pasteboard.clearContents()
            guard pasteboard.setString(item.content, forType: .string) else { return false }
        }
        lastChangeCount = pasteboard.changeCount
        expectedInternalChangeCount = lastChangeCount
        return true
    }

    private func checkClipboard() {
        guard !isMonitoringPaused else { return }

        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if expectedInternalChangeCount == currentCount {
            expectedInternalChangeCount = nil
            return
        }

        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedBundleIDs.contains(bundleID) {
            return
        }

        if let imageData = imageDataFromPasteboard() {
            recordImage(imageData)
        } else if let string = pasteboard.string(forType: .string) {
            record(string)
        } else if let rtf = pasteboard.data(forType: .rtf),
                  let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            record(attributed.string)
        }
    }

    private func imageDataFromPasteboard() -> Data? {
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif"),
            NSPasteboard.PasteboardType("org.webmproject.webp"),
            NSPasteboard.PasteboardType("public.image")
        ]

        for type in imageTypes {
            guard let data = pasteboard.data(forType: type) else { continue }
            if type == .png, NSImage(data: data) != nil {
                return data
            }
            if let image = NSImage(data: data),
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                return png
            }
        }

        return nil
    }

    private func trimHistory() {
        let pinned = history.filter(\.isPinned)
        let unpinned = history.filter { !$0.isPinned }
        history = pinned + Array(unpinned.prefix(maximumHistoryCount))
    }

    private func loadHistory() {
        guard persistHistory,
              let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        var missingImageCount = 0
        history = decoded.map { item in
            var item = item
            if let fileName = item.imageFileName {
                let url = imageDirectory.appendingPathComponent(fileName)
                do {
                    let imageData = try Data(contentsOf: url)
                    guard NSImage(data: imageData) != nil else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    item.imageData = imageData
                } catch {
                    missingImageCount += 1
                    item.imageData = nil
                }
            }
            return item
        }
        trimHistory()
        if missingImageCount > 0 {
            persistenceError = "\(missingImageCount) saved image(s) could not be loaded."
        }
    }

    private func saveHistory() {
        guard persistHistory else { return }

        do {
            try FileManager.default.createDirectory(
                at: imageDirectory,
                withIntermediateDirectories: true
            )
            for index in history.indices where history[index].type == .image {
                guard let imageData = history[index].imageData else {
                    throw CocoaError(.fileReadNoSuchFile)
                }
                let fileName = history[index].imageFileName ?? "\(UUID().uuidString).png"
                try imageData.write(
                    to: imageDirectory.appendingPathComponent(fileName),
                    options: .atomic
                )
                history[index].imageFileName = fileName
            }

            defaults.set(try JSONEncoder().encode(history), forKey: storageKey)
            persistenceError = nil
        } catch {
            persistenceError = "Could not save clipboard history: \(error.localizedDescription)"
        }
    }
}
