import CryptoKit
import Foundation
import XCTest

/// The two GENERATED artifacts change only deliberately.
///
/// This pinned a synced snapshot until 2026-09-15 — it was the mechanism that made "do not
/// hand-edit, re-sync with the export script" enforceable rather than aspirational. That rule is
/// gone: this repository is the source of truth for the kernel now, and `Kernel/`, `include/Kernel/`
/// and the carved `Host/` pairs are ordinary source. What it still guards is narrower and still
/// worth guarding: `Vendor/`'s pristine manifest and the `Generated/` contract data are PRODUCED
/// from it, so an edit to either is either a regeneration (record the new digest, say why) or a
/// mistake (the common case, and silent — a generated blob is exactly the file nobody reads).
///
/// **What a failure here means, and why that has to be readable.** This suite cannot re-derive the
/// artifacts: the generator has not been brought across. What it *can* do is state, in one place,
/// every fact they claim about their own origin — the two content digests **and** the revisions of
/// the three inputs that were transformed on the way in — and fail when the tree stops matching
/// them. Recording only the OUTPUT's digest would say *something changed* while leaving the two
/// causes indistinguishable, and they want opposite responses:
///
/// - `…MatchesTheRecordedSHA` red, tool pins unchanged → the bytes moved under a fixed toolchain:
///   an edit, or a regeneration nobody recorded. Re-record the digest in `VENDOR.md` in the same
///   commit as the change, with the reason.
/// - `…PinsTheToolCommits` red → the *generator* moved. The renames themselves may have moved with
///   it, so the vendoring has to be re-reviewed (`ContractManifestTests` is what actually parses the
///   manifest and checks the renames landed) before the pin below is updated.
///
/// The class-level `@available` is deliberate. `Package.swift:6` declares `.macOS(.v10_13)` while
/// `CryptoKit.SHA256` is `@available(macOS 10.15, iOS 13.0, *)`; this compiles unannotated today
/// only because the Swift driver clamps the arm64-macOS deployment target to 11.0. On an x86_64
/// host, or with a pinned `--triple`, the unannotated version fails with *"'SHA256' is only
/// available in macOS 10.15 or newer"*. Annotating costs nothing and makes the fast macOS loop
/// host-architecture-independent.
@available(macOS 10.15, iOS 13.0, *)
final class VendorSnapshotIntegrityTests: XCTestCase {

    // MARK: - The pins

    /// The InputDec revisions this snapshot was exported from and reviewed against.
    ///
    /// These are duplicated from `Vendor/VENDOR.md` **on purpose**: one side is a compile-time
    /// literal in a reviewed test file, the other is read from the vendored tree at run time, so a
    /// re-sync cannot quietly move the provenance. Updating a pin is the act of accepting a new
    /// snapshot — it should cost a reviewed edit, which is the whole point.
    ///
    /// `generateContractData` is the load-bearing one (see the class comment); the other two are
    /// pinned because their consequences are just as invisible: A3 measured that carving from the
    /// pre-narrowing `IDPrivateUIKit.m` yields an 11-spec host ABI that **compiles** and raises only
    /// at the first `+requireInteractionHost:stage:` call.
    private enum Pin {
        static let upstream = "fdad9ca519f5f27a07362e00dc6cefdcb73ca369"
        static let privateUIKit = "c1517772529a3610f238b5a7caa47ec42b3f1f40"
        static let carveHostPreflight = "60b15b9dcb6bf8663632c987dddaf481c48ac773"
        static let generateContractData = "548d0a4cb654691b60b5eae445a364627590c28f"
    }

    private var vendorRoot: URL {
        RepoLayout.packageRoot.appendingPathComponent("Sources/RichTextInputDecObjC")
    }

    private var vendorMarkdownURL: URL { vendorRoot.appendingPathComponent("Vendor/VENDOR.md") }
    private var pristineManifestURL: URL {
        vendorRoot.appendingPathComponent("Vendor/UIKitBehaviorContracts-iOS26.5.json")
    }
    private var generatedContractDataURL: URL {
        vendorRoot.appendingPathComponent("Generated/TGRichTextInputDecContractData.m")
    }

    // MARK: - Reading VENDOR.md

