import Cocoa
import Carbon

extension String {
    var fourCharCodeValue: Int {
        var result: Int = 0
        if let data = self.data(using: String.Encoding.macOSRoman) {
            data.withUnsafeBytes({ (rawBytes) in
                let bytes = rawBytes.bindMemory(to: UInt8.self)
                for i in 0 ..< data.count {
                    result = result << 8 + Int(bytes[i])
                }
            })
        }
        return result
    }
}

final class GlobalHotkeyManager: NSObject {
    static let shared = GlobalHotkeyManager()
    
    private weak var clipboard: ClipboardManager?
    private var hotKeyRef: EventHotKeyRef?
    
    func setup(with clipboard: ClipboardManager) {
        self.clipboard = clipboard
        registerGlobalHotkey()
    }
    
    private func registerGlobalHotkey() {
        let modifierFlags: UInt32 = getCarbonFlags(
            cocoaFlags: [.option, .command]
        )
        
        let keyCode: UInt32 = 44  // Alt+Cmd+/
        var hotKeyID = EventHotKeyID()
        hotKeyID.id = UInt32(keyCode)
        hotKeyID.signature = OSType("SNAP".fourCharCodeValue)
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                NSLog("Global hotkey Alt+Cmd+/ triggered!")
                DispatchQueue.main.async {
                    ClipboardManager.shared.toggleWindow()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
        
        let status = RegisterEventHotKey(
            keyCode,
            modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            print("Global hotkey registered: Alt+Cmd+/")
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }
    
    private func getCarbonFlags(cocoaFlags: NSEvent.ModifierFlags) -> UInt32 {
        var newFlags: Int = 0
        
        if cocoaFlags.contains(.control) {
            newFlags |= controlKey
        }
        if cocoaFlags.contains(.command) {
            newFlags |= cmdKey
        }
        if cocoaFlags.contains(.shift) {
            newFlags |= shiftKey
        }
        if cocoaFlags.contains(.option) {
            newFlags |= optionKey
        }
        if cocoaFlags.contains(.capsLock) {
            newFlags |= alphaLock
        }
        
        return UInt32(newFlags)
    }
    
    func disable() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            print("Global hotkey disabled")
        }
    }
    
    deinit {
        disable()
    }
}

