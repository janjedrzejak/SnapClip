import Cocoa

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
