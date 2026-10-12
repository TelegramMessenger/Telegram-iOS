import XCTest
import Foundation

/// **No private UIKit name the editor reaches at run time is spelled in a shipping source.**
///
/// The InputDec engine is compiled into every build, flag or not, and it reaches private UIKit by
/// name: it looks classes, protocols, selectors and ivars up, and it answers callbacks UIKit sends
/// it under private names. App Store review scans the binary's strings, so every such name lives in
/// ONE table (`Scripts/private-runtime-names.txt`), stored encoded in the generated
/// `TGPrivateRuntimeNames.h` and decoded when used; a callback is compiled under a neutral `tgpn_`
/// name and added under the private one at run time (`TGPrivateMethodAliases.h`). The table is the
/// set of names that cross the boundary with UIKit, not every name that happens to match one.
///
/// This suite keeps it that way: the header must match the list, and no shipping source may spell a
/// listed name as a string literal, define or declare an Objective-C method or property under it,
/// take its `@selector`, or give it to a Swift `@objc(...)`. The binary-level check is
/// `Scripts/scan-private-runtime-names.py`, run on a release build.
final class PrivateRuntimeNamesTests: XCTestCase {

    private var listURL: URL { RepoLayout.packageRoot.appendingPathComponent("Scripts/private-runtime-names.txt") }
    private var headerURL: URL {
        RepoLayout.packageRoot.appendingPathComponent("Sources/RichTextInputDecObjC/include/TGPrivateRuntimeNames.h")
    }

    /// The shipping sources the rule covers: everything compiled into the app from this package.
    private let shippingRoots = [
        "Sources/RichTextInputDecObjC",
        "Sources/RichTextInputDecUpstream",
        "Sources/RichTextInputDecHost",
        "Sources/RichTextEngineEditor",
        "Sources/RichTextEditorUIKit",
    ]

    /// Files that are part of a shipping target's tree but not of the app build.
    private let excludedPaths = [
        "Sources/RichTextInputDecObjC/include/TGPrivateRuntimeNames.h",   // the table itself
        "Sources/RichTextInputDecObjC/Vendor/",                           // source-tree only
        "Sources/RichTextInputDecUpstream/Generated/",                    // encoded byte arrays
        "Sources/RichTextInputDecObjC/Generated/",
        "Sources/RichTextEditorUIKit/InputBackend/InputDec/Upstream/",    // excluded from the app (BUILD)
    ]

    /// The legacy canvas's text-checking client. It predates the table and answers
    /// `UITextCheckingController`'s callbacks as Swift `@objc` methods; the package `CLAUDE.md`
    /// records it as a known residual. Any OTHER file spelling these names fails.
    private let legacyResidual: [String: Set<String>] = [
        "Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+NativeTextCheckingClient.swift": [
            "replaceRange:withAnnotatedString:relativeReplacementRange:",
            "annotatedSubstringForRange:",
        ],
    ]

