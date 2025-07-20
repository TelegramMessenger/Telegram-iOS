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
import SliderContextItem
import Pasteboard
import AdUI
import AdsInfoScreen
import AdsReportScreen
import SaveProgressScreen
import SectionTitleContextItem
import RasterizedCompositionComponent
import BadgeComponent
import ComponentFlow
import ComponentDisplayAdapters
import ToastComponent
import MultilineTextComponent
import BundleIconComponent

public enum UniversalVideoGalleryItemContentInfo {
    case message(Message, Int?)
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
    let peerIsCopyProtected: Bool
    let playbackRate: () -> Double?
    let configuration: GalleryConfiguration?
    let playbackCompleted: () -> Void
    let performAction: (GalleryControllerInteractionTapAction) -> Void
    let openActionOptions: (GalleryControllerInteractionTapAction, Message) -> Void
    let storeMediaPlaybackState: (MessageId, Double?, Double) -> Void
    let present: (ViewController, Any?) -> Void

    public init(context: AccountContext, presentationData: PresentationData, content: UniversalVideoContent, originData: GalleryItemOriginData?, indexData: GalleryItemIndexData?, contentInfo: UniversalVideoGalleryItemContentInfo?, caption: NSAttributedString, description: NSAttributedString? = nil, credit: NSAttributedString? = nil, displayInfoOnTop: Bool = false, hideControls: Bool = false, fromPlayingVideo: Bool = false, isSecret: Bool = false, landscape: Bool = false, timecode: Double? = nil, peerIsCopyProtected: Bool = false, playbackRate: @escaping () -> Double?, configuration: GalleryConfiguration? = nil, playbackCompleted: @escaping () -> Void = {}, performAction: @escaping (GalleryControllerInteractionTapAction) -> Void, openActionOptions: @escaping (GalleryControllerInteractionTapAction, Message) -> Void, storeMediaPlaybackState: @escaping (MessageId, Double?, Double) -> Void, present: @escaping (ViewController, Any?) -> Void) {
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
        self.peerIsCopyProtected = peerIsCopyProtected
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
        } else if case let .message(message, _) = self.contentInfo, let _ = message.adAttribute {
            node._title.set(.single(self.presentationData.strings.Gallery_Ad))
        }
        
        node.setupItem(self)
        
