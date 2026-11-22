import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

/// A carousel follows the item the media viewer shows.
///
/// The gallery reports each item it swipes to through `hiddenMedia`, and on close asks for that item's transition
/// node. A carousel left on the page that was tapped has no on-screen slot for the item the viewer closes on, so the
/// photo can't fly back into it and the bubble keeps showing the first page. The carousel therefore scrolls to the
/// page of the gallery's item, as a chat album or the standalone gallery's source does.
final class InstantPageV2SlideshowGalleryFollowTests: XCTestCase {
    private func media(index: Int, id: Int64) -> InstantPageMedia {
        let image = TelegramMediaImage(
            imageId: EngineMedia.Id(namespace: Namespaces.Media.CloudImage, id: id),
            representations: [],
            immediateThumbnailData: nil,
            reference: nil,
            partialReference: nil,
            flags: []
        )
        return InstantPageMedia(index: index, media: .image(image), url: nil, caption: nil, credit: nil)
    }

    private func pagedScrollView(pageCount: Int) -> UIScrollView {
        let scrollView = UIScrollView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 200.0))
        scrollView.isPagingEnabled = true
        scrollView.contentSize = CGSize(width: 300.0 * CGFloat(pageCount), height: 200.0)
        return scrollView
    }

    func testScrollsToThePageOfTheGallerysItem() {
        let medias = [self.media(index: 1, id: 10), self.media(index: 2, id: 20), self.media(index: 3, id: 30)]
        let scrollView = self.pagedScrollView(pageCount: medias.count)

        XCTAssertEqual(InstantPageV2SlideshowView.scrollToPage(of: self.media(index: 3, id: 30), medias: medias, scrollView: scrollView), 2)
        XCTAssertEqual(scrollView.contentOffset, CGPoint(x: 600.0, y: 0.0))

        XCTAssertEqual(InstantPageV2SlideshowView.scrollToPage(of: self.media(index: 1, id: 10), medias: medias, scrollView: scrollView), 0)
        XCTAssertEqual(scrollView.contentOffset, CGPoint(x: 0.0, y: 0.0))
    }

    func testACarouselWithoutWidthOwnsTheMediaButDoesNotScroll() {
        let medias = [self.media(index: 1, id: 10), self.media(index: 2, id: 20)]
        let scrollView = UIScrollView()

        // It still answers for the media; there is no page width to scroll by yet.
        XCTAssertEqual(InstantPageV2SlideshowView.scrollToPage(of: self.media(index: 2, id: 20), medias: medias, scrollView: scrollView), 1)
        XCTAssertEqual(scrollView.contentOffset, .zero)
    }

    func testIgnoresAnotherBlocksMedia() {
        let medias = [self.media(index: 1, id: 10), self.media(index: 2, id: 20)]
        let scrollView = self.pagedScrollView(pageCount: medias.count)
        scrollView.contentOffset = CGPoint(x: 300.0, y: 0.0)

        // A photo elsewhere in the same message, reached by swiping past the carousel's last item.
        XCTAssertNil(InstantPageV2SlideshowView.scrollToPage(of: self.media(index: 4, id: 40), medias: medias, scrollView: scrollView))
        XCTAssertEqual(scrollView.contentOffset, CGPoint(x: 300.0, y: 0.0))
    }
}