    private static let hexDigest = #"\b[0-9a-f]{64}\b"#
    private static let hexCommit = #"\b[0-9a-f]{40}\b"#

    /// The single line carrying `label`, or a recorded failure.
    ///
    /// FAIL, never skip. A truncated or malformed `VENDOR.md` is exactly the corruption this suite
    /// exists to catch; `XCTSkip` here would turn the integrity check into a green no-op the moment
    /// the file it reads goes missing. Uniqueness is asserted rather than taking the first match:
    /// several of these labels also appear in `VENDOR.md`'s prose and section headers, so pinning
    /// the first occurrence would make the assertion pass or fail on section order.
    private func soleLine(containing label: String,
                          alsoMatching pattern: String,
                          in markdown: String,
                          file: StaticString = #filePath,
                          line: UInt = #line) -> Substring? {
        let rows = markdown.split(separator: "\n").filter {
            $0.contains(label) && $0.range(of: pattern, options: .regularExpression) != nil
        }
        guard rows.count == 1 else {
            XCTFail("VENDOR.md has \(rows.count) lines carrying \"\(label)\" and a value matching "
                    + "\(pattern); expected exactly 1 — that line is the pin, and it has to "
                    + "exist in exactly one readable form",
                    file: file, line: line)
            return nil
        }
        return rows[0]
    }

    private func recordedSHA(_ label: String,
                             file: StaticString = #filePath,
                             line: UInt = #line) throws -> String {
        let markdown = try String(contentsOf: vendorMarkdownURL)
        guard let row = soleLine(containing: label, alsoMatching: Self.hexDigest, in: markdown,
                                 file: file, line: line),
              let range = row.range(of: Self.hexDigest, options: .regularExpression) else {
            return ""   // `soleLine` already recorded the failure; "" can never equal a real digest.
        }
        return String(row[range])
    }

    private func recordedRevision(of input: String,
                                  in markdown: String,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) -> String {
        guard let row = soleLine(containing: input, alsoMatching: Self.hexCommit, in: markdown,
                                 file: file, line: line),
              let range = row.range(of: Self.hexCommit, options: .regularExpression) else {
            return ""
        }
        return String(row[range])
    }

