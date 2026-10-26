import XCTest
import CoreGraphics
@testable import RichTextEditorMediaView

/// The article editor's glass media buttons: the container's "+" and layout toggle in its top-right corner,
/// and each tile's "…" in the tile's top-left corner, which must never land on the container's buttons.
final class MediaChromeLayoutTests: XCTestCase {
    private let containerWidth: CGFloat = 402.0

    func testContainerControlsSitTopRightWithToggleLeftOfAdd() {
        let frames = MediaChromeLayout.containerControlFrames(containerWidth: self.containerWidth, showsAdd: true, showsToggle: true)
        XCTAssertEqual(frames.add, CGRect(x: 358.0, y: 8.0, width: 36.0, height: 36.0))
        XCTAssertEqual(frames.toggle, CGRect(x: 316.0, y: 8.0, width: 36.0, height: 36.0))
    }

    func testToggleTakesTheCornerOfAFullAlbum() {
        let frames = MediaChromeLayout.containerControlFrames(containerWidth: self.containerWidth, showsAdd: false, showsToggle: true)
        XCTAssertNil(frames.add)
        XCTAssertEqual(frames.toggle, CGRect(x: 358.0, y: 8.0, width: 36.0, height: 36.0))
    }

    func testWideTileKeepsItsMoreButtonTopLeft() {
        let controls = self.controls()
        let photo = CGRect(x: 0.0, y: 0.0, width: 274.0, height: 274.0)
        XCTAssertEqual(MediaChromeLayout.moreButtonOrigin(cellFrame: photo, avoiding: controls), CGPoint(x: 8.0, y: 8.0))
    }

    func testSingleMediaKeepsItsMoreButtonTopLeft() {
        let controls = MediaChromeLayout.containerControlFrames(containerWidth: self.containerWidth, showsAdd: true, showsToggle: false)
        let single = CGRect(x: 0.0, y: 0.0, width: self.containerWidth, height: 300.0)
        XCTAssertEqual(MediaChromeLayout.moreButtonOrigin(cellFrame: single, avoiding: [controls.add, controls.toggle].compactMap { $0 }), CGPoint(x: 8.0, y: 8.0))
    }

    // Issue #28: a 640×640 photo beside a portrait video leaves the video's tile ~126pt wide, and its "…"
    // (top-left of the tile) landed on the container's layout toggle.
    func testNarrowTileUnderTheContainerControlsMovesItsMoreButtonBelowThem() {
        let controls = self.controls()
        let video = CGRect(x: 276.0, y: 0.0, width: 126.0, height: 274.0)
        let origin = MediaChromeLayout.moreButtonOrigin(cellFrame: video, avoiding: controls)
        XCTAssertEqual(origin, CGPoint(x: 8.0, y: 50.0))
        self.assertKeepsClear(cellFrame: video, origin: origin, of: controls)
    }

    // Narrow enough to sit under the "+" alone (a full album's toggle in the corner works the same way).
    func testTileUnderTheAddButtonAloneMovesItsMoreButtonBelowIt() {
        let controls = self.controls()
        let tile = CGRect(x: 340.0, y: 0.0, width: 62.0, height: 200.0)
        let origin = MediaChromeLayout.moreButtonOrigin(cellFrame: tile, avoiding: controls)
        XCTAssertEqual(origin, CGPoint(x: 8.0, y: 50.0))
        self.assertKeepsClear(cellFrame: tile, origin: origin, of: controls)
    }

    // A narrow tile further down the mosaic is clear of the container's buttons.
    func testNarrowTileBelowTheControlsKeepsItsMoreButtonTopLeft() {
        let controls = self.controls()
        let tile = CGRect(x: 276.0, y: 140.0, width: 126.0, height: 134.0)
        XCTAssertEqual(MediaChromeLayout.moreButtonOrigin(cellFrame: tile, avoiding: controls), CGPoint(x: 8.0, y: 8.0))
    }

    // Too short to hold the button below the controls, but wide enough for it in their row.
    func testShortTileWithRoomBesideTheControlsPutsItsMoreButtonInTheirRow() {
        let controls = self.controls()
        let tile = CGRect(x: 268.0, y: 0.0, width: 134.0, height: 80.0)
        let origin = MediaChromeLayout.moreButtonOrigin(cellFrame: tile, avoiding: controls)
        XCTAssertEqual(origin, CGPoint(x: 6.0, y: 8.0))
        self.assertKeepsClear(cellFrame: tile, origin: origin, of: controls)
    }

    // Room neither below nor beside (the top-right tile of a centred 4-item album at 375pt): the button
    // keeps its row position and overflows the tile's left edge, still clear of the container's buttons.
    func testTileTooSmallForEitherOverflowsItsLeftEdgeInTheControlsRow() {
        let width: CGFloat = 375.0
        let frames = MediaChromeLayout.containerControlFrames(containerWidth: width, showsAdd: true, showsToggle: true)
        let controls = [frames.add, frames.toggle].compactMap { $0 }
        let tile = CGRect(x: 256.0, y: 0.0, width: 75.0, height: 75.0)
        let origin = MediaChromeLayout.moreButtonOrigin(cellFrame: tile, avoiding: controls)
        XCTAssertEqual(origin, CGPoint(x: -9.0, y: 8.0))
        XCTAssertTrue(MediaChromeLayout.isOutsideTile(origin: origin, tileSize: tile.size))
        self.assertKeepsClear(cellFrame: tile, origin: origin, of: controls, mayOverflow: true)
    }

