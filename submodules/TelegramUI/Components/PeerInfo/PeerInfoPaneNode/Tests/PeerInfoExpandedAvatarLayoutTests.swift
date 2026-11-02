import XCTest
@testable import PeerInfoPaneNode

final class PeerInfoExpandedAvatarLayoutTests: XCTestCase {
    // The photo is as wide as the container, at most its height less 61 pt, with the title and buttons on its lower part.
    func test_height() {
        XCTAssertEqual(peerInfoExpandedAvatarHeight(containerSize: CGSize(width: 393.0, height: 852.0), bottomHeight: 98.0), 491.0)
        XCTAssertEqual(peerInfoExpandedAvatarHeight(containerSize: CGSize(width: 393.0, height: 852.0), bottomHeight: 60.0), 453.0)
        XCTAssertEqual(peerInfoExpandedAvatarHeight(containerSize: CGSize(width: 631.0, height: 669.0), bottomHeight: 98.0), 706.0)
    }

    // Phones in portrait, the Duo's folded screen and its unfolded portrait one keep the expanded avatar, with the list
    // below it on screen.
    func test_fitsInPortrait() {
        XCTAssertTrue(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 393.0, height: 852.0), bottomHeight: 98.0))
        XCTAssertTrue(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 320.0, height: 568.0), bottomHeight: 98.0))
        XCTAssertTrue(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 440.0, height: 956.0), bottomHeight: 98.0))
        XCTAssertTrue(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 466.0, height: 678.0), bottomHeight: 98.0))
        XCTAssertTrue(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 669.0, height: 951.0), bottomHeight: 98.0))
        XCTAssertTrue(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 466.0, height: 678.0), bottomHeight: 60.0))
    }

    // Landscape collapses it, as before.
    func test_notInLandscape() {
        XCTAssertFalse(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 852.0, height: 393.0), bottomHeight: 98.0))
        XCTAssertFalse(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 678.0, height: 466.0), bottomHeight: 98.0))
    }

    // The unfolded Duo's detail pane in landscape is portrait-shaped but hardly taller than wide: the expanded photo
    // reached past its bottom (706 pt in 669), leaving nothing to drag, so the profile could not scroll (#54).
    func test_notWhenThePhotoCoversTheContainer() {
        XCTAssertFalse(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 631.0, height: 669.0), bottomHeight: 98.0))
        XCTAssertFalse(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 600.0, height: 600.0), bottomHeight: 98.0))
        // Less than a touch's height of the list left below it.
        XCTAssertFalse(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 500.0, height: 641.0), bottomHeight: 98.0))
        XCTAssertTrue(peerInfoAvatarExpansionFits(containerSize: CGSize(width: 500.0, height: 642.0), bottomHeight: 98.0))
    }
}
