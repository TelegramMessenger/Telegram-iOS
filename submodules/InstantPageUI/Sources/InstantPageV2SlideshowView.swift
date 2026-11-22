import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData

// A paged carousel for an `InstantPageBlock.slideshow`. Ports V1's InstantPageSlideshowNode /
// InstantPageSlideshowPagerNode (InstantPageSlideshowItemNode.swift), simplified to create all pages
// eagerly (slideshows are short; this avoids V1's central±1 index bookkeeping and makes the gallery
// transition source available for every page). Each photo/video page hosts an `InstantPageImageNode`
// exactly like the static media views (a video renders as a poster + play badge, tap opens the gallery);
// any other media kind renders an empty page.
final class InstantPageV2SlideshowView: UIView, InstantPageItemView, UIScrollViewDelegate {
    private(set) var item: InstantPageV2SlideshowItem
    var itemFrame: CGRect { return self.item.frame }

    private let renderContext: InstantPageV2RenderContext
    private var theme: InstantPageTheme

    private let scrollView: UIScrollView
    private let pageControlNode: PageControlNode

    // One wrapper view per media (so page count stays aligned with the page control). `pageImageNodes`
    // holds only the real image nodes; it may be shorter than `pageViews` if a non-image media appears
    // (which `layoutSlideshow` currently filters out). Nothing relies on positional correspondence.
    private var pageViews: [UIView] = []
    private var pageImageNodes: [InstantPageImageNode] = []

