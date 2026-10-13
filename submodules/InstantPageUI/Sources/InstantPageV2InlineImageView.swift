import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import PhotoResources
import MediaResources

/// Lightweight inline image view for InstantPage V2 — wraps a `TransformImageNode`
/// to render a single `RichText.image` cell inside a text view.
///
/// Owned by `InstantPageV2View` (not an `InstantPageItemView` conformer; not in
/// the view-factory switch). Hosted inside the parent text view's
/// `imageContainerView` (sibling of `renderContainer`, above the reveal mask,
/// below `emojiContainerView`), so the streaming reveal can wipe text glyphs
/// while the image pops in independently. Non-interactive — taps pass through
/// to the text view, so a URL-wrapping `RichText.url(text: .image(...))`
/// continues to route taps to the URL handler.
final class InstantPageV2InlineImageView: UIView {
    let fileId: Int64
    private let imageNode: TransformImageNode
    private let media: EngineMedia
    private let theme: InstantPageTheme
    private let fetchedDisposable = MetaDisposable()

    /// Excludes this inline image from screenshots — see `InstantPageV2RenderContext.captureProtected`.
    /// An inline image is as much message media as a block image is, so a copy-protected rich message
    /// must protect it too.
    var captureProtected: Bool = false {
        didSet {
            if self.captureProtected != oldValue {
                self.imageNode.captureProtected = self.captureProtected
            }
        }
    }

    init(media: EngineMedia,
         webpage: TelegramMediaWebpage?,
         frame: CGRect,
         context: AccountContext,
         userLocation: MediaResourceUserLocation,
         theme: InstantPageTheme,
         captureProtected: Bool) {
        self.media = media
        self.theme = theme
        self.fileId = media.id?.id ?? 0
        // Configured through a local: `self.imageNode` is not usable until after `super.init`.
        let imageNode = TransformImageNode()
        imageNode.captureProtected = captureProtected
        self.imageNode = imageNode
        self.captureProtected = captureProtected

        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.addSubview(self.imageNode.view)

        self.bindSignal(webpage: webpage, context: context, userLocation: userLocation)
        self.applyLayout(size: frame.size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        self.fetchedDisposable.dispose()
    }

    private func bindSignal(webpage: TelegramMediaWebpage?,
                            context: AccountContext,
                            userLocation: MediaResourceUserLocation) {
        // Without a webpage we can't form a `WebpageReference` for the standard
        // chat-message signals, so the image node stays at its empty colour.
        guard let webpage = webpage else { return }
        let webPageRef = WebpageReference(webpage)

        switch self.media {
        case let .image(image):
            let imageReference = ImageMediaReference.webPage(webPage: webPageRef, media: image)
            self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox,
                                                     userLocation: userLocation,
                                                     photoReference: imageReference))
            // Non-interactive: always auto-fetch so the image arrives without a tap.
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context,
                                                                          userLocation: userLocation,
                                                                          photoReference: imageReference,
                                                                          displayAtSize: nil,
                                                                          storeToDownloadsPeerId: nil).start())
        case let .file(file):
            let fileReference = FileMediaReference.webPage(webPage: webPageRef, media: file)
            if file.mimeType.hasPrefix("image/") {
                self.fetchedDisposable.set(freeMediaFileInteractiveFetched(account: context.account,
                                                                           userLocation: userLocation,
                                                                           fileReference: fileReference).start())
                self.imageNode.setSignal(instantPageImageFile(account: context.account,
                                                              userLocation: userLocation,
                                                              fileReference: fileReference,
                                                              fetched: true))
            } else {
                // Video / animated file: render a single still frame. No play overlay.
                self.imageNode.setSignal(chatMessageVideo(postbox: context.account.postbox,
                                                          userLocation: userLocation,
                                                          videoReference: fileReference))
            }
        default:
            // RichText.image's MediaId resolves to .image or .file in practice; other
            // EngineMedia kinds (geo, webpage, story, ...) leave the image node blank.
            break
        }
    }

    private func applyLayout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        self.imageNode.frame = CGRect(origin: .zero, size: size)

        let intrinsic: CGSize
        switch self.media {
        case let .image(image):
            if let largest = largestImageRepresentation(image.representations) {
                intrinsic = largest.dimensions.cgSize
            } else {
                intrinsic = size
            }
        case let .file(file):
            intrinsic = file.dimensions?.cgSize ?? size
        default:
            intrinsic = size
        }

        let imageSize = intrinsic.aspectFilled(size)
        let arguments = TransformImageArguments(
            corners: ImageCorners(),
            imageSize: imageSize,
            boundingSize: size,
            intrinsicInsets: UIEdgeInsets(),
            emptyColor: nil
        )
        let apply = self.imageNode.asyncLayout()(arguments)
        apply()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if self.imageNode.frame.size != self.bounds.size {
            self.applyLayout(size: self.bounds.size)
        }
    }
}
