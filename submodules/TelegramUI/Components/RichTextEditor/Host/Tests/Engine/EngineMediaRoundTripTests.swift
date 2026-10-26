import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-media: a media block is an attachment atom plus, for captioned kinds, a caption line.
@available(iOS 18.4, *)
final class EngineMediaRoundTripTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        // The document look's default bleed (16) would move every geometry assertion below off the
        // composer's 0 they assume; matches how a real compact host configures the editor.
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    func item(_ id: String, kind: MediaKind = .image, w: Double = 1000, h: Double = 500, spoiler: Bool = false) -> MediaItem {
        MediaItem(mediaID: id, kind: kind, naturalSize: Size2D(width: w, height: h), isSpoiler: spoiler)
    }
    func photo(_ id: String, caption: [TextRun] = []) -> Block {
        .media(MediaBlock(id: BlockID(id), items: [item("m-\(id)")], caption: caption))
    }
    func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    func kinds() -> [String] {
        editor.currentRoles.map { role in
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            switch role.shape { case .media: return "media"; case .buttonRow: return "buttonRow"; case .code: return "code"; case .pullQuote: return "pullQuote"; case .collapsedQuote: return "collapsedQuote"; case .paragraph: return "std" }
        }
    }

    // MARK: - Roles (no engine)

    func test_aMediaShapeDropsTheCaptionAndKeepsEverythingElse() {
        let block = MediaBlock(id: BlockID("a"), items: [item("x", spoiler: true)], displayWidth: 120,
                               alignment: .left, displayMode: .slideshow, caption: [TextRun(text: "cap")])
        let shape = MediaShape(block)
        XCTAssertEqual(shape.block(caption: []), MediaBlock(id: BlockID("a"), items: [item("x", spoiler: true)],
                                                            displayWidth: 120, alignment: .left, displayMode: .slideshow, caption: []))
        XCTAssertEqual(MediaShape.captionLineID(for: BlockID("a")), BlockID("a#caption"))
        XCTAssertFalse(shape.isCaptionless)
        XCTAssertTrue(MediaShape(MediaBlock(id: BlockID("b"), items: [item("y", kind: .audio)])).isCaptionless)
    }

    func test_theCaptionLineMergesItsRunsBackIntoTheMedia() {
        let shape = MediaShape(MediaBlock(id: BlockID("a"), items: [item("x")]))
        var bold = CharacterAttributes(); bold.bold = true
        let roles: [EngineBlockRole] = [
            .standalone(.media(shape), within: []),
            .secondary(owner: .block(.media(shape)), line: shape.captionLineID, kind: .mediaCaption, within: []),
        ]
        let blocks: [Block] = [
            .media(shape.block(caption: [])),
            .paragraph(ParagraphBlock(id: shape.captionLineID, runs: [TextRun(text: "plain "), TextRun(text: "bold", attributes: bold)])),
        ]
        let document = EngineBlockRole.document(roles: roles, blocks: blocks)
        guard document.blocks.count == 1, case let .media(media) = document.blocks[0] else { return XCTFail("\(document.blocks)") }
        XCTAssertEqual(media.caption.map(\.text), ["plain ", "bold"])
        XCTAssertEqual(media.caption[1].attributes.bold, true, "the caption keeps its runs, unlike an author line")
    }

    // MARK: - Round trip

    func test_aCaptionedPhotoIsAnAtomAndACaptionLine() {
        editor.document = Document(blocks: [para("p0", "before"), photo("a", caption: [TextRun(text: "cap")]), para("p1", "after")])
        XCTAssertEqual(strings(), ["before", "\u{FFFC}", "cap", "after"])
        XCTAssertEqual(kinds(), ["std", "media", "secondary.mediaCaption", "std"])
        XCTAssertTrue(editor.engine.attributedBlocks[1].attribute(.attachment, at: 0, effectiveRange: nil) is MediaTextAttachment)
        let back = editor.document.blocks
        XCTAssertEqual(back.count, 3)
        guard case let .media(media) = back[1] else { return XCTFail("\(back)") }
        XCTAssertEqual(media.id, BlockID("a"))
        XCTAssertEqual(media.caption.map(\.text).joined(), "cap")
        XCTAssertEqual(media.items.map(\.mediaID), ["m-a"])
    }

    func test_theCaptionKeepsBoldLinkAndCustomEmoji() {
        var bold = CharacterAttributes(); bold.bold = true
        var link = CharacterAttributes(); link.link = "https://t.me"
        var emoji = CharacterAttributes(); emoji.emoji = EmojiRef(id: "5202", instanceID: "i1")
        editor.document = Document(blocks: [photo("a", caption: [
            TextRun(text: "b", attributes: bold), TextRun(text: "l", attributes: link), TextRun(text: "\u{FFFC}", attributes: emoji)])])
        guard case let .media(media) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(media.caption.map(\.text), ["b", "l", "\u{FFFC}"])
        XCTAssertEqual(media.caption[0].attributes.bold, true)
        XCTAssertEqual(media.caption[1].attributes.link, "https://t.me")
        XCTAssertEqual(media.caption[2].attributes.emoji?.id, "5202")
        XCTAssertNil(media.caption[0].attributes.fontSize, "the caption size is the style's, never pinned into the model")
        XCTAssertNil(media.caption[0].attributes.foreground, "the secondary text colour is the theme's, never the model's")
    }

    func test_theFiveKindsRoundTrip() {
        let blocks: [Block] = [
            .media(MediaBlock(id: BlockID("i"), items: [item("mi")])),
            .media(MediaBlock(id: BlockID("v"), items: [item("mv", kind: .video)])),
            .media(MediaBlock(id: BlockID("l"), items: [item("ml", kind: .location, w: 600, h: 300)])),
            .media(MediaBlock(id: BlockID("a"), items: [item("ma", kind: .audio, w: 0, h: 0)])),
            .media(MediaBlock(id: BlockID("d"), items: [item("md", kind: .document, w: 0, h: 0)])),
        ]
        editor.document = Document(blocks: blocks)
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "media", "secondary.mediaCaption",
                                 "media", "secondary.mediaCaption", "media", "media"],
                       "image, video and location carry a caption line; audio and document never do")
        XCTAssertEqual(editor.document.blocks, blocks)
    }

    func test_anAlbumRoundTripsInBothModesWithSpoilers() {
        for mode in [MediaDisplayMode.mosaic, .slideshow] {
            let album = MediaBlock(id: BlockID("al"), items: [item("1", spoiler: true), item("2"), item("3", kind: .video)],
                                   displayMode: mode, caption: [TextRun(text: "three")])
            editor.document = Document(blocks: [.media(album)])
            XCTAssertEqual(editor.document.blocks, [.media(album)], "\(mode)")
            XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption"], "\(mode)")
        }
    }

    /// Superseded by the R7-nesting rung (`EngineDocumentBridge.flatten`): a media block inside a
    /// quote no longer traps — it round-trips like any other child kind. Full coverage of every
    /// child kind at depth lives in `EngineNestedQuoteRoundTripTests`; this pins the media-specific
    /// shape (atom + caption line) survives being nested.
    func test_aMediaInsideAQuoteRoundTrips() {
        let quote = Block.blockQuote(BlockQuote(id: BlockID("q"), children: [photo("ph", caption: [TextRun(text: "cap")])]))
        editor.document = Document(blocks: [quote])
        XCTAssertEqual(editor.document.blocks, [quote])
        XCTAssertEqual(kinds(), ["media", "secondary.mediaCaption", "secondary.blockQuoteAuthor"])
    }

    // MARK: - Identity across sets

    func test_theCaptionsEngineIdentitySurvivesASetThatChangesAnotherBlock() {
        editor.document = Document(blocks: [para("p0", "before"), photo("a", caption: [TextRun(text: "cap")])])
        let before = editor.engine.tgid_blockIdentifiers
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // "before\n\u{FFFC}\ncap" → inside "cap"
        editor.document = Document(blocks: [para("p0", "BEFORE"), photo("a", caption: [TextRun(text: "cap")])])
        let after = editor.engine.tgid_blockIdentifiers
        XCTAssertEqual(before[1], after[1], "the atom is outside the differing span")
        XCTAssertEqual(before[2], after[2], "so is the caption")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 11, length: 0), "and the caret in it did not move")
    }

    // MARK: - The composer's axis

    func test_theWholeUnitIsOffTheComposerAxis() {
        editor.document = Document(blocks: [para("p0", "before"), photo("a", caption: [TextRun(text: "cap")]), para("p1", "after")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // engine: before 0..6 | FFFC 7 | cap 9..12 | after 13..18 — composer: before 0..6 | after 7..12
        editor.engineSelectedRange = NSRange(location: 15, length: 0)   // "af|ter"
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 9, length: 0))
        editor.engineSelectedRange = NSRange(location: 10, length: 0)   // inside the caption
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 12, length: 0), "off-axis reads as the end of the flat text")
    }

    // MARK: - Geometry (probes P1 and P3)

    func test_theAttachmentReservesTheSlotAtTheLineWidthAndFollowsAWidthChange() {
        editor.document = Document(blocks: [photo("a")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let inset = editor.engine.textContainerInset
        let lineWidth = 320 - inset.left - inset.right
        let frame = editor.engine.id_attachmentFrame(forCanonicalOffset: 0)
        XCTAssertEqual(frame.width, lineWidth, accuracy: 1)
        XCTAssertEqual(frame.height, lineWidth / 2, accuracy: 1, "a 1000×500 image at the line width")
        editor.frame = CGRect(x: 0, y: 0, width: 240, height: 480)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let narrower = editor.engine.id_attachmentFrame(forCanonicalOffset: 0)
        XCTAssertEqual(narrower.width, 240 - inset.left - inset.right, accuracy: 1)
        XCTAssertEqual(narrower.height, (240 - inset.left - inset.right) / 2, accuracy: 1, "TextKit re-asked attachmentBounds at the new width")
    }

    func test_theAtomsLineIsNoTallerThanItsAttachment() {
        editor.document = Document(blocks: [photo("a")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let attachment = editor.engine.id_attachmentFrame(forCanonicalOffset: 0)
        let block = editor.engine.id_frameForBlock(at: 0)
        // The block frame carries the unit's 8pt top interior; anything beyond that is stray descent (P3).
        // Whether `id_frameForBlock(at:)` includes the reserved `blockInsets` is not known, so this is
        // relaxed rather than pinned to the exact 8pt (controller ruling 3).
        XCTAssertLessThanOrEqual(block.height - attachment.height, MediaSlotGeometry.verticalInset + 2)
    }

    func test_aTallPortraitIsCappedAndLaidOutOnItsOwnLine() {
        editor.document = Document(blocks: [.media(MediaBlock(id: BlockID("t"), items: [item("mt", w: 500, h: 4000)]))])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let inset = editor.engine.textContainerInset
        let lineWidth = 320 - inset.left - inset.right
        let frame = editor.engine.id_attachmentFrame(forCanonicalOffset: 0)
        XCTAssertEqual(frame.height, min(1000, lineWidth), accuracy: 1, "capped at min(1000, width)")
        // Relaxed to a bounded gap rather than an exact `minY == maxY`, for the same reason as above
        // (controller ruling 3).
        let gap = editor.engine.id_frameForBlock(at: 1).minY - editor.engine.id_frameForBlock(at: 0).maxY
        XCTAssertGreaterThanOrEqual(gap, -1)
        XCTAssertLessThanOrEqual(gap, MediaSlotGeometry.captionGap + 1)
    }

    // MARK: - Rhythm

    func test_theUnitReservesLegacysInteriorPadding() {
        editor.document = Document(blocks: [para("p0", "before"), photo("a", caption: [TextRun(text: "cap")]), para("p1", "after")])
        let insets = EngineBlockSpacing.blockLayout(for: editor.currentRoles, styleSheet: editor.bridge.styleSheet,
                                                     quoteStyle: .default, pullQuoteStyle: .default,
                                                     lineAttributes: editor.spacingLineAttributes()).insets
        let gapAbove = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .media(hasCredit: false, isRawMedia: true),
                                                    kind: .topLevel, metrics: editor.bridge.styleSheet.metrics)
        // Less the paragraph above's trailing overhang, which the rhythm gives back (2026-09-15).
        XCTAssertEqual(insets[1].top,
                       gapAbove + MediaSlotGeometry.verticalInset - editor.trailingLineBoxOverhang(atRole: 0),
                       accuracy: 0.01)
        // The CAPTION is 15pt text, so the lift takes its 0.0996 drop out of its top inset and
        // returns it below — the pair is net zero, so the unit reserves exactly what it did, and the
        // caption's glyphs now sit where the renderer puts them (2026-09-16).
        let captionDrop = editor.v2BaselineDrop(atRole: 2)
        XCTAssertEqual(insets[2].top, MediaSlotGeometry.captionGap - captionDrop, accuracy: 0.01)
        XCTAssertEqual(insets[2].bottom, MediaSlotGeometry.verticalInset + captionDrop, accuracy: 0.01)
        XCTAssertEqual(insets[2].top + insets[2].bottom,
                       MediaSlotGeometry.captionGap + MediaSlotGeometry.verticalInset, accuracy: 0.01,
                       "the lift must not change what the unit reserves")
    }
}
