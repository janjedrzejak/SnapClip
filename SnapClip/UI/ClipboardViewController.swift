import Cocoa

// MARK: - Clipboard View Controller
/// Manages clipboard history display
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
    /// Configure UI (scroll view, blur effect)
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

        // Container with flipped view (Y axis from top)
        containerView = FlippedView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.documentView = containerView
        view.addSubview(scrollView)
    }

    // MARK: - Refresh UI
    /// Rebuild history view
    func refreshUI() {
        // Clear previous views
        for subview in containerView.subviews {
            subview.removeFromSuperview()
        }
        historyViews.removeAll()

        let history = manager.getHistory()

        // If empty - show empty state
        if history.isEmpty {
            let emptyView = EmptyStateView()
            emptyView.frame = NSRect(x: 0, y: 250, width: 600, height: 150)
            containerView.addSubview(emptyView)
            containerView.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
            return
        }

        // Show all items
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
    /// Create view for one history item
    private func createHistoryItemView(_ item: ClipboardItem) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        
        // Text container (clickable) - różne kolory dla pinnowanych
        let textContainer = ClickableView(frame: NSRect(x: 12, y: 8, width: 420, height: 64))
        textContainer.wantsLayer = true
        
        // Kolor ramki w zależności od pinowania
        if item.isPinned {
            // Teal/cyan dla pinnowanych
            textContainer.layer?.backgroundColor = NSColor(red: 0.125, green: 0.702, blue: 0.624, alpha: 0.25).cgColor
            textContainer.layer?.borderColor = NSColor(red: 0.125, green: 0.702, blue: 0.624, alpha: 0.6).cgColor
        } else {
            // Normalny kolor
            textContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.75).cgColor
            textContainer.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        }
        
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
        
        // Pin button - również zabarwiony gdy pinnowany
        let pinButton = NSButton(frame: NSRect(x: 444, y: 8, width: 52, height: 64))
        pinButton.title = "📍"
        pinButton.font = NSFont.systemFont(ofSize: 24)
        pinButton.bezelStyle = .rounded
        pinButton.isBordered = false
        pinButton.wantsLayer = true
        
        // Kolor pin button'a w zależności od pinowania
        if item.isPinned {
            pinButton.layer?.backgroundColor = NSColor(red: 0.125, green: 0.702, blue: 0.624, alpha: 0.3).cgColor
            pinButton.layer?.borderColor = NSColor(red: 0.125, green: 0.702, blue: 0.624, alpha: 0.6).cgColor
        } else {
            pinButton.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 0.8).cgColor
            pinButton.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.15).cgColor
        }
        
        pinButton.layer?.borderWidth = 1
        pinButton.layer?.cornerRadius = 10
        pinButton.target = self
        pinButton.action = #selector(togglePin(_:))
        let pinButtonTag = item.id.uuidString.hashValue
        pinButton.tag = pinButtonTag
        container.addSubview(pinButton)
        
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
    /// Paste item to last application
    func pasteFromHistoryItem(_ itemId: UUID) {
        let history = manager.getHistory()
        if let item = history.first(where: { $0.id == itemId }) {
            manager.pasteToLastUserApp(item.text)
        }
    }
    
    @objc private func togglePin(_ sender: NSButton) {
        // Znajdź UUID z tag'a (simplified approach)
        let history = manager.getHistory()
        for item in history {
            if item.id.uuidString.hashValue == sender.tag {
                manager.togglePin(item.id)
                break
            }
        }
    }


    /// Reset previous highlight
    func resetPreviousHighlight() {
        guard let previousView = currentHighlightedView else { return }
        previousView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        previousView.layer?.borderWidth = 1
        currentHighlightedView = nil
    }

    /// Set current highlight
    func setCurrentHighlight(_ view: ClickableView) {
        currentHighlightedView = view
    }

    /// Delete item
    @objc private func deleteItem(_ sender: NSButton) {
        guard let deleteButton = sender as? DeleteButton, let itemId = deleteButton.itemId else { return }
        manager.deleteItem(itemId)
    }

    // MARK: - Helpers
    /// Format timestamp
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
