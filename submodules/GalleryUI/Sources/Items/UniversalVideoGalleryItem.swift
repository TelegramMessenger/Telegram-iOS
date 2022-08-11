import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Display
import Postbox
import TelegramPresentationData
import UniversalMediaPlayer
import AccountContext
import RadialStatusNode
import TelegramUniversalVideoContent
import PresentationDataUtils
import OverlayStatusController
import StickerPackPreviewUI
import AppBundle
import AnimationUI
import ContextUI
import SaveToCameraRoll
import UndoUI
import TelegramUIPreferences
import OpenInExternalAppUI
import AVKit
import TextFormat

public enum UniversalVideoGalleryItemContentInfo {
    case message(Message)
    case webPage(TelegramMediaWebpage, Media, ((@escaping () -> GalleryTransitionArguments?, NavigationController?, (ViewController, Any?) -> Void) -> Void)?)
}

public class UniversalVideoGalleryItem: GalleryItem {
    public var id: AnyHashable {
        return self.content.id
    }
    
    let context: AccountContext
    let presentationData: PresentationData
    let content: UniversalVideoContent
    let originData: GalleryItemOriginData?
    let indexData: GalleryItemIndexData?
    let contentInfo: UniversalVideoGalleryItemContentInfo?
    let caption: NSAttributedString
    let description: NSAttributedString?
    let credit: NSAttributedString?
    let displayInfoOnTop: Bool
    let hideControls: Bool
    let fromPlayingVideo: Bool
    let isSecret: Bool
    let landscape: Bool
    let timecode: Double?
    let playbackRate: () -> Double?
    let configuration: GalleryConfiguration?
    let playbackCompleted: () -> Void
    let performAction: (GalleryControllerInteractionTapAction) -> Void
    let openActionOptions: (GalleryControllerInteractionTapAction, Message) -> Void
    let storeMediaPlaybackState: (MessageId, Double?, Double) -> Void
    let present: (ViewController, Any?) -> Void

    public init(context: AccountContext, presentationData: PresentationData, content: UniversalVideoContent, originData: GalleryItemOriginData?, indexData: GalleryItemIndexData?, contentInfo: UniversalVideoGalleryItemContentInfo?, caption: NSAttributedString, description: NSAttributedString? = nil, credit: NSAttributedString? = nil, displayInfoOnTop: Bool = false, hideControls: Bool = false, fromPlayingVideo: Bool = false, isSecret: Bool = false, landscape: Bool = false, timecode: Double? = nil, playbackRate: @escaping () -> Double?, configuration: GalleryConfiguration? = nil, playbackCompleted: @escaping () -> Void = {}, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void, openActionOptions: @escaping (GalleryControllerInteractionTapAction, Message) -> Void, storeMediaPlaybackState: @escaping (MessageId, Double?, Double) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.content = content
        self.originData = originData
        self.indexData = indexData
        self.contentInfo = contentInfo
        self.caption = caption
        self.description = description
        self.credit = credit
        self.displayInfoOnTop = displayInfoOnTop
        self.hideControls = hideControls
        self.fromPlayingVideo = fromPlayingVideo
        self.isSecret = isSecret
        self.landscape = landscape
        self.timecode = timecode
        self.playbackRate = playbackRate
        self.configuration = configuration
        self.playbackCompleted = playbackCompleted
        self.performAction = performAction
        self.openActionOptions = openActionOptions
        self.storeMediaPlaybackState = storeMediaPlaybackState
        self.present = present
    }
    
    public func node(synchronous: Bool) -> GalleryItemNode {
        let node = UniversalVideoGalleryItemNode(context: self.context, presentationData: self.presentationData, performAction: self.performAction, openActionOptions: self.openActionOptions, present: self.present)
        
        if let indexData = self.indexData {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(indexData.position + 1)", "\(indexData.totalCount)").string))
        }
        
        node.setupItem(self)
        
        if self.displayInfoOnTop, case let .message(message) = self.contentInfo {
            node.titleContentView?.setMessage(message, presentationData: self.presentationData, accountPeerId: self.context.account.peerId)
        }
        
        return node
    }
    
    public func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? UniversalVideoGalleryItemNode {
            if let indexData = self.indexData {
                node._title.set(.single(self.presentationData.strings.Items_NOfM("\(indexData.position + 1)", "\(indexData.totalCount)").string))
            }
            
            node.setupItem(self)
            
            if self.displayInfoOnTop, case let .message(message) = self.contentInfo {
                node.titleContentView?.setMessage(message, presentationData: self.presentationData, accountPeerId: self.context.account.peerId)
            }
        }
    }
    
    public func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        guard let contentInfo = self.contentInfo else {
            return nil
        }
        if case let .message(message) = contentInfo {
            if let id = message.groupInfo?.stableId {
                var mediaReference: AnyMediaReference?
                for m in message.media {
                    if let m = m as? TelegramMediaImage {
                        mediaReference = .message(message: MessageReference(message), media: m)
                    } else if let m = m as? TelegramMediaFile, m.isVideo {
                        mediaReference = .message(message: MessageReference(message), media: m)
                    }
                }
                if let mediaReference = mediaReference {
                    if let item = ChatMediaGalleryThumbnailItem(account: self.context.account, mediaReference: mediaReference) {
                        return (Int64(id), item)
                    }
                }
            }
        } else if case let .webPage(webPage, media, _) = contentInfo, let file = media as? TelegramMediaFile  {
            if let item = ChatMediaGalleryThumbnailItem(account: self.context.account, mediaReference: .webPage(webPage: WebpageReference(webPage), media: file)) {
                return (0, item)
            }
        }
        return nil
    }
}

private let pictureInPictureImage = UIImage(bundleImageName: "Media Gallery/PictureInPictureIcon")?.precomposed()
private let pictureInPictureButtonImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/PictureInPictureButton"), color: .white)
private let moreButtonImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/More"), color: .white)

private let placeholderFont = Font.regular(16.0)

private final class UniversalVideoGalleryItemPictureInPictureNode: ASDisplayNode {
    private let iconNode: ASImageNode
    private let textNode: ASTextNode
    
    init(strings: PresentationStrings) {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = pictureInPictureImage
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: strings.Embed_PlayingInPIP, font: placeholderFont, textColor: UIColor(rgb: 0x8e8e93))
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    func updateLayout(_ size: CGSize, transition: ContainedViewLayoutTransition) {
        let iconSize = self.iconNode.image?.size ?? CGSize()
        let textSize = self.textNode.measure(CGSize(width: max(0.0, size.width - 20.0), height: CGFloat.greatestFiniteMagnitude))
        let spacing: CGFloat = 10.0
        let contentHeight = iconSize.height + spacing + textSize.height
        let contentVerticalOrigin = floor((size.height - contentHeight) / 2.0)
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: contentVerticalOrigin + iconSize.height + spacing), size: textSize))
    }
}

private let fullscreenImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/Fullscreen"), color: .white)
private let minimizeImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/Minimize"), color: .white)

private final class UniversalVideoGalleryItemOverlayNode: GalleryOverlayContentNode {
    private let wrapperNode: ASDisplayNode
    private let fullscreenNode: HighlightableButtonNode
    private var validLayout: (CGSize, LayoutMetrics, UIEdgeInsets)?
    
    var action: ((Bool) -> Void)?
    
    override init() {
        self.wrapperNode = ASDisplayNode()
        self.wrapperNode.alpha = 0.0
        
        self.fullscreenNode = HighlightableButtonNode()
        self.fullscreenNode.setImage(fullscreenImage, for: .normal)
        self.fullscreenNode.setImage(minimizeImage, for: .selected)
        self.fullscreenNode.setImage(minimizeImage, for: [.selected, .highlighted])
    
        super.init()
        
        self.addSubnode(self.wrapperNode)
        self.wrapperNode.addSubnode(self.fullscreenNode)
        
        self.fullscreenNode.addTarget(self, action: #selector(self.toggleFullscreenPressed), forControlEvents: .touchUpInside)
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, insets: UIEdgeInsets, isHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, metrics, insets)
        
        let isLandscape = size.width > size.height
        self.fullscreenNode.isSelected = isLandscape
        
        let iconSize: CGFloat = 42.0
        let inset: CGFloat = 4.0
        let buttonFrame = CGRect(origin: CGPoint(x: size.width - iconSize - inset - insets.right, y: size.height - iconSize - inset - insets.bottom), size: CGSize(width: iconSize, height: iconSize))
        transition.updateFrame(node: self.wrapperNode, frame: buttonFrame)
        transition.updateFrame(node: self.fullscreenNode, frame: CGRect(origin: CGPoint(), size: buttonFrame.size))
    }
    
    override func animateIn(previousContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition) {
        if !self.visibilityAlpha.isZero {
            transition.updateAlpha(node: self.wrapperNode, alpha: 1.0)
        }
    }
    
    override func animateOut(nextContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        transition.updateAlpha(node: self.wrapperNode, alpha: 0.0)
    }
    
    override func setVisibilityAlpha(_ alpha: CGFloat) {
        super.setVisibilityAlpha(alpha)
        self.updateFullscreenButtonVisibility()
    }
    
    func updateFullscreenButtonVisibility() {
        self.wrapperNode.alpha = self.visibilityAlpha
        
        if let validLayout = self.validLayout {
            self.updateLayout(size: validLayout.0, metrics: validLayout.1, insets: validLayout.2, isHidden: false, transition: .animated(duration: 0.3, curve: .easeInOut))
        }
    }
    
    @objc func toggleFullscreenPressed() {
        var toLandscape = false
        if let (size, _, _) = self.validLayout, size.width < size.height {
            toLandscape = true
        }
        if toLandscape {
            self.wrapperNode.alpha = 0.0
        }
        self.action?(toLandscape)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.wrapperNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

func optionsBackgroundImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))

        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 14, topCapHeight: 14)
}

private func optionsCircleImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 22.0, height: 22.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))

        context.setStrokeColor(UIColor.white.cgColor)
        let lineWidth: CGFloat = 1.3
        context.setLineWidth(lineWidth)

        context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth, dy: lineWidth))
    })
}

private func optionsRateImage(rate: String, isLarge: Bool, color: UIColor = .white) -> UIImage? {
    return generateImage(isLarge ? CGSize(width: 30.0, height: 30.0) : CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
        UIGraphicsPushContext(context)

        context.clear(CGRect(origin: CGPoint(), size: size))

        if let image = generateTintedImage(image: UIImage(bundleImageName: isLarge ? "Chat/Context Menu/Playspeed30" : "Chat/Context Menu/Playspeed24"), color: .white) {
            image.draw(at: CGPoint(x: 0.0, y: 0.0))
        }

        let string = NSMutableAttributedString(string: rate, font: Font.with(size: isLarge ? 11.0 : 10.0, design: .round, weight: .semibold), textColor: color)

        var offset = CGPoint(x: 1.0, y: 0.0)
        if rate.count >= 3 {
            if rate == "0.5x" {
                string.addAttribute(.kern, value: -0.8 as NSNumber, range: NSRange(string.string.startIndex ..< string.string.endIndex, in: string.string))
                offset.x += -0.5
            } else {
                string.addAttribute(.kern, value: -0.5 as NSNumber, range: NSRange(string.string.startIndex ..< string.string.endIndex, in: string.string))
                offset.x += -0.3
            }
        } else {
            offset.x += -0.3
        }

        if !isLarge {
            offset.x *= 0.5
            offset.y *= 0.5
        }

        let boundingRect = string.boundingRect(with: size, options: [], context: nil)
        string.draw(at: CGPoint(x: offset.x + floor((size.width - boundingRect.width) / 2.0), y: offset.y + floor((size.height - boundingRect.height) / 2.0)))

        UIGraphicsPopContext()
    })
}