    private func sha256(of url: URL) throws -> String {
        // `Data(contentsOf:)` THROWS on a missing file, which surfaces as a test error rather than
        // a pass. That is deliberate: a digest check that silently reads nothing is the exact
        // vacuity this suite is supposed to be immune to.
        let digest = SHA256.hash(data: try Data(contentsOf: url))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Digests

    func test_generatedContractDataMatchesTheRecordedSHA() throws {
        RepoLayout.assertResolved()
        XCTAssertEqual(try sha256(of: generatedContractDataURL),
                       try recordedSHA("generated contract data SHA-256"),
                       "Generated/TGRichTextInputDecContractData.m no longer matches the digest "
                       + "VENDOR.md records for it. If test_vendorMarkdownPinsTheToolCommits… is "
                       + "GREEN the toolchain did not move, so this is an edit or an "
                       + "unrecorded regeneration. This file is GENERATED: prefer regenerating it, "
                       + "and either way re-record the digest in VENDOR.md in the same commit")
    }

    /// The bytes a generated blob's array holds, decoded (every byte XOR 0x5A, the encoding that
    /// keeps the manifest's private UIKit names out of the binary as text).
    private func decodedBlob(at url: URL, array: String) throws -> Data {
        let source = try String(contentsOf: url)
        let start = try XCTUnwrap(source.range(of: "static const unsigned char \(array)[] = {"),
                                  "\(url.lastPathComponent) has no array named \(array)")
        let end = try XCTUnwrap(source.range(of: "};", range: start.upperBound..<source.endIndex))
        let body = source[start.upperBound..<end.lowerBound]
        let bytes = body.split(separator: ",").compactMap { token -> UInt8? in
            let hex = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard hex.hasPrefix("0x") else { return nil }
            return UInt8(hex.dropFirst(2), radix: 16)
        }
        return Data(bytes.map { $0 ^ 0x5A })
    }

    private func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Encoding changed the generated file and must not have changed what it holds.
    func test_generatedContractDataDecodesToTheRecordedContent() throws {
        RepoLayout.assertResolved()
        let decoded = try decodedBlob(at: generatedContractDataURL, array: "TGRichTextInputDecContractBytes")
        XCTAssertEqual(sha256(of: decoded), try recordedSHA("generated contract data decoded SHA-256"))
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: decoded), "the decoded blob is not JSON")
    }

    /// The engine's pristine blob is the vendored manifest, byte for byte, once decoded.
    func test_thePristineBlobDecodesToThePristineManifest() throws {
        RepoLayout.assertResolved()
        let url = RepoLayout.packageRoot.appendingPathComponent(
            "Sources/RichTextInputDecUpstream/Generated/RichTextInputDecUpstreamPristineManifest.m")
        let decoded = try decodedBlob(at: url, array: "TGRichTextInputDecUpstreamPristineContractBytes")
        XCTAssertEqual(sha256(of: decoded), try recordedSHA("pristine manifest SHA-256"))
    }

    func test_pristineManifestMatchesTheRecordedSHA() throws {
        RepoLayout.assertResolved()
        XCTAssertEqual(try sha256(of: pristineManifestURL),
                       try recordedSHA("pristine manifest SHA-256"),
                       "Vendor/UIKitBehaviorContracts-iOS26.5.json no longer matches the digest "
                       + "VENDOR.md records for it — the audit input must stay exactly upstream's")
    }

    // MARK: - Provenance

    func test_vendorMarkdownRecordsACommitAndAnOSBand() throws {
        RepoLayout.assertResolved()
        let markdown = try String(contentsOf: vendorMarkdownURL)
        // "last revision taken", not "upstream commit": the tree it came from stopped being a
        // repository, and this repo owns the kernel now (2026-09-15). The revision is still
        // recorded — it is what says WHICH InputDec these bytes reproduce — and this suite still
        // demands it be readable in exactly one form.
        XCTAssertTrue(markdown.contains("last revision taken: "), "no source revision recorded")
        XCTAssertTrue(markdown.contains("certified OS band: "), "no certified OS band recorded")
        XCTAssertTrue(markdown.contains("23F73"),
                      "the certified build is the only combination this kernel has run on; "
                      + "record it explicitly")
    }

    /// The generator's commit, and the two other transformed inputs' revisions.
    ///
    /// Without this, a digest mismatch is alarming but not diagnostic — see the class comment.
    /// InputDec had no remote and ~950k untracked files, so "the generator is in the working tree"
    /// was never a durable claim — and it has since lost its `.git` altogether, which makes these
    /// recorded revisions the ONLY surviving record of which toolchain produced these artifacts.
    func test_vendorMarkdownPinsTheToolCommitsThatProducedTheSnapshot() throws {
        RepoLayout.assertResolved()
        let markdown = try String(contentsOf: vendorMarkdownURL)

        XCTAssertEqual(recordedRevision(of: "last revision taken:", in: markdown), Pin.upstream,
                       "VENDOR.md records a different source revision than this suite was reviewed "
                       + "against — these bytes reproduce a different InputDec; re-review them and "
                       + "update Pin.upstream")
        XCTAssertEqual(recordedRevision(of: "Scripts/generate-contract-data.py", in: markdown),
                       Pin.generateContractData,
                       "the CODEGEN moved. The class renames it applies may have moved with it, so "
                       + "Generated/TGRichTextInputDecContractData.m cannot be assumed equivalent "
                       + "even if its digest still matches: re-check the parsed manifest "
                       + "(ContractManifestTests) before updating Pin.generateContractData")
        XCTAssertEqual(recordedRevision(of: "Scripts/carve-host-preflight.sh", in: markdown),
                       Pin.carveHostPreflight,
                       "the host-preflight carver moved — re-check Host/"
                       + "TGRichTextInputDecHostPreflight.m before updating Pin.carveHostPreflight")
        XCTAssertEqual(recordedRevision(of: "PrivateUIKit/IDPrivateUIKit.m", in: markdown),
                       Pin.privateUIKit,
                       "the carve INPUT moved. This decides the host ABI: 3 portable specs at the "
                       + "pinned revision, 11 before it, and the wrong carve compiles and raises "
                       + "only at the first +requireInteractionHost:stage: call")
    }

    // MARK: - The pristine manifest

    /// The PRISTINE copy must be exactly upstream's, renames NOT applied — it is the audit
    /// input, and the codegen's own test re-derives the transform from it. Asserting on the
    /// GENERATED file's text is impossible here and would be vacuous anyway: the payload is a
    /// hex byte array (`0x49, 0x44, …`), so `contains("IDRichTextLayoutController")` is false
    /// whether or not a single rename happened. The parsed-manifest assertions are in
    /// ContractManifestTests (Task A6).
    func test_thePristineManifestStillNamesTheUpstreamClasses() throws {
        RepoLayout.assertResolved()
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: pristineManifestURL))
                as? [String: Any])
        let capabilities = try XCTUnwrap(root["capabilities"] as? [String: Any])
        let incoming = try XCTUnwrap(capabilities["incomingCallbacks"] as? [String: Any])
        let members = try XCTUnwrap(incoming["members"] as? [[String: Any]])
        XCTAssertEqual(members.count, 47)
        // The JSON key is "class". "className" exists only as the parsed ObjC property
        // (IDUIKitRuntimeContract.m:344) — renaming on that key would rewrite nothing.
        XCTAssertTrue(members.allSatisfy { $0["class"] as? String == "IDRichTextLayoutController" },
                      "the pristine manifest must be untransformed")
        XCTAssertNil(members.first?["className"],
                     "if upstream ever renames this key, the codegen's RENAMES walker must follow")
    }

    // MARK: - The caveats VENDOR.md must keep stating

    func test_vendorMarkdownRecordsTheRenameTableAndTheExceptionCaveat() throws {
        RepoLayout.assertResolved()
        let markdown = try String(contentsOf: vendorMarkdownURL)
        XCTAssertTrue(markdown.contains("TGRichTextInputDecLayoutController"))
        XCTAssertTrue(markdown.contains("TGRichTextInputDecCanvasABIWitness"))
        XCTAssertTrue(markdown.contains("referenceOnly` is emptied"),
                      "VENDOR.md must state that referenceOnly is emptied, not deleted")
        XCTAssertTrue(markdown.contains("still raises NSException"),
                      "VENDOR.md must not claim the kernel became exception-free")

        // And the surviving-@throw count must agree with the sites it enumerates. This is NOT a
        // literal restated here: both numbers are read out of VENDOR.md, which is the single
        // authority. The check exists because the two documents that stated this count before it
        // — A3's Step 8 and A4's Step 6 — BOTH said "six" while listing seven, and both listed one
        // site the export deletes while omitting a real survivor. A prose count that nobody
        // recomputes is how that happens.
        let (claimed, enumerated) = survivingThrowCounts(in: markdown)
        XCTAssertEqual(claimed, enumerated,
                       "VENDOR.md claims \(claimed.map(String.init) ?? "no parseable number of") "
                       + "surviving @throw sites but enumerates \(enumerated) — the prose and the "
                       + "list disagree")
        XCTAssertGreaterThan(enumerated, 0,
                             "VENDOR.md enumerates no surviving @throw site; the kernel has not "
                             + "become exception-free, so this is a parse failure, not good news")
    }

    /// `claimed` is the spelled-out number in "**Seven sites survive**"; `enumerated` counts the
    /// line numbers in the bullet list under it.
    ///
    /// The bullets are matched, not the whole section, deliberately: the paragraph below the list
    /// names `IDUIKitInteractionCapability.m:130` — the one lookup the export CONVERTS — and a
    /// section-wide regex would count it as an eighth survivor.
    private func survivingThrowCounts(in markdown: String) -> (claimed: Int?, enumerated: Int) {
        let words = ["zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
                     "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12]
        var claimed: Int?
        if let range = markdown.range(of: #"\*\*(\w+) sites survive\*\*"#, options: .regularExpression) {
            let word = markdown[range]
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: " sites survive", with: "")
                .lowercased()
            claimed = words[word]
        }
        var enumerated = 0
        for line in markdown.split(separator: "\n") where line.hasPrefix("- ID") {
            guard let range = line.range(of: #"\.m:[\d,\s]+"#, options: .regularExpression) else { continue }
            enumerated += line[range]
                .dropFirst(3)                        // ".m:"
                .split(whereSeparator: { !$0.isNumber })
                .count
        }
        return (claimed, enumerated)
    }
}
