import Cocoa

// MARK: - FlippedView
/// Custom view with Y-axis from top
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - ClickableView
/// Handles clicks on history items
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

// MARK: - DeleteButton
/// Delete button with UUID
final class DeleteButton: NSButton {
    var itemId: UUID?
}

// MARK: - TextDrawingView
/// Renders text and timestamp
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
        
        // Text
        let textFont = NSFont.systemFont(ofSize: 13)
        let textColor = NSColor.white
        let textAttr: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: textColor]
        
        var displayText = text
        
        // Truncate if too long
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

// MARK: - EmptyStateView
/// Display when history is empty
final class EmptyStateView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let titleFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let titleColor = NSColor(calibratedWhite: 1.0, alpha: 0.8)
        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: titleColor]
        
        let subtitleFont = NSFont.systemFont(ofSize: 13)
        let subtitleColor = NSColor(calibratedWhite: 1.0, alpha: 0.5)
        let subtitleAttr: [NSAttributedString.Key: Any] = [.font: subtitleFont, .foregroundColor: subtitleColor]
        
        let titleString = NSAttributedString(string: "Clipboard History Empty", attributes: titleAttr)
        let subtitleString = NSAttributedString(string: "Copy something to get started", attributes: subtitleAttr)
        
        titleString.draw(at: NSPoint(x: 185, y: 50))
        subtitleString.draw(at: NSPoint(x: 210, y: 20))
    }
}