private final class MoreHeaderButton: HighlightableButtonNode {
    enum Content {
        case image(UIImage?)
        case more(UIImage?)
    }

    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    private let iconNode: ASImageNode
    private var animationNode: AnimationNode?

    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?

    private let wide: Bool

    init(wide: Bool = false) {
        self.wide = wide

        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.contentMode = .scaleToFill

        super.init()

        self.containerNode.addSubnode(self.referenceNode)
        self.referenceNode.addSubnode(self.iconNode)
        self.addSubnode(self.containerNode)

        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.contextAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }

        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 26.0, height: 44.0))
        self.referenceNode.frame = self.containerNode.bounds

        self.iconNode.image = optionsCircleImage(dark: false)
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
        }

        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -4.0, bottom: 0.0, right: -4.0)
    }

    private var content: Content?
    func setContent(_ content: Content, animated: Bool = false) {
        if case .more = content, self.animationNode == nil {
            let iconColor = UIColor(rgb: 0xffffff)
            let animationNode = AnimationNode(animation: "anim_profilemore", colors: ["Point 2.Group 1.Fill 1": iconColor,
                                                                                      "Point 3.Group 1.Fill 1": iconColor,
                                                                                      "Point 1.Group 1.Fill 1": iconColor], scale: 1.0)
            let animationSize = CGSize(width: 22.0, height: 22.0)
            animationNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - animationSize.width) / 2.0), y: floor((self.containerNode.bounds.height - animationSize.height) / 2.0)), size: animationSize)
            self.addSubnode(animationNode)
            self.animationNode = animationNode
        }
        if animated {
            if let snapshotView = self.referenceNode.view.snapshotContentTree() {
                snapshotView.frame = self.referenceNode.frame
                self.view.addSubview(snapshotView)

                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, removeOnCompletion: false)

                self.iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                self.iconNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3)

                self.animationNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                self.animationNode?.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3)
            }

            switch content {
                case let .image(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.animationNode?.isHidden = true
                case let .more(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.animationNode?.isHidden = false
            }
        } else {
            self.content = content
            switch content {
                case let .image(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.animationNode?.isHidden = true
                case let .more(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.animationNode?.isHidden = false
            }
        }
    }

    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: wide ? 32.0 : 22.0, height: 44.0)
    }

    func onLayout() {
    }

    func play() {
        self.animationNode?.playOnce()
    }
}

@available(iOS 15.0, *)
private final class PictureInPictureContentImpl: NSObject, PictureInPictureContent, AVPictureInPictureControllerDelegate {
    private final class PlaybackDelegate: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
        private let node: UniversalVideoNode
        private var statusDisposable: Disposable?
        private var status: MediaPlayerStatus?
        weak var pictureInPictureController: AVPictureInPictureController?

        init(node: UniversalVideoNode) {
            self.node = node

            super.init()

            self.statusDisposable = (self.node.status
            |> deliverOnMainQueue).start(next: { [weak self] status in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.status = status
                strongSelf.pictureInPictureController?.invalidatePlaybackState()
            })
        }

        deinit {
            self.statusDisposable?.dispose()
        }

        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
            self.node.togglePlayPause()
        }

        public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
            guard let status = self.status else {
                return CMTimeRange(start: CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(30.0)), duration: CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(30.0)))
            }
            return CMTimeRange(start: CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(30.0)), duration: CMTime(seconds: status.duration, preferredTimescale: CMTimeScale(30.0)))
        }

        public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
            guard let status = self.status else {
                return false
            }
            switch status.status {
            case .playing:
                return false
            case .buffering, .paused:
                return true
            }
        }

        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        }

        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
            let node = self.node
            let _ = (self.node.status
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak node] status in
                if let node = node, let timestamp = status?.timestamp, let duration = status?.duration {
                    let nextTimestamp = timestamp + skipInterval.seconds
                    if nextTimestamp > duration {
                        node.seek(0.0)
                        node.pause()
                    } else {
                        node.seek(min(duration, nextTimestamp))
                    }
                }

                completionHandler()
            })
        }

        public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
            return false
        }
    }

    private weak var overlayController: OverlayMediaController?
    private weak var mediaManager: MediaManager?
    private var pictureInPictureController: AVPictureInPictureController?
    private var contentDelegate: PlaybackDelegate?
    private let node: UniversalVideoNode
    private let willBegin: (PictureInPictureContentImpl) -> Void
    private let didEnd: (PictureInPictureContentImpl) -> Void
    private let expand: (@escaping () -> Void) -> Void
    private var pictureInPictureTimer: SwiftSignalKit.Timer?
    private var didExpand: Bool = false

    private var hiddenMediaManagerIndex: Int?

    private var messageRemovedDisposable: Disposable?

    init(context: AccountContext, overlayController: OverlayMediaController, mediaManager: MediaManager, accountId: AccountRecordId, hiddenMedia: (MessageId, Media)?, videoNode: UniversalVideoNode, canSkip: Bool, willBegin: @escaping (PictureInPictureContentImpl) -> Void, didEnd: @escaping (PictureInPictureContentImpl) -> Void, expand: @escaping (@escaping () -> Void) -> Void) {
        self.overlayController = overlayController
        self.mediaManager = mediaManager
        self.node = videoNode
        self.willBegin = willBegin
        self.didEnd = didEnd
        self.expand = expand

        self.node.setCanPlaybackWithoutHierarchy(true)

        super.init()

        let contentDelegate = PlaybackDelegate(node: self.node)
        self.contentDelegate = contentDelegate

        let pictureInPictureController = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: videoNode.getVideoLayer()!, playbackDelegate: contentDelegate))
        self.pictureInPictureController = pictureInPictureController
        contentDelegate.pictureInPictureController = pictureInPictureController
        
        pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = false
        pictureInPictureController.requiresLinearPlayback = !canSkip
        pictureInPictureController.delegate = self
        self.pictureInPictureController = pictureInPictureController
        let timer = SwiftSignalKit.Timer(timeout: 0.005, repeat: true, completion: { [weak self] in
            guard let strongSelf = self, let pictureInPictureController = strongSelf.pictureInPictureController else {
                return
            }
            if pictureInPictureController.isPictureInPicturePossible {
                strongSelf.pictureInPictureTimer?.invalidate()
                strongSelf.pictureInPictureTimer = nil

                pictureInPictureController.startPictureInPicture()
            }
        }, queue: .mainQueue())
        self.pictureInPictureTimer = timer
        timer.start()

        if let hiddenMedia = hiddenMedia {
            self.hiddenMediaManagerIndex = mediaManager.galleryHiddenMediaManager.addSource(Signal<(MessageId, Media)?, NoError>.single(hiddenMedia)
            |> map { messageIdAndMedia in
                if let (messageId, media) = messageIdAndMedia {
                    return .chat(accountId, messageId, media)
                } else {
                    return nil
                }
            })
        }

        if let (messageId, _) = hiddenMedia {
            self.messageRemovedDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> map { message -> Bool in
                if let _ = message {
                    return false
                } else {
                    return true
                }
            }
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                overlayController.removePictureInPictureContent(content: strongSelf)
                strongSelf.node.canAttachContent = false
            })
        }
    }

    deinit {
        self.messageRemovedDisposable?.dispose()
        self.pictureInPictureTimer?.invalidate()
        self.node.setCanPlaybackWithoutHierarchy(false)

        if let hiddenMediaManagerIndex = self.hiddenMediaManagerIndex, let mediaManager = self.mediaManager {
            mediaManager.galleryHiddenMediaManager.removeSource(hiddenMediaManagerIndex)
        }
    }

    var videoNode: ASDisplayNode {
        return self.node
    }

    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Queue.mainQueue().after(0.1, { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.willBegin(strongSelf)

            if let overlayController = strongSelf.overlayController {
                overlayController.setPictureInPictureContentHidden(content: strongSelf, isHidden: true)
            }
        })
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.didEnd(self)
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
    }

    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard let overlayController = self.overlayController else {
            return
        }
        overlayController.removePictureInPictureContent(content: self)
        self.node.canAttachContent = false
        if self.didExpand {
            return
        }
        self.node.continuePlayingWithoutSound()
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        self.expand { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.didExpand = true

            if let overlayController = strongSelf.overlayController {
                overlayController.setPictureInPictureContentHidden(content: strongSelf, isHidden: false)
                strongSelf.node.alpha = 0.02
            }

            completionHandler(true)

            /*Queue.mainQueue().after(0.2, {
                self?.node.canAttachContent = false
            })*/
        }
    }
}

final class UniversalVideoGalleryItemNode: ZoomableContentGalleryItemNode {
    private let context: AccountContext
    private let presentationData: PresentationData
    
    fileprivate let _ready = Promise<Void>()
    fileprivate let _title = Promise<String>()
    fileprivate let _titleView = Promise<UIView?>()
    fileprivate let _rightBarButtonItems = Promise<[UIBarButtonItem]?>()
    
    fileprivate var titleContentView: GalleryTitleView?
    private var scrubberView: ChatVideoGalleryItemScrubberView?
    private let footerContentNode: ChatItemGalleryFooterContentNode
    private let overlayContentNode: UniversalVideoGalleryItemOverlayNode

    private let moreBarButton: MoreHeaderButton
    private var moreBarButtonRate: Double = 1.0
    private var moreBarButtonRateTimestamp: Double?
    
    private var videoNode: UniversalVideoNode?
    private var videoNodeUserInteractionEnabled: Bool = false
    private var videoFramePreview: FramePreview?
    private var pictureInPictureNode: UniversalVideoGalleryItemPictureInPictureNode?
    private var disablePictureInPicturePlaceholder: Bool = false
    private let statusButtonNode: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    private var statusNodeShouldBeHidden = true
    
    private var isCentral: Bool?
    private var _isVisible: Bool?
    private var initiallyActivated = false
    private var hideStatusNodeUntilCentrality = false
    private var playOnContentOwnership = false
    private var skipInitialPause = false
    private var ignorePauseStatus = false
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var didPause = false
    private var isPaused = true
    private var dismissOnOrientationChange = false
    private var keepSoundOnDismiss = false
    private var hasPictureInPicture = false

    private var pictureInPictureButton: UIBarButtonItem?
    
    private var requiresDownload = false
    
    private var item: UniversalVideoGalleryItem?
    private var playbackRate: Double?
    private let playbackRatePromise = ValuePromise<Double>()
    
    private let statusDisposable = MetaDisposable()
    private let moreButtonStateDisposable = MetaDisposable()
    private let mediaPlaybackStateDisposable = MetaDisposable()

    private let fetchDisposable = MetaDisposable()
    private var fetchStatus: MediaResourceStatus?
    private var fetchControls: FetchControls?
    
    private var scrubbingFrame = Promise<FramePreviewResult?>(nil)
    private var scrubbingFrames = false
    private var scrubbingFrameDisposable: Disposable?
    
