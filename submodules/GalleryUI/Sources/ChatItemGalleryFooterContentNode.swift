import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Photos
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import TelegramStringFormatting
import AccountContext
import RadialStatusNode
import ShareController
import OpenInExternalAppUI
import AppBundle
import LocalizedPeerData
import TextSelectionNode

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: .white)

private let backwardImage = generateTintedImage(image:  UIImage(bundleImageName: "Media Gallery/BackwardButton"), color: .white)
private let forwardImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/ForwardButton"), color: .white)
private let pauseImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/PauseButton"), color: .white)
private let playImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/PlayButton"), color: .white)

private let cloudFetchIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/FileCloudFetch"), color: UIColor.white)

private let captionMaskImage = generateImage(CGSize(width: 1.0, height: 17.0), opaque: false, rotatedContext: { size, context in
    let bounds = CGRect(origin: CGPoint(), size: size)
    context.clear(bounds)
    
    let gradientColors = [UIColor.white.withAlphaComponent(1.0).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray
    
    var locations: [CGFloat] = [0.0, 1.0]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: 17.0), options: CGGradientDrawingOptions())
})

private let titleFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

enum ChatItemGalleryFooterContent: Equatable {
    case info
    case fetch(status: MediaResourceStatus)
    case playback(paused: Bool, seekable: Bool)
    
    static func ==(lhs: ChatItemGalleryFooterContent, rhs: ChatItemGalleryFooterContent) -> Bool {
        switch lhs {
            case .info:
                if case .info = rhs {
                    return true
                } else {
                    return false
                }
            case let .fetch(lhsStatus):
                if case let .fetch(rhsStatus) = rhs, lhsStatus == rhsStatus {
                    return true
                } else {
                    return false
                }
            case let .playback(lhsPaused, lhsSeekable):
                if case let .playback(rhsPaused, rhsSeekable) = rhs, lhsPaused == rhsPaused, lhsSeekable == rhsSeekable {
                    return true
                } else {
                    return false
                }
            }
    }
}

enum ChatItemGalleryFooterContentTapAction {
    case none
    case url(url: String, concealed: Bool)
    case textMention(String)
    case peerMention(PeerId, String)
    case botCommand(String)
    case hashtag(String?, String)
    case instantPage
    case call(PeerId)
    case openMessage
    case ignore
}

class CaptionScrollWrapperNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result == self.view, let subnode = self.subnodes?.first {
            let convertedPoint = self.view.convert(point, to: subnode.view)
            if let subnodes = subnode.subnodes {
                for node in subnodes {
                    if node.frame.contains(convertedPoint) {
                        return node.view
                    }
                }
            }
            return nil
        }
        return result
    }
}

