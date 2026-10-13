import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

final class InstantPageV2CodeBandTests: XCTestCase {
    /// Top level in a bubble: the page inset is 9pt and the bleed gives all 9 back on each side, so
    /// the band runs the full width while the text still lands at the paragraph inset.
    func testTopLevelBandSpansFullWidth() {
        let frame = instantPageV2CodeBandFrame(
            boundingWidth: 320.0, horizontalInset: 9.0,
            bleed: InstantPageV2ChildBleed(minXSide: 9.0, maxXSide: 9.0), height: 40.0)

        XCTAssertEqual(frame.minX, 0.0, accuracy: 0.01)
        XCTAssertEqual(frame.maxX, 320.0, accuracy: 0.01)
        XCTAssertEqual(frame.height, 40.0, accuracy: 0.01)
    }

    /// Inside a block quote the children lay out flush against their own band (`horizontalInset` 0),
    /// so the bleed is the whole distance to the quote's interior — asymmetric, because a quote
    /// reserves a wide trailing gutter for its icon and chevron.
    func testNestedBandBleedsToContainerInterior() {
        let frame = instantPageV2CodeBandFrame(
            boundingWidth: 257.0, horizontalInset: 0.0,
            bleed: InstantPageV2ChildBleed(minXSide: 6.0, maxXSide: 36.0), height: 20.0)

        XCTAssertEqual(frame.minX, -6.0, accuracy: 0.01)
        XCTAssertEqual(frame.maxX, 293.0, accuracy: 0.01)
    }

    /// No bleed declared ⇒ the band is exactly the content column, i.e. today's geometry. This is the
    /// fallback every container that has not opted in gets, so it must be the conservative one.
    func testNoBleedLeavesTheContentColumn() {
        let frame = instantPageV2CodeBandFrame(
            boundingWidth: 320.0, horizontalInset: 9.0,
            bleed: .none, height: 10.0)

        XCTAssertEqual(frame.minX, 9.0, accuracy: 0.01)
        XCTAssertEqual(frame.maxX, 311.0, accuracy: 0.01)
    }

