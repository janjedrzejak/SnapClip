import Cocoa

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
    private var localMonitor: Any?

    // MARK: - Setup & Initialization
    func setup() {
        loadHistory()
        createMenuBar()
        startMonitoring()
        startTrackingFrontmostApp()
        registerHotkey()
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        // Ustaw ikonę schowka
        if let image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "SnapClip") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "📋"
        }
        
        button.action = #selector(toggleWindow)
        button.target = self

        // Buduj menu
        let menu = NSMenu()
        
        let showItem = NSMenuItem(title: "Show History", action: #selector(toggleWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle "Always on Top"
        let alwaysOnTopItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem.target = self
        alwaysOnTopItem.state = window?.level == .floating ? .on : .off
        menu.addItem(alwaysOnTopItem)
        
        // Toggle "Launch at Login"
        let launchAtStartupItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtStartup), keyEquivalent: "")
        launchAtStartupItem.target = self
        launchAtStartupItem.state = isLaunchAtStartupEnabled() ? .on : .off
        menu.addItem(launchAtStartupItem)
        
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
    /// Toggle "Always on Top"
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
        guard let menu = statusItem?.menu, let item = menu.items.first(where: { $0.title == "Always on Top" }) else { return }
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
    
    /// Toggle "Launch at Startup"
    @objc private func toggleLaunchAtStartup() {
        if isLaunchAtStartupEnabled() {
            disableLaunchAtStartup()
        } else {
            enableLaunchAtStartup()
        }
        
        updateLaunchAtStartupMenuState()
    }
    
    /// Włącz autostart
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
    
    /// Wyłącz autostart
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
        guard let menu = statusItem?.menu, let item = menu.items.first(where: { $0.title == "Launch at Login" }) else { return }
        item.state = isLaunchAtStartupEnabled() ? .on : .off
    }

    // MARK: - Hotkey
    /// Rejestruj global hotkey (CMD+SHIFT+V)
    private func registerHotkey() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // CMD+SHIFT+V (keyCode 9 = V)
            let isCmdShiftV = event.keyCode == 9 &&
                             event.modifierFlags.contains(.command) &&
                             event.modifierFlags.contains(.shift)
            
            if isCmdShiftV {
                self?.toggleWindow()
                return nil
            }
            return event
        }
        
        print("✅ Hotkey registered: CMD+SHIFT+V (local monitor)")
    }
}
