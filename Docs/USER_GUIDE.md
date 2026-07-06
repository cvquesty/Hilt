# Hilt User Guide

Hilt converts **unlocked** Windows e-Sword modules into files you can import into **e-Sword X** on the Mac.

> *A hilt is what you hold when you carry a sword.*  
> e-Sword X is the blade; Hilt is the grip that lets Mac users carry community modules with it.

---

## The two places that matter

Hilt separates **input** from **output** on purpose:

| Area | What it is | What you do |
|------|------------|-------------|
| **Sources** (top) | Where modules *come from* | Drop or open `.bblx`, `.cmtx`, `.dctx`, `.topx` files (or a folder) |
| **Destination** (bottom) | Where converted files *go* | Choose a folder with **Choose Output Folder…** |

**Sources are never modified.** Converted `.bbli` / `.cmti` / `.dcti` / `.topi` files are written **only** to the destination folder.

Do **not** drop modules on Destination — that strip is only for picking an output folder.

---

## Quick start

1. **Add sources** — Drop modules onto **Drop source modules here**, or choose **File → Add Modules…** (⌘O) / toolbar **Add Modules…**.
2. **Review the table** — Green **Ready** rows will convert. Other rows show a **Reason** (encrypted, wrong type, empty, and so on).
3. **Choose a destination** — Use **Choose Output Folder…** under **Destination** (or **File → Output Folder…**, ⌘⇧O). The path always shows there once set.
4. **Convert** — Click **Convert** (⌘↩) or **File → Convert**.
5. **Import in e-Sword X** — **Show in Finder**, then in e-Sword X: **File → Resources → Import…**. Restart e-Sword X if needed.

The top of the window shows the same four steps as a light checklist.

---

## Help menu

| Menu item | Action |
|-----------|--------|
| **Help → Hilt Help** (⌘?) | Opens the offline **Hilt Help** window (topics in the sidebar) |
| **Help → Hilt on GitHub…** | Opens the project page in your browser |

Topics inside Help include Welcome, Add source modules, Choose where files go, Modules table, Convert, Import into e-Sword X, limits, and keyboard shortcuts.

You can also click **Hilt Help** in the workflow strip or **How conversion works** in the empty Sources area.

---

## Where do my files go?

| Situation | Behavior |
|-----------|----------|
| You chose a destination folder | All converted modules are written there. |
| You did not choose a folder | Hilt asks before converting. You can choose a folder, or create `hilt-output` next to each source file. |

**Overwrite** (in **Hilt → Settings…**) only replaces same-named files *inside the destination folder*. It never changes your sources. Overwrite is **off** by default.

**Dry run** reports what would happen without writing files.

---

## Modules table

| Status | Meaning |
|--------|---------|
| **Ready** | Unlocked and recognized — included when you Convert |
| **Unreadable** | Encrypted, corrupt, empty, or missing expected tables — see **Reason** |
| **Unsupported / Not yet supported** | Wrong extension or a type Hilt does not convert yet |

### Selection actions

- **Delete** or **File → Remove from Queue** — remove selected rows
- Context menu: **Remove from Queue**, **Show Original in Finder**, **Copy Path**
- **Clear Queue** — remove everything

---

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Add Modules… |
| ⌘⇧O | Output Folder… |
| ⌘↩ | Convert |
| ⌘K | Clear Queue |
| Delete | Remove selected from queue |
| ⌘? | Hilt Help |
| ⌘, | Settings… |

---

## Supported types (MVP)

| Windows source | e-Sword X target |
|----------------|------------------|
| `.bblx` (Bible) | `.bbli` |
| `.cmtx` (commentary) | `.cmti` |
| `.dctx` (dictionary) | `.dcti` |
| `.topx` (topic notes) | `.topi` |

---

## Command-line (CLI)

```bash
swift build -c release
.build/release/hilt -o ~/Desktop/hilt-output ~/Downloads/SomeModule.bblx
```

Use `-o` / `--output` so results land in one place. Prefer the same destination folder you would pick in the app.

---

## Settings

**Hilt → Settings…** (⌘,):

- Overwrite existing files in the destination folder
- Dry run (do not write files)
- Current destination folder (choose / show in Finder)

About information lives under **Hilt → About Hilt**, not in Settings.

---

## Limits

- No decryption of premium / product-key modules.
- Not affiliated with e-Sword or Rick Meyers.
- Respect copyright on content you convert.
- Community modules vary; Hilt aims for practical import success, not bit-for-bit parity with every Windows tool edge case.

---

## More

- Project overview: [README.md](../README.md)
- License: [LICENSE](../LICENSE) (Apache-2.0)
