import SwiftUI
import Cocoa
import AppKit

// MARK: - App Entry Point
@main
struct SnapClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - Application Delegate
/// Zarządza cyklem życia aplikacji (startup, shutdown)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Ustaw aplikację jako "accessory" - bez ikony w Docku
        NSApplication.shared.setActivationPolicy(.accessory)

        // Inicjalizuj ClipboardManager
        ClipboardManager.shared.setup()

        // Pokaż okno po krótkim opóźnieniu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ClipboardManager.shared.showWindow()
        }
    }

    /// Wyłącz aplikację - wyczyść historię schowka
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ClipboardManager.shared.clearHistory()
        return .terminateNow
    }
}

// MARK: - Clipboard Manager
/// Główny manager - zarządza historią schowka, monitoringiem i UI
final class ClipboardManager: NSObject {
    static let shared = ClipboardManager()

    private var statusItem: NSStatusItem?          // Ikona w menu bar
    private(set) var window: NSWindow?             // Główne okno aplikacji

    private var history: [ClipboardItem] = []      // Historia schowka
    private var monitoringTimer: Timer?            // Timer do monitorowania schowka
    private var lastClipboardContent: String = ""  // Ostatnia wartość schowka

    private let maxHistorySize = 10                // Max liczba elementów w historii
    private let userDefaults = UserDefaults.standard

    private var lastUserApp: NSRunningApplication? // Ostatnia aktywna aplikacja (do wklejania)
    private var observers: [NSObjectProtocol] = []

    // MARK: Models
    struct ClipboardItem: Codable {
        let text: String
        let timestamp: Date
        let id: UUID
    }

    // MARK: - Setup & Initialization
    func setup() {
        loadHistory()
        createMenuBar()
        startMonitoring()
        startTrackingFrontmostApp()
    }

    // MARK: - File Management
    /// Zwraca ścieżkę do pliku z historią
    private func getHistoryFile() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let appSupportPath = paths[0]
        let snapclipDir = (appSupportPath as NSString).appendingPathComponent("SnapClip")
        
        do {
            try FileManager.default.createDirectory(atPath: snapclipDir, withIntermediateDirectories: true)
        } catch {
            print("Error creating directory: \(error)")
        }
        
