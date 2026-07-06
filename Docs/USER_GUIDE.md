# Hilt User Guide

Hilt converts **unlocked** Windows e-Sword modules into files you can import into **e-Sword X** on the Mac.

## Quick start

1. **Add modules** — Drop `.bblx`, `.cmtx`, `.dctx`, or `.topx` files (or a folder) onto the dashed drop area, or choose **File → Add Modules…** (⌘O).
2. **Review the table** — Green **Ready** rows will convert. Other rows show a **Reason** (encrypted, wrong type, empty, and so on).
3. **Choose an output folder** — Use **Choose Output Folder…** so all results go to one place. The **Output folder** strip always shows the destination.
4. **Convert** — Click **Convert** (⌘↩) or **File → Convert**.
5. **Import in e-Sword X** — **File → Resources → Import…**, select the new `.bbli` / `.cmti` / `.dcti` / `.topi` files, restart e-Sword X if needed.

## Where do my files go?

| Situation | Behavior |
|-----------|----------|
| You chose an output folder | All converted modules are written there. |
| You did not choose a folder | Hilt asks, then can create `hilt-output` next to each source file. |

Originals are **never** overwritten by conversion. **Overwrite** only replaces same-named files *inside the output folder*.

## Help menu

In the app: **Help → Hilt Help** for the same topics offline.

## CLI

```bash
swift build -c release
.build/release/hilt -o ~/Desktop/hilt-output ~/Downloads/SomeModule.bblx
```

## Limits

- No decryption of premium modules.
- Not affiliated with e-Sword.
- Respect copyright on content you convert.

More detail: [README.md](../README.md)
