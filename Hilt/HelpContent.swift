import Foundation

struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String

    static let welcome = HelpTopic(
        id: "welcome",
        title: "Welcome to Hilt",
        body: """
        Hilt is a Mac-native utility that converts unlocked Windows e-Sword modules into the format used by e-Sword X.

        Use Hilt when you have BibleSupport (or similar) modules ending in .bblx, .cmtx, .dctx, or .topx and need .bbli, .cmti, .dcti, or .topi files you can import on the Mac.

        Workflow at a glance:
        1. Add sources — drop or open unlocked Windows modules.
        2. Choose a destination — the folder where converted files are written.
        3. Convert — only Ready rows are written.
        4. Import — in e-Sword X, use File → Resources → Import…

        Sources are never modified. Converted files go only to the destination folder.

        Hilt only converts unlocked modules. Encrypted or premium product-key modules are refused. Hilt is not affiliated with e-Sword or Rick Meyers.
        """
    )

    static let addModules = HelpTopic(
        id: "add-modules",
        title: "Add source modules",
        body: """
        The upper part of the main window is Sources — that is the only place you drop files.

        You can add modules in two ways:

        1. Drag files or a folder onto the Sources drop area (labeled “Drop source modules here”).
        2. Choose File → Add Modules… (⌘O), or click Add Modules… in the toolbar.

        Supported Windows extensions: .bblx (Bible), .cmtx (commentary), .dctx (dictionary), .topx (topic notes). Folders are scanned for those files.

        After you add items, the Modules table lists each file, its type, title when available, and whether Hilt can convert it. Use the Reason column when a file is not Ready.

        You can select rows and press Delete (or Edit → Remove from Queue) to remove them. Context-click a row for Show Original in Finder or Copy Path.
        """
    )

    static let output = HelpTopic(
        id: "output",
        title: "Choose where files go",
        body: """
        Converted modules are never written back over your originals.

        The Destination section (below the modules table) always shows where files will be written:

        1. Click Choose Output Folder… (or File → Output Folder…, ⌘⇧O) and pick a folder.
        2. When a folder is set, the full path appears in Destination.
        3. Use Show in Finder to open that folder in Finder.

        If you convert without choosing a folder, Hilt asks what to do. You can choose a folder, or let Hilt create a folder named hilt-output next to each source file. Prefer an explicit destination so all results land in one place.

        Do not drop modules on Destination — that area is only for choosing the output folder. Drops belong on Sources.
        """
    )

    static let queue = HelpTopic(
        id: "queue",
        title: "Read the modules table",
        body: """
        Each row is one module Hilt inspected:

        • Ready — unlocked and recognized; included when you Convert.
        • Unreadable — encrypted, corrupt, empty, or missing expected tables. The Reason column explains why.
        • Unsupported / Not yet supported — wrong extension or a type Hilt does not convert yet.

        Only Ready rows are converted. Blocked rows remain listed so you can see the reason without guessing.

        Clear Queue (toolbar or File menu) removes every item. Remove from Queue affects only the selected rows.
        """
    )

    static let convert = HelpTopic(
        id: "convert",
        title: "Convert",
        body: """
        1. Add sources and confirm Ready rows in the table.
        2. Choose a destination folder (recommended).
        3. Optionally open Hilt → Settings… to enable Overwrite existing files or Dry run.
        4. Click Convert (⌘↩) or File → Convert.

        Dry run reports what would happen without writing files. Overwrite replaces existing files of the same name in the destination folder only — it never changes your source modules. Overwrite is off by default.

        While converting, the status bar shows progress (for example, Converting 3 of 12…). Results appear in Last conversion with success or failure messages.
        """
    )

    static let eswordX = HelpTopic(
        id: "esword-x",
        title: "Import into e-Sword X",
        body: """
        After Hilt writes .bbli / .cmti / .dcti / .topi files:

        1. Click Show in Finder (Destination or status bar) to open the output folder.
        2. Open e-Sword X.
        3. Choose File → Resources → Import….
        4. Select the converted modules from your Hilt destination folder.
        5. Restart e-Sword X if it was already running so the library reloads.

        Official premium modules purchased for e-Sword can usually be re-downloaded inside e-Sword X with your product key — you do not need Hilt for those.
        """
    )

    static let limits = HelpTopic(
        id: "limits",
        title: "What Hilt will not do",
        body: """
        • Decrypt or bypass locked / premium modules.
        • Replace e-Sword X as a study app.
        • Guarantee identical output to the Windows PC Module Conversion Utility on every community edge case — formats vary; Hilt aims for practical import success.

        Always respect copyright on module content. Convert only modules you have a right to use.
        """
    )

    static let keyboard = HelpTopic(
        id: "keyboard",
        title: "Keyboard shortcuts",
        body: """
        • ⌘O — Add Modules…
        • ⌘⇧O — Output Folder…
        • ⌘↩ — Convert
        • ⌘K — Clear Queue
        • Delete — Remove selected rows from the queue
        • ⌘? — Hilt Help
        • ⌘, — Settings…
        """
    )

    static let all: [HelpTopic] = [
        .welcome, .addModules, .output, .queue, .convert, .eswordX, .limits, .keyboard
    ]
}
