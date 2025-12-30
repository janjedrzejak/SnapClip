import SwiftUI
import Cocoa
import AppKit

@main
struct SnapClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 SnapClip uruchomiony")
        NSApplication.shared.setActivationPolicy(.regular)

        ClipboardManager.shared.setup()

        // Okno historii jako startowe
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ClipboardManager.shared.showWindow()
        }
    }
}

final class ClipboardManager: NSObject {
    static let shared = ClipboardManager()

    private var statusItem: NSStatusItem?
    private(set) var window: NSWindow?

    private var history: [ClipboardItem] = []
    private var monitoringTimer: Timer?
    private var lastClipboardContent: String = ""

    private let maxHistorySize = 10
    private let userDefaults = UserDefaults.standard

    // Ostatnia aktywna aplikacja (inna niż SnapClip)
    private var lastUserApp: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []

    struct ClipboardItem: Codable {
        let text: String
        let timestamp: Date
        let id: UUID
    }

    func setup() {
        loadHistory()
        createMenuBar()
        startMonitoring()
        startTrackingFrontmostApp()
    }

    private func createMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "📋"
        statusItem?.button?.action = #selector(toggleWindow)
        statusItem?.button?.target = self

        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Pokaż historię", action: #selector(toggleWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Wyjdź", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func startTrackingFrontmostApp() {
        let token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

            // ignoruj SnapClip
            if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }

            self?.lastUserApp = app
        }

        observers.append(token)
    }

    @objc func toggleWindow() {
        if window == nil {
            createWindow()
            return
        }
        guard let w = window else { return }

        if w.isVisible {
            w.orderOut(nil)
        } else {
            showWindow()
        }
    }

    func showWindow() {
        if window == nil { createWindow() }

        // Nie aktywujemy aplikacji (żeby nie kraść focusu docelowej aplikacji)
        window?.orderFront(nil)
        refreshUI()
    }

    private func createWindow() {
        let rect = NSRect(x: 0, y: 0, width: 600, height: 700)

        // Non-activating panel: panel nie aktywuje SnapClipa
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = "SnapClip"
        panel.isReleasedWhenClosed = false

        // Blokada zmiany rozmiaru
        panel.minSize = NSSize(width: 600, height: 700)
        panel.maxSize = NSSize(width: 600, height: 700)

        // Nie chowaj po utracie aktywacji
        panel.hidesOnDeactivate = false

        // Półprzezroczystość okna
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.alphaValue = 0.92

        panel.contentViewController = ClipboardViewController(manager: self)

        self.window = panel

        positionWindowRight(panel)
        panel.orderFront(nil)
    }

    private func positionWindowRight(_ window: NSWindow, margin: CGFloat = 24) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame

        let x = vf.maxX - window.frame.width - margin
        let y = vf.midY - window.frame.height / 2

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        if let content = pasteboard.string(forType: .string) {
            if content != lastClipboardContent && !content.trimmingCharacters(in: .whitespaces).isEmpty {
                lastClipboardContent = content
                addToHistory(content)
            }
        }
    }

    func addToHistory(_ text: String) {
        if history.first?.text == text { return }

        let item = ClipboardItem(text: text, timestamp: Date(), id: UUID())
        history.insert(item, at: 0)

        if history.count > maxHistorySize {
            history.removeLast()
        }

        saveHistory()
        refreshUI()
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastClipboardContent = text
    }

    /// Wkleja do aplikacji, w której użytkownik miał kursor, bez chowania okna SnapClipa.
    /// Uwaga: wysyłanie ⌘V wymaga uprawnień Accessibility.
    func pasteToLastUserApp(_ text: String) {
        copyToClipboard(text)

        // Spróbuj przywrócić focus docelowej appce (SnapClip nie jest aktywowany jako panel)
        lastUserApp?.activate(options: .activateAllWindows)

        // ⌘V po krótkim delayu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let source = CGEventSource(stateID: .privateState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // V
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    func deleteItem(_ id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
        refreshUI()
    }

    private func refreshUI() {
        DispatchQueue.main.async {
            if let w = self.window, let vc = w.contentViewController as? ClipboardViewController {
                vc.refreshUI()
            }
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: "clipboardHistory")
        }
    }

    private func loadHistory() {
        if let data = userDefaults.data(forKey: "clipboardHistory"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            history = decoded
        }
    }

    func getHistory() -> [ClipboardItem] { history }
}