    private let isPlayingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let isInteractingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let controlsVisiblePromise = ValuePromise<Bool>(true, ignoreRepeated: true)
    private let isShowingContextMenuPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let hasExpandedCaptionPromise = Promise<Bool>()
    private var hideControlsDisposable: Disposable?
    
    var playbackCompleted: (() -> Void)?
    
    private var customUnembedWhenPortrait: ((OverlayMediaItemNode) -> Bool)?

    private var pictureInPictureContent: AnyObject?
    
    init(context: AccountContext, presentationData: PresentationData, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void, openActionOptions: @escaping (GalleryControllerInteractionTapAction, Message) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData

        
        self.footerContentNode = ChatItemGalleryFooterContentNode(context: context, presentationData: presentationData, present: present)
        self.hasExpandedCaptionPromise.set(self.footerContentNode.hasExpandedCaption)
        
        self.footerContentNode.performAction = performAction
        self.footerContentNode.openActionOptions = openActionOptions
        
        self.overlayContentNode = UniversalVideoGalleryItemOverlayNode()
        
        self.statusButtonNode = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
        
        self._title.set(.single(""))

        self.moreBarButton = MoreHeaderButton()
        self.moreBarButton.isUserInteractionEnabled = true
        self.moreBarButton.setContent(.more(optionsCircleImage(dark: false)))
        
        super.init()

        self.moreBarButton.addTarget(self, action: #selector(self.moreButtonPressed), forControlEvents: .touchUpInside)
        
        self.footerContentNode.interacting = { [weak self] value in
            self?.isInteractingPromise.set(value)
        }
        
        self.overlayContentNode.action = { [weak self] toLandscape in
            self?.updateControlsVisibility(!toLandscape)
            self?.updateOrientation(toLandscape ? .landscapeRight : .portrait)
        }
        
        self.statusButtonNode.addSubnode(self.statusNode)
        self.statusButtonNode.addTarget(self, action: #selector(self.statusButtonPressed), forControlEvents: .touchUpInside)
        
        self.addSubnode(self.statusButtonNode)
        
        self.footerContentNode.playbackControl = { [weak self] in
            if let strongSelf = self {
                if !strongSelf.isPaused {
                    strongSelf.didPause = true
                }
                
                strongSelf.videoNode?.togglePlayPause()
            }
        }
        self.footerContentNode.seekBackward = { [weak self] delta in
            if let strongSelf = self, let videoNode = strongSelf.videoNode {
                let _ = (videoNode.status |> take(1)).start(next: { [weak videoNode] status in
                    if let strongVideoNode = videoNode, let timestamp = status?.timestamp {
                        strongVideoNode.seek(max(0.0, timestamp - delta))
                    }
                })
            }
        }
        self.footerContentNode.seekForward = { [weak self] delta in
            if let strongSelf = self, let videoNode = strongSelf.videoNode {
                let _ = (videoNode.status |> take(1)).start(next: { [weak videoNode] status in
                    if let strongVideoNode = videoNode, let timestamp = status?.timestamp, let duration = status?.duration {
                        let nextTimestamp = timestamp + delta
                        if nextTimestamp > duration {
                            strongVideoNode.seek(0.0)
                            strongVideoNode.pause()
                        } else {
                            strongVideoNode.seek(min(duration, timestamp + delta))
                        }
                    }
                })
            }
        }
        
        self.footerContentNode.setPlayRate = { [weak self] rate in
            if let strongSelf = self, let videoNode = strongSelf.videoNode {
                videoNode.setBaseRate(rate)

                if let controller = strongSelf.galleryController() as? GalleryController {
                    controller.updateSharedPlaybackRate(rate)
                }
            }
        }
        
        self.footerContentNode.fetchControl = { [weak self] in
            guard let strongSelf = self, let fetchStatus = strongSelf.fetchStatus, let fetchControls = strongSelf.fetchControls else {
                return
            }
            switch fetchStatus {
                case .Fetching:
                    fetchControls.cancel()
                case .Remote, .Paused:
                    fetchControls.fetch()
                case .Local:
                    break
            }
        }

        self.footerContentNode.toggleFullscreen = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var toLandscape = false
            let size = strongSelf.bounds.size
            if size.width < size.height {
                toLandscape = true
            }
            strongSelf.updateControlsVisibility(!toLandscape)
            strongSelf.updateOrientation(toLandscape ? .landscapeRight : .portrait)
        }
        
        self.scrubbingFrameDisposable = (self.scrubbingFrame.get()
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            if let result = result, strongSelf.scrubbingFrames {
                switch result {
                case .waitingForData:
                    strongSelf.footerContentNode.setFramePreviewImageIsLoading()
                case let .image(image):
                    strongSelf.footerContentNode.setFramePreviewImage(image: image)
                }
            } else {
                strongSelf.footerContentNode.setFramePreviewImage(image: nil)
            }
        })
        
        self.alternativeDismiss = { [weak self] in
            guard let strongSelf = self, strongSelf.hasPictureInPicture else {
                return false
            }
            strongSelf.pictureInPictureButtonPressed()
            return true
        }

        self.moreBarButton.contextAction = { [weak self] sourceNode, gesture in
            self?.openMoreMenu(sourceNode: sourceNode, gesture: gesture)
        }
        
        self.titleContentView = GalleryTitleView(frame: CGRect())
        self._titleView.set(.single(self.titleContentView))
        
        let shouldHideControlsSignal: Signal<Void, NoError> = combineLatest(self.isPlayingPromise.get(), self.isInteractingPromise.get(), self.controlsVisiblePromise.get(), self.isShowingContextMenuPromise.get(), self.hasExpandedCaptionPromise.get())
        |> mapToSignal { isPlaying, isInteracting, controlsVisible, isShowingContextMenu, hasExpandedCaptionPromise -> Signal<Void, NoError> in
            if isShowingContextMenu || hasExpandedCaptionPromise {
                return .complete()
            }
            if isPlaying && !isInteracting && controlsVisible {
                return .single(Void())
                |> delay(4.0, queue: Queue.mainQueue())
            } else {
                return .complete()
            }
        }

        self.hideControlsDisposable = (shouldHideControlsSignal
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.updateControlsVisibility(false)
            }
        })
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.moreButtonStateDisposable.dispose()
        self.mediaPlaybackStateDisposable.dispose()
        self.scrubbingFrameDisposable?.dispose()
        self.hideControlsDisposable?.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        if let _ = self.customUnembedWhenPortrait, layout.size.width < layout.size.height {
            self.expandIntoCustomPiP()
        }
        
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        var dismiss = false
        if let (previousLayout, _) = self.validLayout, self.dismissOnOrientationChange, previousLayout.size.width > previousLayout.size.height && previousLayout.size.height == layout.size.width {
            dismiss = true
        }
        let hadLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        if !hadLayout {
            self.zoomableContent = zoomableContent
        }
        
        let statusDiameter: CGFloat = 50.0
        let statusFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusDiameter) / 2.0), y: floor((layout.size.height - statusDiameter) / 2.0)), size: CGSize(width: statusDiameter, height: statusDiameter))
        transition.updateFrame(node: self.statusButtonNode, frame: statusFrame)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(), size: statusFrame.size))
        
        if let pictureInPictureNode = self.pictureInPictureNode {
            if let item = self.item {
                let placeholderSize = item.content.dimensions.fitted(layout.size)
                transition.updateFrame(node: pictureInPictureNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - placeholderSize.width) / 2.0), y: floor((layout.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
                pictureInPictureNode.updateLayout(placeholderSize, transition: transition)
            }
        }
                
        if dismiss {
            self.dismiss()
        }
    }
    
    func setupItem(_ item: UniversalVideoGalleryItem) {
        if self.item?.content.id != item.content.id {
            func parseChapters(_ string: NSAttributedString) -> [MediaPlayerScrubbingChapter] {
                var timecodeRanges: [(NSRange, TelegramTimecode)] = []
                var lineRanges: [NSRange] = []
                string.enumerateAttributes(in: NSMakeRange(0, string.length), options: [], using: { attributes, range, _ in
                    if let timecode = attributes[NSAttributedString.Key(TelegramTextAttributes.Timecode)] as? TelegramTimecode {
                        timecodeRanges.append((range, timecode))
                    }
                })
                (string.string as NSString).enumerateSubstrings(in: NSMakeRange(0, string.length), options: .byLines, using: { _, range, _, _ in
                    lineRanges.append(range)
                })
                
                var chapters: [MediaPlayerScrubbingChapter] = []
                for (timecodeRange, timecode) in timecodeRanges {
                    inner: for lineRange in lineRanges {
                        if lineRange.contains(timecodeRange.location) {
                            if lineRange.length > timecodeRange.length {
                                var title = ((string.string as NSString).substring(with: lineRange) as NSString).replacingCharacters(in: NSMakeRange(timecodeRange.location - lineRange.location, timecodeRange.length), with: "")
                                title = title.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters)
                                chapters.append(MediaPlayerScrubbingChapter(title: title, start: timecode.time))
                            }
                            break inner
                        }
                    }
                }
                return chapters
            }
            
            var chapters = parseChapters(item.caption)
            if chapters.isEmpty, let description = item.description {
                chapters = parseChapters(description)
            }
            let scrubberView = ChatVideoGalleryItemScrubberView(chapters: chapters)
            self.scrubberView = scrubberView
            scrubberView.seek = { [weak self] timecode in
                self?.videoNode?.seek(timecode)
            }
            scrubberView.updateScrubbing = { [weak self] timecode in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.isInteractingPromise.set(timecode != nil)
                
                if let videoFramePreview = strongSelf.videoFramePreview {
                    if let timecode = timecode {
                        if !strongSelf.scrubbingFrames {
                            strongSelf.scrubbingFrames = true
                            strongSelf.scrubbingFrame.set(videoFramePreview.generatedFrames
                            |> map(Optional.init))
                        }
                        videoFramePreview.generateFrame(at: timecode)
                    } else {
                        strongSelf.isInteractingPromise.set(false)
                        strongSelf.scrubbingFrame.set(.single(nil))
                        videoFramePreview.cancelPendingFrames()
                        strongSelf.scrubbingFrames = false
                    }
                }
            }
            self.footerContentNode.scrubberView = scrubberView
            
            self.isPlayingPromise.set(false)
            
            if item.hideControls {
                self.statusButtonNode.isHidden = true
            }
                        
            self.dismissOnOrientationChange = item.landscape
            
            var hasLinkedStickers = false
            if let content = item.content as? NativeVideoContent {
                hasLinkedStickers = content.fileReference.media.hasLinkedStickers
            }
            
            var disablePictureInPicture = false
            var disablePlayerControls = false
            var forceEnablePiP = false
            var forceEnableUserInteraction = false
            var isAnimated = false
            var isEnhancedWebPlayer = false
            if let content = item.content as? NativeVideoContent {
                isAnimated = content.fileReference.media.isAnimated
                self.videoFramePreview = MediaPlayerFramePreview(postbox: item.context.account.postbox, fileReference: content.fileReference)
            } else if let _ = item.content as? SystemVideoContent {
                self._title.set(.single(item.presentationData.strings.Message_Video))
            } else if let content = item.content as? WebEmbedVideoContent {
                let type = webEmbedType(content: content.webpageContent)
                switch type {
                    case .youtube:
                        isEnhancedWebPlayer = true
                        forceEnableUserInteraction = true
                        disablePictureInPicture = !(item.configuration?.youtubePictureInPictureEnabled ?? false)
                        self.videoFramePreview = YoutubeEmbedFramePreview(context: item.context, content: content)
                    case .vimeo:
                        isEnhancedWebPlayer = true
                    case .iframe:
                        disablePlayerControls = true
                    default:
                        break
                }
            } else if let _ = item.content as? PlatformVideoContent {
                disablePlayerControls = true
                forceEnablePiP = true
            }
            
            let dimensions = item.content.dimensions
            if dimensions.height > 0.0 {
                if dimensions.width / dimensions.height < 1.33 || isAnimated {
                    self.overlayContentNode.isHidden = true
                }
            }
            
            if let videoNode = self.videoNode {
                videoNode.canAttachContent = false
                videoNode.removeFromSupernode()
            }
            
            if isAnimated || disablePlayerControls {
                self.footerContentNode.scrubberView = nil
            }
            
            let mediaManager = item.context.sharedContext.mediaManager
            
            let videoNode = UniversalVideoNode(postbox: item.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: item.content, priority: .gallery)
            let videoScale: CGFloat
            if item.content is WebEmbedVideoContent {
                videoScale = 1.0
            } else {
                videoScale = 2.0
            }
            let videoSize = CGSize(width: item.content.dimensions.width * videoScale, height: item.content.dimensions.height * videoScale)
            videoNode.updateLayout(size: videoSize, transition: .immediate)
            videoNode.ownsContentNodeUpdated = { [weak self] value in
                if let strongSelf = self {
                    strongSelf.updateDisplayPlaceholder(!value)
                    
                    if strongSelf.playOnContentOwnership {
                        strongSelf.playOnContentOwnership = false
                        strongSelf.initiallyActivated = true
                        strongSelf.skipInitialPause = true
                        if let item = strongSelf.item, let _ = item.content as? PlatformVideoContent {
                            strongSelf.videoNode?.play()
                        } else {
                            strongSelf.videoNode?.playOnceWithSound(playAndRecord: false, actionAtEnd: isAnimated ? .loop : strongSelf.actionAtEnd)
                        }

                        if let playbackRate = strongSelf.playbackRate {
                            strongSelf.videoNode?.setBaseRate(playbackRate)
                        }
                    }
                }
            }
            self.videoNode = videoNode
            self.videoNodeUserInteractionEnabled = disablePlayerControls || forceEnableUserInteraction
            videoNode.isUserInteractionEnabled = disablePlayerControls || forceEnableUserInteraction
            videoNode.backgroundColor = videoNode.ownsContentNode ? UIColor.black : UIColor(rgb: 0x333335)
            if item.fromPlayingVideo {
                videoNode.canAttachContent = false
            } else {
                self.updateDisplayPlaceholder(!videoNode.ownsContentNode)
            }
            
            scrubberView.setStatusSignal(videoNode.status |> map { value -> MediaPlayerStatus in
                if let value = value, !value.duration.isZero {
                    return value
                } else {
                    return MediaPlayerStatus(generationTimestamp: 0.0, duration: max(Double(item.content.duration), 0.01), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                }
            })
            
            scrubberView.setBufferingStatusSignal(videoNode.bufferingStatus)
            
            self.requiresDownload = true
            var mediaFileStatus: Signal<MediaResourceStatus?, NoError> = .single(nil)
            
            var hintSeekable = false
            if let contentInfo = item.contentInfo, case let .message(message) = contentInfo {
                if Namespaces.Message.allScheduled.contains(message.id.namespace) {
                    disablePictureInPicture = true
                } else {
                    let throttledSignal = videoNode.status
                    |> mapToThrottled { next -> Signal<MediaPlayerStatus?, NoError> in
                        return .single(next) |> then(.complete() |> delay(0.5, queue: Queue.concurrentDefaultQueue()))
                    }
                    
                    self.mediaPlaybackStateDisposable.set((throttledSignal
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        guard let strongSelf = self, let videoNode = strongSelf.videoNode, videoNode.ownsContentNode else {
                            return
                        }

                        if let status = status, status.duration >= 60.0 * 10.0 {
                            var timestamp: Double?
                            if status.timestamp > 5.0 && status.timestamp < status.duration - 5.0 {
                                timestamp = status.timestamp
                            }
                            item.storeMediaPlaybackState(message.id, timestamp, status.baseRate)
                        }
                    }))
                }
                
                var file: TelegramMediaFile?
                var isWebpage = false
                for m in message.media {
                    if let m = m as? TelegramMediaFile, m.isVideo {
                        file = m
                        break
                    } else if let m = m as? TelegramMediaWebpage, case let .Loaded(content) = m.content, let f = content.file, f.isVideo {
                        file = f
                        isWebpage = true
                        break
                    }
                }
                if let file = file {
                    for attribute in file.attributes {
                        if case let .Video(duration, _, _) = attribute, duration >= 30 {
                            hintSeekable = true
                            break
                        }
                    }
                    let status = messageMediaFileStatus(context: item.context, messageId: message.id, file: file)
                    if !isWebpage {
                        scrubberView.setFetchStatusSignal(status, strings: self.presentationData.strings, decimalSeparator: self.presentationData.dateTimeFormat.decimalSeparator, fileSize: file.size)
                    }
                    
                    self.requiresDownload = !isMediaStreamable(message: message, media: file)
                    mediaFileStatus = status |> map(Optional.init)
                    self.fetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: item.context, message: message, file: file, userInitiated: true).start())
                        }
                    }, cancel: {
                        messageMediaFileCancelInteractiveFetch(context: item.context, messageId: message.id, file: file)
                    })
                }
            }

            self.moreButtonStateDisposable.set(combineLatest(queue: .mainQueue(),
                self.playbackRatePromise.get(),
                self.isShowingContextMenuPromise.get()
            ).start(next: { [weak self] playbackRate, isShowingContextMenu in
                guard let strongSelf = self else {
                    return
                }

                let effectiveBaseRate: Double
                if isShowingContextMenu {
                    effectiveBaseRate = 1.0
                } else {
                    effectiveBaseRate = playbackRate
                }

                if abs(effectiveBaseRate - strongSelf.moreBarButtonRate) > 0.01 {
                    strongSelf.moreBarButtonRate = effectiveBaseRate
                    let animated: Bool
                    if let moreBarButtonRateTimestamp = strongSelf.moreBarButtonRateTimestamp {
                        animated = CFAbsoluteTimeGetCurrent() > (moreBarButtonRateTimestamp + 0.2)
                    } else {
                        animated = false
                    }
                    strongSelf.moreBarButtonRateTimestamp = CFAbsoluteTimeGetCurrent()

                    if abs(effectiveBaseRate - 1.0) > 0.01 {
                        let rateString: String
                        if abs(effectiveBaseRate - 0.5) < 0.01 {
                            rateString = "0.5x"
                        } else if abs(effectiveBaseRate - 1.5) < 0.01 {
                            rateString = "1.5x"
                        } else if abs(effectiveBaseRate - 2.0) < 0.01 {
                            rateString = "2x"
                        } else {
                            rateString = "x"
                        }
                        strongSelf.moreBarButton.setContent(.image(optionsRateImage(rate: rateString, isLarge: true)), animated: animated)
                    } else {
                        strongSelf.moreBarButton.setContent(.more(optionsCircleImage(dark: false)), animated: animated)
                    }
                } else {
                    if strongSelf.moreBarButtonRateTimestamp == nil {
                        strongSelf.moreBarButtonRateTimestamp = CFAbsoluteTimeGetCurrent()
                    }
                }
            }))

            self.statusDisposable.set((combineLatest(queue: .mainQueue(), videoNode.status, mediaFileStatus)
            |> deliverOnMainQueue).start(next: { [weak self] value, fetchStatus in
                if let strongSelf = self {
                    var initialBuffering = false
                    var isPlaying = false
                    var isPaused = true
                    var seekable = hintSeekable
                    var hasStarted = false
                    var displayProgress = true
                    if let value = value {
                        hasStarted = value.timestamp > 0
                        
                        if let zoomableContent = strongSelf.zoomableContent, !value.dimensions.width.isZero && !value.dimensions.height.isZero {
                            let videoSize = CGSize(width: value.dimensions.width * 2.0, height: value.dimensions.height * 2.0)
                            if !zoomableContent.0.equalTo(videoSize) {
                                strongSelf.zoomableContent = (videoSize, zoomableContent.1)
                                strongSelf.videoNode?.updateLayout(size: videoSize, transition: .immediate)
                            }
                        }
                        switch value.status {
                            case .playing:
                                isPaused = false
                                isPlaying = true
                                strongSelf.ignorePauseStatus = false
                            case let .buffering(_, whilePlaying, _, display):
                                displayProgress = display
                                initialBuffering = !whilePlaying
                                isPaused = !whilePlaying
                                var isStreaming = false
                                if let fetchStatus = strongSelf.fetchStatus {
                                    switch fetchStatus {
                                        case .Local:
                                            break
                                        default:
                                            isStreaming = true
                                    }
                                } else {
                                    switch fetchStatus {
                                        case .Local:
                                            break
                                        default:
                                            isStreaming = true
                                    }
                                }
                                if let content = item.content as? NativeVideoContent, !isStreaming {
                                    initialBuffering = false
                                    if !content.enableSound {
                                        isPaused = false
                                    }
                                }
                            default:
                                if let content = item.content as? NativeVideoContent, !content.streamVideo.enabled {
                                    if !content.enableSound {
                                        isPaused = false
                                    }
                                } else if strongSelf.actionAtEnd == .stop {
                                    strongSelf.isPlayingPromise.set(false)
                                    if strongSelf.isCentral == true {
                                        strongSelf.updateControlsVisibility(true)
                                    }
                                }
                        }
                        if !value.duration.isZero {
                            seekable = value.duration >= 30.0
                        }
                    }
                    
                    if !disablePlayerControls && strongSelf.isCentral == true && isPlaying {
                        strongSelf.isPlayingPromise.set(true)
                    } else if !isPlaying {
                        strongSelf.isPlayingPromise.set(false)
                    }
                    
                    var fetching = false
                    if initialBuffering {
                        if displayProgress {
                            strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: nil, cancelEnabled: false, animateRotation: true), animated: false, completion: {})
                        } else {
                            strongSelf.statusNode.transitionToState(.none, animated: false, completion: {})
                        }
                    } else {
                        var state: RadialStatusNodeState = .play(.white)
                        
                        if let fetchStatus = fetchStatus {
                            if strongSelf.requiresDownload {
                                switch fetchStatus {
                                    case .Remote:
                                        state = .download(.white)
                                    case let .Fetching(_, progress):
                                        if !isPlaying {
                                            fetching = true
                                            isPaused = true
                                        }
                                        state = .progress(color: .white, lineWidth: nil, value: CGFloat(progress), cancelEnabled: true, animateRotation: true)
                                    default:
                                        break
                                }
                            }
                        }
                        strongSelf.statusNode.transitionToState(state, animated: false, completion: {})
                    }
                    
                    strongSelf.isPaused = isPaused
                    strongSelf.fetchStatus = fetchStatus
                    
                    if !item.hideControls {
                        strongSelf.statusNodeShouldBeHidden = strongSelf.ignorePauseStatus || (!initialBuffering && (strongSelf.didPause || !isPaused) && !fetching)
                        strongSelf.statusButtonNode.isHidden = strongSelf.hideStatusNodeUntilCentrality || strongSelf.statusNodeShouldBeHidden
                    }
                    
                    if isAnimated || disablePlayerControls {
                        strongSelf.footerContentNode.content = .info
                    } else if isPaused && !strongSelf.ignorePauseStatus {
                        if hasStarted || strongSelf.didPause {
                            strongSelf.footerContentNode.content = .playback(paused: true, seekable: seekable)
                        } else if let fetchStatus = fetchStatus, !strongSelf.requiresDownload {
                            strongSelf.footerContentNode.content = .fetch(status: fetchStatus, seekable: seekable)
                        }
                    } else {
                        strongSelf.footerContentNode.content = .playback(paused: false, seekable: seekable)
                    }
                }
            }))
            
            self.zoomableContent = (videoSize, videoNode)
                        
            var barButtonItems: [UIBarButtonItem] = []
            if hasLinkedStickers {
                let rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/Stickers"), color: .white), style: .plain, target: self, action: #selector(self.openStickersButtonPressed))
                barButtonItems.append(rightBarButtonItem)
            }
            if forceEnablePiP || (!isAnimated && !disablePlayerControls && !disablePictureInPicture) {
                let rightBarButtonItem = UIBarButtonItem(image: pictureInPictureButtonImage, style: .plain, target: self, action: #selector(self.pictureInPictureButtonPressed))
                self.pictureInPictureButton = rightBarButtonItem
                barButtonItems.append(rightBarButtonItem)
                self.hasPictureInPicture = true
            } else {
                self.hasPictureInPicture = false
            }

            if let contentInfo = item.contentInfo, case let .message(message) = contentInfo {
                var file: TelegramMediaFile?
                for m in message.media {
                    if let m = m as? TelegramMediaFile, m.isVideo {
                        file = m
                        break
                    } else if let m = m as? TelegramMediaWebpage, case let .Loaded(content) = m.content, let f = content.file, f.isVideo {
                        file = f
                        break
                    }
                }

                var hasMoreButton = false
                if isEnhancedWebPlayer {
                    hasMoreButton = true
                } else if let file = file, !file.isAnimated {
                    hasMoreButton = true
                }
                 
                if hasMoreButton {
                    let moreMenuItem = UIBarButtonItem(customDisplayNode: self.moreBarButton)!
                    barButtonItems.append(moreMenuItem)
                }
            }

            self._rightBarButtonItems.set(.single(barButtonItems))
        
            videoNode.playbackCompleted = { [weak self, weak videoNode] in
                Queue.mainQueue().async {
                    item.playbackCompleted()
                    if let strongSelf = self, !isAnimated {
                        if let snapshotView = videoNode?.view.snapshotView(afterScreenUpdates: false) {
                            videoNode?.view.addSubview(snapshotView)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                        
                        videoNode?.seek(0.0)
                                                
                        if strongSelf.actionAtEnd == .stop && strongSelf.isCentral == true {
                            strongSelf.isPlayingPromise.set(false)
                            strongSelf.updateControlsVisibility(true)
                        }
                    }
                }
            }

            self._ready.set(videoNode.ready)
        }
        
        self.item = item

        if let _ = item.content as? NativeVideoContent {
            self.playbackRate = item.playbackRate()
        } else if let _ = item.content as? WebEmbedVideoContent {
            self.playbackRate = item.playbackRate()
        }

        self.playbackRatePromise.set(self.playbackRate ?? 1.0)
        
        if let contentInfo = item.contentInfo {
            switch contentInfo {
                case let .message(message):
                    self.footerContentNode.setMessage(message, displayInfo: !item.displayInfoOnTop)
                case let .webPage(webPage, media, _):
                    self.footerContentNode.setWebPage(webPage, media: media)
            }
        }
        self.footerContentNode.setup(origin: item.originData, caption: item.caption)
    }
    
    override func controlsVisibilityUpdated(isVisible: Bool) {
        self.controlsVisiblePromise.set(isVisible)
        
        self.videoNode?.isUserInteractionEnabled = isVisible ? self.videoNodeUserInteractionEnabled : false
        self.videoNode?.notifyPlaybackControlsHidden(!isVisible)
    }
    
    private func updateDisplayPlaceholder(_ displayPlaceholder: Bool) {
        if displayPlaceholder && !self.disablePictureInPicturePlaceholder {
            if self.pictureInPictureNode == nil {
                let pictureInPictureNode = UniversalVideoGalleryItemPictureInPictureNode(strings: self.presentationData.strings)
                pictureInPictureNode.isUserInteractionEnabled = false
                self.pictureInPictureNode = pictureInPictureNode
                self.insertSubnode(pictureInPictureNode, aboveSubnode: self.scrollNode)
                if let validLayout = self.validLayout {
                    if let item = self.item {
                        let placeholderSize = item.content.dimensions.fitted(validLayout.0.size)
                        pictureInPictureNode.frame = CGRect(origin: CGPoint(x: floor((validLayout.0.size.width - placeholderSize.width) / 2.0), y: floor((validLayout.0.size.height - placeholderSize.height) / 2.0)), size: placeholderSize)
                        pictureInPictureNode.updateLayout(placeholderSize, transition: .immediate)
                    }
                }
                self.videoNode?.backgroundColor = UIColor(rgb: 0x333335)
            }
        } else if let pictureInPictureNode = self.pictureInPictureNode {
            self.pictureInPictureNode = nil
            pictureInPictureNode.removeFromSupernode()
            self.videoNode?.backgroundColor = .black
        }

        self.pictureInPictureButton?.isEnabled = self.pictureInPictureNode == nil
    }
    
    private func shouldAutoplayOnCentrality() -> Bool {
        if let item = self.item, let content = item.content as? NativeVideoContent {
            var isLocal = false
            if let fetchStatus = self.fetchStatus, case .Local = fetchStatus {
                isLocal = true
            }
            var isStreamable = false
            if let contentInfo = item.contentInfo, case let .message(message) = contentInfo {
                isStreamable = isMediaStreamable(message: message, media: content.fileReference.media)
            } else {
                isStreamable = isMediaStreamable(media: content.fileReference.media)
            }
            if isLocal || isStreamable {
                return true
            }
        } else if let item = self.item, let _ = item.content as? PlatformVideoContent {
            return true
        }
        return false
    }
    
    override func centralityUpdated(isCentral: Bool) {
        super.centralityUpdated(isCentral: isCentral)
        
        if self.isCentral != isCentral {
            self.isCentral = isCentral
            
            if let videoNode = self.videoNode {
                if isCentral {
                    var isAnimated = false
                    if let item = self.item, let content = item.content as? NativeVideoContent {
                        isAnimated = content.fileReference.media.isAnimated
                    }
                    
                    self.hideStatusNodeUntilCentrality = false
                    self.statusButtonNode.isHidden = self.hideStatusNodeUntilCentrality || self.statusNodeShouldBeHidden

                    if videoNode.ownsContentNode {
                        if isAnimated {
                            videoNode.seek(0.0)
                            videoNode.play()
                        } else if self.shouldAutoplayOnCentrality()  {
                            self.initiallyActivated = true
                            videoNode.playOnceWithSound(playAndRecord: false, actionAtEnd: self.actionAtEnd)

                            videoNode.setBaseRate(self.playbackRate ?? 1.0)
                        }
                    } else {
                        if self.shouldAutoplayOnCentrality()  {
                            self.playOnContentOwnership = true
                        }
                    }
                } else {
                    self.isPlayingPromise.set(false)
                    
                    self.dismissOnOrientationChange = false
                    if videoNode.ownsContentNode {
                        videoNode.pause()
                    }
                }
            }
        }
    }
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if self._isVisible != isVisible {
            let hadPreviousValue = self._isVisible != nil
            self._isVisible = isVisible
            
            if let item = self.item, let videoNode = self.videoNode {
                if hadPreviousValue {
                    videoNode.canAttachContent = isVisible
                    if isVisible {
                        if self.skipInitialPause {
                            self.skipInitialPause = false
                        } else {
                            self.ignorePauseStatus = true
                            videoNode.pause()
                            videoNode.seek(0.0)
                        }
                    } else {
                        videoNode.continuePlayingWithoutSound()
                    }
                    self.updateDisplayPlaceholder(!videoNode.ownsContentNode)
                } else if !item.fromPlayingVideo {
                    videoNode.canAttachContent = isVisible
                    self.updateDisplayPlaceholder(!videoNode.ownsContentNode)
                }
                if self.shouldAutoplayOnCentrality() {
                    self.hideStatusNodeUntilCentrality = true
                    self.statusButtonNode.isHidden = true
                }
            }
        }
    }
    
    override func processAction(_ action: GalleryControllerItemNodeAction) {
        guard let videoNode = self.videoNode else {
            return
        }
        
        switch action {
            case let .timecode(timecode):
                self.scrubberView?.animateTo(timecode)
                videoNode.seek(timecode)
        }
    }
    
    override func activateAsInitial() {
        if let videoNode = self.videoNode, self.isCentral == true {
            self.initiallyActivated = true

            var isAnimated = false
            var seek = MediaPlayerSeek.start
            if let item = self.item {
                if let content = item.content as? NativeVideoContent {
                    isAnimated = content.fileReference.media.isAnimated
                    if let time = item.timecode {
                        seek = .timecode(time)
                    }
                } else if let _ = item.content as? WebEmbedVideoContent {
                    if let time = item.timecode {
                        seek = .timecode(time)
                    }
                }
            }

            videoNode.setBaseRate(self.playbackRate ?? 1.0)

            if isAnimated {
                videoNode.seek(0.0)
                videoNode.play()
            } else {
                self.hideStatusNodeUntilCentrality = false
                self.statusButtonNode.isHidden = self.hideStatusNodeUntilCentrality || self.statusNodeShouldBeHidden
                videoNode.playOnceWithSound(playAndRecord: false, seek: seek, actionAtEnd: self.actionAtEnd)
            }
        }
    }
    
    private var actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd {
        if let item = self.item {
            if !item.isSecret, let content = item.content as? NativeVideoContent, content.duration <= 30 {
                return .loop
            }
        }
        return .stop
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode else {
            return
        }
        
        if let node = node.0 as? OverlayMediaItemNode {
            self.customUnembedWhenPortrait = node.customUnembedWhenPortrait
            node.customUnembedWhenPortrait = nil
        }
        
        if let node = node.0 as? OverlayMediaItemNode, self.context.sharedContext.mediaManager.hasOverlayVideoNode(node) {
            var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
            let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
            
            videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            
            transformedFrame.origin = CGPoint()
            
            let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
            videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
            
            videoNode.canAttachContent = true
            self.updateDisplayPlaceholder(!videoNode.ownsContentNode)
            
            self.context.sharedContext.mediaManager.setOverlayVideoNode(nil)
        } else {
            var transformedFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view)
            var transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view.superview)
            var transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
            let transformedCopyViewFinalFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
            
            let (maybeSurfaceCopyView, _) = node.2()
            let (maybeCopyView, copyViewBackground) = node.2()
            copyViewBackground?.alpha = 0.0
            let surfaceCopyView = maybeSurfaceCopyView!
            let copyView = maybeCopyView!
            
            addToTransitionSurface(surfaceCopyView)
            
            var transformedSurfaceFrame: CGRect?
            var transformedSurfaceFinalFrame: CGRect?
            if let contentSurface = surfaceCopyView.superview {
                transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
                transformedSurfaceFinalFrame = videoNode.view.convert(videoNode.view.bounds, to: contentSurface)
                
                if let frame = transformedSurfaceFrame, frame.minY < 0.0 {
                    transformedSurfaceFrame = CGRect(x: frame.minX, y: 0.0, width: frame.width, height: frame.height)
                }
            }
            
            if transformedSelfFrame.maxY < 0.0 {
                transformedSelfFrame = CGRect(x: transformedSelfFrame.minX, y: 0.0, width: transformedSelfFrame.width, height: transformedSelfFrame.height)
            }
            
            if transformedSuperFrame.maxY < 0.0 {
                transformedSuperFrame = CGRect(x: transformedSuperFrame.minX, y: 0.0, width: transformedSuperFrame.width, height: transformedSuperFrame.height)
            }
            
            if let transformedSurfaceFrame = transformedSurfaceFrame {
                surfaceCopyView.frame = transformedSurfaceFrame
            }
            
            self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
            copyView.frame = transformedSelfFrame
            
            copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
            
            surfaceCopyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            
            copyView.layer.animatePosition(from: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), to: CGPoint(x: transformedCopyViewFinalFrame.midX, y: transformedCopyViewFinalFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak copyView] _ in
                copyView?.removeFromSuperview()
            })
            let scale = CGSize(width: transformedCopyViewFinalFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewFinalFrame.size.height / transformedSelfFrame.size.height)
            copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
            
            if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedSurfaceFinalFrame = transformedSurfaceFinalFrame {
                surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), to: CGPoint(x: transformedSurfaceFinalFrame.midX, y: transformedSurfaceFinalFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak surfaceCopyView] _ in
                    surfaceCopyView?.removeFromSuperview()
                })
                let scale = CGSize(width: transformedSurfaceFinalFrame.size.width / transformedSurfaceFrame.size.width, height: transformedSurfaceFinalFrame.size.height / transformedSurfaceFrame.size.height)
                surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
            }
            
            if surfaceCopyView.superview != nil {
                videoNode.allowsGroupOpacity = true
                videoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { [weak videoNode] _ in
                    videoNode?.allowsGroupOpacity = false
                })
            }
            videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            
            transformedFrame.origin = CGPoint()
            
            let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
            
            videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
            
            if self.item?.fromPlayingVideo ?? false {
                Queue.mainQueue().after(0.001) {
                    videoNode.canAttachContent = true
                    self.updateDisplayPlaceholder(!videoNode.ownsContentNode)
                }
            }
            
            if let pictureInPictureNode = self.pictureInPictureNode {
                let transformedPlaceholderFrame = node.0.view.convert(node.0.view.bounds, to: pictureInPictureNode.view)
                let transform = CATransform3DScale(pictureInPictureNode.layer.transform, transformedPlaceholderFrame.size.width / pictureInPictureNode.layer.bounds.size.width, transformedPlaceholderFrame.size.height / pictureInPictureNode.layer.bounds.size.height, 1.0)
                pictureInPictureNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: pictureInPictureNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
                
                pictureInPictureNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                pictureInPictureNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: pictureInPictureNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            }
            
            self.statusButtonNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusButtonNode.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            self.statusButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            self.statusButtonNode.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode else {
            completion()
            return
        }
        
        let transformedFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view)
        var transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: videoNode.view.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
        
        var positionCompleted = false
        var transformCompleted = false
        var boundsCompleted = true
        var copyCompleted = false
        
        let (maybeSurfaceCopyView, _) = node.2()
        let (maybeCopyView, copyViewBackground) = node.2()
        copyViewBackground?.alpha = 0.0
        let surfaceCopyView = maybeSurfaceCopyView!
        let copyView = maybeCopyView!
        
        addToTransitionSurface(surfaceCopyView)
        
        var transformedSurfaceFrame: CGRect?
        var transformedSurfaceCopyViewInitialFrame: CGRect?
        if let contentSurface = surfaceCopyView.superview {
            transformedSurfaceFrame = node.0.view.convert(node.0.view.bounds, to: contentSurface)
            transformedSurfaceCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: contentSurface)
        }
        
        self.view.insertSubview(copyView, belowSubview: self.scrollNode.view)
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView, weak surfaceCopyView] in
            if positionCompleted && transformCompleted && boundsCompleted && copyCompleted {
                copyView?.removeFromSuperview()
                surfaceCopyView?.removeFromSuperview()
                videoNode.canAttachContent = false
                videoNode.removeFromSupernode()
                completion()
            }
        }
        
        copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false)
        surfaceCopyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        if let transformedSurfaceFrame = transformedSurfaceFrame, let transformedCopyViewInitialFrame = transformedSurfaceCopyViewInitialFrame {
            surfaceCopyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSurfaceFrame.midX, y: transformedSurfaceFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSurfaceFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSurfaceFrame.size.height)
            surfaceCopyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false)
        }
        
        self.statusButtonNode.layer.animatePosition(from: self.statusButtonNode.layer.position, to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
        })
        self.statusButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.statusButtonNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
        
        let fromTransform: CATransform3D
        let toTransform: CATransform3D
        
        if let instantNode = node.0 as? GalleryItemTransitionNode, instantNode.isAvailableForInstantPageTransition(), videoNode.hasAttachedContext {
            copyView.removeFromSuperview()
            
            let previousFrame = videoNode.frame
            let previousSuperview = videoNode.view.superview
            addToTransitionSurface(videoNode.view)
            videoNode.view.superview?.bringSubviewToFront(videoNode.view)
            
            if let previousSuperview = previousSuperview {
                videoNode.frame = previousSuperview.convert(previousFrame, to: videoNode.view.superview)
                transformedSuperFrame = transformedSuperFrame.offsetBy(dx: videoNode.position.x - previousFrame.center.x, dy: videoNode.position.y - previousFrame.center.y)
            }
            
            let initialScale: CGFloat = 1.0
            let targetScale = max(transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height)
            
            videoNode.backgroundColor = .clear
        
            let transformScale: CGFloat = initialScale * targetScale
            fromTransform = CATransform3DScale(videoNode.layer.transform, initialScale, initialScale, 1.0)
            toTransform = CATransform3DScale(videoNode.layer.transform, transformScale, transformScale, 1.0)
            
            if videoNode.hasAttachedContext {
                if self.isPaused || !self.keepSoundOnDismiss {
                    videoNode.continuePlayingWithoutSound()
                }
            }
        } else if let interactiveMediaNode = node.0 as? GalleryItemTransitionNode, interactiveMediaNode.isAvailableForGalleryTransition(), videoNode.hasAttachedContext {
            copyView.removeFromSuperview()
            
            let previousFrame = videoNode.frame
            let previousSuperview = videoNode.view.superview
            addToTransitionSurface(videoNode.view)
            videoNode.view.superview?.bringSubviewToFront(videoNode.view)
            
            if let previousSuperview = previousSuperview {
                videoNode.frame = previousSuperview.convert(previousFrame, to: videoNode.view.superview)
                transformedSuperFrame = transformedSuperFrame.offsetBy(dx: videoNode.position.x - previousFrame.center.x, dy: videoNode.position.y - previousFrame.center.y)
            }
            
            let initialScale = min(videoNode.layer.bounds.width / node.0.view.bounds.width, videoNode.layer.bounds.height / node.0.view.bounds.height)
            let targetScale = max(transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height)
            
            videoNode.backgroundColor = .clear
            if let bubbleDecoration = interactiveMediaNode.decoration as? ChatBubbleVideoDecoration, let decoration = videoNode.decoration as? GalleryVideoDecoration  {
                transformedSuperFrame = transformedSuperFrame.offsetBy(dx: bubbleDecoration.corners.extendedEdges.right / 2.0 - bubbleDecoration.corners.extendedEdges.left / 2.0, dy: 0.0)
                if let item = self.item {
                    let size = item.content.dimensions.aspectFilled(bubbleDecoration.contentContainerNode.frame.size)
                    videoNode.updateLayout(size: size, transition: .immediate)
                    videoNode.bounds = CGRect(origin: CGPoint(), size: size)
                
                    boundsCompleted = false
                    decoration.updateCorners(bubbleDecoration.corners)
                    decoration.updateClippingFrame(bubbleDecoration.contentContainerNode.bounds, completion: {
                        boundsCompleted = true
                        intermediateCompletion()
                    })
                }
            }
        
            let transformScale: CGFloat = initialScale * targetScale
            fromTransform = CATransform3DScale(videoNode.layer.transform, initialScale, initialScale, 1.0)
            toTransform = CATransform3DScale(videoNode.layer.transform, transformScale, transformScale, 1.0)
            
            if videoNode.hasAttachedContext {
                if self.isPaused || !self.keepSoundOnDismiss {
                    videoNode.continuePlayingWithoutSound()
                }
            }
        } else {
            videoNode.allowsGroupOpacity = true
            videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
                videoNode?.allowsGroupOpacity = false
            })
            
            fromTransform = videoNode.layer.transform
            toTransform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
        }
        
        videoNode.layer.animatePosition(from: videoNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        videoNode.layer.animate(from: NSValue(caTransform3D: fromTransform), to: NSValue(caTransform3D: toTransform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            transformCompleted = true
            intermediateCompletion()
        })
        
        if let pictureInPictureNode = self.pictureInPictureNode {
            let transformedPlaceholderFrame = node.0.view.convert(node.0.view.bounds, to: pictureInPictureNode.view)
            let pictureInPictureTransform = CATransform3DScale(pictureInPictureNode.layer.transform, transformedPlaceholderFrame.size.width / pictureInPictureNode.layer.bounds.size.width, transformedPlaceholderFrame.size.height / pictureInPictureNode.layer.bounds.size.height, 1.0)
            pictureInPictureNode.layer.animate(from: NSValue(caTransform3D: pictureInPictureNode.layer.transform), to: NSValue(caTransform3D: pictureInPictureTransform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
            
            pictureInPictureNode.layer.animatePosition(from: pictureInPictureNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                positionCompleted = true
                intermediateCompletion()
            })
            pictureInPictureNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    func animateOut(toOverlay node: ASDisplayNode, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode else {
            completion()
            return
        }
        
        var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = videoNode.view.convert(videoNode.view.bounds, to: self.view)
        let transformedSelfTargetSuperFrame = videoNode.view.convert(videoNode.view.bounds, to: node.view.superview)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        var nodeCompleted = false
        
        let copyView = node.view.snapshotContentTree()!
        
        videoNode.isHidden = true
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView] in
            if positionCompleted && boundsCompleted && copyCompleted && nodeCompleted {
                copyView?.removeFromSuperview()
                completion()
            }
        }
        
        copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        videoNode.layer.animatePosition(from: videoNode.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        self.statusButtonNode.layer.animatePosition(from: self.statusButtonNode.layer.position, to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
        })
        self.statusButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.statusButtonNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        let videoTransform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
        videoNode.layer.animate(from: NSValue(caTransform3D: videoNode.layer.transform), to: NSValue(caTransform3D: videoTransform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        if let pictureInPictureNode = self.pictureInPictureNode {
            pictureInPictureNode.isHidden = true
        }
        
        let nodeTransform = CATransform3DScale(node.layer.transform, videoNode.layer.bounds.size.width / transformedFrame.size.width, videoNode.layer.bounds.size.height / transformedFrame.size.height, 1.0)
        node.layer.animatePosition(from: CGPoint(x: transformedSelfTargetSuperFrame.midX, y: transformedSelfTargetSuperFrame.midY), to: node.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        node.layer.animate(from: NSValue(caTransform3D: nodeTransform), to: NSValue(caTransform3D: node.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            nodeCompleted = true
            intermediateCompletion()
        })
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func titleView() -> Signal<UIView?, NoError> {
        return self._titleView.get()
    }
    
    override func rightBarButtonItems() -> Signal<[UIBarButtonItem]?, NoError> {
        return self._rightBarButtonItems.get()
    }
    
    @objc func statusButtonPressed() {
        if let videoNode = self.videoNode {
            if let fetchStatus = self.fetchStatus, case .Local = fetchStatus {
                self.toggleControlsVisibility()
            }
            
            if let fetchStatus = self.fetchStatus {
                switch fetchStatus {
                    case .Local:
                        videoNode.playOnceWithSound(playAndRecord: false, seek: .none, actionAtEnd: self.actionAtEnd)
                    case .Remote, .Paused:
                        if self.requiresDownload {
                            self.fetchControls?.fetch()
                        } else {
                            videoNode.playOnceWithSound(playAndRecord: false, seek: .none, actionAtEnd: self.actionAtEnd)
                        }
                    case .Fetching:
                        self.fetchControls?.cancel()
                }
            } else {
                videoNode.playOnceWithSound(playAndRecord: false, seek: .none, actionAtEnd: self.actionAtEnd)
            }
        }
    }
    
    private func expandIntoCustomPiP() {
        if let item = self.item, let videoNode = self.videoNode, let customUnembedWhenPortrait = customUnembedWhenPortrait {
            self.customUnembedWhenPortrait = nil
            videoNode.setContinuePlayingWithoutSoundOnLostAudioSession(false)
            
            let context = self.context
            let baseNavigationController = self.baseNavigationController()
            let mediaManager = self.context.sharedContext.mediaManager
            var expandImpl: (() -> Void)?
            let overlayNode = OverlayUniversalVideoNode(postbox: self.context.account.postbox, audioSession: context.sharedContext.mediaManager.audioSession, manager: context.sharedContext.mediaManager.universalVideoManager, content: item.content, expand: {
                expandImpl?()
            }, close: { [weak mediaManager] in
                mediaManager?.setOverlayVideoNode(nil)
            })

            let playbackRate = self.playbackRate

            expandImpl = { [weak overlayNode] in
                guard let contentInfo = item.contentInfo, let overlayNode = overlayNode else {
                    return
                }
                
                switch contentInfo {
                    case let .message(message):
                        let gallery = GalleryController(context: context, source: .peerMessagesAtId(messageId: message.id, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil)), playbackRate: playbackRate, replaceRootController: { controller, ready in
                            if let baseNavigationController = baseNavigationController {
                                baseNavigationController.replaceTopController(controller, animated: false, ready: ready)
                            }
                        }, baseNavigationController: baseNavigationController)
                        gallery.temporaryDoNotWaitForReady = true
                        
                        baseNavigationController?.view.endEditing(true)
                        
                        (baseNavigationController?.topViewController as? ViewController)?.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { [weak overlayNode] id, media in
                            if let overlayNode = overlayNode, let overlaySupernode = overlayNode.supernode {
                                return GalleryTransitionArguments(transitionNode: (overlayNode, overlayNode.bounds, { [weak overlayNode] in
                                    return (overlayNode?.view.snapshotContentTree(), nil)
                                }), addToTransitionSurface: { [weak context, weak overlaySupernode, weak overlayNode] view in
                                    guard let context = context, let overlayNode = overlayNode else {
                                        return
                                    }
                                    if context.sharedContext.mediaManager.hasOverlayVideoNode(overlayNode) {
                                        overlaySupernode?.view.addSubview(view)
                                    }
                                    overlayNode.canAttachContent = false
                                })
                            } else if let info = context.sharedContext.mediaManager.galleryHiddenMediaManager.findTarget(messageId: id, media: media) {
                                return GalleryTransitionArguments(transitionNode: (info.1, info.1.bounds, {
                                    return info.2()
                                }), addToTransitionSurface: info.0)
                            }
                            return nil
                        }))
                    case let .webPage(_, _, expandFromPip):
                        if let expandFromPip = expandFromPip, let baseNavigationController = baseNavigationController {
                            expandFromPip({ [weak overlayNode] in
                                if let overlayNode = overlayNode, let overlaySupernode = overlayNode.supernode {
                                    return GalleryTransitionArguments(transitionNode: (overlayNode, overlayNode.bounds, { [weak overlayNode] in
                                        return (overlayNode?.view.snapshotContentTree(), nil)
                                    }), addToTransitionSurface: { [weak context, weak overlaySupernode, weak overlayNode] view in
                                        guard let context = context, let overlayNode = overlayNode else {
                                            return
                                        }
                                        if context.sharedContext.mediaManager.hasOverlayVideoNode(overlayNode) {
                                            overlaySupernode?.view.addSubview(view)
                                        }
                                        overlayNode.canAttachContent = false
                                    })
                                }
                                return nil
                            }, baseNavigationController, { [weak baseNavigationController] c, a in
                                (baseNavigationController?.topViewController as? ViewController)?.present(c, in: .window(.root), with: a)
                            })
                        }
                }
            }
            if customUnembedWhenPortrait(overlayNode) {
                self.beginCustomDismiss(false)
                self.statusNode.isHidden = true
                self.animateOut(toOverlay: overlayNode, completion: { [weak self] in
                    self?.completeCustomDismiss()
                })
            }
        }
    }
    
    @objc func pictureInPictureButtonPressed() {
        var isNativePictureInPictureSupported = false
        switch self.item?.contentInfo {
        case let .message(message):
            for media in message.media {
                if let media = media as? TelegramMediaFile, media.isVideo {
                    if message.id.namespace == Namespaces.Message.Cloud {
                        isNativePictureInPictureSupported = true
                    }
                }
            }
        default:
            break
        }

        if let item = self.item, let videoNode = self.videoNode, let overlayController = self.context.sharedContext.mediaManager.overlayMediaManager.controller {
            videoNode.setContinuePlayingWithoutSoundOnLostAudioSession(false)

            let context = self.context
            let baseNavigationController = self.baseNavigationController()
            let playbackRate = self.playbackRate

            if #available(iOSApplicationExtension 15.0, iOS 15.0, *), AVPictureInPictureController.isPictureInPictureSupported(), isNativePictureInPictureSupported {
                self.disablePictureInPicturePlaceholder = true

                let overlayVideoNode = UniversalVideoNode(postbox: self.context.account.postbox, audioSession: self.context.sharedContext.mediaManager.audioSession, manager: self.context.sharedContext.mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: item.content, priority: .overlay)
                let absoluteRect = videoNode.view.convert(videoNode.view.bounds, to: nil)
                overlayVideoNode.frame = absoluteRect
                overlayVideoNode.updateLayout(size: absoluteRect.size, transition: .immediate)
                overlayVideoNode.canAttachContent = true

                var hiddenMedia: (MessageId, Media)? = nil
                switch item.contentInfo {
                case let .message(message):
                    for media in message.media {
                        if let media = media as? TelegramMediaImage {
                            hiddenMedia = (message.id, media)
                        } else if let media = media as? TelegramMediaFile, media.isVideo {
                            hiddenMedia = (message.id, media)
                        }
                    }
                default:
                    break
                }

                let content = PictureInPictureContentImpl(context: self.context, overlayController: overlayController, mediaManager: self.context.sharedContext.mediaManager, accountId: self.context.account.id, hiddenMedia: hiddenMedia, videoNode: overlayVideoNode, canSkip: true, willBegin: { [weak self] content in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.beginCustomDismiss(true)
                }, didEnd: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.completeCustomDismiss()
                }, expand: { [weak baseNavigationController] completion in
                    guard let contentInfo = item.contentInfo else {
                        return
                    }

                    switch contentInfo {
                    case let .message(message):
                        let gallery = GalleryController(context: context, source: .peerMessagesAtId(messageId: message.id, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil)), playbackRate: playbackRate, replaceRootController: { [weak baseNavigationController] controller, ready in
                            if let baseNavigationController = baseNavigationController {
                                baseNavigationController.replaceTopController(controller, animated: false, ready: ready)
                            }
                        }, baseNavigationController: baseNavigationController)
                        gallery.temporaryDoNotWaitForReady = true
                        gallery.useSimpleAnimation = true

                        baseNavigationController?.view.endEditing(true)

                        (baseNavigationController?.topViewController as? ViewController)?.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { id, media in
                            return nil
                        }))

                        gallery.onDidAppear = {
                            completion()
                        }
                    case .webPage:
                        break
                    }
                })

                self.pictureInPictureContent = content

                self.context.sharedContext.mediaManager.overlayMediaManager.controller?.setPictureInPictureContent(content: content, absoluteRect: absoluteRect)
            } else {
                let context = self.context
                let baseNavigationController = self.baseNavigationController()
                let mediaManager = self.context.sharedContext.mediaManager
                var expandImpl: (() -> Void)?

                let shouldBeDismissed: Signal<Bool, NoError>
                if let contentInfo = item.contentInfo, case let .message(message) = contentInfo {
                    shouldBeDismissed = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: message.id))
                    |> map { message -> Bool in
                        if let _ = message {
                            return false
                        } else {
                            return true
                        }
                    }
                    |> distinctUntilChanged
                } else {
                    shouldBeDismissed = .single(false)
                }

                let overlayNode = OverlayUniversalVideoNode(postbox: self.context.account.postbox, audioSession: context.sharedContext.mediaManager.audioSession, manager: context.sharedContext.mediaManager.universalVideoManager, content: item.content, shouldBeDismissed: shouldBeDismissed, expand: {
                    expandImpl?()
                }, close: { [weak mediaManager] in
                    mediaManager?.setOverlayVideoNode(nil)
                })

                let playbackRate = self.playbackRate

                expandImpl = { [weak overlayNode] in
                    guard let contentInfo = item.contentInfo, let overlayNode = overlayNode else {
                        return
                    }

                    switch contentInfo {
                        case let .message(message):
                            let gallery = GalleryController(context: context, source: .peerMessagesAtId(messageId: message.id, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil)), playbackRate: playbackRate, replaceRootController: { controller, ready in
                                if let baseNavigationController = baseNavigationController {
                                    baseNavigationController.replaceTopController(controller, animated: false, ready: ready)
                                }
                            }, baseNavigationController: baseNavigationController)
                            gallery.temporaryDoNotWaitForReady = true

                            baseNavigationController?.view.endEditing(true)

                            (baseNavigationController?.topViewController as? ViewController)?.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { [weak overlayNode] id, media in
                                if let overlayNode = overlayNode, let overlaySupernode = overlayNode.supernode {
                                    return GalleryTransitionArguments(transitionNode: (overlayNode, overlayNode.bounds, { [weak overlayNode] in
                                        return (overlayNode?.view.snapshotContentTree(), nil)
                                    }), addToTransitionSurface: { [weak context, weak overlaySupernode, weak overlayNode] view in
                                        guard let context = context, let overlayNode = overlayNode else {
                                            return
                                        }
                                        if context.sharedContext.mediaManager.hasOverlayVideoNode(overlayNode) {
                                            overlaySupernode?.view.addSubview(view)
                                        }
                                        overlayNode.canAttachContent = false
                                    })
                                } else if let info = context.sharedContext.mediaManager.galleryHiddenMediaManager.findTarget(messageId: id, media: media) {
                                    return GalleryTransitionArguments(transitionNode: (info.1, info.1.bounds, {
                                        return info.2()
                                    }), addToTransitionSurface: info.0)
                                }
                                return nil
                            }))
                        case let .webPage(_, _, expandFromPip):
                            if let expandFromPip = expandFromPip, let baseNavigationController = baseNavigationController {
                                expandFromPip({ [weak overlayNode] in
                                    if let overlayNode = overlayNode, let overlaySupernode = overlayNode.supernode {
                                        return GalleryTransitionArguments(transitionNode: (overlayNode, overlayNode.bounds, { [weak overlayNode] in
                                            return (overlayNode?.view.snapshotContentTree(), nil)
                                        }), addToTransitionSurface: { [weak context, weak overlaySupernode, weak overlayNode] view in
                                            guard let context = context, let overlayNode = overlayNode else {
                                                return
                                            }
                                            if context.sharedContext.mediaManager.hasOverlayVideoNode(overlayNode) {
                                                overlaySupernode?.view.addSubview(view)
                                            }
                                            overlayNode.canAttachContent = false
                                        })
                                    }
                                    return nil
                                }, baseNavigationController, { [weak baseNavigationController] c, a in
                                    (baseNavigationController?.topViewController as? ViewController)?.present(c, in: .window(.root), with: a)
                                })
                        }
                    }
                }
                context.sharedContext.mediaManager.setOverlayVideoNode(overlayNode)
                if overlayNode.supernode != nil {
                    self.beginCustomDismiss(false)
                    self.statusNode.isHidden = true
                    self.animateOut(toOverlay: overlayNode, completion: { [weak self] in
                        self?.completeCustomDismiss()
                    })
                }
            }
        }
    }

    private func contentInfo() -> (message: Message, file: TelegramMediaFile?, isWebpage: Bool)? {
        guard let item = self.item else {
            return nil
        }
        if let contentInfo = item.contentInfo, case let .message(message) = contentInfo {
            var file: TelegramMediaFile?
            var isWebpage = false
            for m in message.media {
                if let m = m as? TelegramMediaFile, m.isVideo {
                    file = m
                    break
                } else if let m = m as? TelegramMediaWebpage, case let .Loaded(content) = m.content {
                    if let f = content.file, f.isVideo {
                        file = f
                    }
                    isWebpage = true
                    break
                }
            }
            return (message, file, isWebpage)
        }
        return nil
    }

    private func canDelete() -> Bool {
        guard let (message, _, _) = self.contentInfo() else {
            return false
        }

        var canDelete = false
        if let peer = message.peers[message.id.peerId] {
            if peer is TelegramUser || peer is TelegramSecretChat {
                canDelete = true
            } else if let _ = peer as? TelegramGroup {
                canDelete = true
            } else if let channel = peer as? TelegramChannel {
                if message.flags.contains(.Incoming) {
                    canDelete = channel.hasPermission(.deleteAllMessages)
                } else {
                    canDelete = true
                }
            } else {
                canDelete = false
            }
        } else {
            canDelete = false
        }
        return canDelete
    }

    @objc private func moreButtonPressed() {
        self.moreBarButton.play()
        self.moreBarButton.contextAction?(self.moreBarButton.containerNode, nil)
    }

    private func openMoreMenu(sourceNode: ASDisplayNode, gesture: ContextGesture?) {
        let items: Signal<[ContextMenuItem], NoError> = self.contextMenuMainItems()
        guard let controller = self.baseNavigationController()?.topViewController as? ViewController else {
            return
        }

        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme), source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceNode: self.moreBarButton.referenceNode)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
        self.isShowingContextMenuPromise.set(true)
        controller.presentInGlobalOverlay(contextController)

        contextController.dismissed = { [weak self] in
            Queue.mainQueue().after(0.1, {
                self?.isShowingContextMenuPromise.set(false)
            })
        }
    }

    private func speedList(strings: PresentationStrings) -> [(String, String, Double)] {
        let speedList: [(String, String, Double)] = [
            ("0.5x", "0.5x", 0.5),
            (strings.PlaybackSpeed_Normal, "1x", 1.0),
            ("1.5x", "1.5x", 1.5),
            ("2x", "2x", 2.0)
        ]

        return speedList
    }

    private func contextMenuMainItems() -> Signal<[ContextMenuItem], NoError> {
        guard let videoNode = self.videoNode else {
            return .single([])
        }

        return videoNode.status
        |> take(1)
        |> deliverOnMainQueue
        |> map { [weak self] status -> [ContextMenuItem] in
            guard let status = status, let strongSelf = self else {
                return []
            }

            var items: [ContextMenuItem] = []

            var speedValue: String = strongSelf.presentationData.strings.PlaybackSpeed_Normal
            var speedIconText: String = "1x"
            for (text, iconText, speed) in strongSelf.speedList(strings: strongSelf.presentationData.strings) {
                if abs(speed - status.baseRate) < 0.01 {
                    speedValue = text
                    speedIconText = iconText
                    break
                }
            }

            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PlaybackSpeed_Title, textLayout: .secondLineWithValue(speedValue), icon: { theme in
                return optionsRateImage(rate: speedIconText, isLarge: false, color: theme.contextMenu.primaryColor)
            }, action: { c, _ in
                guard let strongSelf = self else {
                    c.dismiss(completion: nil)
                    return
                }

                c.setItems(strongSelf.contextMenuSpeedItems() |> map { ContextController.Items(content: .list($0)) }, minHeight: nil)
            })))
            
            if let (message, _, _) = strongSelf.contentInfo() {
                for media in message.media {
                    if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                        let url = content.url
                        
                        let item = OpenInItem.url(url: url)
                        let openText = strongSelf.presentationData.strings.Conversation_FileOpenIn
                        items.append(.action(ContextMenuActionItem(text: openText, textColor: .primary, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                            f(.default)

                            if let strongSelf = self, let controller = strongSelf.galleryController() {
                                var presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                if !presentationData.theme.overallDarkAppearance {
                                    presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                                }
                                let actionSheet = OpenInActionSheetController(context: strongSelf.context, forceTheme: presentationData.theme, item: item, openUrl: { [weak self] url in
                                    if let strongSelf = self {
                                        strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: strongSelf.baseNavigationController(), dismissInput: {})
                                    }
                                })
                                controller.present(actionSheet, in: .window(.root))
                            }
                        })))
                        break
                    }
                }
            }
            
            if let (message, maybeFile, _) = strongSelf.contentInfo(), let file = maybeFile, !message.isCopyProtected() {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Gallery_SaveVideo, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.actionSheet.primaryTextColor) }, action: { _, f in
                    f(.default)

                    if let strongSelf = self {
                        switch strongSelf.fetchStatus {
                        case .Local:
                            let _ = (SaveToCameraRoll.saveToCameraRoll(context: strongSelf.context, postbox: strongSelf.context.account.postbox, mediaReference: .message(message: MessageReference(message), media: file))
                            |> deliverOnMainQueue).start(completed: {
                                guard let strongSelf = self else {
                                    return
                                }
                                guard let controller = strongSelf.galleryController() else {
                                    return
                                }
                                controller.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .mediaSaved(text: strongSelf.presentationData.strings.Gallery_VideoSaved), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                            })
                        default:
                            guard let controller = strongSelf.galleryController() else {
                                return
                            }
                            controller.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Gallery_WaitForVideoDownoad, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            })]), in: .window(.root))
                        }
                    }
                })))
            }
            if strongSelf.canDelete() {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                    f(.default)

                    if let strongSelf = self {
                        strongSelf.footerContentNode.deleteButtonPressed()
                    }
                })))
            }

            return items
        }
    }

    private func contextMenuSpeedItems() -> Signal<[ContextMenuItem], NoError> {
        guard let videoNode = self.videoNode else {
            return .single([])
        }

        return videoNode.status
        |> take(1)
        |> deliverOnMainQueue
        |> map { [weak self] status -> [ContextMenuItem] in
            guard let status = status, let strongSelf = self else {
                return []
            }

            var items: [ContextMenuItem] = []

            for (text, _, rate) in strongSelf.speedList(strings: strongSelf.presentationData.strings) {
                let isSelected = abs(status.baseRate - rate) < 0.01
                items.append(.action(ContextMenuActionItem(text: text, icon: { theme in
                    if isSelected {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    } else {
                        return nil
                    }
                }, action: { _, f in
                    f(.default)

                    guard let strongSelf = self, let videoNode = strongSelf.videoNode else {
                        return
                    }

                    videoNode.setBaseRate(rate)

                    if let controller = strongSelf.galleryController() as? GalleryController {
                        controller.updateSharedPlaybackRate(rate)
                    }
                })))
            }

            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Back, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
            }, action: { c, _ in
                guard let strongSelf = self else {
                    c.dismiss(completion: nil)
                    return
                }
                c.setItems(strongSelf.contextMenuMainItems() |> map { ContextController.Items(content: .list($0)) }, minHeight: nil)
            })))

            return items
        }
    }

    @objc func openStickersButtonPressed() {
        if let content = self.item?.content as? NativeVideoContent {
            let context = self.context
            let media = content.fileReference.abstract

            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let topController = (self.baseNavigationController()?.topViewController as? ViewController)
            let progressSignal = Signal<Never, NoError> { subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                topController?.present(controller, in: .window(.root), with: nil)
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.15, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.start()
            
            self.isInteractingPromise.set(true)
            
            let signal = self.context.engine.stickers.stickerPacksAttachedToMedia(media: media)
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            let _ = (signal
            |> deliverOnMainQueue).start(next: { [weak self] packs in
                guard let strongSelf = self, !packs.isEmpty else {
                    return
                }
                let baseNavigationController = strongSelf.baseNavigationController()
                baseNavigationController?.view.endEditing(true)
                let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packs[0], stickerPacks: packs, sendSticker: nil, actionPerformed: { info, items, action in
                    let animateInAsReplacement = false
                    switch action {
                    case .add:
                        topController?.present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { _ in
                            return true
                        }), in: .window(.root))
                    case let .remove(positionInList):
                        topController?.present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_RemovedTitle, text: presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { action in
                            if case .undo = action {
                                let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).start()
                            }
                            return true
                        }), in: .window(.root))
                    }
                }, dismissed: { [weak self] in
                    self?.isInteractingPromise.set(false)
                })
                (baseNavigationController?.topViewController as? ViewController)?.present(controller, in: .window(.root), with: nil)
            })
        }
    }
    
    override func adjustForPreviewing() {
        super.adjustForPreviewing()
        
        self.scrubberView?.isHidden = true
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }

    func updatePlaybackRate(_ playbackRate: Double?) {
        self.playbackRate = playbackRate

        if let playbackRate = self.playbackRate {
            self.videoNode?.setBaseRate(playbackRate)
        }

        self.playbackRatePromise.set(self.playbackRate ?? 1.0)
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode

    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
