import XCTest
import UIKit
import TelegramCore
import UnsupportedContentPill
@testable import InstantPageUI

private let testStrings = UnsupportedContentPillStrings(
    title: "Unsupported message",
    text: "Please update Telegram to view this message.",
    action: "Update"
)

private let testColors = UnsupportedContentPillColors(
    fill: UIColor(white: 0.0, alpha: 0.1),
    primaryText: .white,
    isDark: true
)

/// A real pill item (so its height is the component's real height), moved to `y`.
private func makeUnsupportedItem(y: CGFloat, isTopLevel: Bool = true) -> InstantPageV2LaidOutItem {
    let items = layoutUnsupportedBlock(boundingWidth: 320.0, horizontalInset: 17.0, strings: testStrings, colors: testColors, isTopLevel: isTopLevel)
    guard case var .unsupportedContent(item) = items[0] else {
        preconditionFailure("layoutUnsupportedBlock did not produce an .unsupportedContent item")
    }
    item.frame.origin.y = y
    return .unsupportedContent(item)
}

private func makeLayout(_ items: [InstantPageV2LaidOutItem]) -> InstantPageV2Layout {
    return InstantPageV2Layout(contentSize: CGSize(width: 320.0, height: 500.0), items: items, detailsIndices: [])
}

/// Mirrors the padding local to `unsupportedContentTearZones`. Duplicated rather than shared because
/// the value is private to that function; if it changes there, these tests fail loudly and this
/// line is the fix.
private let expectedTearPadding: CGFloat = 6.0

/// A resolvable-looking image block. Only its *case* matters to the predicate under test — the
/// media id is never dereferenced here.
private func makeImageBlock() -> InstantPageBlock {
    return .image(
        id: EngineMedia.Id(namespace: 0, id: 1),
        caption: InstantPageCaption(text: .empty, credit: .empty),
        url: nil,
        webpageId: nil,
        spoiler: false
    )
}

final class InstantPageV2UnsupportedBlockTests: XCTestCase {
    /// A page from a newer server can contain a whole run of blocks this build cannot decode. One
    /// "update your app" card is the message; five stacked copies is noise. The helper reports
    /// which indices to SKIP rather than returning a filtered array — filtering would renumber the
    /// blocks that `pathPrefix + [i]` turns into structural paths.
    func testAdjacentUnsupportedBlocksCollapseToOne() {
        let blocks: [InstantPageBlock] = [.paragraph(.plain("a")), .unsupported, .unsupported, .unsupported, .paragraph(.plain("b"))]

        XCTAssertEqual(redundantUnsupportedBlockIndices(blocks), Set([2, 3]))
    }

    /// Separated runs are separate cards: the pill marks a position in the document, so two holes
    /// in different places must stay two.
    func testSeparatedRunsAreKept() {
        let blocks: [InstantPageBlock] = [.unsupported, .paragraph(.plain("a")), .unsupported, .unsupported]

        XCTAssertEqual(redundantUnsupportedBlockIndices(blocks), Set([3]))
    }

    /// Sequences with nothing to collapse report nothing (the helper runs on every nested sequence
    /// — details bodies, table cells — so it must be a no-op in the common case).
    func testSequencesWithoutRunsReportNothing() {
        XCTAssertTrue(redundantUnsupportedBlockIndices([]).isEmpty)
        XCTAssertTrue(redundantUnsupportedBlockIndices([.unsupported]).isEmpty)

        let mixed: [InstantPageBlock] = [.paragraph(.plain("a")), .divider, .unsupported, .paragraph(.plain("b"))]
        XCTAssertTrue(redundantUnsupportedBlockIndices(mixed).isEmpty)
    }

    /// The pill is a rounded card, so it is laid out inside the page's horizontal insets like a
    /// paragraph — not flush to the page edge like a document row — and it stretches to fill them.
    func testPillIsLaidOutInsideThePageInsets() {
        let items = layoutUnsupportedBlock(boundingWidth: 320.0, horizontalInset: 17.0, strings: testStrings, colors: testColors, isTopLevel: true)

        XCTAssertEqual(items.count, 1)
        guard case let .unsupportedContent(item) = items[0] else {
            return XCTFail("expected an .unsupportedContent item, got \(items[0])")
        }
        XCTAssertEqual(item.frame.minX, 17.0)
        XCTAssertEqual(item.frame.width, 320.0 - 17.0 * 2.0)
        XCTAssertEqual(item.frame.minY, 0.0)
    }