        if self.displayInfoOnTop, case let .message(message, _) = self.contentInfo {
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
            
            if self.displayInfoOnTop, case let .message(message, _) = self.contentInfo {
                node.titleContentView?.setMessage(message, presentationData: self.presentationData, accountPeerId: self.context.account.peerId)
            }
        }
    }
    
    public func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        guard let contentInfo = self.contentInfo else {
            return nil
        }
        if case let .message(message, mediaIndex) = contentInfo {
            if let paidContent = message.paidContent {
                var mediaReference: AnyMediaReference?
                let mediaIndex = mediaIndex ?? 0
                if case let .full(fullMedia) = paidContent.extendedMedia[Int(mediaIndex)], let m = fullMedia as? TelegramMediaFile {
                    mediaReference = .message(message: MessageReference(message), media: m)
                }
                if let mediaReference = mediaReference {
                    if let item = ChatMediaGalleryThumbnailItem(account: self.context.account, userLocation: .peer(message.id.peerId), mediaReference: mediaReference) {
                        return (0, item)
                    }
                }
            } else if let id = message.groupInfo?.stableId {
                var mediaReference: AnyMediaReference?
                for m in message.media {
                    if let m = m as? TelegramMediaImage {
                        mediaReference = .message(message: MessageReference(message), media: m)
                    } else if let m = m as? TelegramMediaFile, m.isVideo {
                        mediaReference = .message(message: MessageReference(message), media: m)
                    }
                }
                if let mediaReference = mediaReference {
                    if let item = ChatMediaGalleryThumbnailItem(account: self.context.account, userLocation: .peer(message.id.peerId), mediaReference: mediaReference) {
                        return (Int64(id), item)
                    }
                }
            }
        } else if case let .webPage(webPage, media, _) = contentInfo, let file = media as? TelegramMediaFile  {
            if let item = ChatMediaGalleryThumbnailItem(account: self.context.account, userLocation: .other, mediaReference: .webPage(webPage: WebpageReference(webPage), media: file)) {
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
    enum Mode {
        case pictureInPicture
        case airplay
    }
    
    private let iconNode: ASImageNode
    private let textNode: ASTextNode
    
    init(strings: PresentationStrings, mode: Mode) {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = pictureInPictureImage
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        let text: String
        switch mode {
        case .pictureInPicture:
            text = strings.Embed_PlayingInPIP
        case .airplay:
            text = strings.Gallery_AirPlayPlaceholder
        }
        self.textNode.attributedText = NSAttributedString(string: text, font: placeholderFont, textColor: UIColor(rgb: 0x8e8e93))
        
        super.init()
        
        self.backgroundColor = UIColor(rgb: 0x333335)
        
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

private final class UniversalVideoGalleryItemOverlayNode: GalleryOverlayContentNode {
    private var context: AccountContext?
        
    private var adView = ComponentView<Empty>()
    
    private var message: Message?
    private var adContext: AdMessagesHistoryContext?
    private var adState: (startDelay: Int32?, betweenDelay: Int32?, messages: [Message])?
    private let adDisposable = MetaDisposable()
    
    private var adSchedule: [(Int32, Message?)] = []

    var performAction: ((GalleryControllerInteractionTapAction) -> Void)?
    var presentPremiumDemo: (() -> Void)?
    var openMoreMenu: ((ContextReferenceContentNode, Message) -> Void)?
    
    private var validLayout: (size: CGSize, metrics: LayoutMetrics, insets: UIEdgeInsets)?
        
    deinit {
        self.adDisposable.dispose()
    }
    
    func setMessage(context: AccountContext, message: Message) {
        self.context = context
        guard self.message?.id != message.id else {
            return
        }
        self.message = message
        
        let adContext = context.engine.messages.adMessages(peerId: message.id.peerId, messageId: message.id)
        self.adContext = adContext
        self.adDisposable.set((adContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self else {
                return
            }
            if !state.messages.isEmpty {
                self.adState = (state.startDelay, state.betweenDelay, state.messages)
                
                var startTime = Int32(CFAbsoluteTimeGetCurrent()) + (state.startDelay ?? 0)
                var schedule: [(Int32, Message?)] = []
                var maxDisplayDuration: Int32 = 30
                for message in state.messages {
                    if !schedule.isEmpty {
                        schedule.append((startTime, nil))
                        startTime += (state.betweenDelay ?? 0)
                    }
                    schedule.append((startTime, message))
                    
                    if let adAttribute = message.adAttribute {
                        maxDisplayDuration = adAttribute.maxDisplayDuration ?? 30
                        startTime += maxDisplayDuration
                    }
                }
                schedule.append((startTime + maxDisplayDuration, nil))
                self.adSchedule = schedule
            } else {
                self.adState = nil
                
                self.adSchedule = []
            }
            
            if let validLayout = self.validLayout {
                self.updateLayout(size: validLayout.size, metrics: validLayout.metrics, insets: validLayout.insets, isHidden: false, transition: .immediate)
            }
        }))
    }
    
    var timer: SwiftSignalKit.Timer?
    var hiddenMessages = Set<MessageId>()
    var isAnimatingOut = false
    var reportedMessages = Set<Data>()
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, insets: UIEdgeInsets, isHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, metrics, insets)
        
        if self.timer == nil {
            self.timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] progress in
                guard let self else {
                    return
                }
                if let validLayout = self.validLayout {
                    self.updateLayout(size: validLayout.size, metrics: validLayout.metrics, insets: validLayout.insets, isHidden: false, transition: .immediate)
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
        
        let isLandscape = size.width > size.height
        let _ = isLandscape
                
        let currentTime = Int32(CFAbsoluteTimeGetCurrent())
        var currentAd: (Int32, Message?)?
        
        for (time, maybeMessage) in adSchedule {
            if currentTime > time {
                currentAd = (time, maybeMessage)
            }
        }
        
        if let context = self.context, let (initialTimestamp, maybeMessage) = currentAd, let adMessage = maybeMessage, !self.hiddenMessages.contains(adMessage.id) {
            if let adAttribute = adMessage.adAttribute {
                if !self.reportedMessages.contains(adAttribute.opaqueId) {
                    self.reportedMessages.insert(adAttribute.opaqueId)
                    context.engine.messages.markAdAsSeen(opaqueId: adAttribute.opaqueId)
                }
            }
                        
            let sideInset: CGFloat = 16.0
                                    
            var maxWidth = min(size.width, size.height) - sideInset * 2.0
            if case .regular = metrics.widthClass {
                maxWidth = 414.0
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let adSize = self.adView.update(
                transition: .immediate,
                component: AnyComponent(
                    VideoAdComponent(
                        context: context,
                        theme: presentationData.theme,
                        strings: presentationData.strings,
                        message: EngineMessage(adMessage),
                        initialTimestamp: initialTimestamp,
                        action: { [weak self] available in
                            guard let self else {
                                return
                            }
                            if available {
                                self.hiddenMessages.insert(adMessage.id)
                                if let validLayout = self.validLayout {
                                    self.updateLayout(size: validLayout.size, metrics: validLayout.metrics, insets: validLayout.insets, isHidden: false, transition: .immediate)
                                }
                            } else {
                                self.presentPremiumDemo?()
                            }
                        },
                        adAction: { [weak self] in
                            if let self, let ad = adMessage.adAttribute {
                                self.hiddenMessages.insert(adMessage.id)
                                if let validLayout = self.validLayout {
                                    self.updateLayout(size: validLayout.size, metrics: validLayout.metrics, insets: validLayout.insets, isHidden: false, transition: .immediate)
                                }
                                context.engine.messages.markAdAction(opaqueId: ad.opaqueId, media: false, fullscreen: false)
                                self.performAction?(.url(url: ad.url, concealed: false, dismiss: false))
                            }
                        },
                        moreAction: { [weak self] sourceNode in
                            if let self {
                                self.openMoreMenu?(sourceNode, adMessage)
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: maxWidth, height: 200.0)
            )
            if let adView = self.adView.view {
                if adView.superview == nil {
                    self.view.addSubview(adView)
                    
                    adView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    adView.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                }
                transition.updateFrame(view: adView, frame: CGRect(origin: CGPoint(x: floor((size.width - adSize.width) / 2.0), y: size.height - adSize.height - insets.bottom), size: adSize))
            }
        } else if let adView = self.adView.view, !self.isAnimatingOut {
            self.isAnimatingOut = true
            adView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            adView.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 64.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                adView.removeFromSuperview()
                Queue.mainQueue().after(0.1) {
                    adView.layer.removeAllAnimations()
                }
                self.isAnimatingOut = false
            })
        }
    }
    
    override func animateIn(previousContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition) {

    }
    
    override func animateOut(nextContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let adView = self.adView.view, adView.frame.contains(point) {
            return super.hitTest(point, with: event)
        }
        return nil
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

func optionsCircleImage(dark: Bool) -> UIImage? {
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

final class MoreHeaderButton: HighlightableButtonNode {
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

final class SettingsHeaderButton: HighlightableButtonNode {
    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    
    private let iconLayer: RasterizedCompositionMonochromeLayer
    
    private let gearsLayer: RasterizedCompositionImageLayer
    private let dotLayer: RasterizedCompositionImageLayer
    
    private var speedBadge: ComponentView<Empty>?
    private var qualityBadge: ComponentView<Empty>?
    
    private var speedBadgeText: String?
    private var qualityBadgeText: String?
    
    private let badgeFont: UIFont
    
    private var isMenuOpen: Bool = false

    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?

    private let wide: Bool

    init(wide: Bool = false) {
        self.wide = wide

        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.iconLayer = RasterizedCompositionMonochromeLayer()
        //self.iconLayer.backgroundColor = UIColor.green.cgColor
        
        self.gearsLayer = RasterizedCompositionImageLayer()
        self.gearsLayer.image = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/NavigationSettingsNoDot"), color: .white)
        
        self.dotLayer = RasterizedCompositionImageLayer()
        self.dotLayer.image = generateFilledCircleImage(diameter: 4.0, color: .white)
        
        self.iconLayer.contentsLayer.addSublayer(self.gearsLayer)
        self.iconLayer.contentsLayer.addSublayer(self.dotLayer)
        
        self.badgeFont = Font.with(size: 8.0, design: .round, weight: .bold)

        super.init()

        self.containerNode.addSubnode(self.referenceNode)
        self.referenceNode.layer.addSublayer(self.iconLayer)
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

        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -4.0, bottom: 0.0, right: -4.0)
        
        if let image = self.gearsLayer.image {
            let iconInnerInsets = UIEdgeInsets(top: 4.0, left: 8.0, bottom: 4.0, right: 6.0)
            let iconSize = CGSize(width: image.size.width + iconInnerInsets.left + iconInnerInsets.right, height: image.size.height + iconInnerInsets.top + iconInnerInsets.bottom)
            let iconFrame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - iconSize.width) / 2.0), y: floor((self.containerNode.bounds.height - iconSize.height) / 2.0)), size: iconSize)
            self.iconLayer.position = iconFrame.center
            self.iconLayer.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            
            self.iconLayer.contentsLayer.position = CGRect(origin: CGPoint(), size: iconFrame.size).center
            self.iconLayer.contentsLayer.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            
            self.iconLayer.maskedLayer.position = CGRect(origin: CGPoint(), size: iconFrame.size).center
            self.iconLayer.maskedLayer.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            self.iconLayer.maskedLayer.backgroundColor = UIColor.white.cgColor
            
            let gearsFrame = CGRect(origin: CGPoint(x: floor((iconSize.width - image.size.width) * 0.5), y: floor((iconSize.height - image.size.height) * 0.5)), size: image.size)
            self.gearsLayer.position = gearsFrame.center
            self.gearsLayer.bounds = CGRect(origin: CGPoint(), size: gearsFrame.size)
            
            if let dotImage = self.dotLayer.image {
                let dotFrame = CGRect(origin: CGPoint(x: gearsFrame.minX + floorToScreenPixels((gearsFrame.width - dotImage.size.width) * 0.5), y: gearsFrame.minY + floorToScreenPixels((gearsFrame.height - dotImage.size.height) * 0.5)), size: dotImage.size)
                self.dotLayer.position = dotFrame.center
                self.dotLayer.bounds = CGRect(origin: CGPoint(), size: dotFrame.size)
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
    
    func setIsMenuOpen(isMenuOpen: Bool) {
        if self.isMenuOpen == isMenuOpen {
            return
        }
        self.isMenuOpen = isMenuOpen
        
        let rotationTransition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
        rotationTransition.updateTransform(layer: self.gearsLayer, transform: CGAffineTransformMakeRotation(isMenuOpen ? (CGFloat.pi * 2.0 / 6.0) : 0.0))
        self.gearsLayer.animateScale(from: 1.0, to: 1.07, duration: 0.1, removeOnCompletion: false, completion: { [weak self] finished in
            guard let self, finished else {
                return
            }
            self.gearsLayer.animateScale(from: 1.07, to: 1.0, duration: 0.1, removeOnCompletion: true)
        })
        
        self.dotLayer.animateScale(from: 1.0, to: 0.8, duration: 0.1, removeOnCompletion: false, completion: { [weak self] finished in
            guard let self, finished else {
                return
            }
            self.dotLayer.animateScale(from: 0.8, to: 1.0, duration: 0.1, removeOnCompletion: true)
        })
    }
    
    func setBadges(speed: String?, quality: String?, transition: ComponentTransition) {
        if self.speedBadgeText == speed && self.qualityBadgeText == quality {
            return
        }
        self.speedBadgeText = speed
        self.qualityBadgeText = quality
        
        if let badgeText = speed {
            var badgeTransition = transition
            let speedBadge: ComponentView<Empty>
            if let current = self.speedBadge {
                speedBadge = current
            } else {
                speedBadge = ComponentView()
                self.speedBadge = speedBadge
                badgeTransition = badgeTransition.withAnimation(.none)
            }
            let badgeSize = speedBadge.update(
                transition: badgeTransition,
                component: AnyComponent(BadgeComponent(
                    text: badgeText,
                    font: self.badgeFont,
                    cornerRadius: 3.0,
                    insets: UIEdgeInsets(top: 1.33, left: 1.66, bottom: 1.33, right: 1.66),
                    outerInsets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let speedBadgeView = speedBadge.view {
                if speedBadgeView.layer.superlayer == nil {
                    self.iconLayer.contentsLayer.addSublayer(speedBadgeView.layer)
                    
                    transition.animateAlpha(layer: speedBadgeView.layer, from: 0.0, to: 1.0)
                    transition.animateScale(layer: speedBadgeView.layer, from: 0.001, to: 1.0)
                }
                badgeTransition.setFrame(layer: speedBadgeView.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: badgeSize))
            }
        } else if let speedBadge = self.speedBadge {
            self.speedBadge = nil
            if let speedBadgeView = speedBadge.view {
                let speedBadgeLayer = speedBadgeView.layer
                transition.setAlpha(layer: speedBadgeLayer, alpha: 0.0, completion: { [weak speedBadgeLayer] _ in
                    speedBadgeLayer?.removeFromSuperlayer()
                })
                transition.setScale(layer: speedBadgeLayer, scale: 0.001)
            }
        }
        
        if let badgeText = quality {
            var badgeTransition = transition
            let qualityBadge: ComponentView<Empty>
            if let current = self.qualityBadge {
                qualityBadge = current
            } else {
                qualityBadge = ComponentView()
                self.qualityBadge = qualityBadge
                badgeTransition = badgeTransition.withAnimation(.none)
            }
            let badgeSize = qualityBadge.update(
                transition: badgeTransition,
                component: AnyComponent(BadgeComponent(
                    text: badgeText,
                    font: self.badgeFont,
                    cornerRadius: 3.0,
                    insets: UIEdgeInsets(top: 1.33, left: 1.66, bottom: 1.33, right: 1.66),
                    outerInsets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let qualityBadgeView = qualityBadge.view {
                if qualityBadgeView.layer.superlayer == nil {
                    self.iconLayer.contentsLayer.addSublayer(qualityBadgeView.layer)
                    
                    transition.animateAlpha(layer: qualityBadgeView.layer, from: 0.0, to: 1.0)
                    transition.animateScale(layer: qualityBadgeView.layer, from: 0.001, to: 1.0)
                }
                badgeTransition.setFrame(layer: qualityBadgeView.layer, frame: CGRect(origin: CGPoint(x: self.iconLayer.bounds.width - badgeSize.width, y: self.iconLayer.bounds.height - badgeSize.height), size: badgeSize))
            }
        } else if let qualityBadge = self.qualityBadge {
            self.qualityBadge = nil
            if let qualityBadgeView = qualityBadge.view {
                let qualityBadgeLayer = qualityBadgeView.layer
                transition.setAlpha(layer: qualityBadgeLayer, alpha: 0.0, completion: { [weak qualityBadgeLayer] _ in
                    qualityBadgeLayer?.removeFromSuperlayer()
                })
                transition.setScale(layer: qualityBadgeLayer, scale: 0.001)
            }
        }
    }
}

@available(iOS 15.0, *)
private final class NativePictureInPictureContentImpl: NSObject, AVPictureInPictureControllerDelegate {
    private final class PlaybackDelegate: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
        private let node: UniversalVideoNode
        private var statusDisposable: Disposable?
        private var status: MediaPlayerStatus?
        weak var pictureInPictureController: AVPictureInPictureController?
        
        private var previousIsPlaying = false
        init(node: UniversalVideoNode) {
            self.node = node

            super.init()

            var invalidatedStateOnce = false
            self.statusDisposable = (self.node.status
            |> deliverOnMainQueue).start(next: { [weak self] status in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.status = status
                if let status {
                    let isPlaying = status.status == .playing
                    if !invalidatedStateOnce {
                        invalidatedStateOnce = true
                        strongSelf.pictureInPictureController?.invalidatePlaybackState()
                    } else if strongSelf.previousIsPlaying != isPlaying {
                        strongSelf.previousIsPlaying = isPlaying
                        strongSelf.pictureInPictureController?.invalidatePlaybackState()
                    }
                }
            }).strict()
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

    private let context: AccountContext
    private let accountId: AccountRecordId
    private let hiddenMedia: (MessageId, Media)?
    private weak var mediaManager: MediaManager?
    private var pictureInPictureController: AVPictureInPictureController?
    private var contentDelegate: PlaybackDelegate?
    private let node: UniversalVideoNode
    private let willBegin: (NativePictureInPictureContentImpl) -> Void
    private let didBegin: (NativePictureInPictureContentImpl) -> Void
    private let didEnd: (NativePictureInPictureContentImpl) -> Void
    private let expand: (@escaping () -> Void) -> Void
    private var pictureInPictureTimer: SwiftSignalKit.Timer?
    private var didExpand: Bool = false

    private var hiddenMediaManagerIndex: Int?

    private var messageRemovedDisposable: Disposable?
    
    private var isNativePictureInPictureActiveDisposable: Disposable?

    init(context: AccountContext, mediaManager: MediaManager, accountId: AccountRecordId, hiddenMedia: (MessageId, Media)?, videoNode: UniversalVideoNode, canSkip: Bool, willBegin: @escaping (NativePictureInPictureContentImpl) -> Void, didBegin: @escaping (NativePictureInPictureContentImpl) -> Void, didEnd: @escaping (NativePictureInPictureContentImpl) -> Void, expand: @escaping (@escaping () -> Void) -> Void) {
        self.context = context
        self.mediaManager = mediaManager
        self.accountId = accountId
        self.hiddenMedia = hiddenMedia
        self.node = videoNode
        self.willBegin = willBegin
        self.didBegin = didBegin
        self.didEnd = didEnd
        self.expand = expand

        super.init()

        if let videoLayer = videoNode.getVideoLayer() {
            let contentDelegate = PlaybackDelegate(node: self.node)
            self.contentDelegate = contentDelegate
            
            let pictureInPictureController = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: videoLayer, playbackDelegate: contentDelegate))
            self.pictureInPictureController = pictureInPictureController
            contentDelegate.pictureInPictureController = pictureInPictureController
            
            pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = false
            pictureInPictureController.requiresLinearPlayback = !canSkip
            pictureInPictureController.delegate = self
            self.pictureInPictureController = pictureInPictureController
        }

        if let (messageId, _) = hiddenMedia {
            var hadMessage: Bool?
            self.messageRemovedDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> map { message -> Bool in
                if let _ = message {
                    return true
                } else {
                    return false
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                if let hadMessage, hadMessage {
                    if value {
                    } else {
                        if let pictureInPictureController = self.pictureInPictureController {
                            pictureInPictureController.stopPictureInPicture()
                        }
                    }
                    
                    return
                }
                hadMessage = value
            })
        }
    }

    deinit {
        self.messageRemovedDisposable?.dispose()
        self.isNativePictureInPictureActiveDisposable?.dispose()
        self.pictureInPictureTimer?.invalidate()
        self.node.setCanPlaybackWithoutHierarchy(false)

        if let hiddenMediaManagerIndex = self.hiddenMediaManagerIndex, let mediaManager = self.mediaManager {
            mediaManager.galleryHiddenMediaManager.removeSource(hiddenMediaManagerIndex)
        }
    }
    
    func updateIsCentral(isCentral: Bool) {
        guard let pictureInPictureController = self.pictureInPictureController else {
            return
        }
        
        if isCentral {
            pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true
        } else {
            pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = false
        }
    }
    
    func beginPictureInPicture() {
        guard let pictureInPictureController = self.pictureInPictureController else {
            return
        }
        if pictureInPictureController.isPictureInPicturePossible {
            pictureInPictureController.startPictureInPicture()
        }
    }
    
    func invalidatePlaybackState() {
        guard let pictureInPictureController = self.pictureInPictureController else {
            return
        }
        if pictureInPictureController.isPictureInPictureActive {
            pictureInPictureController.invalidatePlaybackState()
        }
    }

    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.node.setCanPlaybackWithoutHierarchy(true)
        
        if let hiddenMedia = self.hiddenMedia, let mediaManager = self.mediaManager, !"".isEmpty {
            let accountId = self.accountId
            self.hiddenMediaManagerIndex = mediaManager.galleryHiddenMediaManager.addSource(Signal<(MessageId, Media)?, NoError>.single(hiddenMedia)
            |> map { messageIdAndMedia in
                if let (messageId, media) = messageIdAndMedia {
                    return .chat(accountId, messageId, media)
                } else {
                    return nil
                }
            })
        }
        
        self.willBegin(self)
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.didBegin(self)
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print(error)
    }

    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.node.setCanPlaybackWithoutHierarchy(false)
        if let hiddenMediaManagerIndex = self.hiddenMediaManagerIndex, let mediaManager = self.mediaManager {
            mediaManager.galleryHiddenMediaManager.removeSource(hiddenMediaManagerIndex)
            self.hiddenMediaManagerIndex = nil
        }
        self.didEnd(self)
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        self.expand { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.didExpand = true

            completionHandler(true)
        }
    }
    
    public func requestExpand() {
        self.pictureInPictureController?.stopPictureInPicture()
    }
    
    public func stop() {
        self.pictureInPictureController?.stopPictureInPicture()
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
    
    private let settingsBarButton: SettingsHeaderButton
    
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
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?
    private var didPause = false
    private var isPaused = true
    private var dismissOnOrientationChange = false
    private var keepSoundOnDismiss = false
    private var hasPictureInPicture = false

    private var pictureInPictureButton: UIBarButtonItem?
    
    private var requiresDownload = false
    
    private(set) var item: UniversalVideoGalleryItem?
    private var playbackRate: Double?
    private var videoQuality: UniversalVideoContentVideoQuality = .auto
    private let playbackRatePromise = ValuePromise<Double>()
    private let videoQualityPromise = ValuePromise<UniversalVideoContentVideoQuality>()
    
    private var playerStatusValue: MediaPlayerStatus?
    private let statusDisposable = MetaDisposable()
    
    private let moreButtonStateDisposable = MetaDisposable()
    private let settingsButtonStateDisposable = MetaDisposable()
    private let mediaPlaybackStateDisposable = MetaDisposable()
    
    private let fetchDisposable = MetaDisposable()
    private var fetchStatus: MediaResourceStatus?
    private var fetchControls: FetchControls?
    
    private var scrubbingFrame = Promise<FramePreviewResult?>(nil)
    private var scrubbingFrames = false
    private var scrubbingFrameDisposable: Disposable?
    
    private var isPlaying = false
    private let isPlayingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let isInteractingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let controlsVisiblePromise = ValuePromise<Bool>(true, ignoreRepeated: true)
    private let isShowingContextMenuPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let isShowingSettingsMenuPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let isShowingAdMenuPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let hasExpandedCaptionPromise = Promise<Bool>()
    private var hideControlsDisposable: Disposable?
    private var automaticPictureInPictureDisposable: Disposable?
    
    var playbackCompleted: (() -> Void)?
    
    private var customUnembedWhenPortrait: ((OverlayMediaItemNode) -> Bool)?

    private var nativePictureInPictureContent: AnyObject?
    
    private var activePictureInPictureNavigationController: NavigationController?
    private var activePictureInPictureController: ViewController?
    
    private var activeEdgeRateState: (initialRate: Double, currentRate: Double)?
    private var activeEdgeRateIndicator: ComponentView<Empty>?
    
    private var isAnimatingOut: Bool = false
    
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
        
        self.settingsBarButton = SettingsHeaderButton()
        self.settingsBarButton.isUserInteractionEnabled = true
        
        super.init()

        self.clipsToBounds = true
        
        self.footerContentNode.shareMediaParameters = { [weak self] in
            guard let self, let playerStatusValue = self.playerStatusValue else {
                return nil
            }
            
            if playerStatusValue.duration >= 60.0 * 10.0 {
                var publicLinkPrefix: ShareControllerSubject.PublicLinkPrefix?
                if case let .message(message, _) = self.item?.contentInfo, message.id.namespace == Namespaces.Message.Cloud, let peer = message.peers[message.id.peerId] as? TelegramChannel, let username = peer.username ?? peer.usernames.first?.username {
                    let visibleString = "t.me/\(username)/\(message.id.id)"
                    publicLinkPrefix = ShareControllerSubject.PublicLinkPrefix(
                        visibleString: visibleString,
                        actualString: "https://\(visibleString)"
                    )
                }
                
                return ShareControllerSubject.MediaParameters(
                    startAtTimestamp: Int32(playerStatusValue.timestamp),
                    publicLinkPrefix: publicLinkPrefix
                )
            } else {
                return nil
            }
        }
        
        self.moreBarButton.addTarget(self, action: #selector(self.moreButtonPressed), forControlEvents: .touchUpInside)
        self.settingsBarButton.addTarget(self, action: #selector(self.settingsButtonPressed), forControlEvents: .touchUpInside)
        
        self.footerContentNode.interacting = { [weak self] value in
            self?.isInteractingPromise.set(value)
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
        }).strict()
        
        self.alternativeDismiss = { [weak self] in
            guard let strongSelf = self, strongSelf.hasPictureInPicture else {
                return false
            }
            strongSelf.pictureInPictureButtonPressed()
            return true
        }

        self.moreBarButton.contextAction = { [weak self] sourceNode, gesture in
            guard let self else {
                return
            }
            var adMessage: Message?
            if case let .message(message, _) = self.item?.contentInfo, let _ = message.adAttribute {
                adMessage = message
            }
            self.openMoreMenu(sourceNode: self.moreBarButton.referenceNode, gesture: gesture, adMessage: adMessage, isSettings: false)
        }
        
        self.titleContentView = GalleryTitleView(frame: CGRect())
        self._titleView.set(.single(self.titleContentView))
        
        let shouldHideControlsSignal: Signal<Void, NoError> = combineLatest(self.isPlayingPromise.get(), self.isInteractingPromise.get(), self.controlsVisiblePromise.get(), self.isShowingContextMenuPromise.get(), self.isShowingSettingsMenuPromise.get(), self.isShowingAdMenuPromise.get(), self.hasExpandedCaptionPromise.get())
        |> mapToSignal { isPlaying, isInteracting, controlsVisible, isShowingContextMenu, isShowingSettingsMenu, isShowingAdMenu, hasExpandedCaptionPromise -> Signal<Void, NoError> in
            if isShowingContextMenu || isShowingSettingsMenu || isShowingAdMenu || hasExpandedCaptionPromise {
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
            if let strongSelf = self, !strongSelf.isAnimatingOut {
                strongSelf.updateControlsVisibility(false)
            }
        }).strict()
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.moreButtonStateDisposable.dispose()
        self.settingsButtonStateDisposable.dispose()
        self.mediaPlaybackStateDisposable.dispose()
        self.scrubbingFrameDisposable?.dispose()
        self.hideControlsDisposable?.dispose()
        self.automaticPictureInPictureDisposable?.dispose()
    }
    
    override func ready() -> Signal<Void, NoError> {
        return self._ready.get()
    }
    
    
    override func contentTapAction() -> Bool {
        if case let .message(message, _) = self.item?.contentInfo, let _ = message.adAttribute {
            self.item?.performAction(.ad(message.id))
            return true
        }
        return false
    }
    
    override func screenFrameUpdated(_ frame: CGRect) {
        let center = frame.midX - self.frame.width / 2.0
        self.subnodeTransform = CATransform3DMakeTranslation(-center * 0.16, 0.0, 0.0)
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
                var placeholderSize = item.content.dimensions.fitted(layout.size)
                placeholderSize.height += 2.0
                transition.updateFrame(node: pictureInPictureNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - placeholderSize.width) / 2.0), y: floor((layout.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
                pictureInPictureNode.updateLayout(placeholderSize, transition: transition)
            }
        }
        
        if let activeEdgeRateState = self.activeEdgeRateState {
            var activeEdgeRateIndicatorTransition = transition
            let activeEdgeRateIndicator: ComponentView<Empty>
            if let current = self.activeEdgeRateIndicator {
                activeEdgeRateIndicator = current
            } else {
                activeEdgeRateIndicator = ComponentView()
                self.activeEdgeRateIndicator = activeEdgeRateIndicator
                activeEdgeRateIndicatorTransition = .immediate
            }
            
            let activeEdgeRateIndicatorSize = activeEdgeRateIndicator.update(
                transition: ComponentTransition(activeEdgeRateIndicatorTransition),
                component: AnyComponent(GalleryRateToastComponent(
                    rate: activeEdgeRateState.currentRate,
                    displayTooltip: self.presentationData.strings.Gallery_ToastVideoSpeedSwipe
                )),
                environment: {},
                containerSize: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: 100.0)
            )
            let activeEdgeRateIndicatorFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - activeEdgeRateIndicatorSize.width) * 0.5), y: max(navigationBarHeight, layout.statusBarHeight ?? 0.0) + 8.0), size: activeEdgeRateIndicatorSize)
            if let activeEdgeRateIndicatorView = activeEdgeRateIndicator.view {
                if activeEdgeRateIndicatorView.superview == nil {
                    self.view.addSubview(activeEdgeRateIndicatorView)
                    transition.animateTransformScale(view: activeEdgeRateIndicatorView, from: 0.001)
                    if transition.isAnimated {
                        activeEdgeRateIndicatorView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                activeEdgeRateIndicatorTransition.updateFrame(view: activeEdgeRateIndicatorView, frame: activeEdgeRateIndicatorFrame)
            }
        } else if let activeEdgeRateIndicator = self.activeEdgeRateIndicator {
            self.activeEdgeRateIndicator = nil
            if let activeEdgeRateIndicatorView = activeEdgeRateIndicator.view {
                transition.updateAlpha(layer: activeEdgeRateIndicatorView.layer, alpha: 0.0, completion: { [weak activeEdgeRateIndicatorView] _ in
                    activeEdgeRateIndicatorView?.removeFromSuperview()
                })
                transition.updateTransformScale(layer: activeEdgeRateIndicatorView.layer, scale: 0.001)
            }
        }
                
        if dismiss {
            self.dismiss()
        }
    }

    func setupItem(_ item: UniversalVideoGalleryItem) {
        if self.item?.content.id != item.content.id {            
            var chapters = parseMediaPlayerChapters(item.caption)
            if chapters.isEmpty, let description = item.description {
                chapters = parseMediaPlayerChapters(description)
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
            
            self.isPlaying = false
            self.isPlayingPromise.set(false)
            
            if item.hideControls {
                self.statusButtonNode.isHidden = true
            }
                        
            self.dismissOnOrientationChange = item.landscape
            
            var hasLinkedStickers = false
            if let content = item.content as? NativeVideoContent {
                hasLinkedStickers = content.fileReference.media.hasLinkedStickers
            } else if let content = item.content as? HLSVideoContent {
                hasLinkedStickers = content.fileReference.media.hasLinkedStickers
            }
            
            var disablePictureInPicture = false
            var disablePlayerControls = false
            var forceEnablePiP = false
            var forceEnableUserInteraction = false
            var isAnimated = false
            var isEnhancedWebPlayer = false
            var isAdaptive = false
            if let content = item.content as? NativeVideoContent {
                isAnimated = content.fileReference.media.isAnimated
                self.videoFramePreview = MediaPlayerFramePreview(postbox: item.context.account.postbox, userLocation: content.userLocation, userContentType: .video, fileReference: content.fileReference)
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
            } else if let content = item.content as? HLSVideoContent {
                isAdaptive = true
                
                if let qualitySet = HLSQualitySet(baseFile: content.fileReference, codecConfiguration: HLSCodecConfiguration(isHardwareAv1Supported: false, isSoftwareAv1Supported: true)), let (quality, playlistFile) = qualitySet.playlistFiles.sorted(by: { $0.key < $1.key }).first, let dataFile = qualitySet.qualityFiles[quality] {
                    if !qualitySet.thumbnails.isEmpty {
                        var selectedThumbnails: (file: FileMediaReference, fileMap: FileMediaReference)?
                        let thumbnailQualities = qualitySet.thumbnails.keys.sorted()
                        for quality in thumbnailQualities.reversed() {
                            if quality <= 230 {
                                selectedThumbnails = qualitySet.thumbnails[quality]
                                break
                            }
                        }
                        if selectedThumbnails == nil, let quality = thumbnailQualities.last {
                            selectedThumbnails = qualitySet.thumbnails[quality]
                        }
                        
                        if let selectedThumbnails {
                            self.videoFramePreview = MediaPlayerFramePreviewHLSThumbnails(
                                postbox: item.context.account.postbox,
                                userLocation: content.userLocation,
                                userContentType: .video,
                                file: selectedThumbnails.file,
                                fileMap: selectedThumbnails.fileMap
                            )
                        }
                    } else {
                        var alternativeQualities: [(playlist: FileMediaReference, dataFile: FileMediaReference)] = []
                        for (otherQuality, otherPlaylistFile) in qualitySet.playlistFiles {
                            if otherQuality != quality, let otherDataFile = qualitySet.qualityFiles[otherQuality] {
                                alternativeQualities.append((otherPlaylistFile, dataFile: otherDataFile))
                            }
                        }
                        self.videoFramePreview = MediaPlayerFramePreviewHLS(
                            postbox: item.context.account.postbox,
                            userLocation: content.userLocation,
                            userContentType: .video,
                            playlistFile: playlistFile,
                            mainDataFile: dataFile,
                            alternativeQualities: alternativeQualities
                        )
                    }
                }
            }
            
            let _ = isAdaptive
               
            if let videoNode = self.videoNode {
                videoNode.canAttachContent = false
                videoNode.removeFromSupernode()
            }
            
            if isAnimated || disablePlayerControls {
                self.footerContentNode.scrubberView = nil
            }
            
            let mediaManager = item.context.sharedContext.mediaManager
            
            let videoNode = UniversalVideoNode(context: item.context, postbox: item.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: item.content, priority: .gallery)
            let videoScale: CGFloat
            if item.content is WebEmbedVideoContent {
                videoScale = 1.0
            } else {
                videoScale = 2.0
            }
            let videoSize = CGSize(width: item.content.dimensions.width * videoScale, height: item.content.dimensions.height * videoScale)
            let actualVideoSize = CGSize(width: item.content.dimensions.width, height: item.content.dimensions.height)
            videoNode.updateLayout(size: videoSize, actualSize: actualVideoSize, transition: .immediate)
            videoNode.ownsContentNodeUpdated = { [weak self] value in
                if let strongSelf = self {
                    strongSelf.updateDisplayPlaceholder(!value)
                    
                    if strongSelf.playOnContentOwnership {
                        strongSelf.playOnContentOwnership = false
                        strongSelf.initiallyActivated = true
                        strongSelf.skipInitialPause = true
                        
                        var seek = MediaPlayerSeek.start
                        if let item = strongSelf.item {
                            if let contentInfo = item.contentInfo, case let .message(message, _) = contentInfo {
                                for attribute in message.attributes {
                                    if let attribute = attribute as? ForwardVideoTimestampAttribute {
                                        seek = .timecode(Double(attribute.timestamp))
                                    }
                                }
                            }
                            if let content = item.content as? NativeVideoContent {
                                isAnimated = content.fileReference.media.isAnimated
                                if let time = item.timecode {
                                    seek = .timecode(time)
                                }
                            } else if let content = item.content as? HLSVideoContent {
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
                        
                        if let item = strongSelf.item, let _ = item.content as? PlatformVideoContent {
                            strongSelf.videoNode?.play()
                        } else {
                            strongSelf.videoNode?.playOnceWithSound(playAndRecord: false, seek: seek, actionAtEnd: isAnimated ? .loop : strongSelf.actionAtEnd)
                        }

                        Queue.mainQueue().after(0.1) {
                            if let playbackRate = strongSelf.playbackRate {
                                strongSelf.videoNode?.setBaseRate(playbackRate)
                            }
                        }
                    }
                }
            }
            self.videoNode = videoNode
            self.videoNodeUserInteractionEnabled = disablePlayerControls || forceEnableUserInteraction
            videoNode.isUserInteractionEnabled = disablePlayerControls || forceEnableUserInteraction
            videoNode.backgroundColor = UIColor.black
            if item.fromPlayingVideo {
                videoNode.canAttachContent = false
            } else {
                self.updateDisplayPlaceholder()
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
            if let contentInfo = item.contentInfo, case let .message(message, _) = contentInfo {
                if message.paidContent != nil {
                    disablePictureInPicture = true
                } else if Namespaces.Message.allNonRegular.contains(message.id.namespace) || message.id.namespace == Namespaces.Message.Local {
                    disablePictureInPicture = true
                }
                
                if message.paidContent == nil {
                    let throttledSignal = videoNode.status
                    |> mapToThrottled { next -> Signal<MediaPlayerStatus?, NoError> in
                        return .single(next) |> then(.complete() |> delay(0.5, queue: Queue.concurrentDefaultQueue()))
                    }
                    
                    self.mediaPlaybackStateDisposable.set((throttledSignal
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        guard let self else {
                            return
                        }

                        if let status {
                            self.maybeStorePlaybackStatus(status: status)
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
                        if case let .Video(duration, _, _, _, _, _) = attribute, duration >= 30 {
                            hintSeekable = true
                            break
                        }
                    }
                    let status = messageMediaFileStatus(context: item.context, messageId: message.id, file: file)
                    if !isWebpage && message.adAttribute == nil && !NativeVideoContent.isHLSVideo(file: file) {
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
                self.videoQualityPromise.get()
            ).start(next: { [weak self] playbackRate, videoQuality in
                guard let self else {
                    return
                }
                
                var rateString: String?
                if abs(playbackRate - 1.0) > 0.05 {
                    var stringValue = String(format: "%.1fx", playbackRate)
                    if stringValue.hasSuffix(".0x") {
                        stringValue = stringValue.replacingOccurrences(of: ".0x", with: "x")
                    }
                    rateString = stringValue
                }
                
                var qualityString: String?
                if case let .quality(quality) = videoQuality {
                    if quality <= 360 {
                        qualityString = self.presentationData.strings.Gallery_VideoSettings_IconQualityLow
                    } else if quality <= 480 {
                        qualityString = self.presentationData.strings.Gallery_VideoSettings_IconQualityMedium
                    } else if quality <= 720 {
                        qualityString = self.presentationData.strings.Gallery_VideoSettings_IconQualityHD
                    } else if quality <= 1080 {
                        qualityString = self.presentationData.strings.Gallery_VideoSettings_IconQualityFHD
                    } else {
                        qualityString = self.presentationData.strings.Gallery_VideoSettings_IconQualityQHD
                    }
                }

                self.settingsBarButton.setBadges(speed: rateString, quality: qualityString, transition: .spring(duration: 0.35))
            }))
            
            self.settingsButtonStateDisposable.set((self.isShowingSettingsMenuPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] isShowingSettingsMenu in
                guard let self else {
                    return
                }
                self.settingsBarButton.setIsMenuOpen(isMenuOpen: isShowingSettingsMenu)
            }))
            
            self.statusDisposable.set((combineLatest(queue: .mainQueue(), videoNode.status, mediaFileStatus)
            |> deliverOnMainQueue).start(next: { [weak self] value, fetchStatus in
                if let strongSelf = self {
                    strongSelf.playerStatusValue = value
                    
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
                                if item.content is HLSVideoContent && display {
                                    initialBuffering = true
                                }
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
                                    strongSelf.isPlaying = false
                                    if strongSelf.isCentral == true {
                                        if !item.isSecret && !strongSelf.playOnDismiss {
                                            strongSelf.updateControlsVisibility(true)
                                        }
                                    }
                                }
                        }
                        if !value.duration.isZero {
                            seekable = value.duration >= 30.0
                        }
                    }
                    
                    if !disablePlayerControls && strongSelf.isCentral == true && isPlaying {
                        strongSelf.isPlayingPromise.set(true)
                        strongSelf.isPlaying = true
                    } else if !isPlaying {
                        strongSelf.isPlayingPromise.set(false)
                        strongSelf.isPlaying = false
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
                    } else if isPaused && !strongSelf.ignorePauseStatus && strongSelf.isCentral == true {
                        if hasStarted || strongSelf.didPause {
                            strongSelf.footerContentNode.content = .playback(paused: true, seekable: seekable)
                        } else if let fetchStatus = fetchStatus, !strongSelf.requiresDownload {
                            if item.content is HLSVideoContent {
                                strongSelf.footerContentNode.content = .playback(paused: true, seekable: seekable)
                            } else {
                                strongSelf.footerContentNode.content = .fetch(status: fetchStatus, seekable: seekable)
                            }
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
                rightBarButtonItem.accessibilityLabel = self.presentationData.strings.Gallery_VoiceOver_Stickers
                barButtonItems.append(rightBarButtonItem)
            }
            
            if forceEnablePiP || (!isAnimated && !disablePlayerControls && !disablePictureInPicture) {
                let rightBarButtonItem = UIBarButtonItem(image: pictureInPictureButtonImage, style: .plain, target: self, action: #selector(self.pictureInPictureButtonPressed))
                rightBarButtonItem.accessibilityLabel = self.presentationData.strings.Gallery_VoiceOver_PictureInPicture
                self.pictureInPictureButton = rightBarButtonItem
                barButtonItems.append(rightBarButtonItem)
                self.hasPictureInPicture = true
            } else {
                self.hasPictureInPicture = false
            }

            if let contentInfo = item.contentInfo, case let .message(message, mediaIndex) = contentInfo {
                var file: TelegramMediaFile?
                for m in message.media {
                    if let m = m as? TelegramMediaFile, m.isVideo {
                        file = m
                        break
                    } else if let m = m as? TelegramMediaWebpage, case let .Loaded(content) = m.content, let f = content.file, f.isVideo {
                        file = f
                        break
                    } else if let paidContent = message.paidContent {
                        let mediaIndex = mediaIndex ?? 0
                        let media = paidContent.extendedMedia[mediaIndex]
                        if case let .full(fullMedia) = media, let m = fullMedia as? TelegramMediaFile {
                            file = m
                        }
                        break
                    }
                }

                var hasMoreButton = false
                if isEnhancedWebPlayer {
                    hasMoreButton = true
                } else if let file = file, !file.isAnimated {
                    hasMoreButton = true
                }
                
                if let _ = message.paidContent, message.id.namespace == Namespaces.Message.Local {
                    hasMoreButton = false
                }
                
                if let _ = message.adAttribute {
                    hasMoreButton = true
                }
                
                if !isAnimated && !disablePlayerControls {
                    let settingsMenuItem = UIBarButtonItem(customDisplayNode: self.settingsBarButton)!
                    settingsMenuItem.accessibilityLabel = self.presentationData.strings.Settings_Title
                    barButtonItems.append(settingsMenuItem)
                }
                
                if hasMoreButton {
                    let moreMenuItem = UIBarButtonItem(customDisplayNode: self.moreBarButton)!
                    moreMenuItem.accessibilityLabel = self.presentationData.strings.Common_More
                    barButtonItems.append(moreMenuItem)
                }
            }

            self._rightBarButtonItems.set(.single(barButtonItems))
        
            videoNode.playbackCompleted = { [weak self, weak videoNode] in
                Queue.mainQueue().async {
                    item.playbackCompleted()
                                        
                    if let strongSelf = self, !isAnimated {
                        if #available(iOS 15.0, *) {
                            if let nativePictureInPictureContent = strongSelf.nativePictureInPictureContent as? NativePictureInPictureContentImpl {
                                nativePictureInPictureContent.invalidatePlaybackState()
                            }
                        }
                        
                        if let snapshotView = videoNode?.view.snapshotView(afterScreenUpdates: false) {
                            videoNode?.view.addSubview(snapshotView)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                        
                        videoNode?.seek(0.0)
                                                
                        if strongSelf.actionAtEnd == .stop && strongSelf.isCentral == true {
                            strongSelf.isPlayingPromise.set(false)
                            strongSelf.isPlaying = false
                            if !item.isSecret {
                                strongSelf.updateControlsVisibility(true)
                            }
                        }
                    }
                }
            }

            self._ready.set(videoNode.ready)
        }
        
        self.item = item

        if let _ = item.content as? NativeVideoContent {
            self.playbackRate = item.playbackRate()
        } else if let _ = item.content as? HLSVideoContent {
            self.playbackRate = item.playbackRate()
        } else if let _ = item.content as? WebEmbedVideoContent {
            self.playbackRate = item.playbackRate()
        }

        self.playbackRatePromise.set(self.playbackRate ?? 1.0)
        self.videoQualityPromise.set(self.videoQuality)
        
        var isAd = false
        if let contentInfo = item.contentInfo {
            switch contentInfo {
                case let .message(message, _):
                    isAd = message.adAttribute != nil
                    self.footerContentNode.setMessage(message, displayInfo: !item.displayInfoOnTop, peerIsCopyProtected: item.peerIsCopyProtected)
                case let .webPage(webPage, media, _):
                    self.footerContentNode.setWebPage(webPage, media: media)
            }
        }
        self.footerContentNode.setup(origin: item.originData, caption: item.caption, isAd: isAd)
        
        if let contentInfo = item.contentInfo, case let .message(message, _) = contentInfo {
            self.overlayContentNode.performAction = { [weak self] action in
                guard let self, let item = self.item else {
                    return
                }
                if case .url = action {
                    self.pictureInPictureButtonPressed()
                    Queue.mainQueue().after(0.3) {
                        item.performAction(action)
                    }
                } else {
                    item.performAction(action)
                }
            }
            self.overlayContentNode.presentPremiumDemo = { [weak self] in
                self?.presentPremiumDemo()
            }
            self.overlayContentNode.openMoreMenu = { [weak self] sourceNode, adMessage in
                self?.openMoreMenu(sourceNode: sourceNode, gesture: nil, adMessage: adMessage, isSettings: false, actionsOnTop: true)
            }
            self.overlayContentNode.setMessage(context: item.context, message: message)
        }
    }
    
    override func controlsVisibilityUpdated(isVisible: Bool) {
        self.controlsVisiblePromise.set(isVisible)
        
        self.videoNode?.isUserInteractionEnabled = isVisible ? self.videoNodeUserInteractionEnabled : false
        self.videoNode?.notifyPlaybackControlsHidden(!isVisible)
    }
    
    private func updateDisplayPlaceholder() {
        self.updateDisplayPlaceholder(!(self.videoNode?.ownsContentNode ?? true) || self.isAirPlayActive)
    }
    
    private func updateDisplayPlaceholder(_ displayPlaceholder: Bool) {
        if displayPlaceholder && !self.disablePictureInPicturePlaceholder {
            if self.pictureInPictureNode == nil {
                let pictureInPictureNode = UniversalVideoGalleryItemPictureInPictureNode(strings: self.presentationData.strings, mode: self.isAirPlayActive ? .airplay : .pictureInPicture)
                pictureInPictureNode.isUserInteractionEnabled = false
                self.pictureInPictureNode = pictureInPictureNode
                self.insertSubnode(pictureInPictureNode, aboveSubnode: self.scrollNode)
                if let validLayout = self.validLayout {
                    if let item = self.item {
                        var placeholderSize = item.content.dimensions.fitted(validLayout.0.size)
                        placeholderSize.height += 2.0
                        pictureInPictureNode.frame = CGRect(origin: CGPoint(x: floor((validLayout.0.size.width - placeholderSize.width) / 2.0), y: floorToScreenPixels((validLayout.0.size.height - placeholderSize.height) / 2.0)), size: placeholderSize)
                        pictureInPictureNode.updateLayout(placeholderSize, transition: .immediate)
                    }
                }
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
            if let contentInfo = item.contentInfo, case let .message(message, _) = contentInfo {
                isStreamable = isMediaStreamable(message: message, media: content.fileReference.media)
            } else {
                isStreamable = isMediaStreamable(media: content.fileReference.media)
            }
            if isLocal || isStreamable {
                return true
            }
        } else if let item = self.item, let _ = item.content as? HLSVideoContent {
            return true
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
                    } else if let item = self.item, let content = item.content as? HLSVideoContent {
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
                        if isAnimated {
                            self.playOnContentOwnership = true
                        } else if self.shouldAutoplayOnCentrality()  {
                            self.playOnContentOwnership = true
                        }
                    }
                } else {
                    self.isPlayingPromise.set(false)
                    self.isPlaying = false
                    
                    self.dismissOnOrientationChange = false
                    if videoNode.ownsContentNode {
                        videoNode.pause()
                    }
                }
            }
            
            if #available(iOS 15.0, *) {
                if let nativePictureInPictureContent = self.nativePictureInPictureContent as? NativePictureInPictureContentImpl {
                    nativePictureInPictureContent.updateIsCentral(isCentral: isCentral)
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
                        if let currentPictureInPictureNode = self.context.sharedContext.mediaManager.currentPictureInPictureNode as? UniversalVideoGalleryItemNode, let currentItem = currentPictureInPictureNode.item, case let .message(currentMessage, _) = currentItem.contentInfo, case let .message(message, _) = item.contentInfo, currentMessage.id == message.id {
                            self.skipInitialPause = true
                        }
                        
                        if self.skipInitialPause {
                            self.skipInitialPause = false
                        } else {
                            self.ignorePauseStatus = true
                            videoNode.pause()
                            videoNode.seek(0.0)
                        }
                    } else {
                        if let status = self.playerStatusValue {
                            self.maybeStorePlaybackStatus(status: status)
                        }
                        videoNode.continuePlayingWithoutSound()
                    }
                    self.updateDisplayPlaceholder()
                } else if !item.fromPlayingVideo {
                    videoNode.canAttachContent = isVisible
                    self.updateDisplayPlaceholder()
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
        if let videoNode = self.videoNode, self.isCentral == true, !self.initiallyActivated {
            self.initiallyActivated = true

            var isAnimated = false
            var seek = MediaPlayerSeek.start
            if let item = self.item {
                if let contentInfo = item.contentInfo, case let .message(message, _) = contentInfo {
                    for attribute in message.attributes {
                        if let attribute = attribute as? ForwardVideoTimestampAttribute {
                            seek = .timecode(Double(attribute.timestamp))
                        }
                    }
                }
                
                if let content = item.content as? NativeVideoContent {
                    isAnimated = content.fileReference.media.isAnimated
                    if let time = item.timecode {
                        seek = .timecode(time)
                    }
                } else if let content = item.content as? HLSVideoContent {
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
                
                Queue.mainQueue().after(1.0, {
                    if let item = self.item, item.isSecret, !self.isPlaying {
                        videoNode.playOnceWithSound(playAndRecord: false, seek: .start, actionAtEnd: self.actionAtEnd)
                    }
                })
            }
        }
    }
    
    private func maybeStorePlaybackStatus(status: MediaPlayerStatus) {
        guard let item = self.item else {
            return
        }
        guard let contentInfo = item.contentInfo, case let .message(message, _) = contentInfo else {
            return
        }
        
        let shouldStorePlaybacksState: Bool
        shouldStorePlaybacksState = status.duration >= 20.0
        
        if shouldStorePlaybacksState {
            var timestamp: Double?
            if status.timestamp > 5.0 && status.timestamp < status.duration - 5.0 {
                timestamp = status.timestamp
            } else {
                timestamp = 0.0
            }
            item.storeMediaPlaybackState(message.id, timestamp, status.baseRate)
        } else {
            item.storeMediaPlaybackState(message.id, nil, status.baseRate)
        }
    }
    
    private var actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd {
        if let item = self.item {
            if !item.isSecret, let content = item.content as? NativeVideoContent, content.duration <= 30 {
                return .loop
            }
            if !item.isSecret, let content = item.content as? HLSVideoContent, content.duration <= 30 {
                return .loop
            }
        }
        return .stop
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        guard let videoNode = self.videoNode, let validLayout = self.validLayout else {
            return
        }
        
        if let node = node.0 as? OverlayMediaItemNode {
            self.customUnembedWhenPortrait = node.customUnembedWhenPortrait
            node.customUnembedWhenPortrait = nil
        }
        
        if let node = node.0 as? OverlayMediaItemNode, self.context.sharedContext.mediaManager.hasOverlayVideoNode(node) {
            if let scrubberView = self.scrubberView {
                scrubberView.animateIn(from: nil, transition: .animated(duration: 0.25, curve: .spring))
            }
            
            var transformedFrame = node.view.convert(node.view.bounds, to: videoNode.view)
            let transformedSuperFrame = node.view.convert(node.view.bounds, to: videoNode.view.superview)
            
            videoNode.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: videoNode.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
            
            transformedFrame.origin = CGPoint()
            
            let transform = CATransform3DScale(videoNode.layer.transform, transformedFrame.size.width / videoNode.layer.bounds.size.width, transformedFrame.size.height / videoNode.layer.bounds.size.height, 1.0)
            videoNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: videoNode.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
            
            videoNode.canAttachContent = true
            self.updateDisplayPlaceholder()
            
            self.context.sharedContext.mediaManager.setOverlayVideoNode(nil)
        } else {
            var scrubberTransition = (node.0 as? GalleryItemTransitionNode)?.scrubberTransition()
            
            if let data = self.context.currentAppConfiguration.with({ $0 }).data {
                if let value = data["ios_gallery_scrubber_transition"] as? Double {
                    if value == 0.0 {
                        scrubberTransition = nil
                    }
                }
            }
            
            if let scrubberView = self.scrubberView {
                scrubberView.animateIn(from: scrubberTransition, transition: .animated(duration: 0.25, curve: .spring))
            }
            
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
            
            if let scrubberTransition, let contentTransition = scrubberTransition.content {
                let transitionContentView = contentTransition.makeView()
                let transitionSelfContentView = contentTransition.makeView()
                
                addToTransitionSurface(transitionContentView)
                self.view.insertSubview(transitionSelfContentView, at: 0)
                transitionSelfContentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
                
                if let transitionContentSuperview = transitionContentView.superview {
                    let transitionContentSourceFrame = contentTransition.sourceView.convert(contentTransition.sourceRect, to: transitionContentSuperview)
                    let transitionContentDestinationFrame = self.view.convert(self.view.bounds, to: transitionContentSuperview)
                    
                    let transitionContentSelfSourceFrame = contentTransition.sourceView.convert(contentTransition.sourceRect, to: self.view)
                    let transitionContentSelfDestinationFrame = self.view.convert(self.view.bounds, to: self.view)
                    
                    let screenCornerRadius: CGFloat = validLayout.layout.deviceMetrics.screenCornerRadius
                    
                    transitionContentView.frame = transitionContentSourceFrame
                    contentTransition.updateView(transitionContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSourceFrame.size, destinationSize: transitionContentDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 0.0), .immediate)
                    
                    transitionSelfContentView.frame = transitionContentSelfSourceFrame
                    contentTransition.updateView(transitionSelfContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSelfSourceFrame.size, destinationSize: transitionContentSelfDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 0.0), .immediate)
                    
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                    
                    transition.updateFrame(view: transitionContentView, frame: transitionContentDestinationFrame, completion: { [weak transitionContentView] _ in
                        transitionContentView?.removeFromSuperview()
                    })
                    contentTransition.updateView(transitionContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSourceFrame.size, destinationSize: transitionContentDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 1.0), transition)
                    
                    transition.updateFrame(view: transitionSelfContentView, frame: transitionContentSelfDestinationFrame, completion: { [weak transitionSelfContentView] _ in
                        transitionSelfContentView?.removeFromSuperview()
                    })
                    contentTransition.updateView(transitionSelfContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSelfSourceFrame.size, destinationSize: transitionContentSelfDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 1.0), transition)
                }
            }
            
            if self.item?.fromPlayingVideo ?? false {
                Queue.mainQueue().after(0.001) {
                    videoNode.canAttachContent = true
                    self.updateDisplayPlaceholder()
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
        if let status = self.playerStatusValue {
            self.maybeStorePlaybackStatus(status: status)
        }
        
        self.isAnimatingOut = true
        
        guard let videoNode = self.videoNode else {
            completion()
            return
        }
        
        var scrubberTransition = (node.0 as? GalleryItemTransitionNode)?.scrubberTransition()
        if let data = self.context.currentAppConfiguration.with({ $0 }).data {
            if let value = data["ios_gallery_scrubber_transition"] as? Double {
                if value == 0.0 {
                    scrubberTransition = nil
                }
            }
        }
        
        if let scrubberView = self.scrubberView {
            var scrubberEffectiveTransition = scrubberTransition
            if !self.controlsVisibility() {
                scrubberEffectiveTransition = nil
            }
            scrubberView.animateOut(to: scrubberEffectiveTransition, transition: .animated(duration: 0.25, curve: .spring))
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
                if let status = self.playerStatusValue {
                    self.maybeStorePlaybackStatus(status: status)
                }
                
                if self.isPaused || !self.keepSoundOnDismiss {
                    if let item = self.item, item.content is HLSVideoContent {
                    } else {
                        videoNode.continuePlayingWithoutSound()
                    }
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
        
        var scrubberContentTransition = scrubberTransition
        if !self.controlsVisibility() {
            scrubberContentTransition = nil
        }
        if let scrubberContentTransition, let contentTransition = scrubberContentTransition.content {
            let transitionContentView = contentTransition.makeView()
            let transitionSelfContentView = contentTransition.makeView()
            
            addToTransitionSurface(transitionContentView)
            //self.view.insertSubview(transitionSelfContentView, at: 0)
            transitionSelfContentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false)
            
            if let validLayout = self.validLayout, let transitionContentSuperview = transitionContentView.superview {
                let transitionContentSourceFrame = contentTransition.sourceView.convert(contentTransition.sourceRect, to: transitionContentSuperview)
                let transitionContentDestinationFrame = self.view.convert(self.view.bounds, to: transitionContentSuperview)
                
                let transitionContentSelfSourceFrame = contentTransition.sourceView.convert(contentTransition.sourceRect, to: self.view)
                let transitionContentSelfDestinationFrame = self.view.convert(self.view.bounds, to: self.view)
                
                let screenCornerRadius: CGFloat = validLayout.layout.deviceMetrics.screenCornerRadius
                
                transitionContentView.frame = transitionContentDestinationFrame
                contentTransition.updateView(transitionContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSourceFrame.size, destinationSize: transitionContentDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 1.0), .immediate)
                
                transitionSelfContentView.frame = transitionContentSelfDestinationFrame
                contentTransition.updateView(transitionSelfContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSelfSourceFrame.size, destinationSize: transitionContentSelfDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 1.0), .immediate)
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                
                transition.updateFrame(view: transitionContentView, frame: transitionContentSourceFrame, completion: { [weak transitionContentView] _ in
                    transitionContentView?.removeFromSuperview()
                })
                contentTransition.updateView(transitionContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSourceFrame.size, destinationSize: transitionContentDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 0.0), transition)
                
                transition.updateFrame(view: transitionSelfContentView, frame: transitionContentSelfSourceFrame, completion: { [weak transitionSelfContentView] _ in
                    transitionSelfContentView?.removeFromSuperview()
                })
                contentTransition.updateView(transitionSelfContentView, GalleryItemScrubberTransition.Content.TransitionState(sourceSize: transitionContentSelfSourceFrame.size, destinationSize: transitionContentSelfDestinationFrame.size, destinationCornerRadius: screenCornerRadius, progress: 0.0), transition)
            }
        }
        
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
    
    override func maybePerformActionForSwipeDismiss() -> Bool {
        if let data = self.context.currentAppConfiguration.with({ $0 }).data {
            if let _ = data["ios_killswitch_disable_swipe_pip"] {
                return false
            }
            var swipeUpToClose = false
            if let value = data["video_swipe_up_to_close"] as? Double, value == 1.0 {
                swipeUpToClose = true
            } else if let value = data["video_swipe_up_to_close"] as? Bool, value {
                swipeUpToClose = true
            }
            
            if swipeUpToClose {
                addAppLogEvent(postbox: self.context.account.postbox, type: "swipe_up_close", peerId: self.context.account.peerId)
                
                return false
            }
        }
        
        if #available(iOS 15.0, *) {
            if let nativePictureInPictureContent = self.nativePictureInPictureContent as? NativePictureInPictureContentImpl {
                addAppLogEvent(postbox: self.context.account.postbox, type: "swipe_up_pip", peerId: self.context.account.peerId)
                nativePictureInPictureContent.beginPictureInPicture()
                return true
            }
        }
        return false
    }
    
    override func maybePerformActionForSwipeDownDismiss() -> Bool {
        addAppLogEvent(postbox: self.context.account.postbox, type: "swipe_down_close", peerId: self.context.account.peerId)
        return false
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
            let overlayNode = OverlayUniversalVideoNode(context: self.context, postbox: self.context.account.postbox, audioSession: context.sharedContext.mediaManager.audioSession, manager: context.sharedContext.mediaManager.universalVideoManager, content: item.content, expand: {
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
                    case let .message(message, _):
                        let gallery = GalleryController(context: context, source: .peerMessagesAtId(messageId: message.id, chatLocation: .peer(id: message.id.peerId), customTag: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil)), playbackRate: playbackRate, replaceRootController: { controller, ready in
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
                self.beginCustomDismiss(.default)
                self.statusNode.isHidden = true
                self.animateOut(toOverlay: overlayNode, completion: { [weak self] in
                    self?.completeCustomDismiss(false)
                })
            }
        }
    }
    
    private func setupNativePictureInPicture() {
        guard let item = self.item, let videoNode = self.videoNode else {
            return
        }
        
        if videoNode.getVideoLayer() == nil {
            return
        }
        
        var useNative = true
        if let data = self.context.currentAppConfiguration.with({ $0 }).data, let _ = data["ios_killswitch_disable_native_pip_v2"] {
            useNative = false
        }
        var isAd = false
        if let contentInfo = item.contentInfo {
            switch contentInfo {
            case let .message(message, _):
                isAd = message.adAttribute != nil
                self.footerContentNode.setMessage(message, displayInfo: !item.displayInfoOnTop, peerIsCopyProtected: item.peerIsCopyProtected)
            case let .webPage(webPage, media, _):
                self.footerContentNode.setWebPage(webPage, media: media)
            }
        }
        if isAd {
            useNative = false
        }
        if let content = item.content as? NativeVideoContent {
            if content.fileReference.media.isAnimated {
                useNative = false
            }
        }
        if !useNative {
            return
        }
        
        var hiddenMedia: (MessageId, Media)? = nil
        switch item.contentInfo {
        case let .message(message, _):
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
        
        if #available(iOS 15.0, *) {
            var didExpand = false
            let content = NativePictureInPictureContentImpl(context: self.context, mediaManager: self.context.sharedContext.mediaManager, accountId: self.context.account.id, hiddenMedia: hiddenMedia, videoNode: videoNode, canSkip: true, willBegin: { [weak self] content in
                guard let self, let controller = self.galleryController(), let navigationController = self.baseNavigationController() else {
                    return
                }
                
                self.activePictureInPictureNavigationController = navigationController
                self.activePictureInPictureController = controller
                self.context.sharedContext.mediaManager.currentPictureInPictureNode = self
                
                self.beginCustomDismiss(.pip)
                controller.view.alpha = 0.0
                controller.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                    self?.completeCustomDismiss(true)
                })
                if let videoNode = self.videoNode {
                    videoNode.setNativePictureInPictureIsActive(false)
                }
                didExpand = false
            }, didBegin: { [weak self] _ in
                guard let self else {
                    return
                }
                let _ = self
            }, didEnd: { [weak self] _ in
                guard let self else {
                    return
                }
                
                if self.context.sharedContext.mediaManager.currentPictureInPictureNode === self {
                    self.context.sharedContext.mediaManager.currentPictureInPictureNode = nil
                }
                
                if let videoNode = self.videoNode {
                    videoNode.setNativePictureInPictureIsActive(false)
                }
                
                if !didExpand {
                    self.activePictureInPictureController = nil
                    self.activePictureInPictureNavigationController = nil
                    
                    addAppLogEvent(postbox: self.context.account.postbox, type: "pip_close_btn", peerId: self.context.account.peerId)
                }
            }, expand: { [weak self] completion in
                didExpand = true
                
                guard let self, let activePictureInPictureController = self.activePictureInPictureController, let activePictureInPictureNavigationController = self.activePictureInPictureNavigationController else {
                    completion()
                    return
                }
                
                self.activePictureInPictureController = nil
                self.activePictureInPictureNavigationController = nil
                
                let previousPresentationArguments = activePictureInPictureController.presentationArguments
                activePictureInPictureController.presentationArguments = nil
                activePictureInPictureNavigationController.currentWindow?.present(activePictureInPictureController, on: .root, blockInteraction: false, completion: {
                })
                activePictureInPictureController.presentationArguments = previousPresentationArguments
                self.updateControlsVisibility(false)
                
                activePictureInPictureController.view.alpha = 1.0
                activePictureInPictureController.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.35, completion: { _ in
                })
                
                completion()
            })
            
            self.nativePictureInPictureContent = content
        }
    }
    
    @objc func pictureInPictureButtonPressed() {
        if self.nativePictureInPictureContent == nil {
            self.setupNativePictureInPicture()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            
            if let currentPictureInPictureNode = self.context.sharedContext.mediaManager.currentPictureInPictureNode as? UniversalVideoGalleryItemNode, let currentItem = currentPictureInPictureNode.item, case let .message(currentMessage, _) = currentItem.contentInfo, case let .message(message, _) = self.item?.contentInfo, currentMessage.id == message.id {
                if let controller = self.galleryController() as? GalleryController {
                    controller.dismiss(forceAway: true)
                }
                return
            }
            
            if #available(iOS 15.0, *) {
                if let nativePictureInPictureContent = self.nativePictureInPictureContent as? NativePictureInPictureContentImpl {
                    addAppLogEvent(postbox: self.context.account.postbox, type: "pip_btn", peerId: self.context.account.peerId)
                    nativePictureInPictureContent.beginPictureInPicture()
                    return
                }
            }
        }
    }
    
    func expandPIP() {
        if #available(iOS 15.0, *) {
            if let nativePictureInPictureContent = self.nativePictureInPictureContent as? NativePictureInPictureContentImpl {
                nativePictureInPictureContent.requestExpand()
            }
        }
    }

    private func contentInfo() -> (message: Message, file: TelegramMediaFile?, isWebpage: Bool)? {
        guard let item = self.item else {
            return nil
        }
        if let contentInfo = item.contentInfo, case let .message(message, mediaIndex) = contentInfo {
            var file: TelegramMediaFile?
            var isWebpage = false
            for m in message.media {
                if let paidContent = m as? TelegramMediaPaidContent {
                    let media = paidContent.extendedMedia[mediaIndex ?? 0]
                    if case let .full(fullMedia) = media, let fullMedia = fullMedia as? TelegramMediaFile, fullMedia.isVideo {
                        file = fullMedia
                    }
                    break
                } else if let m = m as? TelegramMediaFile, m.isVideo {
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

    private var playOnDismiss = false
    private func openMoreMenu(sourceNode: ContextReferenceContentNode, gesture: ContextGesture?, adMessage: Message?, isSettings: Bool, actionsOnTop: Bool = false) {
        guard let controller = self.baseNavigationController()?.topViewController as? ViewController else {
            return
        }
                
        var dismissImpl: (() -> Void)?
        let items: Signal<(items: [ContextMenuItem], topItems: [ContextMenuItem]), NoError>
        if let adMessage {
            items = self.adMenuMainItems(message: adMessage) |> map { items in
                return (items, [])
            }
        } else {
            items = self.contextMenuMainItems(isSettings: isSettings, dismiss: {
                dismissImpl?()
            })
        }
        
        let contextController = ContextController(presentationData: self.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme), source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceNode: sourceNode, actionsOnTop: actionsOnTop)), items: items |> map { items in
            if !items.topItems.isEmpty {
                return ContextController.Items(id: AnyHashable(0), content: .twoLists(items.items, items.topItems))
            } else {
                return ContextController.Items(id: AnyHashable(0), content: .list(items.items))
            }
        }, gesture: gesture)
        
        if let _ = adMessage {
            if self.isPlaying {
                self.playOnDismiss = true
                self.videoNode?.pause()
            }
            self.isShowingAdMenuPromise.set(true)
        } else if isSettings {
            self.isShowingSettingsMenuPromise.set(true)
        } else {
            self.isShowingContextMenuPromise.set(true)
        }
        controller.presentInGlobalOverlay(contextController)
        dismissImpl = { [weak contextController] in
            contextController?.dismiss()
        }
        contextController.dismissed = { [weak self] in
            Queue.mainQueue().after(isSettings ? 0.0 : 0.1, {
                guard let self else {
                    return
                }
                if let _ = adMessage {
                    if self.playOnDismiss {
                        self.playOnDismiss = false
                        self.videoNode?.play()
                    }
                    self.isShowingAdMenuPromise.set(false)
                } else if isSettings {
                    self.isShowingSettingsMenuPromise.set(false)
                } else {
                    self.isShowingContextMenuPromise.set(false)
                }
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
    
    private func presentPremiumDemo() {
        var replaceImpl: ((ViewController) -> Void)?
        let controller = self.context.sharedContext.makePremiumDemoController(context: self.context, subject: .noAds, forceDark: true, action: {
            let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .ads, forceDark: true, dismissed: nil)
            replaceImpl?(controller)
        }, dismissed: nil)
        replaceImpl = { [weak controller] c in
            controller?.replace(with: c)
        }
        if let navigationController = self.baseNavigationController() {
            navigationController.pushViewController(controller)
        }
    }
    
    private func adMenuMainItems(message: Message) -> Signal<[ContextMenuItem], NoError> {
        guard let adAttribute = message.adAttribute else {
            return .single([])
        }
        
        let context = self.context
        let presentationData = self.presentationData
        var actions: [ContextMenuItem] = []
        if adAttribute.canReport {
            actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_ContextMenu_AboutAd, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
            }, iconSource: nil, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                if let navigationController = self?.baseNavigationController() as? NavigationController {
                    navigationController.pushViewController(AdsInfoScreen(context: context, mode: .channel, forceDark: true))
                }
            })))
            
            actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_ContextMenu_ReportAd, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.primaryTextColor)
            }, iconSource: nil, action: { [weak self] _, f in
                f(.default)
                
                let _ = (context.engine.messages.reportAdMessage(opaqueId: adAttribute.opaqueId, option: nil)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    if case let .options(title, options) = result {
                        if let navigationController = self?.baseNavigationController() as? NavigationController {
                            navigationController.pushViewController(
                                AdsReportScreen(
                                    context: context,
                                    opaqueId: adAttribute.opaqueId,
                                    title: title,
                                    options: options,
                                    forceDark: true,
                                    completed: {
                                        if let navigationController = self?.baseNavigationController() as? NavigationController, let chatController = navigationController.viewControllers.last as? ChatController {
                                            chatController.removeAd(opaqueId: adAttribute.opaqueId)
                                        }
                                    }
                                )
                            )
                        }
                    }
                })
            })))
            
            actions.append(.separator)
                           
            actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Chat_ContextMenu_RemoveAd, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.primaryTextColor)
            }, iconSource: nil, action: { [weak self] c, _ in
                c?.dismiss(completion: {
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .noAds, forceDark: true, action: {
                        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: true, dismissed: nil)
                        replaceImpl?(controller)
                    }, dismissed: nil)
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    if let navigationController = self?.baseNavigationController() as? NavigationController {
                        navigationController.pushViewController(controller)
                    }
                })
            })))
        } else {
            actions.append(.action(ContextMenuActionItem(text: presentationData.strings.SponsoredMessageMenu_Info, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
            }, iconSource: nil, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                if let navigationController = self?.baseNavigationController() as? NavigationController {
                    navigationController.pushViewController(AdInfoScreen(context: context, forceDark: true))
                }
            })))
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            if !context.isPremium && !premiumConfiguration.isPremiumDisabled {
                actions.append(.action(ContextMenuActionItem(text: presentationData.strings.SponsoredMessageMenu_Hide, textColor: .primary, textLayout: .twoLinesMax, textFont: .custom(font: Font.regular(presentationData.listsFontSize.baseDisplaySize - 1.0), height: nil, verticalOffset: nil), badge: nil, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.primaryTextColor)
                }, iconSource: nil, action: { [weak self] c, _ in
                    c?.dismiss(completion: { [weak self] in
                        self?.presentPremiumDemo()
                    })
                })))
            }
            
            if !message.text.isEmpty {
                actions.append(.separator)
                actions.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuCopy, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    var messageEntities: [MessageTextEntity]?
                    for attribute in message.attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            messageEntities = attribute.entities
                        }
                    }
                    
                    storeMessageTextInPasteboard(message.text, entities: messageEntities)
                    
                    Queue.mainQueue().after(0.2, {
                        guard let self, let controller = self.galleryController() else {
                            return
                        }
                        controller.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: presentationData.strings.Conversation_MessageCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    })
                    
                    f(.default)
                })))
            }
        }

        return .single(actions)
    }


    private func contextMenuMainItems(isSettings: Bool, dismiss: @escaping () -> Void) -> Signal<(items: [ContextMenuItem], topItems: [ContextMenuItem]), NoError> {
        guard let videoNode = self.videoNode, let item = self.item else {
            return .single(([], []))
        }
        
        let peer: Signal<EnginePeer?, NoError>
        if let (message, _, _) = self.contentInfo() {
            peer = self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: message.id.peerId))
        } else {
            peer = .single(nil)
        }

        return combineLatest(queue: Queue.mainQueue(),
            videoNode.status |> take(1),
            peer,
            videoNode.videoQualityStateSignal()
        )
        |> map { [weak self] status, peer, videoQualityState -> (items: [ContextMenuItem], topItems: [ContextMenuItem]) in
            guard let status = status, let strongSelf = self else {
                return ([], [])
            }

            var topItems: [ContextMenuItem] = []
            var items: [ContextMenuItem] = []
            
            if isSettings {
                let sliderValuePromise = ValuePromise<Double?>(nil)
                topItems.append(.custom(SliderContextItem(title: strongSelf.presentationData.strings.Gallery_VideoSettings_SpeedControlTitle, minValue: 0.2, maxValue: 2.5, value: status.baseRate, valueChanged: { [weak self] newValue, _ in
                    guard let strongSelf = self, let videoNode = strongSelf.videoNode else {
                        return
                    }
                    let newValue = normalizeValue(newValue)
                    videoNode.setBaseRate(newValue)
                    if let controller = strongSelf.galleryController() as? GalleryController {
                        controller.updateSharedPlaybackRate(newValue)
                    }
                    sliderValuePromise.set(newValue)
                }), true))
                
                if let videoQualityState, !videoQualityState.available.isEmpty {
                } else {
                    items.append(.custom(SectionTitleContextItem(text: strongSelf.presentationData.strings.Gallery_VideoSettings_SpeedSectionTitle), false))
                    for (text, _, rate) in strongSelf.speedList(strings: strongSelf.presentationData.strings) {
                        let isSelected = abs(status.baseRate - rate) < 0.01
                        items.append(.action(ContextMenuActionItem(text: text, icon: { _ in return nil }, iconSource: ContextMenuActionItemIconSource(size: CGSize(width: 24.0, height: 24.0), signal: sliderValuePromise.get()
                        |> map { value in
                            if isSelected && value == nil {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .white)
                            } else {
                                return nil
                            }
                        }), action: { _, f in
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
                }
                
                if let videoQualityState, !videoQualityState.available.isEmpty {
                    items.append(.custom(SectionTitleContextItem(text: strongSelf.presentationData.strings.Gallery_VideoSettings_QualitySectionTitle), false))
                    
                    do {
                        let isSelected = videoQualityState.preferred == .auto
                        let qualityText: String = strongSelf.presentationData.strings.Gallery_VideoSettings_QualityAuto
                        let textLayout: ContextMenuActionItemTextLayout
                        if videoQualityState.current != 0 {
                            textLayout = .secondLineWithValue("\(videoQualityState.current)p")
                        } else {
                            textLayout = .singleLine
                        }
                        items.append(.action(ContextMenuActionItem(id: AnyHashable("q"), text: qualityText, textLayout: textLayout, icon: { _ in
                            if isSelected {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .white)
                            } else {
                                return nil
                            }
                        }, action: { [weak strongSelf] _, f in
                            f(.default)
                            
                            guard let strongSelf, let videoNode = strongSelf.videoNode else {
                                return
                            }
                            videoNode.setVideoQuality(.auto)
                            strongSelf.videoQualityPromise.set(.auto)
                        })))
                    }
                    
                    if videoQualityState.available.count > 1 {
                        for quality in videoQualityState.available {
                            let isSelected = videoQualityState.preferred == .quality(quality)
                            let qualityTitle: String
                            if quality <= 360 {
                                qualityTitle = strongSelf.presentationData.strings.Gallery_VideoSettings_QualityLow
                            } else if quality <= 480 {
                                qualityTitle = strongSelf.presentationData.strings.Gallery_VideoSettings_QualityMedium
                            } else if quality <= 720 {
                                qualityTitle = strongSelf.presentationData.strings.Gallery_VideoSettings_QualityHD
                            } else if quality <= 1080 {
                                qualityTitle = strongSelf.presentationData.strings.Gallery_VideoSettings_QualityFHD
                            } else {
                                qualityTitle = strongSelf.presentationData.strings.Gallery_VideoSettings_QualityQHD
                            }
                            var qualityDebugText = ""
                            var displayDebugInfo = false
                            if strongSelf.context.sharedContext.applicationBindings.appBuildType == .internal {
                                displayDebugInfo = true
                            } else {
                                #if DEBUG
                                displayDebugInfo = true
                                #endif
                            }
                            if displayDebugInfo, let content = item.content as? HLSVideoContent, let qualitySet = HLSQualitySet(baseFile: content.fileReference, codecConfiguration: HLSCodecConfiguration(context: strongSelf.context)), let qualityFile = qualitySet.qualityFiles[quality] {
                                for attribute in qualityFile.media.attributes {
                                    if case let .Video(_, _, _, _, _, videoCodec) = attribute, let videoCodec {
                                        qualityDebugText += " \(videoCodec)"
                                        if videoCodec == "av1" || videoCodec == "av01" {
                                            qualityDebugText += internal_isHardwareAv1Supported ? " (HW)" : " (SW)"
                                        }
                                    }
                                }
                                if let size = qualityFile.media.size {
                                    qualityDebugText += ", \(dataSizeString(size, formatting: DataSizeStringFormatting(presentationData: strongSelf.presentationData)))"
                                }
                            }
                            items.append(.action(ContextMenuActionItem(text: qualityTitle, textLayout: .secondLineWithValue("\(quality)p\(qualityDebugText)"), icon: { _ in
                                if isSelected {
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .white)
                                } else {
                                    return nil
                                }
                            }, action: { [weak self] _, f in
                                f(.default)
                                
                                guard let self, let videoNode = self.videoNode else {
                                    return
                                }
                                videoNode.setVideoQuality(.quality(quality))
                                self.videoQualityPromise.set(.quality(quality))
                                
                                /*if let controller = strongSelf.galleryController() as? GalleryController {
                                 controller.updateSharedPlaybackRate(rate)
                                 }*/
                            })))
                        }
                    }
                }
            } else {
                if let (message, maybeFile, _) = strongSelf.contentInfo(), let file = maybeFile, !message.isCopyProtected() && !item.peerIsCopyProtected && message.paidContent == nil {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Gallery_MenuSaveToGallery, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.actionSheet.primaryTextColor) }, action: { c, _ in
                        guard let self else {
                            c?.dismiss(result: .default, completion: nil)
                            return
                        }
                        
                        if let content = item.content as? HLSVideoContent {
                            guard let videoNode = self.videoNode, let qualityState = videoNode.videoQualityState(), !qualityState.available.isEmpty else {
                                return
                            }
                            if qualityState.available.isEmpty {
                                return
                            }
                            guard let qualitySet = HLSQualitySet(baseFile: content.fileReference, codecConfiguration: HLSCodecConfiguration(context: self.context)) else {
                                return
                            }
                            
                            var allFiles: [FileMediaReference] = []
                            allFiles.append(content.fileReference)
                            allFiles.append(contentsOf: qualitySet.qualityFiles.values)
                            
                            let qualitySignals = allFiles.map { file -> Signal<(fileId: MediaId, isCached: Bool), NoError> in
                                return self.context.account.postbox.mediaBox.resourceStatus(file.media.resource)
                                |> take(1)
                                |> map { status -> (fileId: MediaId, isCached: Bool) in
                                    return (file.media.fileId, status == .Local)
                                }
                            }
                            let _ = (combineLatest(queue: .mainQueue(), qualitySignals)
                            |> deliverOnMainQueue).startStandalone(next: { [weak self, weak c] fileStatuses in
                                guard let self else {
                                    return
                                }
                                
                                var items: [ContextMenuItem] = []
                                
                                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Common_Back, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                                }, iconPosition: .left, action: { c, _ in
                                    c?.popItems()
                                })))
                                
                                let addItem: (Int?, FileMediaReference) -> Void = { quality, qualityFile in
                                    guard let qualityFileSize = qualityFile.media.size else {
                                        return
                                    }
                                    var fileSizeString = dataSizeString(qualityFileSize, formatting: DataSizeStringFormatting(presentationData: self.presentationData))
                                    let title: String
                                    if let quality {
                                        title = self.presentationData.strings.Gallery_SaveToGallery_Quality("\(quality)").string
                                    } else {
                                        title = self.presentationData.strings.Gallery_SaveToGallery_Original
                                    }
                                    
                                    if let statusValue = fileStatuses.first(where: { $0.fileId ==  qualityFile.media.fileId }), statusValue.isCached {
                                        fileSizeString.append(" • \(self.presentationData.strings.Gallery_SaveToGallery_cached)")
                                    } else {
                                        fileSizeString.insert(contentsOf: "↓ ", at: fileSizeString.startIndex)
                                    }
                                    
                                    items.append(.action(ContextMenuActionItem(text: title, textLayout: .secondLineWithValue(fileSizeString), icon: { _ in
                                        return nil
                                    }, action: { [weak self] c, _ in
                                        c?.dismiss(result: .default, completion: nil)
                                        
                                        guard let self else {
                                            return
                                        }
                                        guard let controller = self.galleryController() else {
                                            return
                                        }
                                        
                                        let saveScreen = SaveProgressScreen(context: self.context, content: .progress(self.presentationData.strings.Story_TooltipSaving, 0.0))
                                        controller.present(saveScreen, in: .current)
                                        
                                        let stringSaving = self.presentationData.strings.Story_TooltipSaving
                                        let stringSaved = self.presentationData.strings.Story_TooltipSaved
                                        
                                        let saveFileReference: AnyMediaReference = qualityFile.abstract
                                        let saveSignal = SaveToCameraRoll.saveToCameraRoll(context: self.context, postbox: self.context.account.postbox, userLocation: .peer(message.id.peerId), mediaReference: saveFileReference)
                                        
                                        let disposable = (saveSignal
                                        |> deliverOnMainQueue).start(next: { [weak saveScreen] progress in
                                            guard let saveScreen else {
                                                return
                                            }
                                            saveScreen.content = .progress(stringSaving, progress)
                                        }, completed: { [weak saveScreen] in
                                            guard let saveScreen else {
                                                return
                                            }
                                            saveScreen.content = .completion(stringSaved)
                                            Queue.mainQueue().after(3.0, { [weak saveScreen] in
                                                saveScreen?.dismiss()
                                            })
                                        })
                                        
                                        saveScreen.cancelled = {
                                            disposable.dispose()
                                        }
                                    })))
                                }
                                
                                if self.context.isPremium {
                                    addItem(nil, content.fileReference)
                                } else {
                                    #if DEBUG
                                    addItem(nil, content.fileReference)
                                    #endif
                                }
                                
                                for quality in qualityState.available {
                                    guard let qualityFile = qualitySet.qualityFiles[quality] else {
                                        continue
                                    }
                                    addItem(quality, qualityFile)
                                }
                                
                                c?.pushItems(items: .single(ContextController.Items(content: .list(items))))
                            })
                        } else {
                            c?.dismiss(result: .default, completion: nil)
                            
                            switch self.fetchStatus {
                            case .Local:
                                let _ = (SaveToCameraRoll.saveToCameraRoll(context: self.context, postbox: self.context.account.postbox, userLocation: .peer(message.id.peerId), mediaReference: .message(message: MessageReference(message), media: file))
                                |> deliverOnMainQueue).start(completed: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    guard let controller = self.galleryController() else {
                                        return
                                    }
                                    controller.present(UndoOverlayController(presentationData: self.presentationData, content: .mediaSaved(text: self.presentationData.strings.Gallery_VideoSaved), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                })
                            default:
                                guard let controller = self.galleryController() else {
                                    return
                                }
                                controller.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Gallery_WaitForVideoDownoad, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {
                                })]), in: .window(.root))
                            }
                        }
                    })))
                }
                
                if !items.isEmpty {
                    items.append(.separator)
                }
                if let (message, _, _) = strongSelf.contentInfo() {
                    let context = strongSelf.context
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor)}, action: { [weak self] _, f in
                        guard let strongSelf = self, let peer = peer else {
                            return
                        }
                        if let navigationController = strongSelf.baseNavigationController() {
                            strongSelf.beginCustomDismiss(.simpleAnimation)
                            
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(message.id), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false)))
                            
                            Queue.mainQueue().after(0.3) {
                                strongSelf.completeCustomDismiss(false)
                            }
                        }
                        f(.default)
                    })))
                }
                
                //            if #available(iOS 11.0, *) {
                //                items.append(.action(ContextMenuActionItem(text: "AirPlay", textColor: .primary, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/AirPlay"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                //                    f(.default)
                //                    guard let strongSelf = self else {
                //                        return
                //                    }
                //                    strongSelf.beginAirPlaySetup()
                //                })))
                //            }
                
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
                
                if let peer, let (message, _, _) = strongSelf.contentInfo(), canSendMessagesToPeer(peer._asPeer()) {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuReply, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reply"), color: theme.contextMenu.primaryColor)}, action: { [weak self] _, f in
                        if let self, let navigationController = self.baseNavigationController() {
                            self.beginCustomDismiss(.simpleAnimation)
                            
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(message.id), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: true)))
                            
                            Queue.mainQueue().after(0.3) {
                                self.completeCustomDismiss(false)
                            }
                        }
                        f(.default)
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
            }

            return (items, topItems)
        }
    }
    
    private var isAirPlayActive = false
    private var externalVideoPlayer: ExternalVideoPlayer?
    func beginAirPlaySetup() {
        guard let content = self.item?.content as? NativeVideoContent else {
            return
        }
        if #available(iOS 11.0, *) {
            self.externalVideoPlayer = ExternalVideoPlayer(context: self.context, content: content)
            self.externalVideoPlayer?.openRouteSelection()
            self.externalVideoPlayer?.isActiveUpdated = { [weak self] isActive in
                if let strongSelf = self {
                    if strongSelf.isAirPlayActive && !isActive {
                        strongSelf.externalVideoPlayer = nil
                    }
                    strongSelf.isAirPlayActive = isActive
                    strongSelf.updateDisplayPlaceholder()
                }
            }
        }
    }

    @objc func openStickersButtonPressed() {
        guard let content = self.item?.content as? NativeVideoContent else {
            return
        }
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
            let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packs[0], stickerPacks: packs, sendSticker: nil, actionPerformed: { actions in
                if let (info, items, action) = actions.first {
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
                }
            }, dismissed: { [weak self] in
                self?.isInteractingPromise.set(false)
            })
            (baseNavigationController?.topViewController as? ViewController)?.present(controller, in: .window(.root), with: nil)
        })
    }
    
    @objc private func settingsButtonPressed() {
        self.openMoreMenu(sourceNode: self.settingsBarButton.referenceNode, gesture: nil, adMessage: nil, isSettings: true)
    }
    
    override func adjustForPreviewing() {
        super.adjustForPreviewing()
        
        self.scrubberView?.isHidden = true
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, self.overlayContentNode))
    }

    func updatePlaybackRate(_ playbackRate: Double?) {
        self.playbackRate = playbackRate

        if let playbackRate = self.playbackRate {
            self.videoNode?.setBaseRate(playbackRate)
        }

        self.playbackRatePromise.set(self.playbackRate ?? 1.0)
    }
    
    func updateVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.videoQuality = videoQuality
        self.videoQualityPromise.set(videoQuality)
        
        self.videoNode?.setVideoQuality(videoQuality)
    }
    
    public func seekToStart() {
        self.videoNode?.seek(0.0)
        self.videoNode?.play()
    }
    
    override var keyShortcuts: [KeyShortcut] {
        let strings = self.presentationData.strings
        
        var keyShortcuts: [KeyShortcut] = []
        keyShortcuts.append(
            KeyShortcut(
                title: self.isPlaying ? strings.KeyCommand_Pause : strings.KeyCommand_Play,
                input: " ",
                modifiers: [],
                action: { [weak self] in
                    self?.footerContentNode.playbackControl?()
                }
            )
        )
        
        keyShortcuts.append(
            KeyShortcut(
                title: strings.KeyCommand_SeekBackward,
                input: UIKeyCommand.inputLeftArrow,
                modifiers: [.shift],
                action: { [weak self] in
                    self?.footerContentNode.seekBackward?(5)
                }
            )
        )
        keyShortcuts.append(
            KeyShortcut(
                title: strings.KeyCommand_SeekForward,
                input: UIKeyCommand.inputRightArrow,
                modifiers: [.shift],
                action: { [weak self] in
                    self?.footerContentNode.seekForward?(5)
                }
            )
        )
        
        keyShortcuts.append(
            KeyShortcut(
                title: strings.KeyCommand_Share,
                input: "S",
                modifiers: [.command],
                action: { [weak self] in
                    self?.footerContentNode.actionButtonPressed()
                }
            )
        )
        if self.hasPictureInPicture {
            keyShortcuts.append(
                KeyShortcut(
                    title: strings.KeyCommand_SwitchToPIP,
                    input: "P",
                    modifiers: [.command],
                    action: { [weak self] in
                        self?.pictureInPictureButtonPressed()
                    }
                )
            )
        }
        if self.canDelete() {
            keyShortcuts.append(
                KeyShortcut(
                    input: "\u{8}",
                    modifiers: [],
                    action: { [weak self] in
                        self?.footerContentNode.deleteButtonPressed()
                    }
                )
            )
        }
        return keyShortcuts
    }
    
    override func hasActiveEdgeAction(edge: ActiveEdge) -> Bool {
        if case .right = edge {
            if let playerStatusValue = self.playerStatusValue, case .playing = playerStatusValue.status {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    override func setActiveEdgeAction(edge: ActiveEdge?) {
        guard let videoNode = self.videoNode else {
            return
        }
        if let edge, case .right = edge {
            let effectiveRate: Double
            if let current = self.activeEdgeRateState {
                effectiveRate = min(4.0, current.initialRate + 1.0)
                self.activeEdgeRateState = (current.initialRate, effectiveRate)
            } else {
                guard let playbackRate = self.playbackRate else {
                    return
                }
                effectiveRate = min(4.0, playbackRate + 1.0)
                self.activeEdgeRateState = (playbackRate, effectiveRate)
            }
            videoNode.setBaseRate(effectiveRate)
        } else if let (initialRate, _) = self.activeEdgeRateState {
            self.activeEdgeRateState = nil
            videoNode.setBaseRate(initialRate)
        }
        
        if let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout.layout, navigationBarHeight: validLayout.navigationBarHeight, transition: .animated(duration: 0.35, curve: .spring))
        }
    }
    
    override func adjustActiveEdgeAction(distance: CGFloat) {
        guard let videoNode = self.videoNode else {
            return
        }
        if let current = self.activeEdgeRateState {
            var rateFraction = Double(distance) / 100.0
            rateFraction = max(-1.0, min(1.0, rateFraction))
            
            let effectiveRate: Double
            if rateFraction < 0.0 {
                let rateDistance = (current.initialRate + 1.0) * (1.0 - (-rateFraction)) + 1.0 * (-rateFraction)
                effectiveRate = max(1.0, min(4.0, rateDistance))
            } else {
                let rateDistance = (current.initialRate + 1.0) * (1.0 - rateFraction) + 3.0 * rateFraction
                effectiveRate = max(1.0, min(4.0, rateDistance))
            }
            self.activeEdgeRateState = (current.initialRate, effectiveRate)
            videoNode.setBaseRate(effectiveRate)
            
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(validLayout.layout, navigationBarHeight: validLayout.navigationBarHeight, transition: .animated(duration: 0.35, curve: .spring))
            }
        }
    }
}

final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    private let actionsOnTop: Bool
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode, actionsOnTop: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.actionsOnTop = actionsOnTop
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: self.actionsOnTop ? .top : .bottom)
    }
}

private func normalizeValue(_ value: CGFloat) -> CGFloat {
    return round(value * 10.0) / 10.0
}
