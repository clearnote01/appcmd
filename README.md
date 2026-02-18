## AppCmd - App Switcher

AppCmd is a minimal Swift-based app switcher for macOS that allows you to instantly switch between applications using the **Right Command** key. It is inspired by the functionality of `rcmd`.

### Features

- **Instant Switching**: Use **Right Command + [Letter]** to jump to any running app starting with that letter.
- **App Cycling**: Repeatedly press the same letter while holding Right Command to cycle through all matching apps.
- **Visual Overlay**: A modern, translucent UI showing matching apps and your current selection.
- **Static Mapping**: Assign specific letters to specific apps (e.g., 'O' for Outlook) using **Right Command + Option + [Letter]**.
- **Auto-Launch**: Static mappings will automatically launch the assigned app if it isn't running.
- **Menu Bar Icon**: Quick access to Settings and app status.
- **HUD Feedback**: Optional on-screen notifications for quick switches.

### Requirements

- macOS 13 or newer.
- **Accessibility** permissions (required for global hotkey detection).

### Installation (Homebrew)

The easiest way to install and stay updated is via Homebrew:

```bash
brew tap clearnote01/tap
brew install appcmd
brew services start appcmd
```

**Note:** After installation, you will need to grant **Accessibility** permissions to `appcmd` in **System Settings → Privacy & Security → Accessibility**. The binary is typically located at `/opt/homebrew/bin/appcmd`.

### Build from Source

From the project root:

```bash
swift build -c release
```

The executable will be at `.build/release/appcmd`.

### Usage

- **Dynamic Switching**: Hold **Right Command** and press a letter (e.g., `S` for Safari).
- **Custom Assignment**: Focus an app, then hold **Right Command + Option** and press a letter.
- **Settings**: Click the `⌘` icon in the menu bar and select **Settings...** to customize themes, HUD feedback, and manage your assignments.

Static assignments are stored in:
`~/Library/Application Support/AppCmd/config.json`

### Auto-start at Login (Manual)

If not using Homebrew services, you can use the provided scripts:

```bash
./install-launch-agent.sh
```

To disable auto-start:

```bash
./uninstall-launch-agent.sh
```

### Notes

- **Right Command**: This tool specifically targets the **Right Command** key to avoid conflicts with standard system shortcuts.
- **Permissions**: If the app doesn't seem to respond, ensure it is enabled under **System Settings → Privacy & Security → Accessibility**.

---
Created with love by Utkarsh Raj
