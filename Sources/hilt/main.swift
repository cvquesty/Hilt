import Foundation
import HiltCore

@main
struct HiltCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.isEmpty || args.contains("-h") || args.contains("--help") {
            printUsage()
            exit(args.isEmpty ? 1 : 0)
        }
        if args.contains("-v") || args.contains("--version") {
            print("\(HiltVersion.toolName) \(HiltVersion.marketing) (\(HiltVersion.build))")
            print(HiltVersion.blurb)
            exit(0)
        }

        var overwrite = false
        var dryRun = false
        var force = false
        var recursive = false
        var outputDir: URL?
        var inputs: [String] = []

        var i = 0
        while i < args.count {
            let a = args[i]
            switch a {
            case "-o", "--output":
                i += 1
                guard i < args.count else { die("Missing value for \(a)") }
                outputDir = URL(fileURLWithPath: (args[i] as NSString).expandingTildeInPath)
            case "--overwrite":
                overwrite = true
            case "--dry-run":
                dryRun = true
            case "--force":
                force = true
            case "-r", "--recursive":
                recursive = true
            case "-h", "--help", "-v", "--version":
                break
            default:
                if a.hasPrefix("-") {
                    die("Unknown option: \(a)")
                }
                inputs.append((a as NSString).expandingTildeInPath)
            }
            i += 1
        }

        guard !inputs.isEmpty else {
            die("Provide at least one module file or directory.")
        }

        let options = ConversionOptions(overwrite: overwrite, dryRun: dryRun, force: force)
        let converter = ModuleConverter(options: options)

        var allResults: [ConversionResult] = []
        var failures = 0

        for path in inputs {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
                fputs("error: not found: \(path)\n", stderr)
                failures += 1
                continue
            }

            let url = URL(fileURLWithPath: path)
            let out = outputDir ?? (isDir.boolValue
                ? url.appendingPathComponent("hilt-output")
                : url.deletingLastPathComponent().appendingPathComponent("hilt-output"))

            if isDir.boolValue {
                let results = converter.convertDirectory(url, outputDirectory: out, recursive: recursive)
                allResults.append(contentsOf: results)
            } else {
                do {
                    let result = try converter.convert(file: url, outputDirectory: out)
                    allResults.append(result)
                } catch {
                    allResults.append(
                        ConversionResult(
                            sourceURL: url,
                            moduleType: ModuleType.from(fileExtension: url.pathExtension),
                            success: false,
                            message: error.localizedDescription
                        )
                    )
                }
            }
        }

        for r in allResults {
            let mark = r.success ? "OK  " : "FAIL"
            let title = r.abbreviation ?? r.title ?? r.sourceURL.lastPathComponent
            print("[\(mark)] \(r.sourceURL.lastPathComponent) → \(title): \(r.message)")
            if !r.success { failures += 1 }
        }

        let ok = allResults.filter(\.success).count
        print("—")
        print("Done: \(ok) succeeded, \(failures) failed, \(allResults.count) total.")
        if let outputDir {
            print("Output directory: \(outputDir.path)")
        }
        print("Import into e-Sword X: File → Resources → Import… then restart e-Sword X.")
        exit(failures == 0 ? 0 : 2)
    }

    static func printUsage() {
        print("""
        \(HiltVersion.toolName) \(HiltVersion.marketing) — Mac-native e-Sword → e-Sword X converter

        USAGE:
          hilt [-o DIR] [--overwrite] [--dry-run] [--force] [-r] <file-or-dir> [...]

        OPTIONS:
          -o, --output DIR   Write converted modules here (default: ./hilt-output next to input)
          --overwrite        Replace existing output files
          --dry-run          Report actions without writing
          --force            Also re-process already-mobile (*i) extensions
          -r, --recursive    Recurse into directories
          -v, --version      Print version
          -h, --help         Show help

        SUPPORTED (MVP):
          .bblx → .bbli   Bible
          .cmtx → .cmti   Commentary
          .dctx → .dcti   Dictionary
          .topx → .topi   Topic notes

        Unlocked / public-domain modules only. Encrypted premium modules are refused.

        After conversion, in e-Sword X:
          File → Resources → Import…  (then restart e-Sword X)
        """)
    }

    static func die(_ message: String) -> Never {
        fputs("error: \(message)\n", stderr)
        exit(1)
    }
}