    init(item: InstantPageV2SlideshowItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item
        self.renderContext = renderContext
        self.theme = theme
        self.scrollView = UIScrollView()
        self.pageControlNode = PageControlNode(dotColor: .white, inactiveDotColor: UIColor(white: 1.0, alpha: 0.5))

        super.init(frame: item.frame)

        self.backgroundColor = .black                      // structural — slideshow backdrop is black (gallery look), not the media placeholder color
        self.clipsToBounds = true                          // structural
        if item.cornerRadius != 0.0 {
            self.layer.cornerRadius = item.cornerRadius
        }

        self.scrollView.disablesInteractiveTransitionGestureRecognizer = true
        
        self.scrollView.isPagingEnabled = true
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.scrollsToTop = false
        if #available(iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.scrollView.delegate = self
        self.addSubview(self.scrollView)                   // structural

        self.pageControlNode.isUserInteractionEnabled = false
        self.addSubview(self.pageControlNode.view)         // structural

        self.rebuildPages()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func rebuildPages() {
        for view in self.pageViews {
            view.removeFromSuperview()
        }
        self.pageViews = []
        self.pageImageNodes = []

        let renderContext = self.renderContext
        // The image node owns this closure, and is owned (transitively) by self — capture weakly.
        let openMedia: (InstantPageMedia) -> Void = { [weak self] tapped in
            guard let self else { return }
            handleOpenMediaTap(tapped: tapped, wrapper: self, renderContext: renderContext)
        }

        for media in self.item.medias {
            let pageView = UIView()
            pageView.clipsToBounds = true
            pageView.backgroundColor = .black   // black letterbox behind each page, not the media placeholder color
            // Both photos (`.image`) and videos (`.file`) get a page: `InstantPageImageNode` renders a
            // video `.file` as a poster + play badge (tap opens the gallery), like a collage video cell.
            let isRenderableMedia: Bool
            switch media.media {
            case .image, .file: isRenderableMedia = true
            default: isRenderableMedia = false
            }
            if isRenderableMedia {
                let node = makeMediaWrapper(
                    frame: CGRect(origin: .zero, size: self.item.frame.size),
                    media: media,
                    webPage: self.item.webPage,
                    attributes: [],
                    renderContext: self.renderContext,
                    theme: self.theme,
                    openMedia: openMedia,
                    longPressMedia: { _ in },
                    emptyColor: .black,
                    fit: true   // letterbox each page: one shared block frame (tallest media) would otherwise crop shorter items
                )
                pageView.addSubview(node.view)
                self.pageImageNodes.append(node)
            }
            // Any other media kind (none in practice — layoutSlideshow emits only image/video) gets an
            // empty page to keep page indices aligned with the page control.
            self.scrollView.addSubview(pageView)
            self.pageViews.append(pageView)
        }

        self.pageControlNode.pagesCount = self.item.medias.count
        self.pageControlNode.setPage(0.0)
        // Re-register media indices when rebuilding while already on-window (positional reuse with
        // changed content); no-ops before the view is attached, where didMoveToWindow handles it.
        self.registerMedias()
        self.setNeedsLayout()
    }

    private func registerMedias() {
        guard self.window != nil else { return }
        // Register under every contained media index so transitionArgsFor(media) can find this view.
        for media in self.item.medias {
            registerInRootRegistry(wrapper: self, mediaIndex: media.index)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.registerMedias()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        guard size.width > 0.0, size.height > 0.0 else { return }

        self.scrollView.frame = CGRect(origin: .zero, size: size)
        for (i, pageView) in self.pageViews.enumerated() {
            pageView.frame = CGRect(x: CGFloat(i) * size.width, y: 0.0, width: size.width, height: size.height)
        }
        for node in self.pageImageNodes {
            node.frame = CGRect(origin: .zero, size: size)
        }
        self.scrollView.contentSize = CGSize(width: CGFloat(self.pageViews.count) * size.width, height: size.height)

        self.pageControlNode.layer.transform = CATransform3DIdentity
        self.pageControlNode.frame = CGRect(x: 0.0, y: size.height - 20.0, width: size.width, height: 20.0)
        let maxWidth = size.width - 36.0
        let pageControlSize = self.pageControlNode.calculateSizeThatFits(size)
        if pageControlSize.width > maxWidth, pageControlSize.width > 0.0 {
            let scale = maxWidth / pageControlSize.width
            self.pageControlNode.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = self.bounds.size.width
        guard width > 0.0, !self.item.medias.isEmpty else { return }
        let page = Int((scrollView.contentOffset.x + width / 2.0) / width)
        let clamped = max(0, min(self.item.medias.count - 1, page))
        self.pageControlNode.setPage(CGFloat(clamped))
    }

    // Scrolls, without animation, to the page showing `media` if this carousel holds it.
    @discardableResult
    private func showPage(of media: InstantPageMedia) -> Bool {
        // A carousel created while the gallery is open may not be laid out yet; its pages need their frames
        // before one can be scrolled to. The page dots follow the scroll in `scrollViewDidScroll`.
        self.layoutIfNeeded()
        return InstantPageV2SlideshowView.scrollToPage(of: media, medias: self.item.medias, scrollView: self.scrollView) != nil
    }

    static func scrollToPage(of media: InstantPageMedia, medias: [InstantPageMedia], scrollView: UIScrollView) -> Int? {
        guard let index = medias.firstIndex(where: { instantPageMediaMatchesNodeIdentity($0, media) }) else {
            return nil
        }
        let width = scrollView.bounds.width
        if width > 0.0 {
            let contentOffset = CGPoint(x: CGFloat(index) * width, y: 0.0)
            if scrollView.contentOffset != contentOffset {
                scrollView.setContentOffset(contentOffset, animated: false)
            }
        }
        return index
    }

    func update(item: InstantPageV2SlideshowItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        let mediasChanged = self.item.medias.map { $0.index } != item.medias.map { $0.index }
        self.item = item
        self.theme = theme
        self.backgroundColor = .black
        if self.layer.cornerRadius != item.cornerRadius {
            self.layer.cornerRadius = item.cornerRadius
        }
        if mediasChanged {
            self.rebuildPages()
        } else {
            let strings = renderContext.context.sharedContext.currentPresentationData.with { $0 }.strings
            for node in self.pageImageNodes {
                node.update(strings: strings, theme: theme)
                node.captureProtected = renderContext.captureProtected
                // The reuse check above compares only the INDEX list, so a page keeps its node while
                // its media value moves underneath it. The node's `media` is what a tap hands to the
                // gallery's lookup, so it has to be re-pointed or tap-to-open silently stops working
                // (see `InstantPageImageNode.updateMediaValue`). Matched by index rather than by
                // position: a non-renderable media contributes a page but no node.
                guard let updated = self.item.medias.first(where: { $0.index == node.media.index }), updated != node.media else {
                    continue
                }
                if updated.media.id != node.media.media.id {
                    node.updateInteractiveMediaBinding(sourceLocation: renderContext.sourceLocation, media: updated, imageReferenceForMedia: renderContext.imageReference, fileReferenceForMedia: renderContext.fileReference)
                } else {
                    node.updateMediaValue(updated)
                }
            }
        }
        self.setNeedsLayout()
    }

    // MARK: InstantPageItemView gallery hooks

    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        // A slideshow registers under EVERY contained media index, so the gallery may ask about a media that
        // sits on an off-screen page: the item it closes on after the user swiped to it. Only the displayed
        // page has an on-screen representation, so scroll to that media's page first; the photo then flies
        // back into its own slot and the carousel stays on it, as a chat album does.
        guard self.showPage(of: media) else {
            return nil
        }
        for node in self.pageImageNodes {
            if let transition = node.transitionNode(media: media) {
                return transition
            }
        }
        return nil
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
        // The gallery hides each item it swipes to: follow it, so the carousel already shows that item when the
        // viewer closes, including an interactive swipe-away that reveals the bubble before the transition.
        if let media {
            self.showPage(of: media)
        }
        for node in self.pageImageNodes {
            node.updateHiddenMedia(media: media)
        }
        InstantPageV2SlideshowView.updatePageControlHidden(self.pageControlNode.view, isHidden: InstantPageV2SlideshowView.pageControlIsHidden(medias: self.item.medias, hiddenMedia: media))
    }

    // The gallery flies its copy of the photo on a surface above this view and removes it only when the close
    // transition lands, so dots left visible under it pop in at that moment. Like chat media's overlays
    // (`ChatMessageInteractiveMediaNode.updateIsHidden`), they hide while one of this carousel's media is in the
    // gallery and fade back in when the gallery hands it back.
    static func pageControlIsHidden(medias: [InstantPageMedia], hiddenMedia: InstantPageMedia?) -> Bool {
        guard let hiddenMedia else {
            return false
        }
        return medias.contains(where: { instantPageMediaMatchesNodeIdentity($0, hiddenMedia) })
    }

    static func updatePageControlHidden(_ view: UIView, isHidden: Bool) {
        if view.isHidden == isHidden {
            return
        }
        view.isHidden = isHidden
        if !isHidden {
            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }
}
