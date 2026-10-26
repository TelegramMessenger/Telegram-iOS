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

    // Too short to hold the button below the controls: it goes as low as the tile allows, still inside it.
    func testShortNarrowTileMovesItsMoreButtonToItsBottom() {
        let controls = self.controls()
        let tile = CGRect(x: 276.0, y: 0.0, width: 126.0, height: 80.0)
        XCTAssertEqual(MediaChromeLayout.moreButtonOrigin(cellFrame: tile, avoiding: controls), CGPoint(x: 8.0, y: 36.0))
    }

    private func controls() -> [CGRect] {
        let frames = MediaChromeLayout.containerControlFrames(containerWidth: self.containerWidth, showsAdd: true, showsToggle: true)
        return [frames.add, frames.toggle].compactMap { $0 }
    }

    private func assertKeepsClear(cellFrame: CGRect, origin: CGPoint, of controls: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
        let more = CGRect(origin: CGPoint(x: cellFrame.minX + origin.x, y: cellFrame.minY + origin.y), size: MediaChromeLayout.buttonSize)
        XCTAssertTrue(cellFrame.contains(more), "the button left its tile", file: file, line: line)
        for control in controls {
            XCTAssertFalse(control.insetBy(dx: -MediaChromeLayout.spacing + 0.5, dy: -MediaChromeLayout.spacing + 0.5).intersects(more), "closer than the spacing to \(control)", file: file, line: line)
        }
    }
}
