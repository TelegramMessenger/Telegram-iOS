import XCTest
import CoreGraphics

/// The spacing of the chat list header's expanded stories row when its avatars do not all fit.
final class StoryPeerListRowLayoutTests: XCTestCase {
    // The row as the header lays it out: the first avatar 12 pt in, 60 pt avatars 14 pt apart.
    private let leadingInset: CGFloat = 12.0
    private let itemWidth: CGFloat = 60.0
    private let baseSpacing: CGFloat = 14.0

    private func spacing(_ containerWidth: CGFloat, itemCount: Int = 20) -> CGFloat {
        return StoryPeerListRowLayout.itemSpacing(containerWidth: containerWidth, leadingInset: self.leadingInset, itemWidth: self.itemWidth, baseSpacing: self.baseSpacing, itemCount: itemCount)
    }

    /// The first avatar the row's edge cuts, and how much of its ring shows.
    private func partialItem(_ containerWidth: CGFloat, spacing: CGFloat) -> (index: Int, visibleWidth: CGFloat) {
        var index = 0
        while self.leadingInset + CGFloat(index) * (self.itemWidth + spacing) + self.itemWidth <= containerWidth {
            index += 1
        }
        return (index, containerWidth - (self.leadingInset + CGFloat(index) * (self.itemWidth + spacing)) + StoryPeerListRowLayout.ringOutset)
    }

    // iPhone Duo folded: five avatars fit exactly and the sixth's ring shows at the edge. The spacing grows until the
    // fifth is cut at its centre.
    func test_spacing_grows_whenTheNextAvatarPeeksLessThanFourPoints() {
        XCTAssertEqual(self.spacing(382.0), 25.0)
        XCTAssertEqual(self.partialItem(382.0, spacing: 25.0).index, 4)
        XCTAssertEqual(self.partialItem(382.0, spacing: 25.0).visibleWidth, 30.0 + StoryPeerListRowLayout.ringOutset)

        // 3.66 pt of ring.
        XCTAssertGreaterThan(self.spacing(385.0), self.baseSpacing)
    }

    // A peek of 4 pt or more keeps the spacing: 390 and 393 show 8 and 11 pt, 402 a third of the avatar.
    func test_spacing_isUnchanged_whenTheNextAvatarPeeksFourPointsOrMore() {
        // 4.16 pt of ring.
        XCTAssertEqual(self.spacing(385.5), self.baseSpacing)
        XCTAssertEqual(self.spacing(390.0), self.baseSpacing)
        XCTAssertEqual(self.spacing(393.0), self.baseSpacing)
        XCTAssertEqual(self.spacing(402.0), self.baseSpacing)
    }

    // An edge in the gap after the last whole avatar shows nothing of the next, and one that cuts an avatar near its
    // end leaves it peeking: neither is a sliver.
    func test_spacing_isUnchanged_whenNothingPeeks_orTheCutAvatarIsMostlyVisible() {
        XCTAssertEqual(self.spacing(375.0), self.baseSpacing)
        XCTAssertEqual(self.spacing(382.0 - StoryPeerListRowLayout.ringOutset), self.baseSpacing)
        XCTAssertEqual(self.spacing(414.0), self.baseSpacing)
        XCTAssertEqual(self.spacing(430.0), self.baseSpacing)
        XCTAssertEqual(self.spacing(440.0), self.baseSpacing)
    }

    // With nothing past the last avatar there is no peek to fix (the content overflows by its trailing inset alone).
    func test_spacing_isUnchanged_whenEveryAvatarIsVisible() {
        XCTAssertEqual(self.spacing(382.0, itemCount: 5), self.baseSpacing)
    }

    // At any width the spacing changes only for a sliver, never shrinks, and leaves no sliver behind.
    func test_spacing_leavesNoSliver() {
        var containerWidth: CGFloat = 320.0
        while containerWidth <= 520.0 {
            let spacing = self.spacing(containerWidth)
            let basePeek = self.partialItem(containerWidth, spacing: self.baseSpacing).visibleWidth
            if basePeek > 0.0 && basePeek < 4.0 {
                XCTAssertGreaterThan(spacing, self.baseSpacing, "at \(containerWidth)")
                XCTAssertEqual(spacing, floor(spacing), "at \(containerWidth)")
                let peek = self.partialItem(containerWidth, spacing: spacing).visibleWidth
                XCTAssertGreaterThanOrEqual(peek, self.itemWidth * 0.5, "at \(containerWidth)")
            } else {
                XCTAssertEqual(spacing, self.baseSpacing, "at \(containerWidth)")
            }
            containerWidth += 0.25
        }
    }
}
