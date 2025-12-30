
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
