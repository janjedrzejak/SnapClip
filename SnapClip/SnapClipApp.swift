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
        NSApplication.shared.setActivationPolicy(.accessory)

        ClipboardManager.shared.setup()

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
        window?.orderFront(nil)
        refreshUI()
    }

    private func createWindow() {
        let rect = NSRect(x: 0, y: 0, width: 600, height: 700)

        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = "SnapClip"
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 600, height: 700)
        panel.maxSize = NSSize(width: 600, height: 700)
        panel.hidesOnDeactivate = false
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

    func pasteToLastUserApp(_ text: String) {
        copyToClipboard(text)
        lastUserApp?.activate(options: .activateAllWindows)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let source = CGEventSource(stateID: .privateState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
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

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class ClickableView: NSView {
    weak var target: ClipboardViewController?
    var itemId: UUID?
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        guard let target = target, let itemId = itemId else { return }
        
        target.resetPreviousHighlight()
        self.layer?.borderColor = NSColor(calibratedWhite: 0.7, alpha: 0.8).cgColor
        self.layer?.borderWidth = 2
        target.setCurrentHighlight(self)
        target.pasteFromHistoryItem(itemId)
    }
}

final class TextDrawingView: NSView {
    let text: String
    let timestamp: String
    
    init(text: String, timestamp: String) {
        self.text = text
        self.timestamp = timestamp
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let textFont = NSFont.systemFont(ofSize: 13)
        let textColor = NSColor.white
        let textAttr: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: textColor]
        
        let maxWidth: CGFloat = 448
        let maxHeight: CGFloat = 48
        
        var displayText = text
        
        if let newlineIndex = text.firstIndex(of: "\n") {
            displayText = String(text[..<newlineIndex])
            if displayText.count > 40 {
                displayText = String(displayText.prefix(40)) + "..."
            }
        } else if text.count > 50 {
            displayText = String(text.prefix(50)) + "..."
        }
        
        let displayString = NSAttributedString(string: displayText, attributes: textAttr)
        let textRect = NSRect(x: 12, y: 10, width: maxWidth, height: maxHeight)
        
        displayString.draw(in: textRect)
        
        let timeFont = NSFont.systemFont(ofSize: 11)
        let timeColor = NSColor(calibratedWhite: 1.0, alpha: 0.7)
        let timeAttr: [NSAttributedString.Key: Any] = [.font: timeFont, .foregroundColor: timeColor]
        let timeString = NSAttributedString(string: timestamp, attributes: timeAttr)
        timeString.draw(at: NSPoint(x: 12, y: 2))
    }
}

final class ClipboardViewController: NSViewController {
    let manager: ClipboardManager

    var scrollView: NSScrollView!
    var containerView: FlippedView!
    var emptyLabel: NSTextField!
    var historyViews: [NSView] = []

    private var blurView: NSVisualEffectView!
    private var currentHighlightedView: ClickableView?

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

        let contentHeight = history.count * 80 + 20
        containerView.frame = NSRect(x: 0, y: 0, width: 600, height: CGFloat(contentHeight))

        var yPosition: CGFloat = 10

        for item in history {
            let itemView = createHistoryItemView(item)
            itemView.frame = NSRect(x: 16, y: yPosition, width: 568, height: 80)
            
            historyViews.append(itemView)
            containerView.addSubview(itemView)
            yPosition += 80
        }
    }

    private func createHistoryItemView(_ item: ClipboardManager.ClipboardItem) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)

        let textContainer = ClickableView(frame: NSRect(x: 12, y: 8, width: 480, height: 64))
        textContainer.wantsLayer = true
        textContainer.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)
        textContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.75).cgColor
        textContainer.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        textContainer.layer?.borderWidth = 1
        textContainer.layer?.cornerRadius = 10
        textContainer.target = self
        textContainer.itemId = item.id

        let textDrawView = TextDrawingView(text: item.text, timestamp: formatTime(item.timestamp))
        textDrawView.frame = textContainer.bounds
        textDrawView.wantsLayer = true
        textDrawView.layer?.backgroundColor = NSColor.clear.cgColor
        textContainer.addSubview(textDrawView)

        container.addSubview(textContainer)

        let deleteContainer = NSView(frame: NSRect(x: 504, y: 8, width: 52, height: 64))
        deleteContainer.wantsLayer = true
        deleteContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.75).cgColor
        deleteContainer.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        deleteContainer.layer?.borderWidth = 1
        deleteContainer.layer?.cornerRadius = 10
        
        let deleteButton = NSButton(frame: NSRect(x: 0, y: 0, width: 52, height: 64))
        deleteButton.title = "🗑"
        deleteButton.font = NSFont.systemFont(ofSize: 24)
        deleteButton.bezelStyle = .rounded
        deleteButton.isBordered = false
        deleteButton.wantsLayer = true
        deleteButton.layer?.backgroundColor = NSColor.clear.cgColor
        deleteButton.layer?.borderWidth = 0
        deleteButton.target = self
        deleteButton.action = #selector(deleteItem(_:))
        deleteButton.tag = item.id.hashValue
        deleteContainer.addSubview(deleteButton)
        
        container.addSubview(deleteContainer)

        container.layer?.backgroundColor = NSColor.clear.cgColor

        return container
    }

    func pasteFromHistoryItem(_ itemId: UUID) {
        let history = manager.getHistory()
        if let item = history.first(where: { $0.id == itemId }) {
            manager.pasteToLastUserApp(item.text)
        }
    }

    func resetPreviousHighlight() {
        guard let previousView = currentHighlightedView else { return }
        previousView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        previousView.layer?.borderWidth = 1
        currentHighlightedView = nil
    }

    func setCurrentHighlight(_ view: ClickableView) {
        currentHighlightedView = view
    }

    @objc private func deleteItem(_ sender: NSButton) {
        let history = manager.getHistory()
        if let item = history.first(where: { $0.id.hashValue == sender.tag }) {
            manager.deleteItem(item.id)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
