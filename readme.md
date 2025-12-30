# SnapClip 📋

A simple and efficient clipboard history manager for macOS. Store and quickly access your last 10 copied texts with one click.

## Features ✨

- **Clipboard History** - Keep track of your last 10 copied texts
- **Quick Access** - Click any item to paste it to the last active application
- **Persistent Storage** - History saved in `~/Library/Application Support/SnapClip/history.json`
- **Always on Top** - Toggle window to stay above other applications
- **Auto-Launch** - Option to start SnapClip with system boot
- **Status Bar** - Quick access icon in menu bar
- **Clean Shutdown** - Automatically clear history and clipboard on app close
- **Hotkey Support** - CMD+SHIFT+V to toggle window (requires Accessibility permissions)

## Screenshots

![SnapClip Demo](screenshots/demo.gif)

## Requirements

- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

## Installation

### Build from Source
git clone https://github.com/janjedrzejak/SnapClip.git
cd SnapClip
open SnapClip.xcodeproj

Press `Cmd+B` to build, `Cmd+R` to run.

## Configuration

### Global Hotkey (CMD+SHIFT+V)

To enable global hotkey support:

1. **System Preferences → Security & Privacy → Accessibility**
2. Click **+** to add SnapClip
3. Navigate to Applications folder and select **SnapClip.app**
4. Restart SnapClip

## Usage

### Toggle Window
- Click clipboard icon in menu bar 📋
- Press **CMD+SHIFT+V** (requires Accessibility)

### Paste from History
1. Click any item
2. Text auto-pastes to last active app
3. Window hides automatically

### Delete Item
- Click 🗑️ button next to item

## Menu Bar Options

| Option | Description |
|--------|-------------|
| **Show History** | Toggle window |
| **Always on Top** ☑ | Stay above other apps |
| **Launch at Login** ☑ | Auto-start with system |
| **Quit** | Close app |

## Project Structure
SnapClip/
├── App/
│ ├── SnapClipApp.swift # Entry point
│ └── AppDelegate.swift # Lifecycle
├── Core/
│ ├── ClipboardManager.swift # Core logic
│ └── Models/
│ └── ClipboardItem.swift
├── UI/
│ ├── ClipboardViewController.swift
│ └── UIComponents.swift # All custom views
## Storage Location
~/Library/Application Support/SnapClip/history.json
## Troubleshooting

**Hotkey not working:**
System Preferences > Security & Privacy > Accessibility > Add SnapClip

**Icon not visible:**
- Restart SnapClip
- Check Dock settings

## Roadmap 🚀

- [ ] Settings panel
- [ ] Search & filter
- [ ] iCloud sync
- [ ] Rich text support
- [ ] Custom hotkeys

## License

MIT License

## Author

[Jan Jędrzejak](https://github.com/janjedrzejak)

---

⭐ Star if useful!