    /// The block layout and the component must agree on height, or the page reserves the wrong
    /// amount of space and the pill is clipped or floats.
    func testPillHeightMatchesTheComponent() {
        let contentWidth = 320.0 - 17.0 * 2.0
        let expected = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: contentWidth)
        let items = layoutUnsupportedBlock(boundingWidth: 320.0, horizontalInset: 17.0, strings: testStrings, colors: testColors, isTopLevel: true)

        guard case let .unsupportedContent(item) = items[0] else {
            return XCTFail("expected an .unsupportedContent item, got \(items[0])")
        }
        XCTAssertEqual(item.frame.height, expected.size.height)
        XCTAssertEqual(item.layout, expected)
    }

    /// The host tears a band out of its background across each pill. The band is the pill's own
    /// box plus breathing room, or the bubble's cut edges would touch the pill.
    func testTearZoneIsThePillPlusPadding() {
        let item = makeUnsupportedItem(y: 40.0)
        guard case let .unsupportedContent(pill) = item else {
            return XCTFail("expected an .unsupportedContent item")
        }

        let zones = unsupportedContentTearZones(in: makeLayout([item]))

        XCTAssertEqual(zones.count, 1)
        XCTAssertEqual(zones[0].minY, 40.0 - expectedTearPadding)
        XCTAssertEqual(zones[0].maxY, 40.0 + pill.frame.height + expectedTearPadding)
        // Horizontal extent is left alone: the host is what decides how wide a tear is, because
        // only the host knows how wide its background is.
        XCTAssertEqual(zones[0].minX, pill.frame.minX)
        XCTAssertEqual(zones[0].width, pill.frame.width)
    }

    /// Two runs separated by supported content are two pills, so two separate zones, in order.
    func testEachTopLevelPillProducesItsOwnZone() {
        let zones = unsupportedContentTearZones(in: makeLayout([
            makeUnsupportedItem(y: 40.0),
            makeUnsupportedItem(y: 300.0)
        ]))

        XCTAssertEqual(zones.count, 2)
        XCTAssertLessThan(zones[0].minY, zones[1].minY)
    }

    /// Top level only. A pill nested inside a table (or a <details> body, or a blockquote) is not
    /// full-width relative to the host's background, so a band across it would cut a stripe through
    /// unrelated content.
    func testNestedPillsProduceNoZone() {
        let inner = InstantPageV2Layout(
            contentSize: CGSize(width: 200.0, height: 100.0),
            items: [makeUnsupportedItem(y: 0.0)],
            detailsIndices: []
        )
        let table = InstantPageV2TableItem(
            frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 120.0),
            titleSubLayout: inner,
            titleFrame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 100.0),
            contentSize: CGSize(width: 320.0, height: 20.0),
            contentInset: 17.0,
            cells: [],
            horizontalLines: [],
            verticalLines: [],
            bordered: false,
            striped: false,
            borderColor: .clear
        )

        XCTAssertTrue(unsupportedContentTearZones(in: makeLayout([.table(table)])).isEmpty)
    }

    /// The case not recursing does NOT catch, and the reason `isTopLevel` is carried on the item at
    /// all: a blockquote lays its children out with `layoutBlock` and appends the results straight
    /// into its parent's item array, offset. So a quoted pill sits in `layout.items` looking exactly
    /// like a top-level one, and only the flag tells them apart.
    func testASplicedNestedPillProducesNoZone() {
        let zones = unsupportedContentTearZones(in: makeLayout([
            makeUnsupportedItem(y: 40.0, isTopLevel: false)
        ]))

        XCTAssertTrue(zones.isEmpty)
    }

    /// And a page holding both still tears across the top-level one.
    func testASplicedNestedPillDoesNotSuppressATopLevelOne() {
        let zones = unsupportedContentTearZones(in: makeLayout([
            makeUnsupportedItem(y: 40.0, isTopLevel: false),
            makeUnsupportedItem(y: 300.0, isTopLevel: true)
        ]))

        XCTAssertEqual(zones.count, 1)
        XCTAssertEqual(zones[0].minY, 300.0 - expectedTearPadding)
    }

    /// The overwhelmingly common case: an ordinary page tears nothing.
    func testPagesWithoutUnsupportedBlocksProduceNoZones() {
        XCTAssertTrue(unsupportedContentTearZones(in: makeLayout([])).isEmpty)
    }

    // MARK: - Tap arbitration

    /// The pill's Update button is a `UIButton` living inside the page view, but the chat bubble
    /// arbitrates every touch over its content: unless `tapActionAtPoint` reports that the point
    /// belongs to something interactive, the bubble's tap recognizer claims the touch and cancels
    /// the button's tracking, so `touchUpInside` never fires. The bubble resolves that from the
    /// LAYOUT — it has no pill view to ask mid-touch — so the region has to be derivable here.
    func testTheActionRegionIsFoundOnATopLevelPill() {
        let item = makeUnsupportedItem(y: 40.0)
        guard case let .unsupportedContent(pill) = item else {
            return XCTFail("expected an .unsupportedContent item")
        }
        let layout = makeLayout([item])
        let expected = pill.layout.actionFrame(in: pill.frame.size).offsetBy(dx: pill.frame.minX, dy: pill.frame.minY)

        XCTAssertEqual(unsupportedActionFrame(in: layout, containing: CGPoint(x: expected.midX, y: expected.midY)), expected)
    }

    /// Only the button, not the whole card: the rest of the pill is ordinary bubble content, and
    /// claiming it would kill the message's own tap and long-press.
    func testTheRestOfThePillIsNotPartOfTheActionRegion() {
        let item = makeUnsupportedItem(y: 40.0)
        guard case let .unsupportedContent(pill) = item else {
            return XCTFail("expected an .unsupportedContent item")
        }
        let layout = makeLayout([item])

        // The badge, at the leading inset.
        XCTAssertNil(unsupportedActionFrame(in: layout, containing: CGPoint(x: pill.frame.minX + 20.0, y: pill.frame.midY)))
        // Just above the pill.
        XCTAssertNil(unsupportedActionFrame(in: layout, containing: CGPoint(x: pill.frame.maxX - 30.0, y: pill.frame.minY - 4.0)))
    }

    /// A page with no pill at all reports nothing — this runs on every touch over every rich
    /// message, so the common case must be a clean miss.
    func testPagesWithoutPillsHaveNoActionRegion() {
        XCTAssertNil(unsupportedActionFrame(in: makeLayout([]), containing: CGPoint(x: 10.0, y: 10.0)))
    }

    /// Unlike the tear zones — which are top-level only, because only a full-width pill may cut a
    /// band through the bubble's background — tap arbitration must reach nested pills too: a pill
    /// inside a `<details>` body or a table cell has exactly the same dead button without it.
    func testTheActionRegionIsFoundOnAPillNestedInATableCell() {
        let inner = InstantPageV2Layout(
            contentSize: CGSize(width: 200.0, height: 100.0),
            items: [makeUnsupportedItem(y: 0.0, isTopLevel: false)],
            detailsIndices: []
        )
        guard case let .unsupportedContent(pill) = inner.items[0] else {
            return XCTFail("expected an .unsupportedContent item")
        }
        let cellFrame = CGRect(x: 0.0, y: 10.0, width: 300.0, height: 100.0)
        let table = InstantPageV2TableItem(
            frame: CGRect(x: 0.0, y: 30.0, width: 320.0, height: 120.0),
            titleSubLayout: nil,
            titleFrame: nil,
            contentSize: CGSize(width: 320.0, height: 120.0),
            contentInset: 17.0,
            cells: [InstantPageV2TableCell(
                frame: cellFrame,
                isHeader: false,
                horizontalAlignment: .natural,
                verticalAlignment: .top,
                backgroundColor: nil,
                subLayout: inner
            )],
            horizontalLines: [],
            verticalLines: [],
            bordered: false,
            striped: false,
            borderColor: .clear
        )

        let cellOrigin = CGPoint(x: 0.0 + 17.0 + cellFrame.minX, y: 30.0 + cellFrame.minY)
        let expected = pill.layout.actionFrame(in: pill.frame.size)
            .offsetBy(dx: cellOrigin.x + pill.frame.minX, dy: cellOrigin.y + pill.frame.minY)

        XCTAssertEqual(
            unsupportedActionFrame(in: makeLayout([.table(table)]), containing: CGPoint(x: expected.midX, y: expected.midY)),
            expected
        )
    }

    // MARK: - A collage this build cannot fully decode

    /// A collage carrying a block this build cannot decode is unsupported *as a whole*. Rendering it
    /// as a mosaic is worse than not rendering it: `layoutCollage` reserves a zero-size mosaic slot
    /// for the undecodable item and then draws nothing in it, so the tiles that DO decode are laid
    /// out around a hole and the mosaic geometry is wrong.
    func testACollageContainingAnUnsupportedBlockRendersAsAPill() {
        let collage = InstantPageBlock.collage(
            items: [makeImageBlock(), .unsupported],
            caption: InstantPageCaption(text: .empty, credit: .empty)
        )

        XCTAssertTrue(blockRendersAsUnsupported(collage))
    }

    /// The overwhelmingly common collage is untouched — this predicate runs over every block of
    /// every page.
    func testAFullyDecodableCollageIsNotUnsupported() {
        let collage = InstantPageBlock.collage(
            items: [makeImageBlock(), makeImageBlock()],
            caption: InstantPageCaption(text: .empty, credit: .empty)
        )

        XCTAssertFalse(blockRendersAsUnsupported(collage))
        XCTAssertFalse(blockRendersAsUnsupported(InstantPageBlock.collage(items: [], caption: InstantPageCaption(text: .empty, credit: .empty))))
        XCTAssertFalse(blockRendersAsUnsupported(.paragraph(.plain("a"))))
        XCTAssertTrue(blockRendersAsUnsupported(.unsupported))
    }

    /// Deliberately NOT extended to `.slideshow`: it drops an undecodable item silently (a page
    /// fewer) rather than leaving a hole, and it keeps rendering the items it does understand.
    func testASlideshowIsNotCoveredByTheRule() {
        let slideshow = InstantPageBlock.slideshow(
            items: [makeImageBlock(), .unsupported],
            caption: InstantPageCaption(text: .empty, credit: .empty)
        )

        XCTAssertFalse(blockRendersAsUnsupported(slideshow))
    }

    /// A collage-turned-pill next to a real `.unsupported` block is ONE pill, not two stacked ones —
    /// the same "a maximal run collapses" rule, which is why the run finder tests the predicate
    /// rather than the `.unsupported` case.
    func testACollagePillCollapsesIntoAnAdjacentUnsupportedRun() {
        let brokenCollage = InstantPageBlock.collage(
            items: [.unsupported],
            caption: InstantPageCaption(text: .empty, credit: .empty)
        )

        XCTAssertEqual(redundantUnsupportedBlockIndices([.unsupported, brokenCollage]), Set([1]))
        XCTAssertEqual(redundantUnsupportedBlockIndices([brokenCollage, .unsupported]), Set([1]))
        // A collage that renders normally still breaks a run in two.
        let goodCollage = InstantPageBlock.collage(
            items: [makeImageBlock()],
            caption: InstantPageCaption(text: .empty, credit: .empty)
        )
        XCTAssertTrue(redundantUnsupportedBlockIndices([.unsupported, goodCollage, .unsupported]).isEmpty)
    }

    /// Spacing follows the rendering, not the case: the pill takes its own 8pt padding rather than
    /// the media block's flush-both-sides rhythm, or it butts against its neighbours like a
    /// full-bleed image.
    func testACollagePillTakesThePillsSpacing() {
        let brokenCollage = InstantPageBlock.collage(
            items: [makeImageBlock(), .unsupported],
            caption: InstantPageCaption(text: .empty, credit: .empty)
        )
        let metrics = InstantPageMetrics.unscaled

        let spacing = brokenCollage.spacing(metrics: metrics)
        let pillSpacing = InstantPageBlock.unsupported.spacing(metrics: metrics)

        XCTAssertEqual(spacing.verticalPadding, pillSpacing.verticalPadding)
        XCTAssertEqual(spacing.flushAbove, pillSpacing.flushAbove)
        XCTAssertEqual(spacing.flushBelow, pillSpacing.flushBelow)
        XCTAssertFalse(spacing.flushAbove)
    }
}
