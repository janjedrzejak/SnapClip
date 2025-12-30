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