    /// A code band contributes its INNER text, not its own frame: the frame is the container's width
    /// by construction, so it would pin every message containing code to the full bubble width.
    func testCodeBandContributesItsTextNotItsFrame() {
        let band = makeCodeItem(frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 40.0))
        // makeCodeItem's text item is block-local [9, 109] inside a band at x = 0.
        XCTAssertEqual(instantPageV2FitWidthMaxX(band), 109.0, accuracy: 0.01)
    }

    /// The band's own frame is offset into the contribution, because the nested frames are
    /// block-local — a band that is not at x = 0 would otherwise under-report its text's reach.
    func testCodeBandContributionIsOffsetByTheBandOrigin() {
        let band = makeCodeItem(frame: CGRect(x: 12.0, y: 0.0, width: 200.0, height: 40.0))
        XCTAssertEqual(instantPageV2FitWidthMaxX(band), 121.0, accuracy: 0.01)
    }

    /// A language line wider than the code drives the width instead.
    func testCodeBandContributionTakesTheWiderOfTextAndLanguage() {
        let band = makeCodeItem(frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 40.0),
                                languageWidth: 200.0)
        XCTAssertEqual(instantPageV2FitWidthMaxX(band), 209.0, accuracy: 0.01)
    }

    /// Everything else contributes its own frame, unchanged.
    func testOtherItemsContributeTheirOwnFrame() {
        let divider = InstantPageV2LaidOutItem.divider(
            InstantPageV2DividerItem(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 1.0), color: .gray))
        XCTAssertEqual(instantPageV2FitWidthMaxX(divider), 100.0, accuracy: 0.01)
    }

    /// After the shrink, the band is re-widened to the surviving content width — so a short code
    /// message keeps a narrow bubble AND a band that still reaches its edges.
    func testStretchWidensBandToFinalContentWidth() {
        var items: [InstantPageV2LaidOutItem] = [
            makeCodeItem(frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 40.0))
        ]
        instantPageV2StretchCodeBands(in: &items, contentWidth: 180.0)

        XCTAssertEqual(items[0].frame.minX, 0.0, accuracy: 0.01)
        XCTAssertEqual(items[0].frame.width, 180.0, accuracy: 0.01)
    }

    /// The stretch moves the trailing edge only. The leading edge carries the bleed, and the code
    /// text's block-local x is measured from it — moving it would drag the text off the paragraph
    /// inset.
    func testStretchNeverMovesTheLeadingEdge() {
        var items: [InstantPageV2LaidOutItem] = [
            makeCodeItem(frame: CGRect(x: 12.0, y: 0.0, width: 200.0, height: 40.0))
        ]
        instantPageV2StretchCodeBands(in: &items, contentWidth: 180.0)

        XCTAssertEqual(items[0].frame.minX, 12.0, accuracy: 0.01)
        XCTAssertEqual(items[0].frame.maxX, 180.0, accuracy: 0.01)
    }

    /// A band already narrower than the final width is widened, not left alone: the shrink is the
    /// only thing that decides the final width, and the band always spans it.
    func testStretchWidensANarrowBand() {
        var items: [InstantPageV2LaidOutItem] = [
            makeCodeItem(frame: CGRect(x: 0.0, y: 0.0, width: 50.0, height: 40.0))
        ]
        instantPageV2StretchCodeBands(in: &items, contentWidth: 180.0)

        XCTAssertEqual(items[0].frame.width, 180.0, accuracy: 0.01)
    }

    /// The label is lowercased at layout time, not by the view — so a copy/paste of the model's
    /// "Swift" and a server's "SWIFT" render identically.
    func testLanguageDisplayTextIsLowercased() {
        XCTAssertEqual(instantPageV2CodeLanguageDisplayText("Swift"), "swift")
        XCTAssertEqual(instantPageV2CodeLanguageDisplayText("SWIFT"), "swift")
    }

    /// No language, and an empty-string language, both mean "no line" — the empty case reached the
    /// old view as a zero-size label rather than as nothing.
    func testLanguageDisplayTextIsNilWhenAbsentOrEmpty() {
        XCTAssertNil(instantPageV2CodeLanguageDisplayText(nil))
        XCTAssertNil(instantPageV2CodeLanguageDisplayText(""))
    }

    /// End-to-end on the two helpers as `layoutBlockSequence` composes them: a short paragraph plus a
    /// full-width code band must shrink to the paragraph's width, and the band must then span exactly
    /// that. Composing them here (rather than calling the private sequence function, which needs a
    /// `PresentationStrings` the test bundle cannot build) pins the ORDER, which is the part that goes
    /// wrong: stretching before the shrink re-inflates the page.
    func testShortCodeMessageKeepsANarrowContentWidthAndAFullBand() {
        let boundingWidth: CGFloat = 320.0
        let horizontalInset: CGFloat = 9.0
        var items: [InstantPageV2LaidOutItem] = [
            .divider(InstantPageV2DividerItem(   // stands in for a short paragraph: maxX 100
                frame: CGRect(x: horizontalInset, y: 0.0, width: 91.0, height: 1.0), color: .gray)),
            makeCodeItem(frame: CGRect(x: 0.0, y: 10.0, width: boundingWidth, height: 40.0))
        ]

        var maxX: CGFloat = 0.0
        for item in items {
            maxX = max(maxX, ceil(instantPageV2FitWidthMaxX(item)) + horizontalInset)
        }
        let contentWidth = min(maxX, boundingWidth)
        instantPageV2StretchCodeBands(in: &items, contentWidth: contentWidth)

        // The code TEXT (block-local maxX 109) is wider than the paragraph (100), so it decides the
        // width — 109 + the 9pt right margin. The band's own 320pt frame never enters it.
        XCTAssertEqual(contentWidth, 118.0, accuracy: 0.01, "the band's frame must not drive the shrink")
        XCTAssertEqual(items[1].frame.width, 118.0, accuracy: 0.01, "the band spans the surviving width")
    }

    /// THE REGRESSION (reported on device, 2026-08-18): a message whose widest content is its code
    /// must get a bubble wide enough for that code. Excluding the band from the shrink WITHOUT
    /// reaching into it dropped the code text's contribution entirely — the bubble sized itself to
    /// the other blocks, the band was then stretched down to that narrower width, and the code text,
    /// laid out against the full available width, was clipped at the bubble's edge.
    func testBubbleIsWideEnoughForCodeWiderThanEveryOtherBlock() {
        let boundingWidth: CGFloat = 320.0
        let horizontalInset: CGFloat = 9.0
        var items: [InstantPageV2LaidOutItem] = [
            .divider(InstantPageV2DividerItem(   // a short paragraph: absolute maxX 60
                frame: CGRect(x: horizontalInset, y: 0.0, width: 51.0, height: 1.0), color: .gray)),
            makeCodeItem(frame: CGRect(x: 0.0, y: 10.0, width: boundingWidth, height: 40.0),
                         textWidth: 260.0)      // code text block-local maxX 269 — the widest content
        ]

        var maxX: CGFloat = 0.0
        for item in items {
            maxX = max(maxX, ceil(instantPageV2FitWidthMaxX(item)) + horizontalInset)
        }
        let contentWidth = min(maxX, boundingWidth)
        instantPageV2StretchCodeBands(in: &items, contentWidth: contentWidth)

        guard case let .codeBlock(band) = items[1] else { return XCTFail("expected a code band") }
        let textRightEdge = band.frame.minX + band.textItem.frame.maxX
        XCTAssertGreaterThanOrEqual(contentWidth, textRightEdge,
                                    "the bubble must be at least as wide as the code text it contains")
        XCTAssertGreaterThanOrEqual(band.frame.maxX, textRightEdge,
                                    "the band must cover its own text")
    }

    // MARK: - Helpers

    private func makeCodeItem(frame: CGRect, textWidth: CGFloat = 100.0,
                              languageWidth: CGFloat? = nil) -> InstantPageV2LaidOutItem {
        // `InstantPageTextItem`'s only initialiser (internal — reached via @testable) is
        // init(frame:attributedString:alignment:opaqueBackground:lines:). Nothing here reads the
        // string or the lines; the tests are about the BAND's frame.
        let textItem = InstantPageTextItem(
            frame: CGRect(x: 9.0, y: 6.0, width: textWidth, height: 20.0),
            attributedString: NSAttributedString(string: "x"),
            alignment: .natural,
            opaqueBackground: true,
            lines: [])
        let languageItem = languageWidth.map { width in
            InstantPageTextItem(
                frame: CGRect(x: 9.0, y: 0.0, width: width, height: 18.0),
                attributedString: NSAttributedString(string: "swift"),
                alignment: .natural,
                opaqueBackground: false,
                lines: [])
        }
        return .codeBlock(InstantPageV2CodeBlockItem(
            frame: frame,
            backgroundColor: .gray,
            language: languageWidth == nil ? nil : "swift",
            languageItem: languageItem,
            textItem: textItem,
            inset: UIEdgeInsets(top: 6.0, left: 9.0, bottom: 6.0, right: 9.0)))
    }
}
