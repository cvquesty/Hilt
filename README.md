# Hilt

**Mac-native e-Sword module conversion for [e-Sword X](https://www.e-sword.net/mac/).**

Hilt converts **unlocked** Windows / BibleSupport-style e-Sword modules into the mobile-style modules that **e-Sword X** can import — without Wine, VMs, or a Windows PC.

> *A hilt is what you hold when you carry a sword.*  
> e-Sword X is the blade; Hilt is the grip that lets Mac users carry community modules with it.

## Features

- **macOS app** — clear **Sources** vs **Destination** regions, modules table, workflow checklist
- **Installer packages** — notarized `.pkg` / `.dmg` / `.zip` for direct distribution (no App Store required)
- **Help menu** — offline **Hilt Help** window (⌘?) with full topics
- **CLI** — `hilt` for scripts
- **Types (MVP)** — `.bblx`→`.bbli`, `.cmtx`→`.cmti`, `.dctx`→`.dcti`, `.topx`→`.topi`
- RTF → HTML for common markup; refuses encrypted modules
- Pure Swift + system SQLite
- Non-destructive defaults (Overwrite off unless you enable it in Settings)

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ to build from source
- [e-Sword X](https://www.e-sword.net/mac/) to import results

## Website & App Store URLs

Public site: **[https://hiltutil.org](https://hiltutil.org)** (hosted on server.questy.org at `/var/www/html/hilt`)

| App Store Connect field | URL |
|-------------------------|-----|
| Marketing URL | https://hiltutil.org/ |
| Support URL | https://hiltutil.org/support.html |
| Privacy Policy URL | https://hiltutil.org/privacy.html |

Site sources: [website/](website/)

## Download & install (end users)

**Latest:** [Hilt 1.0.0 (.dmg)](https://github.com/cvquesty/Hilt/releases/download/v1.0.0/Hilt-1.0.0.dmg) · [all releases](https://github.com/cvquesty/Hilt/releases) · site: [hiltutil.org](https://hiltutil.org)

See **[Docs/INSTALL.md](Docs/INSTALL.md)**.

| Artifact | Action |
|----------|--------|
| `Hilt-<version>.dmg` | **Recommended** — open → **Install Hilt.command**, or drag **Hilt** → Applications |
| `Hilt-<version>.zip` | Unzip → move **Hilt.app** to Applications |
| `Hilt-<version>.pkg` | Double-click installer → Applications (when Installer-signed) |

Signed with **Developer ID** and **notarized** by Apple (team `QCLT43467P`).

## Using the app

**Two zones — do not mix them up:**

1. **Sources** (top) — Drop unlocked Windows modules here (`.bblx`, `.cmtx`, `.dctx`, `.topx`), or **File → Add Modules…** (⌘O).
2. **Destination** (bottom) — **Choose Output Folder…** (⌘⇧O). Converted files are written **only** here. Sources are never modified.

Then:

3. Read the **Modules** table — only **Ready** rows convert; others show a **Reason**.
4. Click **Convert** (⌘↩).
5. **Show in Finder**, then in e-Sword X: **File → Resources → Import…**

**Help → Hilt Help** (⌘?) opens the offline guide.

Full walkthrough: [Docs/USER_GUIDE.md](Docs/USER_GUIDE.md)

## Build from source

```bash
cd Hilt
swift build -c release
swift test
open Hilt.xcodeproj   # GUI
```

CLI:

```bash
.build/release/hilt -o ~/Desktop/hilt-output ~/Downloads/module.bblx
```

## Distribute yourself (maintainer)

Notarized **Developer ID** packages — no App Store review. Recipients install without Xcode.

| | |
|---|---|
| **Bundle ID** | `org.questy.hilt` |
| **Team** | QCLT43467P (Jerald Sheets) |
| **Signing** | Developer ID Application (Cloud Managed) |
| **Min macOS** | 13.0 |

```bash
bash Scripts/distribute-mac.sh
```

Outputs in `build/dist/`:

- `Hilt-<version>.dmg` — disk image with app, **Install Hilt.command**, instructions
- `Hilt-<version>.zip` — portable app
- `Hilt-<version>.pkg` — productbuild installer (Installer-signed when cert present)
- `INSTALL.txt` — short end-user notes

Prerequisites: Xcode signed into team `QCLT43467P`, App Store Connect API key under `.secrets/` (see `.secrets/README.txt`). Optional **Developer ID Installer** cert fully signs/notarizes the `.pkg`.

### App Store / TestFlight (later)

Store listing and TestFlight are optional and deferred. When ready:

```bash
bash Scripts/ship-mac.sh
```

| | |
|---|---|
| **Store name** | Hilt for e-Sword X |
| **Apple ID** | `6788101386` |
| **Bundle ID** | `org.questy.hilt` |

## Project layout

```
Sources/HiltCore/   Conversion engine + module inspector
Sources/hilt/       Command-line tool
Hilt/               SwiftUI app (AppState, Help, UI)
Packaging/          Installer welcome / Distribution.xml / INSTALL.txt
Docs/               User guide + install notes
Scripts/            distribute-mac.sh (direct), ship-mac.sh (App Store later)
Assets/             Master app icon
```

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Disclaimer

e-Sword® is a trademark of its respective owner. Hilt is an independent open-source utility and is **not** affiliated with or endorsed by Rick Meyers or e-Sword.net. Respect copyright on module *content*.

## Author

Jerald Sheets ([@cvquesty](https://github.com/cvquesty))
