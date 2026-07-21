# Changelog

## Website (2026-07-21)

### Direct download — v0.2.0 on GitHub
- GitHub release **[v0.2.0](https://github.com/cvquesty/Hilt/releases/tag/v0.2.0)** with `Hilt-0.2.0.dmg`
- [hiltutil.org](https://hiltutil.org) hero + Download section link straight to the DMG
- Same marketing version as the build under Mac App Store review

## Website (2026-07-14)

### Publicity site — hiltutil.org
- Static marketing site at **https://hiltutil.org** (docroot `/var/www/html/hilt` on server.questy.org)
- App Store–ready pages: home, **support**, **privacy**
- Let's Encrypt TLS for `hiltutil.org`; HTTP → HTTPS redirect
- Sources under [website/](website/)

## 0.2.0 (2026-07-13) — build 5 (complete self-distribution)

### Installer & packaging
- **DMG installer** — `Install Hilt.command` copies the notarized app to `/Applications` and launches it; drag-to-Applications still works
- **`.pkg` installer** (productbuild) with Welcome / License / Conclusion — signed+notarized when a Developer ID Installer cert is present
- **ZIP** portable app retained for simple hand-off
- Packaging assets under `Packaging/` (`Distribution.xml`, welcome/conclusion HTML, `INSTALL.txt`)
- [Docs/INSTALL.md](Docs/INSTALL.md) for end users; README prioritizes direct distribution
- App Store / TestFlight path remains optional (`Scripts/ship-mac.sh`) for a later date

### App
- Destination folder restored across launches via **security-scoped bookmark** (App Sandbox)
- Version **0.2.0** (build **5**)

## 0.1.1 (2026-07-13) — build 4 (direct distribution)

### Direct distribution (outside App Store)
- **Developer ID** export via Cloud Managed certificate (team QCLT43467P)
- Apple **notarization** + staple (Gatekeeper: Notarized Developer ID)
- Installable packages: `build/dist/Hilt-0.1.1.dmg` and `Hilt-0.1.1.zip`
- `Scripts/distribute-mac.sh` — archive → Developer ID export → notarize → DMG/ZIP
- `ExportOptions-DeveloperID.plist` for non–App Store signing

## 0.1.1 (2026-07-06) — build 4

### App Store Connect / TestFlight
- Registered bundle ID `org.questy.hilt` (UNIVERSAL) on team QCLT43467P
- Created App Store Connect app **Hilt for e-Sword X** (Apple ID `6788101386`) — plain name “Hilt” was already taken on the store
- Uploaded macOS build **0.1.1 (4)** to TestFlight (VALID)
- Internal Testers beta group + en-US beta localization
- Export compliance declared in Info.plist (`ITSAppUsesNonExemptEncryption` = false)
- App Sandbox + user-selected read/write entitlements for Mac App Store distribution
- Ship scripts: `Scripts/archive-mac.sh`, `Scripts/ship-mac.sh`

## 0.1.1 (2026-07-06)

### Added
- **Help menu** — **Hilt Help** (⌘?) opens a non-modal Help window with full offline topics
- Help topics: Welcome, sources, destination, queue, convert, e-Sword X import, limits, keyboard shortcuts
- Workflow checklist in the main window (Add sources → Destination → Convert → Import)
- Explicit **Sources** and **Destination** sections so drag-in vs write-out are unmistakable
- Queue selection actions: Remove (Delete), Show Original in Finder, Copy Path (context menu + Edit menu)
- Conversion progress (“Converting *n* of *m*…”) with progress indicator
- Expanded [Docs/USER_GUIDE.md](Docs/USER_GUIDE.md)

### Changed (Apple HIG compliance)
- **About Hilt** moved to the application menu standard About panel (not Settings)
- Settings hold conversion preferences only (Overwrite, Dry run, destination)
- Overwrite defaults to **off** (non-destructive)
- Unified labels: **Clear Queue**, **Show in Finder** everywhere
- Removed misleading “always require output folder” preference (app always prompts when unset)
- Help menu trimmed to **Hilt Help** + GitHub (topics live in the Help window)
- Single primary `Window` for the converter; separate Help window
- Overwrite / Dry run removed from main toolbar (Settings only)
- Default table columns reduced to Status, File, Type, Title, Reason
- Status bar is live state; import tips live in Help

### UI guidance
- Drop zone copy: “Drop **source** modules here”
- Destination empty state: “No destination selected” with prominent **Choose Output Folder…**
- Persistent rule: sources are not modified; output only goes to Destination

## 0.1.0 (2026-07-06)

### Added
- **HiltCore** conversion engine (Swift + system SQLite)
- **CLI** `hilt` — batch convert unlocked Windows e-Sword modules
- **macOS GUI** — SwiftUI drop-zone app (`org.questy.hilt`)
- Support for Bible (`.bblx`→`.bbli`), Commentary (`.cmtx`→`.cmti`),
  Dictionary (`.dctx`→`.dcti`), Topic (`.topx`→`.topi`)
- RTF → HTML body conversion for common e-Sword control words
- Encrypted / unreadable module detection and refusal
- Unit tests with in-memory sample `.bblx` fixtures
