import XCTest
import TelegramCore
@testable import InstantPageUI

/// The identity notion that lets a media TAP find its media in the CURRENT layout.
///
/// A tapped media view hands `openInstantPageMedia` the `InstantPageMedia` it was built with, and
/// that value is matched against the medias of the layout the page is showing NOW. The two are
/// different objects with independent lifetimes: the layout is rebuilt on every message update,
/// while the item view is reused. So the match has to survive a media value drifting under a stable
/// id — otherwise `openInstantPageMedia` finds no central index and returns having done nothing,
/// which on screen is a photo that simply ignores taps.
///
/// `==` cannot be that match: it compares the media DEEPLY. These tests pin the two properties the
/// fallback depends on — the drift really does break `==`, and `instantPageMediaMatchesNodeIdentity`
/// really does see through it — so that tightening either one fails here rather than silently
/// re-arming a swallowed tap.
final class InstantPageMediaIdentityTests: XCTestCase {
    private func representation(width: Int32, height: Int32, fileId: Int64) -> TelegramMediaImageRepresentation {
        return TelegramMediaImageRepresentation(
            dimensions: PixelDimensions(width: width, height: height),
            resource: LocalFileMediaResource(fileId: fileId),
            progressiveSizes: [],
            immediateThumbnailData: nil
        )
    }

    private func image(
        id: Int64,
        representations: [TelegramMediaImageRepresentation],
        immediateThumbnailData: Data? = nil
    ) -> TelegramMediaImage {
        return TelegramMediaImage(
            imageId: EngineMedia.Id(namespace: Namespaces.Media.CloudImage, id: id),
            representations: representations,
            immediateThumbnailData: immediateThumbnailData,
            reference: nil,
            partialReference: nil,
            flags: []
        )
    }

    private func media(index: Int, image: TelegramMediaImage) -> InstantPageMedia {
        return InstantPageMedia(index: index, media: .image(image), url: nil, caption: nil, credit: nil)
    }

    /// The baseline: an untouched re-layout still matches under both notions.
    func testUnchangedMediaMatchesUnderBothNotions() {
        let reps = [self.representation(width: 100, height: 100, fileId: 1)]
        let held = self.media(index: 0, image: self.image(id: 42, representations: reps))
        let relaidOut = self.media(index: 0, image: self.image(id: 42, representations: reps))

        XCTAssertEqual(held, relaidOut)
        XCTAssertTrue(instantPageMediaMatchesNodeIdentity(held, relaidOut))
    }

    /// The shape that breaks a tap: the server's copy of the same photo carries different
    /// representations than the one the client laid out (an edit, or the round-trip on send).
    func testRepresentationDriftBreaksEqualityButNotIdentity() {
        let held = self.media(index: 0, image: self.image(
            id: 42,
            representations: [self.representation(width: 100, height: 100, fileId: 1)]
        ))
        let relaidOut = self.media(index: 0, image: self.image(
            id: 42,
            representations: [
                self.representation(width: 100, height: 100, fileId: 1),
                self.representation(width: 800, height: 800, fileId: 2)
            ]
        ))

        XCTAssertNotEqual(held, relaidOut, "precondition: the drift must actually defeat ==")
        XCTAssertTrue(
            instantPageMediaMatchesNodeIdentity(held, relaidOut),
            "a photo that gained a size is still the same photo the user tapped"
        )
    }

    /// `TelegramMediaImage.isEqual` compares `immediateThumbnailData` too, and a message update can
    /// fill it in without the media becoming a different medium.
    func testThumbnailDataDriftBreaksEqualityButNotIdentity() {
        let reps = [self.representation(width: 100, height: 100, fileId: 1)]
        let held = self.media(index: 0, image: self.image(id: 42, representations: reps))
        let relaidOut = self.media(index: 0, image: self.image(
            id: 42,
            representations: reps,
            immediateThumbnailData: Data([0x01, 0x02])
        ))

        XCTAssertNotEqual(held, relaidOut, "precondition: the drift must actually defeat ==")
        XCTAssertTrue(instantPageMediaMatchesNodeIdentity(held, relaidOut))
    }

    /// The fallback must stay a fallback, not a wildcard: two genuinely different media on the same
    /// page must never resolve to each other, or a tap would open the gallery on the wrong item.
    func testDifferentMediumDoesNotMatch() {
        let reps = [self.representation(width: 100, height: 100, fileId: 1)]
        let first = self.media(index: 0, image: self.image(id: 42, representations: reps))

        XCTAssertFalse(instantPageMediaMatchesNodeIdentity(
            first,
            self.media(index: 1, image: self.image(id: 43, representations: reps))
        ))
        // Index alone is the page-unique slot, so neither half of the pair may match on its own.
        XCTAssertFalse(instantPageMediaMatchesNodeIdentity(
            first,
            self.media(index: 0, image: self.image(id: 43, representations: reps))
        ), "same slot, different medium")
        XCTAssertFalse(instantPageMediaMatchesNodeIdentity(
            first,
            self.media(index: 1, image: self.image(id: 42, representations: reps))
        ), "same medium, different slot")
    }
}