        let filePath = (snapclipDir as NSString).appendingPathComponent("history.json")
        return URL(fileURLWithPath: filePath)
    }

    /// Zapisz historię do pliku
    private func saveHistory() {
        do {
            let encoded = try JSONEncoder().encode(history)
            let fileURL = getHistoryFile()
            try encoded.write(to: fileURL)
        } catch {
            print("Error saving history: \(error)")
        }
    }

    /// Załaduj historię z pliku
    private func loadHistory() {
        do {
            let fileURL = getHistoryFile()
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                history = try JSONDecoder().decode([ClipboardItem].self, from: data)
            }
        } catch {
            print("Error loading history: \(error)")
        }
    }

    // MARK: - Menu Bar
    /// Stwórz ikonę i menu w status bar
    private func createMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        guard let button = statusItem?.button else { return }
        
        // Ustaw ikonę schowka
            if let image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "SnapClip") {
                image.isTemplate = true // ← WAŻNE! Pozwól systemowi kolorować ikonę
                button.image = image
            } else {
                // Fallback - jeśli brak ikony, użyj emoji
                button.title = "📋"
            }
            
            button.action = #selector(toggleWindow)
            button.target = self

        // Buduj menu
        let menu = NSMenu()
        
        let showItem = NSMenuItem(title: "Pokaż historię", action: #selector(toggleWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle "Zawsze na wierzchu"
        let alwaysOnTopItem = NSMenuItem(title: "Zawsze na wierzchu", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem.target = self
        alwaysOnTopItem.state = window?.level == .floating ? .on : .off
        menu.addItem(alwaysOnTopItem)
        
        // Toggle "Uruchom przy starcie systemu"
        let launchAtStartupItem = NSMenuItem(title: "Uruchom przy starcie systemu", action: #selector(toggleLaunchAtStartup), keyEquivalent: "")
        launchAtStartupItem.target = self
        launchAtStartupItem.state = isLaunchAtStartupEnabled() ? .on : .off
        menu.addItem(launchAtStartupItem)
        
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Wyjdź", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Window Management
    /// Utwórz główne okno aplikacji
    private func createWindow() {
        let rect = NSRect(x: 0, y: 0, width: 600, height: 700)

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "SnapClip"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 700)
        window.maxSize = NSSize(width: 600, height: 700)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.92
        
        // Zastosuj zapisany stan "zawsze na wierzchu"
        let alwaysOnTop = userDefaults.bool(forKey: "alwaysOnTop")
        window.level = alwaysOnTop ? .floating : .normal

        window.contentViewController = ClipboardViewController(manager: self)
        self.window = window

        positionWindowRight(window)
        window.makeKeyAndOrderFront(nil)
        
        updateAlwaysOnTopMenuState()
    }

    /// Pokaż okno
    func showWindow() {
        if window == nil { createWindow() }
        window?.orderFront(nil)
        refreshUI()
    }

    /// Toggle widoczności okna
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

    /// Pozycjonuj okno w prawym górnym rogu
    private func positionWindowRight(_ window: NSWindow, margin: CGFloat = 24) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame

        let x = vf.maxX - window.frame.width - margin
        let y = vf.maxY - window.frame.height - margin

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Clipboard Monitoring
    /// Monitoruj schowek co 0.5 sekundy
    private func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    /// Sprawdź czy schowek się zmienił
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        if let content = pasteboard.string(forType: .string) {
            if content != lastClipboardContent && !content.trimmingCharacters(in: .whitespaces).isEmpty {
                lastClipboardContent = content
                addToHistory(content)
            }
        }
    }

    /// Śledź ostatnią aktywną aplikację (do wklejania CMD+V)
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

    // MARK: - Clipboard Operations
    /// Dodaj tekst do historii
    func addToHistory(_ text: String) {
        if history.first?.text == text { return }

        let item = ClipboardItem(text: text, timestamp: Date(), id: UUID())
        history.insert(item, at: 0)

        // Limit do maxHistorySize
        if history.count > maxHistorySize {
            history.removeLast()
        }

        saveHistory()
        refreshUI()
    }

    /// Skopiuj tekst do schowka
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastClipboardContent = text
    }

    /// Wklej tekst do ostatniej aktywnej aplikacji
    func pasteToLastUserApp(_ text: String) {
        copyToClipboard(text)
        lastUserApp?.activate(options: .activateAllWindows)

        // Symuluj naciśnięcie CMD+V
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

    /// Usuń element z historii
    func deleteItem(_ id: UUID) {
        let itemToDelete = history.first(where: { $0.id == id })
        
        history.removeAll { $0.id == id }
        saveHistory()
        
        // Jeśli usunęliśmy aktualny tekst schowka - wyczyść schowek
        if let item = itemToDelete, item.text == lastClipboardContent {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            lastClipboardContent = ""
        }
        
        // Update ostatniej wartości
        if let firstItem = history.first {
            lastClipboardContent = firstItem.text
        } else {
            lastClipboardContent = ""
        }
        
        refreshUI()
    }

    /// Wyczyść całą historię (na shutdown)
    func clearHistory() {
        history.removeAll()
        saveHistory()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
    }

    func getHistory() -> [ClipboardItem] { history }

    // MARK: - UI Refresh
    /// Odśwież UI (aktualizuj widok historii)
    private func refreshUI() {
        DispatchQueue.main.async {
            if let w = self.window, let vc = w.contentViewController as? ClipboardViewController {
                vc.refreshUI()
            }
        }
    }

    // MARK: - Always On Top
    /// Toggle "Zawsze na wierzchu"
    @objc private func toggleAlwaysOnTop() {
        guard let w = window else { return }
        
        if w.level == .floating {
            w.level = .normal
            userDefaults.set(false, forKey: "alwaysOnTop")
        } else {
            w.level = .floating
            userDefaults.set(true, forKey: "alwaysOnTop")
        }
        
        userDefaults.synchronize()
        updateAlwaysOnTopMenuState()
    }
    
    /// Aktualizuj checkmark w menu
    private func updateAlwaysOnTopMenuState() {
        guard let menu = statusItem?.menu, let item = menu.items.first(where: { $0.title == "Zawsze na wierzchu" }) else { return }
        let alwaysOnTop = userDefaults.bool(forKey: "alwaysOnTop")
        item.state = alwaysOnTop ? .on : .off
    }

    // MARK: - Launch at Startup
    /// Sprawdź czy launch at startup jest włączony
    private func isLaunchAtStartupEnabled() -> Bool {
        let launchAgentsPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        let plistPath = (launchAgentsPath as NSString).appendingPathComponent("LaunchAgents/com.snapclip.SnapClip.plist")
        return FileManager.default.fileExists(atPath: plistPath)
    }
    
    /// Toggle "Uruchom przy starcie systemu"
    @objc private func toggleLaunchAtStartup() {
        if isLaunchAtStartupEnabled() {
            disableLaunchAtStartup()
        } else {
            enableLaunchAtStartup()
        }
        
        updateLaunchAtStartupMenuState()
    }
    
    /// Włącz autostart - stwórz LaunchAgent plist
    private func enableLaunchAtStartup() {
        let launchAgentsPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        let launchAgentsDir = (launchAgentsPath as NSString).appendingPathComponent("LaunchAgents")
        let plistPath = (launchAgentsDir as NSString).appendingPathComponent("com.snapclip.SnapClip.plist")
        
        do {
            try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
            
            let appPath = Bundle.main.bundlePath
            let plistDict: [String: Any] = [
                "Label": "com.snapclip.SnapClip",
                "ProgramArguments": [appPath],
                "RunAtLoad": true
            ]
            
            let plist = NSDictionary(dictionary: plistDict)
            plist.write(toFile: plistPath, atomically: true)
        } catch {
            print("Error enabling launch at startup: \(error)")
        }
    }
    
    /// Wyłącz autostart - usuń LaunchAgent plist
    private func disableLaunchAtStartup() {
        let launchAgentsPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        let plistPath = (launchAgentsPath as NSString).appendingPathComponent("LaunchAgents/com.snapclip.SnapClip.plist")
        
        do {
            try FileManager.default.removeItem(atPath: plistPath)
        } catch {
            print("Error disabling launch at startup: \(error)")
        }
    }
    
    /// Aktualizuj checkmark w menu
    private func updateLaunchAtStartupMenuState() {
        guard let menu = statusItem?.menu, let item = menu.items.first(where: { $0.title == "Uruchom przy starcie systemu" }) else { return }
        item.state = isLaunchAtStartupEnabled() ? .on : .off
    }
}

