## AppCmd - App Switcher

This is a minimal Swift implementation of an `appcmd`-style app switcher for macOS.

It listens for:

- **Right Command + letter**: switch to (or cycle between) apps starting with that letter.
- **Right Command + Option + letter**: assign that letter to the currently focused app (static mapping).

Static mappings are stored on disk and used to **launch** apps when they are not running.

### Requirements

- macOS 13 or newer.
- Swift toolchain (Xcode command line tools).
- **Accessibility** and **Input Monitoring** permissions for the built binary (needed for global hotkeys).

### Build

From the project root:

```bash
swift build -c release
```

The executable will be at:

```bash
.build/release/appcmd
```

### Run

Run the tool from the terminal:

```bash
./.build/release/appcmd
```

On first run, macOS will likely ask you to grant:

- **Accessibility** access.
- **Input Monitoring** access.

Grant these in **System Settings → Privacy & Security**. If it does not appear automatically, add the built binary manually.

The tool will keep running in the background in that terminal, listening for hotkeys.

### Usage

- **Switching apps dynamically**
  - Hold **Right Command** and press a letter, e.g. `S`.
  - The tool finds all **running** apps whose name starts with that letter (`Safari`, `Spotify`, `Shortcuts`, etc.).
  - It focuses the most appropriate one and brings it to the front.
  - Repeated presses of the same letter will **cycle** between matching apps.

- **Static assignments (launch apps)**
  - Focus an app (e.g. Music).
  - Hold **Right Command + Option** and press a letter, e.g. `U`.
  - From now on, **Right Command + U** will:
    - Focus Music if it is running.
    - Launch Music if it is not.

Static assignments and per-key settings are stored in:

```text
~/Library/Application Support/AppCmd/config.json
```

### Auto-start at Login

To make AppCmd start automatically when you log in:

```bash
./install-launch-agent.sh
```

This will:
- Create a Launch Agent plist file
- Configure it to start AppSwitch at login
- Load it immediately

To disable auto-start:

```bash
./uninstall-launch-agent.sh
```

Alternatively, you can manually add it to **System Settings → General → Login Items**.

### Notes / limitations

- This is a **CLI-style core**, not a full App Store-ready GUI app:
  - There is no menu bar icon or visual app switcher overlay yet.
  - Those can be added later in a dedicated macOS app target using this core as a library.
- Right Command detection uses `NSEvent`’s `modifierFlags` and specifically the `.rightCommand` flag.
- For advanced window-level switching (per-window instead of per-app), you would need to integrate with Accessibility APIs or an external tool (similar to how `appcmd` uses Hammerspoon).