    private func listedNames() throws -> [String] {
        try String(contentsOf: listURL).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    // MARK: - The table

    func test_theHeaderEncodesExactlyTheListedNames() throws {
        RepoLayout.assertResolved()
        let header = try String(contentsOf: headerURL)
        let entry = try NSRegularExpression(pattern: #"^TG_PRIVATE_RUNTIME_NAME\((\w+), ([^)]*)\)$"#,
                                            options: .anchorsMatchLines)
        var decoded: [String] = []
        for match in entry.matches(in: header, range: NSRange(header.startIndex..., in: header)) {
            let function = String(header[Range(match.range(at: 1), in: header)!])
            let bytes = header[Range(match.range(at: 2), in: header)!].split(separator: ",").map {
                UInt8($0.trimmingCharacters(in: .whitespaces).dropFirst(2), radix: 16)! ^ 0x5A
            }
            let name = try XCTUnwrap(String(bytes: bytes, encoding: .utf8))
            XCTAssertEqual(function, "TGPN_" + name.replacingOccurrences(of: ":", with: "_"),
                           "\(function) does not decode to the name it is called after")
            decoded.append(name)
        }
        XCTAssertEqual(decoded.sorted(), try listedNames().sorted(),
                       "TGPrivateRuntimeNames.h is out of date: run Scripts/generate-private-runtime-names.py")
        XCTAssertGreaterThan(decoded.count, 100, "the table is suspiciously small; the parse may have failed")
    }

    // MARK: - The shipping sources

    private func shippingFiles() throws -> [(path: String, text: String)] {
        var files: [(String, String)] = []
        for root in shippingRoots {
            let base = RepoLayout.packageRoot.appendingPathComponent(root)
            let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
            for case let url as URL in enumerator where ["m", "h", "swift"].contains(url.pathExtension) {
                let relative = String(url.path.dropFirst(RepoLayout.packageRoot.path.count + 1))
                if excludedPaths.contains(where: { relative.hasPrefix($0) }) { continue }
                files.append((relative, try String(contentsOf: url)))
            }
        }
        XCTAssertGreaterThan(files.count, 200, "the scan found suspiciously few files")
        return files
    }

    /// The source with comments blanked out, so prose may name anything.
    private func withoutComments(_ source: String) -> String {
        let pattern = try! NSRegularExpression(pattern: #"//[^\n]*|/\*[\s\S]*?\*/"#)
        let mutable = NSMutableString(string: source)
        for match in pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            let text = (source as NSString).substring(with: match.range)
            let blank = String(text.map { $0 == "\n" ? "\n" : " " })
            mutable.replaceCharacters(in: match.range, with: blank)
        }
        return mutable as String
    }

    /// Every Objective-C selector a method signature in `source` declares or defines.
    private func methodSelectors(in source: String) -> [String] {
        let signature = try! NSRegularExpression(pattern: #"^[ \t]*[-+][ \t]*\(([^;{]*?)[;{]"#,
                                                 options: [.anchorsMatchLines, .dotMatchesLineSeparators])
        let keyword = try! NSRegularExpression(pattern: #"([A-Za-z_]\w*)\s*:\s*\((?:[^()]|\([^()]*\))*\)"#)
        var selectors: [String] = []
        for match in signature.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            var text = (source as NSString).substring(with: match.range)
            // Drop the return type.
            if let close = text.range(of: ")") { text = String(text[close.upperBound...]) }
            let parts = keyword.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                (text as NSString).substring(with: $0.range(at: 1))
            }
            if !parts.isEmpty {
                selectors.append(parts.map { $0 + ":" }.joined())
            } else if let name = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).first {
                selectors.append(String(name))
            }
        }
        return selectors
    }

    /// The getter and setter of every `@property` in `source`.
    private func propertyAccessors(in source: String) -> [String] {
        let property = try! NSRegularExpression(pattern: #"@property\s*(\(([^)]*)\))?[^;]*?\b(\w+)\s*;"#)
        var accessors: [String] = []
        for match in property.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            let name = (source as NSString).substring(with: match.range(at: 3))
            let attributes = match.range(at: 2).location == NSNotFound ? "" : (source as NSString).substring(with: match.range(at: 2))
            if let getter = attributes.range(of: #"getter\s*=\s*(\w+)"#, options: .regularExpression) {
                accessors.append(String(attributes[getter]).components(separatedBy: "=").last!.trimmingCharacters(in: .whitespaces))
            } else {
                accessors.append(name)
            }
            if !attributes.contains("readonly") {
                accessors.append("set" + name.prefix(1).uppercased() + name.dropFirst() + ":")
            }
        }
        return accessors
    }

    static let embeddedNameMinimumLength = 8

    func test_noShippingSourceSpellsAPrivateName() throws {
        RepoLayout.assertResolved()
        let names = Set(try listedNames())
        // One pattern for all of them: a name as a whole identifier or selector, not part of a longer one.
        let alternation = names.filter { $0.count >= Self.embeddedNameMinimumLength }
            .sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let embedded = try NSRegularExpression(pattern: "(?<![A-Za-z0-9_])(" + alternation + ")(?![A-Za-z0-9_:])")
        let literal = try NSRegularExpression(pattern: #"@?"((?:[^"\\\n]|\\.)*)""#)
        let selectorExpression = try NSRegularExpression(pattern: #"@selector\(\s*([A-Za-z_][\w:]*)\s*\)"#)
        let swiftObjC = try NSRegularExpression(pattern: #"@objc\(([A-Za-z_][\w:]*)\)"#)
        let swiftFunction = try NSRegularExpression(pattern: #"\bfunc\s+([A-Za-z_]\w*)\s*\("#)
        var violations: [String] = []
        var residualSeen: [String: Set<String>] = [:]
        for (path, text) in try shippingFiles() {
            let source = withoutComments(text)
            var found: [(String, String)] = []
            func capture(_ regex: NSRegularExpression, group: Int, kind: String) {
                for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                    let value = (source as NSString).substring(with: match.range(at: group))
                    if names.contains(value) { found.append((value, kind)) }
                }
            }
            capture(literal, group: 1, kind: "string literal")
            // A name inside a longer string — a diagnostic message — is as visible to a scan of the
            // binary's strings as a bare one. Names shorter than `embeddedNameMinimumLength` are left
            // to the exact-match check above: inside prose they collide with ordinary words.
            for match in literal.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                let value = (source as NSString).substring(with: match.range(at: 1))
                for hit in embedded.matches(in: value, range: NSRange(value.startIndex..., in: value)) {
                    let name = (value as NSString).substring(with: hit.range(at: 1))
                    if name != value { found.append((name, "inside a string literal")) }
                }
            }
            capture(selectorExpression, group: 1, kind: "@selector")
            capture(swiftObjC, group: 1, kind: "@objc name")
            if path.hasSuffix(".m") || path.hasSuffix(".h") {
                found += methodSelectors(in: source).filter(names.contains).map { ($0, "method") }
                found += propertyAccessors(in: source).filter(names.contains).map { ($0, "property accessor") }
            }
            // `#function` is a string literal the compiler writes: inside `func selectWord()` it is
            // "selectWord()", which the binary then carries. Measured in a release-path archive scan
            // (2026-10-12): two kernel-witness wrappers in the InputDec backend reported failures
            // with `witness: #function` and put both names in `__cstring`, which none of the checks
            // above could see. So a file that spells `#function` may not declare a Swift function
            // whose base name is a listed name.
            if path.hasSuffix(".swift"), source.contains("#function") {
                capture(swiftFunction, group: 1, kind: "Swift function named in #function")
            }
            for (name, kind) in found {
                if legacyResidual[path]?.contains(name) == true {
                    residualSeen[path, default: []].insert(name)
                    continue
                }
                violations.append("\(path): \(kind) \(name)")
            }
        }
        XCTAssertEqual(violations, [], "a private UIKit name is spelled in a shipping source; use TGPN_<name>() "
                       + "or, for a callback UIKit sends, a tgpn_ method added by TGPrivateInstallMethodAliases")
        // The residual is a live exemption, not a stale one: if the legacy client stops spelling a
        // name, drop it from the list rather than keep a blanket allowance.
        XCTAssertEqual(residualSeen, legacyResidual, "the legacy residual list no longer matches the source")
    }
}