// MARK: - UI Components

/// FlippedView - do drawingu z oryginalnym Y axis (od góry)
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// ClickableView - obsługuje kliknięcia na elementy historii
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

/// DeleteButton - przycisk usuwania z itemId
final class DeleteButton: NSButton {
    var itemId: UUID?
}

/// TextDrawingView - rysuje tekst i timestamp
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
        
        // Tekst
        let textFont = NSFont.systemFont(ofSize: 13)
        let textColor = NSColor.white
        let textAttr: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: textColor]
        
        var displayText = text
        
        // Skróć tekst jeśli zbyt długi
        if let newlineIndex = text.firstIndex(of: "\n") {
            displayText = String(text[..<newlineIndex])
            if displayText.count > 40 {
                displayText = String(displayText.prefix(40)) + "..."
            }
        } else if text.count > 50 {
            displayText = String(text.prefix(50)) + "..."
        }
        
        let displayString = NSAttributedString(string: displayText, attributes: textAttr)
        let textRect = NSRect(x: 12, y: 10, width: 448, height: 48)
        displayString.draw(in: textRect)
        
        // Timestamp
        let timeFont = NSFont.systemFont(ofSize: 11)
        let timeColor = NSColor(calibratedWhite: 1.0, alpha: 0.7)
        let timeAttr: [NSAttributedString.Key: Any] = [.font: timeFont, .foregroundColor: timeColor]
        let timeString = NSAttributedString(string: timestamp, attributes: timeAttr)
        timeString.draw(at: NSPoint(x: 12, y: 2))
    }
}

/// EmptyStateView - widok gdy schowek jest pusty
final class EmptyStateView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let titleFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let titleColor = NSColor(calibratedWhite: 1.0, alpha: 0.8)
        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: titleColor]
        
        let subtitleFont = NSFont.systemFont(ofSize: 13)
        let subtitleColor = NSColor(calibratedWhite: 1.0, alpha: 0.5)
        let subtitleAttr: [NSAttributedString.Key: Any] = [.font: subtitleFont, .foregroundColor: subtitleColor]
        
        let titleString = NSAttributedString(string: "Historia schowka pusta", attributes: titleAttr)
        let subtitleString = NSAttributedString(string: "Skopiuj coś, aby zacząć", attributes: subtitleAttr)
        
        titleString.draw(at: NSPoint(x: 210, y: 50))
        subtitleString.draw(at: NSPoint(x: 230, y: 20))
    }
}

