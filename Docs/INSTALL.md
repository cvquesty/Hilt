# Installing Hilt (direct distribution)

Hilt is distributed **outside the Mac App Store** as a notarized Developer ID build. You do not need Xcode or TestFlight.

## What you receive

| File | What to do |
|------|------------|
| **Hilt-*.dmg** (recommended) | Open → double-click **Install Hilt.command**, or drag **Hilt** → **Applications** |
| **Hilt-*.zip** | Unzip → move **Hilt.app** to **Applications** |
| **Hilt-*.pkg** | Double-click installer → `/Applications` (when Installer-signed) |

## Requirements

- macOS 13 Ventura or later (Apple silicon or Intel)
- [e-Sword X](https://www.e-sword.net/mac/) to import converted modules

## Gatekeeper

The app is **signed** (Developer ID Application) and **notarized** by Apple.

If macOS still blocks the first open:

1. Right-click (or Control-click) **Hilt**
2. Choose **Open**
3. Confirm **Open** in the dialog

If **Install Hilt.command** is blocked the first time: right-click → **Open** (allows Terminal once).

## After install

1. Open **Hilt** from Applications or Spotlight  
2. Drop unlocked Windows modules onto **Sources** (`.bblx`, `.cmtx`, `.dctx`, `.topx`)  
3. **Choose Output Folder…** under **Destination**  
4. Click **Convert**  
5. In e-Sword X: **File → Resources → Import…**

In-app help: **Help → Hilt Help** (⌘?).

Full guide: [USER_GUIDE.md](USER_GUIDE.md).

## Building packages yourself (maintainer)

```bash
# From the Hilt repo root — needs Xcode team QCLT43467P + .secrets API key
bash Scripts/distribute-mac.sh
```

Artifacts land in `build/dist/`:

| Artifact | Notes |
|----------|--------|
| `Hilt-*.dmg` | Primary hand-out — app + Install Hilt.command + instructions |
| `Hilt-*.zip` | Portable notarized app |
| `Hilt-*.pkg` | productbuild installer (signed/notarized only if a **Developer ID Installer** identity is in the keychain) |

### Optional: sign the `.pkg`

1. In [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list), create **Developer ID Installer**
2. Install the certificate in your login keychain
3. Re-run `bash Scripts/distribute-mac.sh` — the script will `productsign` + notarize the package and place **Install Hilt.pkg** on the DMG

App Store / TestFlight upload is separate and optional: `bash Scripts/ship-mac.sh` (not required for personal distribution).

## License & disclaimer

Apache-2.0. Hilt is not affiliated with e-Sword or Rick Meyers. Respect copyright on module content.