    // The reported layout, through the real album engine: a 640×640 photo and a 360×780 video at 402pt
    // (the video tile is 127pt wide; a 9:16 one gets 144pt, which already clears the buttons).
    func testReportedPhotoAndVideoRowKeepsBothMoreButtonsClear() {
        let tiles = MosaicCellFrames.frames(itemSizes: [CGSize(width: 640.0, height: 640.0), CGSize(width: 360.0, height: 780.0)], size: CGSize(width: self.containerWidth, height: 0.0))
        XCTAssertEqual(tiles.count, 2)
        let controls = self.controls()
        XCTAssertEqual(MediaChromeLayout.moreButtonOrigin(cellFrame: tiles[0], avoiding: controls), CGPoint(x: 8.0, y: 8.0))
        let videoOrigin = MediaChromeLayout.moreButtonOrigin(cellFrame: tiles[1], avoiding: controls)
        XCTAssertEqual(videoOrigin, CGPoint(x: 8.0, y: 50.0))
        self.assertKeepsClear(cellFrame: tiles[1], origin: videoOrigin, of: controls)
    }

    // Tiny top-right tiles the sweep finds, through the real album engine.

    // 375pt, a tall portrait beside three stacked ones: the 75pt top-right tile has no room below the
    // controls, so its "…" goes into their row, just inside its left edge.
    func testTinyTileOfAFourItemAlbumFitsItsMoreButtonInTheControlsRow() {
        let tiles = self.albumTiles([0.5, 1.0, 0.5, 0.5], width: 375.0)
        let origins = MediaChromeLayout.moreButtonOrigins(cellFrames: tiles, avoiding: self.controls(width: 375.0, count: 4))
        XCTAssertEqual(tiles[1], CGRect(x: 244.0, y: 0.0, width: 75.0, height: 75.0))
        XCTAssertEqual(origins[1], CGPoint(x: 3.0, y: 8.0))
        XCTAssertFalse(MediaChromeLayout.isOutsideTile(origin: origins[1], tileSize: tiles[1].size))
        XCTAssertEqual(origins[0], CGPoint(x: 8.0, y: 8.0))
    }

    func testTinyTileOfASevenItemAlbumOverflowsIntoTheControlsRow() {
        let tiles = self.albumTiles([2.0, 2.0, 1.0, 1.33, 2.0, 1.78, 1.33], width: 375.0)
        let origins = MediaChromeLayout.moreButtonOrigins(cellFrames: tiles, avoiding: self.controls(width: 375.0, count: 7))
        let overflowing = origins.filter(MediaChromeLayout.overflowsTile)
        XCTAssertEqual(overflowing.count, 1)
        XCTAssertGreaterThanOrEqual(overflowing[0].x, -MediaChromeLayout.maxOverflow)
        self.assertAlbumKeepsClear([2.0, 2.0, 1.0, 1.33, 2.0, 1.78, 1.33], widths: [375.0])
    }

    // 320pt, a 68pt top-right tile: in the row it would stick out more than `maxOverflow`, so it keeps the
    // top-left spot and the overlap it always had (one of the residual layouts).
    func testTinyTileAt320KeepsItsOldSpotWhenTheRowWouldLeaveItsTile() {
        let tiles = self.albumTiles([1.0, 1.0, 0.5625, 0.5], width: 320.0)
        let origins = MediaChromeLayout.moreButtonOrigins(cellFrames: tiles, avoiding: self.controls(width: 320.0, count: 4))
        XCTAssertEqual(tiles[1], CGRect(x: 222.0, y: 0.0, width: 68.0, height: 67.0))
        XCTAssertEqual(origins[1], CGPoint(x: 8.0, y: 8.0))
    }

    // 320pt, a panorama over three 68pt tiles: the last one's row position would touch the middle tile's
    // "…", so it keeps the top-left spot too.
    func testOverflowingMoreButtonNeverLandsOnAnotherTilesOne() {
        let tiles = self.albumTiles([2.5, 0.8, 0.75, 0.75], width: 320.0)
        let controls = self.controls(width: 320.0, count: 4)
        let lone = tiles.map { MediaChromeLayout.moreButtonOrigin(cellFrame: $0, avoiding: controls) }
        XCTAssertTrue(lone.contains(where: MediaChromeLayout.overflowsTile))
        let origins = MediaChromeLayout.moreButtonOrigins(cellFrames: tiles, avoiding: controls)
        XCTAssertFalse(origins.contains(where: MediaChromeLayout.overflowsTile))
        self.assertAlbumKeepsClear([2.5, 0.8, 0.75, 0.75], widths: [320.0])
    }