// MARK: - Clipboard View Controller
/// Zarządza wyświetlaniem historii schowka
final class ClipboardViewController: NSViewController {
    let manager: ClipboardManager

    var scrollView: NSScrollView!
    var containerView: FlippedView!
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
    
    // MARK: - Setup
    /// Konfiguruj UI (scroll view, blur effect)
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        // Blur effect background
        blurView = NSVisualEffectView(frame: view.bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = .behindWindow
        blurView.material = .underWindowBackground
        blurView.state = .active
        view.addSubview(blurView, positioned: .below, relativeTo: nil)

        // Scroll view
        scrollView = NSScrollView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 600, height: 700)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        // Container z flipped view (Y axis od góry)
        containerView = FlippedView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.documentView = containerView
        view.addSubview(scrollView)
    }

    // MARK: - Refresh UI
    /// Przebuduj widok historii
    func refreshUI() {
        // Wyczyść poprzednie views
        for subview in containerView.subviews {
            subview.removeFromSuperview()
        }
        historyViews.removeAll()

        let history = manager.getHistory()

        // Jeśli pusta - pokaż empty state
        if history.isEmpty {
            let emptyView = EmptyStateView()
            emptyView.frame = NSRect(x: 0, y: 250, width: 600, height: 150)
            containerView.addSubview(emptyView)
            containerView.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
            return
        }

        // Pokaż wszystkie elementy
        let contentHeight = history.count * 80 + 60
        containerView.frame = NSRect(x: 0, y: 0, width: 600, height: CGFloat(contentHeight))

        var yPosition: CGFloat = 40
        for item in history {
            let itemView = createHistoryItemView(item)
            itemView.frame = NSRect(x: 16, y: yPosition, width: 568, height: 80)
            
            historyViews.append(itemView)
            containerView.addSubview(itemView)
            yPosition += 80
        }
    }

    // MARK: - Create History Item
    /// Stwórz widok dla jednego elementu historii
    private func createHistoryItemView(_ item: ClipboardManager.ClipboardItem) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // Text container (clickable)
        let textContainer = ClickableView(frame: NSRect(x: 12, y: 8, width: 480, height: 64))
        textContainer.wantsLayer = true
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

        // Delete button
        let deleteButton = DeleteButton(frame: NSRect(x: 504, y: 8, width: 52, height: 64))
        deleteButton.title = "🗑"
        deleteButton.font = NSFont.systemFont(ofSize: 28)
        deleteButton.bezelStyle = .rounded
        deleteButton.isBordered = false
        deleteButton.wantsLayer = true
        deleteButton.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 0.8).cgColor
        deleteButton.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.15).cgColor
        deleteButton.layer?.borderWidth = 1
        deleteButton.layer?.cornerRadius = 10
        deleteButton.target = self
        deleteButton.action = #selector(deleteItem(_:))
        deleteButton.itemId = item.id
        
        container.addSubview(deleteButton)
        container.layer?.backgroundColor = NSColor.clear.cgColor

        return container
    }

    // MARK: - Actions
    /// Wklej element z historii do ostatniej aplikacji
    func pasteFromHistoryItem(_ itemId: UUID) {
        let history = manager.getHistory()
        if let item = history.first(where: { $0.id == itemId }) {
            manager.pasteToLastUserApp(item.text)
        }
    }

    /// Resetuj poprzednie highlight
    func resetPreviousHighlight() {
        guard let previousView = currentHighlightedView else { return }
        previousView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        previousView.layer?.borderWidth = 1
        currentHighlightedView = nil
    }

    /// Ustaw bieżący highlight
    func setCurrentHighlight(_ view: ClickableView) {
        currentHighlightedView = view
    }

    /// Usuń element
    @objc private func deleteItem(_ sender: NSButton) {
        guard let deleteButton = sender as? DeleteButton, let itemId = deleteButton.itemId else { return }
        manager.deleteItem(itemId)
    }

    // MARK: - Helpers
    /// Sformatuj timestamp
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
