# Hilt

**Mac-native e-Sword module conversion for [e-Sword X](https://www.e-sword.net/mac/).**

Hilt converts **unlocked** Windows / BibleSupport-style e-Sword modules into the mobile-style modules that **e-Sword X** can import — without Wine, VMs, or a Windows PC.

> *A hilt is what you hold when you carry a sword.*  
> e-Sword X is the blade; Hilt is the grip that lets Mac users carry community modules with it.

## Features

- **macOS app** — toolbar actions, drop zone, modules table, always-visible output path
- **Help menu** — offline Hilt Help (Welcome, Add modules, Output, Convert, e-Sword X import, limits)
- **CLI** — `hilt` for scripts
- **Types (MVP)** — `.bblx`→`.bbli`, `.cmtx`→`.cmti`, `.dctx`→`.dcti`, `.topx`→`.topi`
- RTF → HTML for common markup; refuses encrypted modules
- Pure Swift + system SQLite

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ to build from source
- [e-Sword X](https://www.e-sword.net/mac/) to import results

## Using the app

1. **Drop** modules on the dashed area (or **File → Add Modules…** / ⌘O).
2. Read the **Modules** table — only **Ready** rows convert; others show a **Reason**.
3. **Choose Output Folder…** — the Output strip always shows where files will be written.
4. Click **Convert** (⌘↩).
5. **Show Output in Finder**, then in e-Sword X: **File → Resources → Import…**

Full walkthrough: [Docs/USER_GUIDE.md](Docs/USER_GUIDE.md)

## Build

```bash
cd Hilt
swift build -c release
swift test
.open Hilt.xcodeproj   # GUI / Archive / TestFlight
```

CLI:

```bash
.build/release/hilt -o ~/Desktop/hilt-output ~/Downloads/module.bblx
```

## Project layout

```
Sources/HiltCore/   Conversion engine + module inspector
Sources/hilt/       Command-line tool
Hilt/               SwiftUI app (AppState, Help, UI)
Docs/               User guide
Assets/             Master app icon
```

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Disclaimer

e-Sword® is a trademark of its respective owner. Hilt is an independent open-source utility and is **not** affiliated with or endorsed by Rick Meyers or e-Sword.net. Respect copyright on module *content*.

## Author

Jerald Sheets ([@cvquesty](https://github.com/cvquesty))
