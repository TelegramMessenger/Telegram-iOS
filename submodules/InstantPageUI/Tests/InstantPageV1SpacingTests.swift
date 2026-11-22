import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

/// The Instant View reader (V1) and the rich-message renderer (V2) are two typographic designs, and
/// `InstantPageLayout.swift` must keep using V1's. The two tables were briefly merged, which pulled
/// the reader's rhythm onto the chat bubble's much tighter scale.
///
/// These pin the V1 table's own numbers — deliberately as literals, so a change to the V2 metrics can
/// never move them, and so a future "unify these" refactor fails here rather than on screen.
final class InstantPageV1SpacingTests: XCTestCase {
    private let paragraph = InstantPageBlock.paragraph(.plain("x"))
    private let header = InstantPageBlock.header(.plain("x"))
    private let subheader = InstantPageBlock.subheader(.plain("x"))
    private let list = InstantPageBlock.list(items: [], ordered: false)
    private let preformatted = InstantPageBlock.preformatted(text: .plain("x"), language: nil)
    private let divider = InstantPageBlock.divider
    private let blockQuote = InstantPageBlock.blockQuote(blocks: [], caption: .empty, collapsed: false)
    private let title = InstantPageBlock.title(.plain("x"))
    private let cover = InstantPageBlock.cover(.divider)
    private let anchor = InstantPageBlock.anchor("a")

    func test_pairwiseTable_isTheReadersOwn() {
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.paragraph), 25.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.header, lower: self.paragraph), 25.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.subheader, lower: self.paragraph), 25.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.list, lower: self.paragraph), 31.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.preformatted, lower: self.paragraph), 19.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.header), 32.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.subheader), 32.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.list), 25.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.preformatted), 19.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.title, lower: self.paragraph), 34.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.divider, lower: self.paragraph), 25.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.blockQuote), 27.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.title), 20.0)
    }

    func test_zeroAndEdgeCases_areTheReadersOwn() {
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.cover), 0.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.anchor), 0.0)
        // Leading / trailing edges.
        XCTAssertEqual(spacingBetweenBlocksV1(upper: nil, lower: self.paragraph), 25.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: nil, lower: self.cover), 0.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: nil, lower: self.anchor), 0.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: nil), 25.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: .relatedArticles(title: .empty, articles: []), lower: nil), 0.0)
        XCTAssertEqual(spacingBetweenBlocksV1(upper: nil, lower: nil), 25.0)
    }

    /// The two functions must genuinely differ — if a refactor ever made V1 forward to V2 this would
    /// still compile and still look plausible, so assert the divergence itself.
    func test_v1AndV2AreDistinct() {
        let v2 = spacingBetweenBlocks(upper: self.paragraph, lower: self.paragraph,
                                      kind: .topLevel, metrics: .unscaled)
        XCTAssertEqual(v2, 1.0, "V2 holds two body paragraphs 1pt apart")
        XCTAssertNotEqual(spacingBetweenBlocksV1(upper: self.paragraph, lower: self.paragraph), v2)
    }
}
