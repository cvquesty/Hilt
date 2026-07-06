# Hilt

**Mac-native e-Sword module conversion for [e-Sword X](https://www.e-sword.net/mac/).**

Hilt converts **unlocked** Windows / BibleSupport-style e-Sword modules into the mobile-style modules that **e-Sword X** can import — without Wine, VMs, or a Windows PC.

> *A hilt is what you hold when you carry a sword.*  
> e-Sword X is the blade; Hilt is the grip that lets Mac users carry community modules with it.

## Why Hilt exists

| Platform | Module style | Typical extensions |
|----------|--------------|--------------------|
| Windows e-Sword + [BibleSupport](https://biblesupport.com) | PC SQLite (+ often RTF text) | `.bblx`, `.cmtx`, `.dctx`, `.topx`, … |
| e-Sword X (Mac), HD, Android | Mobile SQLite (+ HTML text) | `.bbli`, `.cmti`, `.dcti`, `.topi`, … |

The official **PC Module Conversion Utility** only runs on Windows. Hilt is a **100% macOS-native** alternative for unlocked modules.

## Features (MVP 0.1.0)

- **GUI app** — drag-and-drop batch conversion (SwiftUI)
- **CLI** — `hilt` for scripts and power users
- **Supported types**
  - `.bblx` → `.bbli` (Bible)
  - `.cmtx` → `.cmti` (Commentary)
  - `.dctx` → `.dcti` (Dictionary)
  - `.topx` → `.topi` (Topic notes)
- RTF → HTML conversion for body text
- Refuses encrypted / unreadable modules (no cracking)
- Pure Swift + system SQLite — no third-party package dependencies

## Requirements

- macOS 13 Ventura or later (Apple silicon or Intel)
- Xcode 15+ to build from source
- [e-Sword X](https://www.e-sword.net/mac/) to import results

## Build

```bash
cd Hilt
swift build -c release
swift test

# CLI binary:
.build/release/hilt --help
```

Open `Hilt.xcodeproj` in Xcode to build/run the **Hilt** macOS app (GUI), archive for **TestFlight**, or run the **hilt** CLI scheme.

## CLI usage

```bash
# Convert one module
hilt -o ~/Desktop/hilt-output ~/Downloads/SomeBible.bblx

# Convert a folder of BibleSupport downloads
hilt -o ~/Desktop/hilt-output --overwrite ~/Downloads/e-SwordModules

# Preview only
hilt --dry-run ~/Downloads/module.cmtx
```

## After conversion — e-Sword X

1. Open **e-Sword X**
2. **File → Resources → Import…**
3. Select the `.bbli` / `.cmti` / … files Hilt produced
4. **Restart e-Sword X** if it was already running

## What Hilt will not do

- Decrypt or bypass **locked / premium / product-key** modules  
- Replace e-Sword X as a study app  
- Guarantee byte-identical output to Rick Meyers’ Windows utility (community formats vary; we aim for practical import success)

## Project layout

```
Sources/HiltCore/   Shared conversion engine
Sources/hilt/       Command-line tool
Hilt/               SwiftUI macOS application
Tests/              Unit tests (fixture modules generated in-memory)
```

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Disclaimer

e-Sword® is a trademark of its respective owner. Hilt is an independent open-source utility and is **not** affiliated with or endorsed by Rick Meyers or e-Sword.net. Respect copyright on module *content*; convert only modules you have a right to use.

## Roadmap

- [ ] Broader module types (maps, devotionals, graphics)
- [ ] Richer RTF edge cases (tables, complex color tables)
- [ ] Regression corpus from community samples
- [ ] Mac App Store / public TestFlight polish
- [ ] Optional “reveal in e-Sword X library folder” helpers

---

**Author:** Jerald Sheets ([@cvquesty](https://github.com/cvquesty))
