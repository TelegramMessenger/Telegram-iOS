import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramUIPreferences

/// A self-contained, host-embeddable view that renders ONE standalone medium (image or video) via the
/// (module-internal) `InstantPageImageNode`. Built for the rich-text composer, which needs to show a
/// freshly-picked `EngineMedia` outside any web page. The caller sizes it (frame / `update(size:)`);
/// the underlying node self-lays-out from its frame (see `InstantPageImageNode.layout()`).
@available(iOS 13.0, *)
public final class StandaloneInstantPageImageView: UIView {
    private let node: InstantPageImageNode

    public init(context: AccountContext, media: EngineMedia, attributes: [InstantPageImageAttribute] = []) {
        // A synthetic, content-free webpage — the node only needs it for media-reference plumbing.
        // Precedent: ChatMessageRichDataBubbleContentNode.swift:371.
        let webpage = TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(
            url: "", displayUrl: "", hash: 0, type: nil, websiteName: nil, title: nil, text: nil,
            embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil,
            isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil,
            attributes: [], instantPage: nil)))

        self.node = InstantPageImageNode(
            context: context,
            sourceLocation: InstantPageSourceLocation(userLocation: .other, peerType: .channel),
            theme: StandaloneInstantPageImageView.composeTheme(),
            webPage: webpage,
            media: InstantPageMedia(index: 0, media: media, url: nil, caption: nil, credit: nil),
            attributes: attributes,
            interactive: false,
            roundCorners: false,
            fit: true,
            openMedia: { _ in },
            longPressMedia: { _ in },
            activatePinchPreview: nil,
            pinchPreviewFinished: nil,
            imageReferenceForMedia: { image in ImageMediaReference.standalone(media: image) },
            fileReferenceForMedia: { file in FileMediaReference.standalone(media: file) },
            getPreloadedResource: { _ in nil }
        )
        super.init(frame: .zero)
        self.addSubview(self.node.view)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(size: CGSize) {
        self.node.frame = CGRect(origin: .zero, size: size)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.node.frame = self.bounds
    }

    // NOTE: duplicated from InstantPageUI's private `lightTheme`. TODO: reuse a shared default-theme
    // factory (e.g. instantPageThemeForType(.light, settings:)) if one is exposed, to avoid drift.
    private static func composeTheme() -> InstantPageTheme {
        return InstantPageTheme(
            type: .light,
            pageBackgroundColor: .white,
            textCategories: InstantPageTextCategories(
                kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 0.685), color: .black),
                header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 0.685, weight: .medium), color: .black),
                subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: instantPageNominalSubheaderFontSize, lineSpacingFactor: 0.685, weight: .medium), color: .black),
                paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 1.0), color: .black),
                caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x79828b)),
                credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: UIColor(rgb: 0x79828b)),
                table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: .black),
                article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: .black),
                codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: 14.0, lineSpacingFactor: 1.0), color: .black)
            ),
            serif: false,
            codeBlockBackgroundColor: UIColor(rgb: 0xf5f8fc),
            linkColor: UIColor(rgb: 0x0088ff),
            textHighlightColor: UIColor(rgb: 0, alpha: 0.12),
            linkHighlightColor: UIColor(rgb: 0x0088ff, alpha: 0.07),
            markerColor: UIColor(rgb: 0xfef3bc),
            panelBackgroundColor: UIColor(rgb: 0xf3f4f5),
            panelHighlightedBackgroundColor: UIColor(rgb: 0xe7e7e7),
            panelPrimaryColor: .black,
            panelSecondaryColor: UIColor(rgb: 0x79828b),
            panelAccentColor: UIColor(rgb: 0x0088ff),
            tableBorderColor: UIColor(rgb: 0xe2e2e2),
            tableHeaderColor: UIColor(rgb: 0xf4f4f4),
            controlColor: UIColor(rgb: 0xc7c7cd),
            imageTintColor: nil,
            overlayPanelColor: .white,
            separatorColor: UIColor(rgb: 0xe2e2e2),
            secondaryControlColor: .black,
            quoteAccentColor: .black
        )
    }
}