    // Every tile of every album over a grid of aspect ratios (all combinations up to 5 items, a
    // deterministic sample up to 10) at common widths. No two "…" ever overlap, none sticks out of its tile
    // by more than `maxOverflow`, and from 375pt up every "…" keeps the spacing from the container's
    // buttons; narrower, a "…" that cannot keeps its old top-left spot.
    func testEveryAlbumKeepsItsMoreButtonsClear() {
        let ratios: [CGFloat] = [0.5, 0.5625, 0.75, 1.0, 1.33, 1.78, 2.0, 2.5]
        var albums: [[CGFloat]] = [[]]
        for _ in 1 ... 4 {
            albums = albums.flatMap { album in ratios.map { album + [$0] } }
            if albums[0].count >= 2 {
                albums.forEach { self.assertAlbumKeepsClear($0) }
            }
        }
        var seed: UInt64 = 28
        for count in 5 ... 10 {
            for _ in 0 ..< 1500 {
                let album = (0 ..< count).map { _ -> CGFloat in
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return ratios[Int(seed >> 33) % ratios.count]
                }
                self.assertAlbumKeepsClear(album)
            }
        }
    }

    private func albumTiles(_ aspectRatios: [CGFloat], width: CGFloat) -> [CGRect] {
        return MosaicCellFrames.frames(itemSizes: aspectRatios.map { CGSize(width: 1000.0 * $0, height: 1000.0) }, size: CGSize(width: width, height: 0.0))
    }

    private func controls(width: CGFloat, count: Int) -> [CGRect] {
        let frames = MediaChromeLayout.containerControlFrames(containerWidth: width, showsAdd: count < 10, showsToggle: true)
        return [frames.add, frames.toggle].compactMap { $0 }
    }

    private func assertAlbumKeepsClear(_ aspectRatios: [CGFloat], widths: [CGFloat] = [320.0, 375.0, 393.0, 402.0, 430.0, 440.0], file: StaticString = #filePath, line: UInt = #line) {
        for width in widths {
            let tiles = self.albumTiles(aspectRatios, width: width)
            let controls = self.controls(width: width, count: aspectRatios.count)
            let origins = MediaChromeLayout.moreButtonOrigins(cellFrames: tiles, avoiding: controls)
            let buttons = tiles.indices.map { CGRect(origin: CGPoint(x: tiles[$0].minX + origins[$0].x, y: tiles[$0].minY + origins[$0].y), size: MediaChromeLayout.buttonSize) }
            for (index, button) in buttons.enumerated() {
                let tile = tiles[index]
                let context = "album \(aspectRatios) at \(width), tile \(tile)"
                let tooClose = controls.contains { $0.insetBy(dx: -MediaChromeLayout.spacing + 0.5, dy: -MediaChromeLayout.spacing + 0.5).intersects(button) }
                if tooClose {
                    XCTAssertLessThan(width, 375.0, "\(context): \(button) is closer than the spacing to a container button", file: file, line: line)
                    XCTAssertEqual(origins[index], CGPoint(x: MediaChromeLayout.inset, y: MediaChromeLayout.inset), context, file: file, line: line)
                }
                for (otherIndex, other) in buttons.enumerated() where otherIndex != index && other.intersects(button) {
                    XCTFail("\(context): \(button) overlaps the \"…\" of tile \(tiles[otherIndex])", file: file, line: line)
                }
                // A moved "…" stays in its tile but for the row overflow on the left. (A tile under 44pt, such
                // as a scaled-down column or a 2:1 panorama row, has never held a top-left one either; a moved
                // one reaches no lower than that did.)
                if origins[index] != CGPoint(x: MediaChromeLayout.inset, y: MediaChromeLayout.inset) {
                    XCTAssertLessThanOrEqual(tile.minX - button.minX, MediaChromeLayout.maxOverflow + 0.001, context, file: file, line: line)
                    XCTAssertLessThanOrEqual(button.maxX, tile.maxX + 0.001, context, file: file, line: line)
                    XCTAssertLessThanOrEqual(button.maxY, max(tile.maxY, tile.minY + MediaChromeLayout.inset + MediaChromeLayout.buttonSize.height) + 0.001, context, file: file, line: line)
                }
            }
        }
    }

    private func controls() -> [CGRect] {
        let frames = MediaChromeLayout.containerControlFrames(containerWidth: self.containerWidth, showsAdd: true, showsToggle: true)
        return [frames.add, frames.toggle].compactMap { $0 }
    }

    private func assertKeepsClear(cellFrame: CGRect, origin: CGPoint, of controls: [CGRect], mayOverflow: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let more = CGRect(origin: CGPoint(x: cellFrame.minX + origin.x, y: cellFrame.minY + origin.y), size: MediaChromeLayout.buttonSize)
        if !mayOverflow {
            XCTAssertTrue(cellFrame.contains(more), "the button left its tile", file: file, line: line)
        }
        for control in controls {
            XCTAssertFalse(control.insetBy(dx: -MediaChromeLayout.spacing + 0.5, dy: -MediaChromeLayout.spacing + 0.5).intersects(more), "closer than the spacing to \(control)", file: file, line: line)
        }
    }
}
