import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

/// A carousel's page dots while one of its media is open in the gallery.
///
/// The gallery flies its copy of the photo on a surface ABOVE the carousel, and removes it only when the close
/// transition lands. Dots left visible under it are covered for the whole close and then pop in at once. So the
/// dots hide while the gallery shows one of the carousel's media and fade back in when it hands the media back,
/// as chat media's overlays do (`ChatMessageInteractiveMediaNode.updateIsHidden`).
final class InstantPageV2SlideshowPageControlTests: XCTestCase {
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

    func testDotsHideOnlyWhileOneOfTheCarouselsMediaIsInTheGallery() {
        let medias = [self.media(index: 1, id: 10), self.media(index: 2, id: 20)]

        XCTAssertFalse(InstantPageV2SlideshowView.pageControlIsHidden(medias: medias, hiddenMedia: nil))
        XCTAssertTrue(InstantPageV2SlideshowView.pageControlIsHidden(medias: medias, hiddenMedia: self.media(index: 2, id: 20)))
        // Another block's media in the same message.
        XCTAssertFalse(InstantPageV2SlideshowView.pageControlIsHidden(medias: medias, hiddenMedia: self.media(index: 3, id: 30)))
    }

    func testDotsFadeBackInWhenTheGalleryReturnsTheMedia() {
        let dots = UIView()

        InstantPageV2SlideshowView.updatePageControlHidden(dots, isHidden: true)
        XCTAssertTrue(dots.isHidden)
        XCTAssertNil(dots.layer.animation(forKey: "opacity"))

        InstantPageV2SlideshowView.updatePageControlHidden(dots, isHidden: false)
        XCTAssertFalse(dots.isHidden)
        let fade = dots.layer.animation(forKey: "opacity") as? CABasicAnimation
        XCTAssertNotNil(fade, "the dots must fade in, not pop")
        XCTAssertEqual((fade?.fromValue as? NSNumber)?.doubleValue, 0.0)
        XCTAssertEqual((fade?.toValue as? NSNumber)?.doubleValue, 1.0)
    }

    func testAlreadyVisibleDotsDoNotRefade() {
        let dots = UIView()

        InstantPageV2SlideshowView.updatePageControlHidden(dots, isHidden: false)
        XCTAssertFalse(dots.isHidden)
        XCTAssertNil(dots.layer.animation(forKey: "opacity"))
    }
}
