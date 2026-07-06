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

        Hilt only converts unlocked modules. Encrypted or premium product-key modules are refused. Hilt is not affiliated with e-Sword or Rick Meyers.
        """
    )

    static let addModules = HelpTopic(
        id: "add-modules",
        title: "Add modules",
        body: """
        You can add modules in two ways:

        1. Drag files or a folder onto the drop area at the top of the window.
        2. Choose File → Add Modules… (⌘O), or click Add Modules….

        Supported Windows extensions: .bblx (Bible), .cmtx (commentary), .dctx (dictionary), .topx (topic notes). Folders are scanned for those files.

        After you add items, the Modules table lists each file, its type, size, title when available, and whether Hilt can convert it.
        """
    )

    static let output = HelpTopic(
        id: "output",
        title: "Choose where files go",
        body: """
        Converted modules are never written back over your originals.

        1. Click Choose Output Folder… (or File → Output Folder…) and pick a destination.
        2. The Output strip under the toolbar always shows that path.

        If you convert without choosing a folder, Hilt offers to create a folder named hilt-output next to each source file. Prefer setting an explicit output folder so all results land in one place.

        After a successful conversion, use Show Output in Finder (or Reveal in Finder in the status bar) to open the destination.
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
        """
    )

    static let convert = HelpTopic(
        id: "convert",
        title: "Convert",
        body: """
        1. Add modules and confirm Ready rows in the table.
        2. Choose an output folder (recommended).
        3. Optionally enable Overwrite existing or Dry run in Settings or the toolbar.
        4. Click Convert (⌘↩) or File → Convert.

        Dry run reports what would happen without writing files. Overwrite replaces existing files of the same name in the output folder.

        Results appear in the Last conversion list with success or failure messages.
        """
    )

    static let eswordX = HelpTopic(
        id: "esword-x",
        title: "Import into e-Sword X",
        body: """
        After Hilt writes .bbli / .cmti / .dcti / .topi files:

        1. Open e-Sword X.
        2. Choose File → Resources → Import….
        3. Select the converted modules from your Hilt output folder.
        4. Restart e-Sword X if it was already running so the library reloads.

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

    static let all: [HelpTopic] = [
        .welcome, .addModules, .output, .queue, .convert, .eswordX, .limits
    ]
}
