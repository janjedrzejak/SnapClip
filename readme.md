# SnapClip

Production Ready Menu Bar Clipboard Manager for macOS

## Overview

SnapClip is a lightweight clipboard history manager that lives in your menu bar. Access your clipboard history with a global hotkey and pin your most important clips.

## Features

- **Global Hotkey** - Alt+Cmd+/ works everywhere (Safari, Chrome, Notes, VS Code)
- **Pin/Unpin** - Pin important clips to top of list
- **Clipboard History** - Keep track of your last copied texts
- **Quick Access** - Click any item to paste it to the last active application
- **Menu Bar Accessory** - No Dock icon, status bar only
- **Persistent Storage** - History saved in `~/Library/Application Support/SnapClip/`
- **Auto-Launch** - Option to start SnapClip with system boot
- **Professional Dark UI** - Clean design with SF Symbols

## Requirements

- macOS 12+ (Monterey+)
- Xcode 14+
- Swift 5.7+
- Accessibility permissions (auto-prompt on first launch)

## Installation

### Download Latest Release

1. Go to [Releases](https://github.com/janjedrzejak/SnapClip/releases)
2. Download latest `SnapClip.app`
3. Double-click to install
4. Grant Accessibility permissions when prompted
5. Use Alt+Cmd+/ to open

### Build from Source

```bash
git clone https://github.com/janjedrzejak/SnapClip.git
cd SnapClip
open SnapClip.xcodeproj
```

Press `Cmd+B` to build, `Cmd+R` to run.

## Usage

### Toggle Window
- Click clipboard icon in menu bar
- Press Alt+Cmd+/ (global hotkey)

### Paste from History
1. Click any item
2. Text auto-pastes to last active app
3. Window hides automatically

### Pin/Unpin Items
- Click pin icon to pin important clips to top
- Unpinned items return to chronological order

### Delete Item
- Click trash icon next to item

## Menu Bar Options

| Option | Description |
|--------|-------------|
| Show History | Toggle window |
| Quit | Close app |

## Configuration

### Global Hotkey (Alt+Cmd+/)

Accessibility permissions are required for global hotkey support. SnapClip automatically prompts on first launch.

To manually enable:
1. System Settings → Privacy & Security → Accessibility
2. Click + to add SnapClip
3. Navigate to Applications folder and select SnapClip.app
4. Restart SnapClip

## Storage Location

Clipboard history is stored at:
```
~/Library/Application Support/SnapClip/history.json
```

## Project Structure

```
SnapClip/
├── SnapClip/
│   ├── Core/
│   │   ├── App/
│   │   │   ├── AppDelegate.swift
│   │   │   └── SnapClipApp.swift
│   │   ├── ClipboardManager.swift
│   │   └── Models/
│   │       └── ClipboardItem.swift
│   ├── UI/
│   │   ├── ClipboardViewController.swift
│   │   └── UIComponents.swift
│   ├── Assets.xcassets
│   └── SnapClip.entitlements
├── SnapClip.xcodeproj
├── SnapClipTests/
├── SnapClipUITests/
└── README.md
```

## Troubleshooting

**Hotkey not working:**
- System Settings → Privacy & Security → Accessibility
- Ensure SnapClip is in the list
- Restart SnapClip

**App not opening:**
- Restart your Mac
- Reinstall SnapClip.app

**Icon not visible in menu bar:**
- Click Apple menu → System Settings → General → Login Items
- Remove and re-add SnapClip

## Roadmap

- v1.1: Search and filtering
- v1.2: iCloud sync
- v2.0: Multiple workspaces/tabs
- Custom hotkey configuration

## License

MIT License

## Author

[Jan Jędrzejak](https://github.com/janjedrzejak)

---

Questions? Open an issue on GitHub.