final class ChatItemGalleryFooterContentNode: GalleryFooterContentNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var nameOrder: PresentationPersonNameOrder
    private var dateTimeFormat: PresentationDateTimeFormat
    
    private let deleteButton: UIButton
    private let actionButton: UIButton
    private let maskNode: ASDisplayNode
    private let scrollWrapperNode: CaptionScrollWrapperNode
    private let scrollNode: ASScrollNode

    private let textNode: ImmediateTextNode
    private var textSelectionNode: TextSelectionNode?
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    private let backwardButton: HighlightableButtonNode
    private let forwardButton: HighlightableButtonNode
    private let playbackControlButton: HighlightableButtonNode
    
    private let statusButtonNode: HighlightTrackingButtonNode
    private let statusNode: RadialStatusNode
    
    private var currentMessageText: NSAttributedString?
    private var currentAuthorNameText: String?
    private var currentDateText: String?
    
    private var currentMessage: Message?
    
    private var currentWebPageAndMedia: (TelegramMediaWebpage, Media)?
    
    private let messageContextDisposable = MetaDisposable()
    
    private var videoFramePreviewNode: (ASImageNode, ImmediateTextNode)?
    
    private var validLayout: (CGSize, LayoutMetrics, CGFloat, CGFloat, CGFloat, CGFloat)?
    
    var playbackControl: (() -> Void)?
    var seekBackward: (() -> Void)?
    var seekForward: (() -> Void)?
    
    var fetchControl: (() -> Void)?
    
    var performAction: ((GalleryControllerInteractionTapAction) -> Void)?
    var openActionOptions: ((GalleryControllerInteractionTapAction) -> Void)?
    
    var content: ChatItemGalleryFooterContent = .info {
        didSet {
            if self.content != oldValue {
                switch self.content {
                    case .info:
                        self.authorNameNode.isHidden = false
                        self.dateNode.isHidden = false
                        self.backwardButton.isHidden = true
                        self.forwardButton.isHidden = true
                        self.playbackControlButton.isHidden = true
                        self.statusButtonNode.isHidden = true
                        self.statusNode.isHidden = true
                    case let .fetch(status):
                        self.authorNameNode.isHidden = true
                        self.dateNode.isHidden = true
                        self.backwardButton.isHidden = true
                        self.forwardButton.isHidden = true
                        if status == .Local {
                            self.playbackControlButton.isHidden = false
                            self.playbackControlButton.setImage(playImage, for: [])
                        } else {
                            self.playbackControlButton.isHidden = true
                        }
                        self.statusButtonNode.isHidden = false
                        self.statusNode.isHidden = false
                        
                        var statusState: RadialStatusNodeState = .none
                        switch status {
                            case let .Fetching(isActive, progress):
                                let adjustedProgress = max(progress, 0.027)
                                statusState = .cloudProgress(color: UIColor.white, strokeBackgroundColor: UIColor.white.withAlphaComponent(0.5), lineWidth: 2.0, value: CGFloat(adjustedProgress))
                            case .Local:
                                break
                            case .Remote:
                                if let image = cloudFetchIcon {
                                    statusState = .customIcon(image)
                                }
                        }
                        self.statusNode.transitionToState(statusState, completion: {})
                        self.statusButtonNode.isUserInteractionEnabled = statusState != .none
                    case let .playback(paused, seekable):
                        self.authorNameNode.isHidden = true
                        self.dateNode.isHidden = true
                        self.backwardButton.isHidden = !seekable
                        self.forwardButton.isHidden = !seekable
                        self.playbackControlButton.isHidden = false
                        self.playbackControlButton.setImage(paused ? playImage : pauseImage, for: [])
                        self.statusButtonNode.isHidden = true
                        self.statusNode.isHidden = true
                }
            }
        }
    }
    
    private var scrubbingHandleRelativePosition: CGFloat = 0.0
    private var scrubbingVisualTimestamp: Double?
    
    var scrubberView: ChatVideoGalleryItemScrubberView? = nil {
        willSet {
            if let scrubberView = self.scrubberView, scrubberView.superview == self.view {
                scrubberView.removeFromSuperview()
            }
        }
        didSet {
            if let scrubberView = self.scrubberView {
                self.view.addSubview(scrubberView)
                scrubberView.updateScrubbingVisual = { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    if let value = value {
                        strongSelf.scrubbingVisualTimestamp = value
                        if let (videoFramePreviewNode, videoFrameTextNode) = strongSelf.videoFramePreviewNode {
                            videoFrameTextNode.attributedText = NSAttributedString(string: stringForDuration(Int32(value)), font: Font.regular(13.0), textColor: .white)
                            let textSize = videoFrameTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                            let imageFrame = videoFramePreviewNode.frame
                            let textOffset = (Int((imageFrame.size.width - videoFrameTextNode.bounds.width) / 2) / 2) * 2
                            videoFrameTextNode.frame = CGRect(origin: CGPoint(x: CGFloat(textOffset), y: imageFrame.size.height - videoFrameTextNode.bounds.height - 5.0), size: textSize)
                        }
                    } else {
                        strongSelf.scrubbingVisualTimestamp = nil
                    }
                }
                scrubberView.updateScrubbingHandlePosition = { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.scrubbingHandleRelativePosition = value
                    if let validLayout = strongSelf.validLayout {
                        let _ = strongSelf.updateLayout(size: validLayout.0, metrics: validLayout.1, leftInset: validLayout.2, rightInset: validLayout.3, bottomInset: validLayout.4, contentInset: validLayout.5, transition: .immediate)
                    }
                }
            }
        }
    }
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.nameOrder = presentationData.nameDisplayOrder
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        self.deleteButton = UIButton()
        self.actionButton = UIButton()
        
        self.deleteButton.setImage(deleteImage, for: [.normal])
        self.actionButton.setImage(actionImage, for: [.normal])
        
        self.scrollWrapperNode = CaptionScrollWrapperNode()
        self.scrollWrapperNode.clipsToBounds = true
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.clipsToBounds = false
        
        self.maskNode = ASDisplayNode()
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.linkHighlightColor = UIColor(rgb: 0x5ac8fa, alpha: 0.2)
        
        self.authorNameNode = ASTextNode()
        self.authorNameNode.maximumNumberOfLines = 1
        self.authorNameNode.isUserInteractionEnabled = false
        self.authorNameNode.displaysAsynchronously = false
        self.dateNode = ASTextNode()
        self.dateNode.maximumNumberOfLines = 1
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = false
        
        self.backwardButton = HighlightableButtonNode()
        self.backwardButton.isHidden = true
        self.backwardButton.setImage(backwardImage, for: [])
        
        self.forwardButton = HighlightableButtonNode()
        self.forwardButton.isHidden = true
        self.forwardButton.setImage(forwardImage, for: [])
        
        self.playbackControlButton = HighlightableButtonNode()
        self.playbackControlButton.isHidden = true
        
        self.statusButtonNode = HighlightTrackingButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        self.statusNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.textNode.highlightAttributeAction = { attributes in
            let highlightedAttributes = [TelegramTextAttributes.URL,
                                         TelegramTextAttributes.PeerMention,
                                         TelegramTextAttributes.PeerTextMention,
                                         TelegramTextAttributes.BotCommand,
                                         TelegramTextAttributes.Hashtag,
                                         TelegramTextAttributes.Timecode]
            
            for attribute in highlightedAttributes {
                if let _ = attributes[NSAttributedString.Key(rawValue: attribute)] {
                    return NSAttributedString.Key(rawValue: attribute)
                }
            }
            return nil
        }
        self.textNode.tapAttributeAction = { [weak self] attributes, _ in
            if let strongSelf = self, let action = strongSelf.actionForAttributes(attributes) {
                strongSelf.performAction?(action)
            }
        }
        self.textNode.longTapAttributeAction = { [weak self] attributes, _ in
            if let strongSelf = self, let action = strongSelf.actionForAttributes(attributes) {
                strongSelf.openActionOptions?(action)
            }
        }
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.actionButton)
        self.addSubnode(self.scrollWrapperNode)
        self.scrollWrapperNode.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.textNode)
        
        self.addSubnode(self.authorNameNode)
        self.addSubnode(self.dateNode)
        
        self.addSubnode(self.backwardButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.playbackControlButton)
        
        self.addSubnode(self.statusNode)
        self.addSubnode(self.statusButtonNode)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
        
        self.backwardButton.addTarget(self, action: #selector(self.backwardButtonPressed), forControlEvents: .touchUpInside)
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), forControlEvents: .touchUpInside)
        self.playbackControlButton.addTarget(self, action: #selector(self.playbackControlPressed), forControlEvents: .touchUpInside)
        
        self.statusButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.statusNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.statusNode.alpha = 0.4
                } else {
                    strongSelf.statusNode.alpha = 1.0
                    strongSelf.statusNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.statusButtonNode.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        
        let accentColor = presentationData.theme.list.itemAccentColor
        let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: accentColor.withAlphaComponent(0.2), knob: accentColor), strings: presentationData.strings, textNode: self.textNode, updateIsActive: { [weak self] value in
//            self?.updateIsTextSelectionActive?(value)
        }, present: { [weak self] c, a in
//            self?.item?.controllerInteraction.presentGlobalOverlayController(c, a)
        }, rootNode: self, performAction: { [weak self] text, action in
//            guard let strongSelf = self, let item = strongSelf.item else {
//                return
//            }
//            item.controllerInteraction.performTextSelectionAction(item.message.stableId, text, action)
        })
        self.textSelectionNode = textSelectionNode
        self.scrollNode.addSubnode(textSelectionNode)
        self.scrollNode.insertSubnode(textSelectionNode.highlightAreaNode, belowSubnode: self.textNode)
        textSelectionNode.frame = self.textNode.frame
        textSelectionNode.highlightAreaNode.frame = self.textNode.frame
    }
    
    deinit {
        self.messageContextDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.delegate = self
        self.scrollNode.view.showsVerticalScrollIndicator = false
    }
    
    private func actionForAttributes(_ attributes: [NSAttributedString.Key: Any]) -> GalleryControllerInteractionTapAction? {
        if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
            return .url(url: url, concealed: false)
        } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
            return .peerMention(peerMention.peerId, peerMention.mention)
        } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
            return .textMention(peerName)
        } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
            return .botCommand(botCommand)
        } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
            return .hashtag(hashtag.peerName, hashtag.hashtag)
        } else if let timecode = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Timecode)] as? TelegramTimecode {
            return .timecode(timecode.time, timecode.text)
        } else {
            return nil
        }
    }
    
    func setup(origin: GalleryItemOriginData?, caption: NSAttributedString) {
        let titleText = origin?.title
        let dateText = origin?.timestamp.flatMap { humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: $0) }
        
        if self.currentMessageText != caption || self.currentAuthorNameText != titleText || self.currentDateText != dateText {
            self.currentMessageText = caption
            self.currentAuthorNameText = titleText
            self.currentDateText = dateText
            
            if caption.length == 0 {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = caption
            }
            
            if let titleText = titleText {
                self.authorNameNode.attributedText = NSAttributedString(string: titleText, font: titleFont, textColor: .white)
            } else {
                self.authorNameNode.attributedText = nil
            }
            if let dateText = dateText {
                self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            } else {
                self.dateNode.attributedText = nil
            }

            self.requestLayout?(.immediate)
        }
        
        if origin == nil {
            self.deleteButton.isHidden = true
        }
    }
    
    func setMessage(_ message: Message) {
        self.currentMessage = message
        
        let canDelete: Bool
        var canShare = !message.containsSecretMedia && !Namespaces.Message.allScheduled.contains(message.id.namespace)
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
            canShare = false
        }
        
        var authorNameText: String?
        
        if let author = message.effectiveAuthor {
            authorNameText = author.displayTitle(strings: self.strings, displayOrder: self.nameOrder)
        } else if let peer = message.peers[message.id.peerId] {
            authorNameText = peer.displayTitle(strings: self.strings, displayOrder: self.nameOrder)
        }
        
        let dateText = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: message.timestamp)
        
        var messageText = NSAttributedString(string: "")
        var hasCaption = false
        for media in message.media {
            if media is TelegramMediaImage {
                hasCaption = true
            } else if let file = media as? TelegramMediaFile {
                hasCaption = file.mimeType.hasPrefix("image/")
            }
        }
        if hasCaption {
            var entities: [MessageTextEntity] = []
            for attribute in message.attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    entities = attribute.entities
                    break
                }
            }
            messageText = galleryCaptionStringWithAppliedEntities(message.text, entities: entities)
        }
        
        self.actionButton.isHidden = message.containsSecretMedia || Namespaces.Message.allScheduled.contains(message.id.namespace)
        
        
        if self.currentMessageText != messageText || canDelete != !self.deleteButton.isHidden || canShare != !self.actionButton.isHidden || self.currentAuthorNameText != authorNameText || self.currentDateText != dateText {
            self.currentMessageText = messageText
            
            if messageText.length == 0 {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = messageText
            }
            
            if let authorNameText = authorNameText {
                self.authorNameNode.attributedText = NSAttributedString(string: authorNameText, font: titleFont, textColor: .white)
            } else {
                self.authorNameNode.attributedText = nil
            }
            self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            
            self.deleteButton.isHidden = !canDelete
            self.actionButton.isHidden = !canShare
            
            self.requestLayout?(.immediate)
        }
    }
    
    func setWebPage(_ webPage: TelegramMediaWebpage, media: Media) {
        self.currentWebPageAndMedia = (webPage, media)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.requestLayout?(.immediate)
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (size, metrics, leftInset, rightInset, bottomInset, contentInset)
        
        let width = size.width
        var bottomInset = bottomInset
        if !bottomInset.isZero && bottomInset < 30.0 {
            bottomInset -= 7.0
        }
        var panelHeight = 44.0 + bottomInset
        panelHeight += contentInset
        
        let isLandscape = size.width > size.height
        let displayCaption: Bool
        if case .compact = metrics.widthClass {
            displayCaption = !self.textNode.isHidden && !isLandscape
        } else {
            displayCaption = !self.textNode.isHidden
        }
        
        var textFrame = CGRect()
        var visibleTextHeight: CGFloat = 0.0
        if !self.textNode.isHidden {
            let sideInset: CGFloat = 8.0 + leftInset
            let topInset: CGFloat = 8.0
            let textBottomInset: CGFloat = 8.0
            let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            
            var textOffset: CGFloat = 0.0
            if displayCaption {
                visibleTextHeight = textSize.height
                if visibleTextHeight > 100.0 {
                    visibleTextHeight = 80.0
                    self.scrollNode.view.isScrollEnabled = true
                } else {
                    self.scrollNode.view.isScrollEnabled = false
                }
                
                let visibleTextPanelHeight = visibleTextHeight + topInset + textBottomInset
                let scrollViewContentSize = CGSize(width: width, height: textSize.height + topInset + textBottomInset)
                if self.scrollNode.view.contentSize != scrollViewContentSize {
                    self.scrollNode.view.contentSize = scrollViewContentSize
                }
                let scrollNodeFrame = CGRect(x: 0.0, y: 0.0, width: width, height: visibleTextPanelHeight)
                if self.scrollNode.frame != scrollNodeFrame {
                    self.scrollNode.frame = scrollNodeFrame
                }
                
                textOffset = min(400.0, self.scrollNode.view.contentOffset.y)
                panelHeight = max(0.0, panelHeight + visibleTextPanelHeight + textOffset)
                
                if self.scrollNode.view.isScrollEnabled {
                    if self.scrollWrapperNode.layer.mask == nil, let maskImage = captionMaskImage {
                        let maskLayer = CALayer()
                        maskLayer.contents = maskImage.cgImage
                        maskLayer.contentsScale = maskImage.scale
                        maskLayer.contentsCenter = CGRect(x: 0.0, y: 0.0, width: 1.0, height: (maskImage.size.height - 16.0) / maskImage.size.height)
                        self.scrollWrapperNode.layer.mask = maskLayer
                        
                    }
                } else {
                    self.scrollWrapperNode.layer.mask = nil
                }
                
                let scrollWrapperNodeFrame = CGRect(x: 0.0, y: 0.0, width: width, height: max(0.0, visibleTextPanelHeight + textOffset))
                if self.scrollWrapperNode.frame != scrollWrapperNodeFrame {
                    self.scrollWrapperNode.frame = scrollWrapperNodeFrame
                    self.scrollWrapperNode.layer.mask?.frame = self.scrollWrapperNode.bounds
                    self.scrollWrapperNode.layer.mask?.removeAllAnimations()
                }
            }
            textFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + textOffset), size: textSize)
            if self.textNode.frame != textFrame {
                self.textNode.frame = textFrame
                
                if let textSelectionNode = self.textSelectionNode {
                    textSelectionNode.frame = textFrame
                    textSelectionNode.highlightAreaNode.frame = textFrame
                    textSelectionNode.updateLayout()
                }
            }
        }
        
        if let scrubberView = self.scrubberView, scrubberView.superview == self.view {
            panelHeight += 10.0
            if isLandscape, case .compact = metrics.widthClass {
                panelHeight += 14.0
            } else {
                panelHeight += 34.0
            }
            
            var scrubberY: CGFloat = 8.0
            if self.textNode.isHidden || !displayCaption {
                panelHeight += 8.0
            } else {
                scrubberY = panelHeight - bottomInset - 44.0 - 41.0
                if contentInset > 0.0 {
                    scrubberY -= contentInset + 3.0
                }
            }
            
            let scrubberFrame = CGRect(origin: CGPoint(x: leftInset, y: scrubberY), size: CGSize(width: width - leftInset - rightInset, height: 34.0))
            scrubberView.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
            transition.updateFrame(layer: scrubberView.layer, frame: scrubberFrame)
        }
        transition.updateAlpha(node: self.textNode, alpha: displayCaption ? 1.0 : 0.0)
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        self.deleteButton.frame = CGRect(origin: CGPoint(x: width - 44.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))

        if let image = self.backwardButton.image(for: .normal) {
            self.backwardButton.frame = CGRect(origin: CGPoint(x: floor((width - image.size.width) / 2.0) - 66.0, y: panelHeight - bottomInset - 44.0 + 7.0), size: image.size)
        
        }
        if let image = self.forwardButton.image(for: .normal) {
            self.forwardButton.frame = CGRect(origin: CGPoint(x: floor((width - image.size.width) / 2.0) + 66.0, y: panelHeight - bottomInset - 44.0 + 7.0), size: image.size)
        }
        
        self.playbackControlButton.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0), y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let statusSize = CGSize(width: 28.0, height: 28.0)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: floor((width - statusSize.width) / 2.0), y: panelHeight - bottomInset - statusSize.height - 8.0), size: statusSize))
        
        self.statusButtonNode.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0), y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let authorNameSize = self.authorNameNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        if authorNameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 0.0
            self.authorNameNode.frame = CGRect(origin: CGPoint(x: floor((width - authorNameSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0)), size: authorNameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0) + authorNameSize.height + labelsSpacing), size: dateSize)
        }
        
        if let (videoFramePreviewNode, videoFrameTextNode) = self.videoFramePreviewNode {
            let intrinsicImageSize = videoFramePreviewNode.image?.size ?? CGSize(width: 320.0, height: 240.0)
            let fitSize: CGSize
            if intrinsicImageSize.width < intrinsicImageSize.height {
                fitSize = CGSize(width: 90.0, height: 160.0)
            } else {
                fitSize = CGSize(width: 160.0, height: 90.0)
            }
            let scrubberInset: CGFloat
            if size.width > size.height {
                scrubberInset = 58.0
            } else {
                scrubberInset = 13.0
            }
            
            let imageSize = intrinsicImageSize.aspectFitted(fitSize)
            var imageFrame = CGRect(origin: CGPoint(x: leftInset + scrubberInset + floor(self.scrubbingHandleRelativePosition * (width - leftInset - rightInset - scrubberInset * 2.0) - imageSize.width / 2.0), y: self.scrollNode.frame.minY - 6.0 - imageSize.height), size: imageSize)
            imageFrame.origin.x = min(imageFrame.origin.x, width - rightInset - 10.0 - imageSize.width)
            imageFrame.origin.x = max(imageFrame.origin.x, leftInset + 10.0)
            
            videoFramePreviewNode.frame = imageFrame
            videoFramePreviewNode.subnodes?.first?.frame = CGRect(origin: CGPoint(), size: imageFrame.size)
            
            let textOffset = (Int((imageFrame.size.width - videoFrameTextNode.bounds.width) / 2) / 2) * 2
            videoFrameTextNode.frame = CGRect(origin: CGPoint(x: CGFloat(textOffset), y: imageFrame.size.height - videoFrameTextNode.bounds.height - 5.0), size: videoFrameTextNode.bounds.size)
        }
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
        if let scrubberView = self.scrubberView, scrubberView.superview == self.view {
            if let previousContentNode = previousContentNode as? ChatItemGalleryFooterContentNode, previousContentNode.scrubberView != nil {
            } else {
                transition.animatePositionAdditive(layer: scrubberView.layer, offset: CGPoint(x: 0.0, y: self.bounds.height - fromHeight))
            }
            scrubberView.alpha = 1.0
            scrubberView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        }
        transition.animatePositionAdditive(node: self.scrollWrapperNode, offset: CGPoint(x: 0.0, y: self.bounds.height - fromHeight))
        self.scrollWrapperNode.alpha = 1.0
        self.dateNode.alpha = 1.0
        self.authorNameNode.alpha = 1.0
        self.deleteButton.alpha = 1.0
        self.actionButton.alpha = 1.0
        self.backwardButton.alpha = 1.0
        self.forwardButton.alpha = 1.0
        self.statusNode.alpha = 1.0
        self.playbackControlButton.alpha = 1.0
        self.scrollWrapperNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    override func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        if let scrubberView = self.scrubberView, scrubberView.superview == self.view {
            if let nextContentNode = nextContentNode as? ChatItemGalleryFooterContentNode, nextContentNode.scrubberView != nil {
            } else {
                transition.updateFrame(view: scrubberView, frame: scrubberView.frame.offsetBy(dx: 0.0, dy: self.bounds.height - toHeight))
            }
            scrubberView.alpha = 0.0
            scrubberView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
        }
        transition.updateFrame(node: self.scrollWrapperNode, frame: self.scrollWrapperNode.frame.offsetBy(dx: 0.0, dy: self.bounds.height - toHeight))
        self.scrollWrapperNode.alpha = 0.0
        self.dateNode.alpha = 0.0
        self.authorNameNode.alpha = 0.0
        self.deleteButton.alpha = 0.0
        self.actionButton.alpha = 0.0
        self.backwardButton.alpha = 0.0
        self.forwardButton.alpha = 0.0
        self.statusNode.alpha = 0.0
        self.playbackControlButton.alpha = 0.0
        self.scrollWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in
            completion()
        })
    }
    
    @objc func deleteButtonPressed() {
        if let currentMessage = self.currentMessage {
            let _ = (self.context.account.postbox.transaction { transaction -> [Message] in
                return transaction.getMessageGroup(currentMessage.id) ?? []
            } |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self, !messages.isEmpty {
                    if messages.count == 1 {
                        strongSelf.commitDeleteMessages(messages, ask: true)
                    } else {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        var generalMessageContentKind: MessageContentKind?
                        for message in messages {
                            let currentKind = messageContentKind(contentSettings: strongSelf.context.currentContentSettings.with { $0 }, message: message, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, accountPeerId: strongSelf.context.account.peerId)
                            if generalMessageContentKind == nil || generalMessageContentKind == currentKind {
                                generalMessageContentKind = currentKind
                            } else {
                                generalMessageContentKind = nil
                                break
                            }
                        }
                        
                        var singleText = presentationData.strings.Media_ShareItem(1)
                        var multipleText = presentationData.strings.Media_ShareItem(Int32(messages.count))
                    
                        if let generalMessageContentKind = generalMessageContentKind {
                            switch generalMessageContentKind {
                                case .image:
                                    singleText = presentationData.strings.Media_ShareThisPhoto
                                    multipleText = presentationData.strings.Media_SharePhoto(Int32(messages.count))
                                case .video:
                                    singleText = presentationData.strings.Media_ShareThisVideo
                                    multipleText = presentationData.strings.Media_ShareVideo(Int32(messages.count))
                                default:
                                    break
                            }
                        }
                    
                        let deleteAction: ([Message]) -> Void = { messages in
                            if let strongSelf = self {
                                strongSelf.commitDeleteMessages(messages, ask: false)
                            }
                        }
                    
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        let items: [ActionSheetItem] = [
                            ActionSheetButtonItem(title: singleText, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                deleteAction([currentMessage])
                            }),
                            ActionSheetButtonItem(title: multipleText, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                deleteAction(messages)
                            })
                        ]
                    
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.controllerInteraction?.presentController(actionSheet, nil)
                    }
                }
            })
        }
    }

    private func commitDeleteMessages(_ messages: [Message], ask: Bool) {
        self.messageContextDisposable.set((self.context.sharedContext.chatAvailableMessageActions(postbox: self.context.account.postbox, accountPeerId: self.context.account.peerId, messageIds: Set(messages.map { $0.id })) |> deliverOnMainQueue).start(next: { [weak self] actions in
            if let strongSelf = self, let controllerInteration = strongSelf.controllerInteraction, !actions.options.isEmpty {
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                var items: [ActionSheetItem] = []
                var personalPeerName: String?
                var isChannel = false
                let peerId: PeerId = messages[0].id.peerId
                if let user = messages[0].peers[messages[0].id.peerId] as? TelegramUser {
                    personalPeerName = user.compactDisplayTitle
                } else if let channel = messages[0].peers[messages[0].id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                    isChannel = true
                }
                
                if actions.options.contains(.deleteGlobally) {
                    let globalTitle: String
                    if isChannel {
                        globalTitle = strongSelf.strings.Common_Delete
                    } else if let personalPeerName = personalPeerName {
                        globalTitle = strongSelf.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                    } else {
                        globalTitle = strongSelf.strings.Conversation_DeleteMessagesForEveryone
                    }
                    items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: messages.map { $0.id }, type: .forEveryone).start()
                            strongSelf.controllerInteraction?.dismissController()
                        }
                    }))
                }
                if actions.options.contains(.deleteLocally) {
                    var localOptionText = strongSelf.strings.Conversation_DeleteMessagesForMe
                    if let messageId = messages.first?.id, Namespaces.Message.allScheduled.contains(messageId.namespace) {
                        localOptionText = messages.count > 1 ? strongSelf.strings.ScheduledMessages_DeleteMany : strongSelf.strings.ScheduledMessages_Delete
                    } else if strongSelf.context.account.peerId == peerId {
                        localOptionText = strongSelf.strings.Conversation_Moderate_Delete
                    }
                    items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: messages.map { $0.id }, type: .forLocalPeer).start()
                            strongSelf.controllerInteraction?.dismissController()
                        }
                    }))
                }
                if !ask && items.count == 1 {
                    let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: messages.map { $0.id }, type: .forEveryone).start()
                    strongSelf.controllerInteraction?.dismissController()
                } else if !items.isEmpty {
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controllerInteration.presentController(actionSheet, nil)
                }
            }
        }))
    }
    
    @objc func actionButtonPressed() {
        if let currentMessage = self.currentMessage {
            let _ = (self.context.account.postbox.transaction { transaction -> [Message] in
                return transaction.getMessageGroup(currentMessage.id) ?? []
            } |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self, !messages.isEmpty {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    var generalMessageContentKind: MessageContentKind?
                    for message in messages {
                        let currentKind = messageContentKind(contentSettings: strongSelf.context.currentContentSettings.with { $0 }, message: message, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, accountPeerId: strongSelf.context.account.peerId)
                        if generalMessageContentKind == nil || generalMessageContentKind == currentKind {
                            generalMessageContentKind = currentKind
                        } else {
                            generalMessageContentKind = nil
                            break
                        }
                    }
                    var preferredAction = ShareControllerPreferredAction.default
                    if let generalMessageContentKind = generalMessageContentKind {
                        switch generalMessageContentKind {
                            case .image, .video:
                                preferredAction = .saveToCameraRoll
                            default:
                                break
                        }
                    }
                    
                    if messages.count == 1 {
                        var subject: ShareControllerSubject = ShareControllerSubject.messages(messages)
                        for m in messages[0].media {
                            if let image = m as? TelegramMediaImage {
                                subject = .image(image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: .media(media: .message(message: MessageReference(messages[0]), media: m), resource: $0.resource)) }))
                            } else if let webpage = m as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                if content.embedType == "iframe" {
                                    let item = OpenInItem.url(url: content.url)
                                    if availableOpenInOptions(context: strongSelf.context, item: item).count > 1 {
                                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Conversation_FileOpenIn, action: { [weak self] in
                                            if let strongSelf = self {
                                                let openInController = OpenInActionSheetController(context: strongSelf.context, item: item, additionalAction: nil, openUrl: { [weak self] url in
                                                    if let strongSelf = self {
                                                        strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                                                    }
                                                })
                                                strongSelf.controllerInteraction?.presentController(openInController, nil)
                                            }
                                        }))
                                    } else {
                                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Web_OpenExternal, action: { [weak self] in
                                            if let strongSelf = self {
                                                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: content.url, forceExternal: false, presentationData: presentationData, navigationController: nil, dismissInput: {})
                                            }
                                        }))
                                    }
                                } else {
                                    if let file = content.file {
                                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: file))
                                        preferredAction = .saveToCameraRoll
                                    } else if let image = content.image {
                                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: image))
                                        preferredAction = .saveToCameraRoll
                                    }
                                }
                            } else if let file = m as? TelegramMediaFile {
                                subject = .media(.message(message: MessageReference(messages[0]), media: file))
                                if file.isAnimated {
                                    preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Preview_SaveGif, action: { [weak self] in
                                        if let strongSelf = self {
                                            let message = messages[0]
                                            let _ = addSavedGif(postbox: strongSelf.context.account.postbox, fileReference: .message(message: MessageReference(message), media: file)).start()
                                        }
                                    }))
                                } else if file.mimeType.hasPrefix("image/") || file.mimeType.hasPrefix("video/") {
                                    preferredAction = .saveToCameraRoll
                                }
                            }
                        }
                        let shareController = ShareController(context: strongSelf.context, subject: subject, preferredAction: preferredAction)
                        strongSelf.controllerInteraction?.presentController(shareController, nil)
                    } else {
                        var singleText = presentationData.strings.Media_ShareItem(1)
                        var multipleText = presentationData.strings.Media_ShareItem(Int32(messages.count))
                        
                        if let generalMessageContentKind = generalMessageContentKind {
                            switch generalMessageContentKind {
                                case .image:
                                    singleText = presentationData.strings.Media_ShareThisPhoto
                                    multipleText = presentationData.strings.Media_SharePhoto(Int32(messages.count))
                                case .video:
                                    singleText = presentationData.strings.Media_ShareThisVideo
                                    multipleText = presentationData.strings.Media_ShareVideo(Int32(messages.count))
                                default:
                                    break
                            }
                        }
                        
                        let shareAction: ([Message]) -> Void = { messages in
                            if let strongSelf = self {
                                let shareController = ShareController(context: strongSelf.context, subject: .messages(messages), preferredAction: preferredAction)
                                strongSelf.controllerInteraction?.presentController(shareController, nil)
                            }
                        }
                        
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        let items: [ActionSheetItem] = [
                            ActionSheetButtonItem(title: singleText, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                shareAction([currentMessage])
                            }),
                            ActionSheetButtonItem(title: multipleText, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                shareAction(messages)
                            })
                        ]
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.controllerInteraction?.presentController(actionSheet, nil)
                    }
                }
            })
        } else if let (webPage, media) = self.currentWebPageAndMedia {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            var preferredAction = ShareControllerPreferredAction.default
            var subject = ShareControllerSubject.media(.webPage(webPage: WebpageReference(webPage), media: media))
            
            if let file = media as? TelegramMediaFile {
                if file.isAnimated {
                    preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Preview_SaveGif, action: { [weak self] in
                        if let strongSelf = self {
                            let _ = addSavedGif(postbox: strongSelf.context.account.postbox, fileReference: .webPage(webPage: WebpageReference(webPage), media: file)).start()
                        }
                    }))
                } else if file.mimeType.hasPrefix("image/") || file.mimeType.hasPrefix("video/") {
                    preferredAction = .saveToCameraRoll
                }
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if content.embedType == "iframe" || content.embedType == "video" {
                    subject = .url(content.url)
                    
                    let item = OpenInItem.url(url: content.url)
                    if availableOpenInOptions(context: self.context, item: item).count > 1 {
                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Conversation_FileOpenIn, action: { [weak self] in
                            if let strongSelf = self {
                                let openInController = OpenInActionSheetController(context: strongSelf.context, item: item, additionalAction: nil, openUrl: { [weak self] url in
                                    if let strongSelf = self {
                                        strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                                    }
                                })
                                strongSelf.controllerInteraction?.presentController(openInController, nil)
                            }
                        }))
                    } else {
                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Web_OpenExternal, action: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: content.url, forceExternal: false, presentationData: presentationData, navigationController: nil, dismissInput: {})
                            }
                        }))
                    }
                } else {
                    if let file = content.file {
                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: file))
                        preferredAction = .saveToCameraRoll
                    } else if let image = content.image {
                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: image))
                        preferredAction = .saveToCameraRoll
                    }
                }
            }
            let shareController = ShareController(context: self.context, subject: subject, preferredAction: preferredAction)
            self.controllerInteraction?.presentController(shareController, nil)
        }
    }
    
    @objc func playbackControlPressed() {
        self.playbackControl?()
    }
    
    @objc func backwardButtonPressed() {
        self.seekBackward?()
    }
    
    @objc func forwardButtonPressed() {
        self.seekForward?()
    }
    
    @objc private func statusPressed() {
        self.fetchControl?()
    }
    
    func setFramePreviewImageIsLoading() {
        if self.videoFramePreviewNode?.0.image != nil {
            //self.videoFramePreviewNode?.subnodes?.first?.alpha = 1.0
        }
    }
    
    func setFramePreviewImage(image: UIImage?) {
        if let image = image {
            let videoFramePreviewNode: ASImageNode
            let videoFrameTextNode: ImmediateTextNode
            var animateIn = false
            if let current = self.videoFramePreviewNode {
                videoFramePreviewNode = current.0
                videoFrameTextNode = current.1
            } else {
                videoFramePreviewNode = ASImageNode()
                videoFramePreviewNode.displaysAsynchronously = false
                videoFramePreviewNode.displayWithoutProcessing = true
                videoFramePreviewNode.clipsToBounds = true
                videoFramePreviewNode.cornerRadius = 6.0
                
                let dimNode = ASDisplayNode()
                dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                videoFramePreviewNode.addSubnode(dimNode)
                
                videoFrameTextNode = ImmediateTextNode()
                videoFrameTextNode.displaysAsynchronously = false
                videoFrameTextNode.maximumNumberOfLines = 1
                videoFrameTextNode.textShadowColor = .black
                if let scrubbingVisualTimestamp = self.scrubbingVisualTimestamp {
                    videoFrameTextNode.attributedText = NSAttributedString(string: stringForDuration(Int32(scrubbingVisualTimestamp)), font: Font.regular(13.0), textColor: .white)
                }
                let textSize = videoFrameTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                videoFrameTextNode.frame = CGRect(origin: CGPoint(), size: textSize)
                videoFramePreviewNode.addSubnode(videoFrameTextNode)
                
                self.videoFramePreviewNode = (videoFramePreviewNode, videoFrameTextNode)
                self.addSubnode(videoFramePreviewNode)
                animateIn = true
            }
            videoFramePreviewNode.subnodes?.first?.alpha = 0.0
            let updateLayout = videoFramePreviewNode.image?.size != image.size
            videoFramePreviewNode.image = image
            if updateLayout, let validLayout = self.validLayout {
                let _ = self.updateLayout(size: validLayout.0, metrics: validLayout.1, leftInset: validLayout.2, rightInset: validLayout.3, bottomInset: validLayout.4, contentInset: validLayout.5, transition: .immediate)
            }
            if animateIn {
                videoFramePreviewNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            }
        } else if let (videoFramePreviewNode, _) = self.videoFramePreviewNode {
            self.videoFramePreviewNode = nil
            videoFramePreviewNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak videoFramePreviewNode] _ in
                videoFramePreviewNode?.removeFromSupernode()
            })
        }
    }
}