// Flipped view dla prawidłowego scrollowania
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class ClipboardViewController: NSViewController {
    let manager: ClipboardManager

    var scrollView: NSScrollView!
    var containerView: FlippedView!
    var emptyLabel: NSTextField!
    var historyViews: [NSView] = []

    private var blurView: NSVisualEffectView!

    init(manager: ClipboardManager) {
        self.manager = manager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 700))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.refreshUI()
        }
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        // Blur w tle
        blurView = NSVisualEffectView(frame: view.bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = .behindWindow
        blurView.material = .underWindowBackground
        blurView.state = .active
        view.addSubview(blurView, positioned: .below, relativeTo: nil)

        scrollView = NSScrollView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 600, height: view.bounds.height)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        containerView = FlippedView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.documentView = containerView
        view.addSubview(scrollView)

        emptyLabel = NSTextField(labelWithString: "Historia schowka pusta\n\nSkopiuj coś, aby zacząć")
        emptyLabel.alignment = .center
        emptyLabel.textColor = NSColor.secondaryLabelColor
        emptyLabel.isEditable = false
        emptyLabel.isSelectable = false
        emptyLabel.isBezeled = false
        emptyLabel.drawsBackground = false
        emptyLabel.frame = NSRect(x: 0, y: 0, width: 600, height: 100)
        containerView.addSubview(emptyLabel)
    }

    func refreshUI() {
        historyViews.forEach { $0.removeFromSuperview() }
        historyViews.removeAll()

        let history = manager.getHistory()

        if history.isEmpty {
            emptyLabel.isHidden = false
            containerView.frame = NSRect(x: 0, y: 0, width: 600, height: 100)
            return
        }

        emptyLabel.isHidden = true

        let contentHeight = history.count * 112 + 40
        containerView.frame = NSRect(x: 0, y: 0, width: 600, height: CGFloat(contentHeight))

        var yPosition: CGFloat = 20

        for item in history {
            let itemView = createHistoryItemView(item)
            itemView.frame = NSRect(x: 16, y: yPosition, width: 568, height: 100)
            historyViews.append(itemView)
            containerView.addSubview(itemView)
            yPosition += 112
        }
    }

    private func createHistoryItemView(_ item: ClipboardManager.ClipboardItem) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.75).cgColor
        container.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        container.layer?.borderWidth = 1
        container.layer?.cornerRadius = 10

        let textView = NSTextView(frame: NSRect(x: 12, y: 32, width: 460, height: 60))
        textView.string = item.text
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.drawsBackground = false
        textView.textColor = NSColor.white
        container.addSubview(textView)

        let timeLabel = NSTextField(labelWithString: formatTime(item.timestamp))
        timeLabel.font = NSFont.systemFont(ofSize: 11)
        timeLabel.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.7)
        timeLabel.frame = NSRect(x: 12, y: 12, width: 460, height: 16)
        container.addSubview(timeLabel)

        let copyButton = NSButton(frame: NSRect(x: 484, y: 54, width: 80, height: 32))
        copyButton.title = "Kopiuj"
        copyButton.bezelStyle = .rounded
        copyButton.target = self
        copyButton.action = #selector(copyItem(_:))
        copyButton.tag = item.id.hashValue
        container.addSubview(copyButton)

        let pasteButton = NSButton(frame: NSRect(x: 484, y: 12, width: 80, height: 32))
        pasteButton.title = "Wklej"
        pasteButton.bezelStyle = .rounded
        pasteButton.target = self
        pasteButton.action = #selector(pasteItem(_:))
        pasteButton.tag = item.id.hashValue
        container.addSubview(pasteButton)

        return container
    }

    @objc private func copyItem(_ sender: NSButton) {
        let history = manager.getHistory()
        if let item = history.first(where: { $0.id.hashValue == sender.tag }) {
            manager.copyToClipboard(item.text)
        }
    }

    @objc private func pasteItem(_ sender: NSButton) {
        let history = manager.getHistory()
        if let item = history.first(where: { $0.id.hashValue == sender.tag }) {
            manager.pasteToLastUserApp(item.text)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

