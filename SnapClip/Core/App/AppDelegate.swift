import Cocoa

// MARK: - Application Delegate
/// Zarządza cyklem życia aplikacji (startup, shutdown)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Ustaw aplikację jako "accessory" - bez ikony w Docku
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // SPRAWDŹ UPRAWNIENIA PODCZAS STARTU
        checkAccessibilityPermissions()
        
        // Inicjalizuj ClipboardManager
        ClipboardManager.shared.setup()
        
        // Pokaż okno po krótkim opóźnieniu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ClipboardManager.shared.showWindow()
        }
    }

    /// Sprawdź i poproś o uprawnienia Accessibility
    private func checkAccessibilityPermissions() {
        let alert = NSAlert()
        
        if AXIsProcessTrusted() {
            print("Accessibility permissions granted")
            return
        }
        
        print("No Accessibility permissions - requesting...")
        
        alert.messageText = "SnapClip needs Accessibility permissions"
        alert.informativeText = "Enable SnapClip in System Settings > Privacy & Security > Accessibility to use global hotkeys."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Otwórz System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }


    /// Wyłącz aplikację - wyczyść historię schowka
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ClipboardManager.shared.clearHistory()
        return .terminateNow
    }
}
