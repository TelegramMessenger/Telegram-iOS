import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
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
import UrlEscaping
import UndoUI
import ManagedAnimationNode
import TelegramUniversalVideoContent
import InvisibleInkDustNode
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import Pasteboard
import Speak
import TranslateUI
import TelegramNotices
import SolidRoundedButtonNode
import UrlHandling

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: .white)
private let editImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/Draw"), color: .white)

private let backwardImage = generateTintedImage(image:  UIImage(bundleImageName: "Media Gallery/BackwardButton"), color: .white)
private let forwardImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/ForwardButton"), color: .white)

private let cloudFetchIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/FileCloudFetch"), color: UIColor.white)

private let fullscreenOnImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Expand"), color: .white)
private let fullscreenOffImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Collapse"), color: .white)

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
    case fetch(status: MediaResourceStatus, seekable: Bool)
    case playback(paused: Bool, seekable: Bool)
    
    static func ==(lhs: ChatItemGalleryFooterContent, rhs: ChatItemGalleryFooterContent) -> Bool {
        switch lhs {
            case .info:
                if case .info = rhs {
                    return true
                } else {
                    return false
                }
            case let .fetch(lhsStatus, lhsSeekable):
                if case let .fetch(rhsStatus, rhsSeekable) = rhs, lhsStatus == rhsStatus, lhsSeekable == rhsSeekable {
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
                for node in subnodes.reversed() {
                    if node.frame.contains(convertedPoint) && node.isUserInteractionEnabled {
                        if let dustNode = node as? InvisibleInkDustNode, dustNode.isRevealed {
                            continue
                        }
                        return node.view
                    }
                }
            }
            return nil
        }
        return result
    }
}

final class ChatItemGalleryFooterContentNode: GalleryFooterContentNode, ASScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var nameOrder: PresentationPersonNameOrder
    private var dateTimeFormat: PresentationDateTimeFormat
    
    private let contentNode: ASDisplayNode
    private let deleteButton: UIButton
    private let fullscreenButton: UIButton
    private let actionButton: UIButton
    private let editButton: UIButton
    private let maskNode: ASDisplayNode
    private let textSelectionKnobContainer: UIView
    private let textSelectionKnobSurface: UIView
    private let scrollWrapperNode: CaptionScrollWrapperNode
    private let scrollNode: ASScrollNode

    private let textNode: ImmediateTextNodeWithEntities
    private var spoilerTextNode: ImmediateTextNodeWithEntities?
    private var dustNode: InvisibleInkDustNode?
    private var buttonNode: SolidRoundedButtonNode?
    private var buttonIconNode: ASImageNode?
    
    private var textSelectionNode: TextSelectionNode?
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    private let backwardButton: PlaybackButtonNode
    private let forwardButton: PlaybackButtonNode
    private let playbackControlButton: HighlightableButtonNode
    private let playPauseIconNode: PlayPauseIconNode
    
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
    
    private var codeHighlightState: (id: EngineMessage.Id, specs: [CachedMessageSyntaxHighlight.Spec], disposable: Disposable)?
    
    var playbackControl: (() -> Void)?
    var seekBackward: ((Double) -> Void)?
    var seekForward: ((Double) -> Void)?
    var setPlayRate: ((Double) -> Void)?
    var toggleFullscreen: (() -> Void)?
    var fetchControl: (() -> Void)?
    
    var interacting: ((Bool) -> Void)?
    
    var shareMediaParameters: (() -> ShareControllerSubject.MediaParameters?)?
    
    private var seekTimer: SwiftSignalKit.Timer?
    private var currentIsPaused: Bool = true
    private var seekRate: Double = 1.0
    
    private var currentSpeechHolder: SpeechSynthesizerHolder?
    
    var performAction: ((GalleryControllerInteractionTapAction) -> Void)?
    var openActionOptions: ((GalleryControllerInteractionTapAction, Message) -> Void)?
    
    private var isAd: Bool {
        if self.currentMessage?.adAttribute != nil {
            return true
        }
        return false
    }
    
    var content: ChatItemGalleryFooterContent = .info {
        didSet {
            if self.content != oldValue {
                switch self.content {
                    case .info:
                        self.authorNameNode.isHidden = false
                        self.dateNode.isHidden = false
                        self.hasSeekControls = false
                        self.playbackControlButton.isHidden = true
                        self.statusButtonNode.isHidden = true
                        self.statusNode.isHidden = true
                    case let .fetch(status, seekable):
                        self.currentIsPaused = true
                        self.authorNameNode.isHidden = true
                        self.dateNode.isHidden = true
                        self.hasSeekControls = seekable && !self.isAd
                    
                        if status == .Local && !self.isAd {
                            self.playbackControlButton.isHidden = false
                            self.playPauseIconNode.enqueueState(.play, animated: true)
                        } else {
                            self.playbackControlButton.isHidden = true
                        }
                        self.statusButtonNode.isHidden = false
                        self.statusNode.isHidden = false
                        
                        var statusState: RadialStatusNodeState = .none
                        switch status {
                            case let .Fetching(_, progress):
                                let adjustedProgress = max(progress, 0.027)
                                statusState = .cloudProgress(color: UIColor.white, strokeBackgroundColor: UIColor.white.withAlphaComponent(0.5), lineWidth: 2.0, value: CGFloat(adjustedProgress))
                            case .Local:
                                break
                            case .Remote, .Paused:
                                var isHLS = false
                                if let message = self.currentMessage {
                                    for media in message.media {
                                        if let file = media as? TelegramMediaFile {
                                            isHLS = NativeVideoContent.isHLSVideo(file: file)
                                            break
                                        }
                                    }
                                }
                                if isHLS {
                                    statusState = .none
                                } else {
                                    if let image = cloudFetchIcon {
                                        statusState = .customIcon(image)
                                    }
                                }
                        }
                        self.statusNode.transitionToState(statusState, completion: {})
                        self.statusButtonNode.isUserInteractionEnabled = statusState != .none
                    case let .playback(paused, seekable):
                        self.currentIsPaused = paused
                        self.authorNameNode.isHidden = true
                        self.dateNode.isHidden = true
                        
                        if !self.isAd {
                            self.playbackControlButton.isHidden = false
                            let icon: PlayPauseIconNodeState
                            if let wasPlaying = self.wasPlaying {
                                icon = wasPlaying ? .pause : .play
                            } else {
                                icon = paused ? .play : .pause
                            }
                            self.playPauseIconNode.enqueueState(icon, animated: true)
                            self.hasSeekControls = seekable
                        } else {
                            self.hasSeekControls = false
                        }
                        self.statusButtonNode.isHidden = true
                        self.statusNode.isHidden = true
                }
            }
        }
    }
    
    var hasSeekControls: Bool = false {
        didSet {
            let alpha = self.hasSeekControls ? 1.0 : 0.0
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            transition.updateAlpha(node: self.backwardButton, alpha: alpha)
            transition.updateAlpha(node: self.forwardButton, alpha: alpha)
            self.backwardButton.isUserInteractionEnabled = self.hasSeekControls
            self.forwardButton.isUserInteractionEnabled = self.hasSeekControls
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
                scrubberView.setCollapsed(self.visibilityAlpha < 1.0, animated: false)
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
    
    override func setVisibilityAlpha(_ alpha: CGFloat, animated: Bool) {
        self.visibilityAlpha = alpha
        self.contentNode.alpha = alpha
        self.scrubberView?.setCollapsed(alpha < 1.0, animated: animated)
    }
    
    private var hasExpandedCaptionPromise = ValuePromise<Bool>(false)
    var hasExpandedCaption: Signal<Bool, NoError> {
        return hasExpandedCaptionPromise.get()
    }
    
    init(context: AccountContext, presentationData: PresentationData, present: @escaping (ViewController, Any?) -> Void = { _, _ in }) {
        self.context = context
        self.presentationData = presentationData
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.nameOrder = presentationData.nameDisplayOrder
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        self.contentNode = ASDisplayNode()
        
        self.deleteButton = UIButton()
        self.fullscreenButton = UIButton()
        self.actionButton = UIButton()
        self.editButton = UIButton()
        
        self.deleteButton.setImage(deleteImage, for: [.normal])
        self.actionButton.setImage(actionImage, for: [.normal])
        self.editButton.setImage(editImage, for: [.normal])
        
        self.textSelectionKnobContainer = UIView()
        self.textSelectionKnobSurface = UIView()
        self.textSelectionKnobContainer.addSubview(self.textSelectionKnobSurface)
        
        self.scrollWrapperNode = CaptionScrollWrapperNode()
        self.scrollWrapperNode.clipsToBounds = true
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.clipsToBounds = false
        
        self.maskNode = ASDisplayNode()
        
        self.textNode = ImmediateTextNodeWithEntities()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.linkHighlightColor = UIColor(rgb: 0x5ac8fa, alpha: 0.2)
        self.textNode.displaySpoilerEffect = false
        
        self.authorNameNode = ASTextNode()
        self.authorNameNode.maximumNumberOfLines = 1
        self.authorNameNode.isUserInteractionEnabled = false
        self.authorNameNode.displaysAsynchronously = false
    
        self.dateNode = ASTextNode()
        self.dateNode.maximumNumberOfLines = 1
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = false
        
        self.backwardButton = PlaybackButtonNode()
        self.backwardButton.alpha = 0.0
        self.backwardButton.isUserInteractionEnabled = false
        self.backwardButton.backgroundIconNode.image = backwardImage
        
        self.forwardButton = PlaybackButtonNode()
        self.forwardButton.alpha = 0.0
        self.forwardButton.isUserInteractionEnabled = false
        self.forwardButton.forward = true
        self.forwardButton.backgroundIconNode.image = forwardImage
        
        self.playbackControlButton = HighlightableButtonNode()
        self.playbackControlButton.isHidden = true
        
        self.playPauseIconNode = PlayPauseIconNode()
        
        self.statusButtonNode = HighlightTrackingButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        self.statusNode.isUserInteractionEnabled = false
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        super.init()
        
        self.addSubnode(self.contentNode)
        
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
        self.textNode.tapAttributeAction = { [weak self] attributes, index in
            if let strongSelf = self, let action = strongSelf.actionForAttributes(attributes, index) {
                strongSelf.performAction?(action)
            }
        }
        self.textNode.longTapAttributeAction = { [weak self] attributes, index in
            if let strongSelf = self, let action = strongSelf.actionForAttributes(attributes, index), let message = strongSelf.currentMessage {
                strongSelf.openActionOptions?(action, message)
            } else {
                
            }
        }
        
        self.textNode.arguments = TextNodeWithEntities.Arguments(
            context: self.context,
            cache: self.animationCache,
            renderer: self.animationRenderer,
            placeholderColor: defaultDarkPresentationTheme.list.mediaPlaceholderColor,
            attemptSynchronous: false
        )
        self.textNode.visibility = true
        
        let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: defaultDarkPresentationTheme.list.itemAccentColor.withMultipliedAlpha(0.5), knob: defaultDarkPresentationTheme.list.itemAccentColor, isDark: true), strings: presentationData.strings, textNode: self.textNode, updateIsActive: { [weak self] value in
            guard let self else {
                return
            }
            let _ = self
        }, present: { c, a in
            present(c, a)
        }, rootNode: { [weak self] in
            guard let self else {
                return nil
            }
            return self.controllerInteraction?.controller()?.displayNode
        }, externalKnobSurface: self.textSelectionKnobSurface, performAction: { [weak self] text, action in
            guard let self else {
                return
            }
            
            switch action {
            case .copy:
                storeAttributedTextInPasteboard(text)
                
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                let undoController = UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, appearance: UndoOverlayController.Appearance(isBlurred: true), action: { _ in true })
                
                self.controllerInteraction?.presentController(undoController, nil)
            case .share:
                let theme = defaultDarkPresentationTheme
                let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), self.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                
                let shareController = ShareController(context: self.context, subject: .text(text.string), externalShare: true, immediateExternalShare: false, updatedPresentationData: updatedPresentationData)
                
                self.controllerInteraction?.presentController(shareController, nil)
            case .lookup:
                let controller = UIReferenceLibraryViewController(term: text.string)
                if let window = self.controllerInteraction?.controller()?.view.window {
                    controller.popoverPresentationController?.sourceView = window
                    controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                    window.rootViewController?.present(controller, animated: true)
                }
            case .speak:
                if let speechHolder = speakText(context: self.context, text: text.string) {
                    speechHolder.completion = { [weak self, weak speechHolder] in
                        guard let self else {
                            return
                        }
                        if self.currentSpeechHolder === speechHolder {
                            self.currentSpeechHolder = nil
                        }
                    }
                    self.currentSpeechHolder = speechHolder
                }
            case .translate:
                let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] sharedData in
                    guard let self else {
                        return
                    }
                    //let peer = component.slice.peer
                    
                    let translationSettings: TranslationSettings
                    if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                        translationSettings = current
                    } else {
                        translationSettings = TranslationSettings.defaultSettings
                    }
                    
                    /*var showTranslateIfTopical = false
                    if case let .channel(channel) = peer, !(channel.addressName ?? "").isEmpty {
                        showTranslateIfTopical = true
                    }*/
                    let showTranslateIfTopical = false
                    
                    let (_, language) = canTranslateText(context: self.context, text: text.string, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: showTranslateIfTopical, ignoredLanguages: translationSettings.ignoredLanguages)
                    
                    let _ = ApplicationSpecificNotice.incrementTranslationSuggestion(accountManager: self.context.sharedContext.accountManager, timestamp: Int32(Date().timeIntervalSince1970)).start()
                    
                    let translateController = TranslateScreen(context: self.context, forceTheme: defaultDarkPresentationTheme, text: text.string, canCopy: true, fromLanguage: language, ignoredLanguages: translationSettings.ignoredLanguages)
                    translateController.pushController = { [weak self] c in
                        guard let self else {
                            return
                        }
                        self.controllerInteraction?.pushController(c)
                    }
                    translateController.presentController = { [weak self] c in
                        guard let self else {
                            return
                        }
                        self.controllerInteraction?.presentController(c, nil)
                    }
                    
                    //self.actionSheet = translateController
                    //view.updateIsProgressPaused()
                    
                    /*translateController.wasDismissed = { [weak self, weak view] in
                        guard let self, let view else {
                            return
                        }
                        self.actionSheet = nil
                        view.updateIsProgressPaused()
                    }*/
                    
                    //component.controller()?.present(translateController, in: .window(.root))
                    self.controllerInteraction?.presentController(translateController, nil)
                })
            case .quote:
                break
            }
        })
        
        textSelectionNode.enableLookup = true
        textSelectionNode.canBeginSelection = { [weak self] location in
            guard let self else {
                return false
            }
            
            let textNode = self.textNode
            
            let titleFrame = textNode.view.bounds
            
            if let (index, attributes) = textNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
                let _ = index
                
                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] {
                    return false
                } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                    return false
                } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Timecode)] {
                    return false
                } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                    return false
                } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                    return false
                } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                    return false
                } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BankCard)] as? String {
                    return false
                } else if let emoji = attributes[NSAttributedString.Key(rawValue: ChatTextInputAttributes.customEmoji.rawValue)] as? ChatTextInputTextCustomEmojiAttribute, let _ = emoji.file {
                    return false
                }
            }
            
            return true
        }
        
        self.textSelectionNode = textSelectionNode
        
        self.contentNode.view.addSubview(self.deleteButton)
        self.contentNode.view.addSubview(self.fullscreenButton)
        self.contentNode.view.addSubview(self.actionButton)
        self.contentNode.view.addSubview(self.editButton)
        self.contentNode.addSubnode(self.scrollWrapperNode)
        self.scrollWrapperNode.addSubnode(self.scrollNode)
        self.contentNode.view.addSubview(self.textSelectionKnobContainer)
        self.scrollNode.addSubnode(textSelectionNode.highlightAreaNode)
        self.scrollNode.addSubnode(self.textNode)
        self.scrollNode.addSubnode(textSelectionNode)
        
        self.contentNode.addSubnode(self.authorNameNode)
        self.contentNode.addSubnode(self.dateNode)
        
        self.contentNode.addSubnode(self.backwardButton)
        self.contentNode.addSubnode(self.forwardButton)
        self.contentNode.addSubnode(self.playbackControlButton)
        self.playbackControlButton.addSubnode(self.playPauseIconNode)
        
        self.contentNode.addSubnode(self.statusNode)
        self.contentNode.addSubnode(self.statusButtonNode)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.deleteButton.accessibilityTraits = [.button]
        self.deleteButton.accessibilityLabel = presentationData.strings.Gallery_VoiceOver_Delete
        
        self.fullscreenButton.addTarget(self, action: #selector(self.fullscreenButtonPressed), for: [.touchUpInside])
        self.fullscreenButton.accessibilityTraits = [.button]
        self.fullscreenButton.accessibilityLabel = presentationData.strings.Gallery_VoiceOver_Fullscreen
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
        self.actionButton.accessibilityTraits = [.button]
        self.actionButton.accessibilityLabel = presentationData.strings.Gallery_VoiceOver_Share
        
        self.editButton.addTarget(self, action: #selector(self.editButtonPressed), for: [.touchUpInside])
        self.editButton.accessibilityTraits = [.button]
        self.editButton.accessibilityLabel = presentationData.strings.Gallery_VoiceOver_Edit
        
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
    }
    
    deinit {
        self.messageContextDisposable.dispose()
        self.codeHighlightState?.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        let backwardLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.seekBackwardLongPress(_:)))
        backwardLongPressGestureRecognizer.minimumPressDuration = 0.3
        self.backwardButton.view.addGestureRecognizer(backwardLongPressGestureRecognizer)
        
        let forwardLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.seekForwardLongPress(_:)))
        forwardLongPressGestureRecognizer.minimumPressDuration = 0.3
        self.forwardButton.view.addGestureRecognizer(forwardLongPressGestureRecognizer)
    }
    
    private var wasPlaying: Bool?
    @objc private func seekBackwardLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
            case .began:
                self.interacting?(true)
                self.backwardButton.isPressing = true
                self.wasPlaying = !self.currentIsPaused
                if self.wasPlaying == true {
                    self.playbackControl?()
                }
                
                var time: Double = 0.0
                let seekTimer = SwiftSignalKit.Timer(timeout: 0.1, repeat: true, completion: { [weak self] in
                    if let strongSelf = self {
                        var delta: Double = 0.8
                        if time >= 4.0 {
                            delta = 3.2
                        } else if time >= 2.0 {
                            delta = 1.6
                        }
                        time += 0.1
                        
                        strongSelf.seekBackward?(delta)
                    }
                }, queue: Queue.mainQueue())
                self.seekTimer = seekTimer
                seekTimer.start()
            case .ended, .cancelled:
                self.interacting?(false)
                self.backwardButton.isPressing = false
                self.seekTimer?.invalidate()
                self.seekTimer = nil
                if self.wasPlaying == true {
                    self.playbackControl?()
                }
                self.wasPlaying = nil
            default:
                break
        }
    }
    
    @objc private func seekForwardLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
            case .began:
                self.interacting?(true)
                self.forwardButton.isPressing = true
                self.wasPlaying = !self.currentIsPaused
                if self.wasPlaying == false {
                    self.playbackControl?()
                }
                
                self.seekRate = 4.0
                self.setPlayRate?(self.seekRate)
                let seekTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
                    if let strongSelf = self {
                        if strongSelf.seekRate == 4.0 {
                            strongSelf.seekRate = 8.0
                        }
                        strongSelf.setPlayRate?(strongSelf.seekRate)
                        if strongSelf.seekRate == 8.0 {
                            strongSelf.seekTimer?.invalidate()
                            strongSelf.seekTimer = nil
                        }
                    }
                }, queue: Queue.mainQueue())
                self.seekTimer = seekTimer
                seekTimer.start()
            case .ended, .cancelled:
                self.interacting?(false)
                self.forwardButton.isPressing = false
                self.setPlayRate?(1.0)
                self.seekTimer?.invalidate()
                self.seekTimer = nil
                
                if self.wasPlaying == false {
                    self.playbackControl?()
                }
                self.wasPlaying = nil
            default:
                break
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        
        if let textSelectionNode = self.textSelectionNode, result === textSelectionNode.view {
            let localPoint = self.view.convert(point, to: textSelectionNode.view)
            if !textSelectionNode.canBeginSelection(localPoint) {
                if let result = self.textNode.view.hitTest(self.view.convert(point, to: self.textNode.view), with: event) {
                    return result
                }
            }
        }
        
        return result
    }
    
    private func actionForAttributes(_ attributes: [NSAttributedString.Key: Any], _ index: Int) -> GalleryControllerInteractionTapAction? {
        if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
            var concealed = true
            if let (attributeText, fullText) = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
            }
            return .url(url: url, concealed: concealed)
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
    
    func setup(origin: GalleryItemOriginData?, caption: NSAttributedString, isAd: Bool = false) {
        var titleText = origin?.title
        var dateText = origin?.timestamp.flatMap { humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: $0).string }
        
        let caption = caption.mutableCopy() as! NSMutableAttributedString
        if isAd {
            if let titleText, !titleText.isEmpty {
                caption.insert(NSAttributedString(string: titleText + "\n", font: Font.semibold(17.0), textColor: .white), at: 0)
            }
            titleText = nil
            dateText = nil
        }
        
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
            self.textSelectionNode?.isHidden = self.textNode.isHidden
            
            if let titleText = titleText {
                self.authorNameNode.attributedText = NSAttributedString(string: titleText, font: titleFont, textColor: .white)
            } else {
                self.authorNameNode.attributedText = nil
            }
            self.authorNameNode.accessibilityLabel = self.authorNameNode.attributedText?.string
            
            if let dateText = dateText {
                self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            } else {
                self.dateNode.attributedText = nil
            }
            self.dateNode.accessibilityLabel = self.dateNode.attributedText?.string
            
            self.requestLayout?(.immediate)
        }
        
        if origin == nil {
            self.editButton.isHidden = true
            self.deleteButton.isHidden = true
            self.fullscreenButton.isHidden = true
            self.editButton.isHidden = true
        }
    }
    
    func setMessage(_ message: Message, displayInfo: Bool = true, translateToLanguage: String? = nil, peerIsCopyProtected: Bool = false) {
        self.currentMessage = message
        
        var displayInfo = displayInfo
        if Namespaces.Message.allNonRegular.contains(message.id.namespace) || message.timestamp == 0 {
            displayInfo = false
        }
        var canFullscreen = false
        var canDelete: Bool
        var canShare = !message.containsSecretMedia && !Namespaces.Message.allNonRegular.contains(message.id.namespace) && message.adAttribute == nil
                
        var canEdit = false
        var isImage = false
        var isVideo = false
        for media in message.media {
            if media is TelegramMediaImage {
                canEdit = true
                isImage = true
            } else if let media = media as? TelegramMediaFile, !media.isAnimated {
                for attribute in media.attributes {
                    switch attribute {
                    case let .Video(_, dimensions, _, _, _, _):
                        isVideo = true
                        if dimensions.height > 0 {
                            if CGFloat(dimensions.width) / CGFloat(dimensions.height) > 1.33 {
                                canFullscreen = true
                            }
                        }
                    default:
                        break
                    }
                }
                
                if !isVideo {
                    canEdit = true
                    isImage = true
                }
            } else if let media = media as? TelegramMediaWebpage, case let .Loaded(content) = media.content {
                let type = webEmbedType(content: content)
                switch type {
                    case .youtube, .vimeo:
                        canFullscreen = true
                    default:
                        break
                }
                if let file = content.file, !file.isAnimated, file.isVideo {
                    canFullscreen = true
                }
                if content.type == "photo", let _ = content.image {
                    canEdit = true
                }
            }
        }
        
        canEdit = canEdit && !message.containsSecretMedia
        if let peer = message.peers[message.id.peerId] {
            if peer is TelegramUser || peer is TelegramSecretChat {
                canDelete = true
            } else if let _ = peer as? TelegramGroup {
                canDelete = true
            } else if let channel = peer as? TelegramChannel {
                if message.flags.contains(.Incoming) {
                    canDelete = channel.hasPermission(.deleteAllMessages)
                    if canEdit {
                        if isImage {
                            if !channel.hasPermission(.sendPhoto) {
                                canEdit = false
                            }
                        } else if isVideo {
                            if !channel.hasPermission(.sendVideo) {
                                canEdit = false
                            }
                        } else {
                            canEdit = false
                        }
                    }
                } else {
                    canDelete = true
                }
            } else {
                canDelete = false
                canEdit = false
            }
        } else {
            canDelete = false
            canShare = false
            canEdit = false
        }
        
        if message.isCopyProtected() || peerIsCopyProtected || message.paidContent != nil {
            canShare = false
            canEdit = false
        }
        
        if message.containsSecretMedia {
            canDelete = false
        }
        
        if let _ = message.adAttribute {
            displayInfo = false
            canFullscreen = false
        }
        
        var authorNameText: String?
        if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported), let authorSignature = forwardInfo.authorSignature {
            authorNameText = authorSignature
        } else if let author = message.effectiveAuthor {
            authorNameText = EnginePeer(author).displayTitle(strings: self.strings, displayOrder: self.nameOrder)
        } else if let peer = message.peers[message.id.peerId] {
            authorNameText = EnginePeer(peer).displayTitle(strings: self.strings, displayOrder: self.nameOrder)
        }
        
        var dateText = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: message.timestamp).string

        var messageText = NSMutableAttributedString(string: "")
        var hasCaption = false
        var mediaDuration: Double?
        for media in message.media {
            if media is TelegramMediaPaidContent {
                hasCaption = true
            } else if media is TelegramMediaImage {
                hasCaption = true
            } else if let file = media as? TelegramMediaFile {
                hasCaption = file.mimeType.hasPrefix("image/") || file.mimeType.hasPrefix("video/")
                mediaDuration = file.duration
            } else if media is TelegramMediaInvoice {
                hasCaption = true
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
            var text = message.text
            if let result = addLocallyGeneratedEntities(text, enabledTypes: [.timecode], entities: entities, mediaDuration: mediaDuration) {
                entities = result
            }
            if let translateToLanguage, !text.isEmpty {
                for attribute in message.attributes {
                    if let attribute = attribute as? TranslationMessageAttribute, !attribute.text.isEmpty, attribute.toLang == translateToLanguage {
                        text = attribute.text
                        entities = attribute.entities
                        break
                    }
                }
            }
            
            let codeHighlightSpecs = extractMessageSyntaxHighlightSpecs(text: text, entities: entities)
            var cachedMessageSyntaxHighlight: CachedMessageSyntaxHighlight?
            
            if !codeHighlightSpecs.isEmpty {
                for attribute in message.attributes {
                    if let attribute = attribute as? DerivedDataMessageAttribute {
                        if let value = attribute.data["code"]?.get(CachedMessageSyntaxHighlight.self) {
                            cachedMessageSyntaxHighlight = value
                        }
                    }
                }
            }
            
            if !codeHighlightSpecs.isEmpty {
                if let current = self.codeHighlightState, current.id == message.id, current.specs == codeHighlightSpecs {
                } else {
                    if let codeHighlightState = self.codeHighlightState {
                        self.codeHighlightState = nil
                        codeHighlightState.disposable.dispose()
                    }
                    
                    let disposable = MetaDisposable()
                    self.codeHighlightState = (message.id, codeHighlightSpecs, disposable)
                    disposable.set(asyncUpdateMessageSyntaxHighlight(engine: self.context.engine, messageId: message.id, current: cachedMessageSyntaxHighlight, specs: codeHighlightSpecs).startStrict(completed: {
                    }))
                }
            } else if let codeHighlightState = self.codeHighlightState {
                self.codeHighlightState = nil
                codeHighlightState.disposable.dispose()
            }
            
            messageText = galleryCaptionStringWithAppliedEntities(context: self.context, text: text, entities: entities, message: message, cachedMessageSyntaxHighlight: cachedMessageSyntaxHighlight).mutableCopy() as! NSMutableAttributedString
            if let _ = message.adAttribute {
                messageText.insert(NSAttributedString(string: (authorNameText ?? "") + "\n", font: Font.semibold(17.0), textColor: .white), at: 0)
            }
        }
        
        if !displayInfo {
            authorNameText = ""
            dateText = ""
            canEdit = false
        }
                        
        if self.currentMessageText != messageText || canDelete != !self.deleteButton.isHidden || canFullscreen != !self.fullscreenButton.isHidden || canShare != !self.actionButton.isHidden || canEdit != !self.editButton.isHidden || self.currentAuthorNameText != authorNameText || self.currentDateText != dateText {
            self.currentMessageText = messageText
            
            if messageText.length == 0 {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = messageText
            }
            
            self.textSelectionNode?.isHidden = self.textNode.isHidden
            
            if let authorNameText = authorNameText {
                self.authorNameNode.attributedText = NSAttributedString(string: authorNameText, font: titleFont, textColor: .white)
            } else {
                self.authorNameNode.attributedText = nil
            }
            self.authorNameNode.accessibilityLabel = self.authorNameNode.attributedText?.string
           
            self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            self.dateNode.accessibilityLabel = self.dateNode.attributedText?.string
            
            if canFullscreen {
                self.fullscreenButton.isHidden = false
                self.deleteButton.isHidden = true
            } else {
                self.deleteButton.isHidden = !canDelete
                self.fullscreenButton.isHidden = true
            }

            self.actionButton.isHidden = !canShare
            self.editButton.isHidden = !canEdit
            
            if let adAttribute = message.adAttribute {
                if self.buttonNode == nil {
                    let buttonNode = SolidRoundedButtonNode(title: adAttribute.buttonText, theme: SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.15), foregroundColor: UIColor(rgb: 0xffffff)), height: 50.0, cornerRadius: 11.0)
                    buttonNode.pressed = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.performAction?(.ad(message.id))
                    }
                    self.contentNode.addSubnode(buttonNode)
                    self.buttonNode = buttonNode
                    
                    if !isTelegramMeLink(adAttribute.url) {
                        let buttonIconNode = ASImageNode()
                        buttonIconNode.displaysAsynchronously = false
                        buttonIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotLink"), color: .white)
                        buttonNode.addSubnode(buttonIconNode)
                        self.buttonIconNode = buttonIconNode
                    }
                }
            } else if let buttonNode = self.buttonNode {
                buttonNode.removeFromSupernode()
            }
            
            self.requestLayout?(.immediate)
        }
    }
    
    private func updateSpoilers(textFrame: CGRect) {
        if let textLayout = self.textNode.cachedLayout, !textLayout.spoilers.isEmpty {
            if self.spoilerTextNode == nil {
                let spoilerTextNode = ImmediateTextNodeWithEntities()
                spoilerTextNode.displaySpoilerEffect = false
                spoilerTextNode.attributedText = textNode.attributedText
                spoilerTextNode.maximumNumberOfLines = 0
                spoilerTextNode.linkHighlightColor = UIColor(rgb: 0x5ac8fa, alpha: 0.2)
                spoilerTextNode.displaySpoilers = true
                spoilerTextNode.isHidden = false
                spoilerTextNode.alpha = 0.0
                spoilerTextNode.isUserInteractionEnabled = false
                
                self.spoilerTextNode = spoilerTextNode
                self.textNode.supernode?.insertSubnode(spoilerTextNode, aboveSubnode: self.textNode)
                
                let dustNode = InvisibleInkDustNode(textNode: spoilerTextNode, enableAnimations: self.context.sharedContext.energyUsageSettings.fullTranslucency)
                self.dustNode = dustNode
                if let textSelectionNode = self.textSelectionNode {
                    spoilerTextNode.supernode?.insertSubnode(dustNode, aboveSubnode: textSelectionNode)
                } else {
                    spoilerTextNode.supernode?.insertSubnode(dustNode, aboveSubnode: spoilerTextNode)
                }
            }
            if let dustNode = self.dustNode {
                dustNode.update(size: textFrame.size, color: .white, textColor: .white, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 0.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 0.0, dy: 1.0) })
                dustNode.frame = textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
            }
        } else {
            if let spoilerTextNode = self.spoilerTextNode {
                self.spoilerTextNode = nil
                spoilerTextNode.removeFromSupernode()
            }
            if let dustNode = self.dustNode {
                self.dustNode = nil
                dustNode.removeFromSupernode()
            }
        }
    }
    
    func setWebPage(_ webPage: TelegramMediaWebpage, media: Media) {
        self.currentWebPageAndMedia = (webPage, media)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.textSelectionKnobContainer.frame = CGRect(origin: CGPoint(x: 0.0, y: -scrollView.bounds.origin.y), size: CGSize())
        
        self.requestLayout?(.immediate)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.hasExpandedCaptionPromise.set(true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.hasExpandedCaptionPromise.set(scrollView.contentOffset.y > 1.0)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.hasExpandedCaptionPromise.set(scrollView.contentOffset.y > 1.0)
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

        self.fullscreenButton.setImage(isLandscape ? fullscreenOffImage : fullscreenOnImage, for: [.normal])

        let displayCaption: Bool
        if case .compact = metrics.widthClass {
            displayCaption = !self.textNode.isHidden && !isLandscape
        } else {
            displayCaption = !self.textNode.isHidden
        }
        
        if metrics.isTablet {
            self.fullscreenButton.isHidden = true
        }
        
        if !self.textNode.isHidden {
            var textFrame = CGRect()
            var visibleTextHeight: CGFloat = 0.0
            
            let sideInset: CGFloat = 8.0 + leftInset
            let topInset: CGFloat = 8.0
            let textBottomInset: CGFloat = 8.0
            
            let constrainSize = CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude)
            let textSize = self.textNode.updateLayout(constrainSize)
            
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
                
                var maxTextOffset: CGFloat = size.height - bottomInset - 238.0 - UIScreenPixel
                if let _ = self.scrubberView {
                    maxTextOffset -= 44.0
                }
                textOffset = min(maxTextOffset, self.scrollNode.view.contentOffset.y)
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
                
                if let buttonNode = self.buttonNode {
                    let buttonHeight = buttonNode.updateLayout(width: constrainSize.width, transition: transition)
                    transition.updateFrame(node: buttonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: scrollWrapperNodeFrame.maxY + 8.0), size: CGSize(width: constrainSize.width, height: buttonHeight)))
                    
                    if let buttonIconNode = self.buttonIconNode, let icon = buttonIconNode.image {
                        transition.updateFrame(node: buttonIconNode, frame: CGRect(origin: CGPoint(x: constrainSize.width - icon.size.width - 9.0, y: 9.0), size: icon.size))
                    }
                    
                    if let _ = self.scrubberView {
                        panelHeight += 68.0
                    } else {
                        panelHeight += 22.0
                    }
                }
            }
            textFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + textOffset), size: textSize)
            
            self.updateSpoilers(textFrame: textFrame)
            
            let _ = self.spoilerTextNode?.updateLayout(constrainSize)
            
            if self.textNode.frame != textFrame {
                self.textNode.frame = textFrame
                self.spoilerTextNode?.frame = textFrame
                
                self.textSelectionNode?.frame = textFrame
                self.textSelectionNode?.highlightAreaNode.frame = textFrame
                self.textSelectionKnobSurface.frame = textFrame
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
                scrubberY = panelHeight - bottomInset - 44.0 - 44.0
                if contentInset > 0.0 {
                    scrubberY -= contentInset
                }
            }
            
            if let _ = self.buttonNode {
                panelHeight -= 44.0
            }
            
            let scrubberFrame = CGRect(origin: CGPoint(x: leftInset, y: scrubberY), size: CGSize(width: width - leftInset - rightInset, height: 34.0))
            scrubberView.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
            transition.updateBounds(layer: scrubberView.layer, bounds: CGRect(origin: CGPoint(), size: scrubberFrame.size))
            transition.updatePosition(layer: scrubberView.layer, position: CGPoint(x: scrubberFrame.midX, y: scrubberFrame.midY))
        }
        transition.updateAlpha(node: self.scrollWrapperNode, alpha: displayCaption ? 1.0 : 0.0)
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let deleteFrame = CGRect(origin: CGPoint(x: width - 44.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        var editFrame = CGRect(origin: CGPoint(x: width - 44.0 - 50.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        if self.deleteButton.isHidden && self.fullscreenButton.isHidden {
            editFrame = deleteFrame
        }
        self.deleteButton.frame = deleteFrame
        self.fullscreenButton.frame = deleteFrame
        self.editButton.frame = editFrame

        if let image = self.backwardButton.backgroundIconNode.image {
            self.backwardButton.frame = CGRect(origin: CGPoint(x: floor((width - image.size.width) / 2.0) - 66.0, y: panelHeight - bottomInset - 44.0 + 7.0), size: image.size)
        }
        if let image = self.forwardButton.backgroundIconNode.image {
            self.forwardButton.frame = CGRect(origin: CGPoint(x: floor((width - image.size.width) / 2.0) + 66.0, y: panelHeight - bottomInset - 44.0 + 7.0), size: image.size)
        }
        
        self.playbackControlButton.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0), y: panelHeight - bottomInset - 44.0 - 2.0), size: CGSize(width: 44.0, height: 44.0))
        self.playPauseIconNode.frame = self.playbackControlButton.bounds.offsetBy(dx: 2.0, dy: 2.0)
        
        let statusSize = CGSize(width: 28.0, height: 28.0)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: floor((width - statusSize.width) / 2.0), y: panelHeight - bottomInset - statusSize.height - 8.0), size: statusSize))
        
        self.statusButtonNode.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0), y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let buttonsSideInset: CGFloat = !self.editButton.isHidden ? 88.0 : 44.0
        let authorNameSize = self.authorNameNode.measure(CGSize(width: width - buttonsSideInset * 2.0 - 8.0 * 2.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: width - buttonsSideInset * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
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
        
        self.contentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        return panelHeight
    }
    
    override func animateIn(transition: ContainedViewLayoutTransition) {
        self.contentNode.alpha = 0.0
        transition.updateAlpha(node: self.contentNode, alpha: self.visibilityAlpha)
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
        self.fullscreenButton.alpha = 1.0
        self.actionButton.alpha = 1.0
        self.editButton.alpha = 1.0
        self.backwardButton.alpha = self.hasSeekControls ? 1.0 : 0.0
        self.forwardButton.alpha = self.hasSeekControls ? 1.0 : 0.0
        self.statusNode.alpha = 1.0
        self.playbackControlButton.alpha = 1.0
        self.buttonNode?.alpha = 1.0
        self.scrollWrapperNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    override func animateOut(transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.contentNode, alpha: 0.0)
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
        self.fullscreenButton.alpha = 0.0
        self.actionButton.alpha = 0.0
        self.editButton.alpha = 0.0
        self.backwardButton.alpha = 0.0
        self.forwardButton.alpha = 0.0
        self.statusNode.alpha = 0.0
        self.playbackControlButton.alpha = 0.0
        self.buttonNode?.alpha = 0.0
        self.scrollWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in
            completion()
        })
    }

    @objc func fullscreenButtonPressed() {
        self.toggleFullscreen?()
    }
    
    @objc func deleteButtonPressed() {
        if let currentMessage = self.currentMessage {
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.MessageGroup(id: currentMessage.id))
            |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self, !messages.isEmpty {
                    if messages.count == 1 {
                        strongSelf.commitDeleteMessages(messages, ask: true)
                    } else {
                        strongSelf.interacting?(true)
                        
                        var presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        if !presentationData.theme.overallDarkAppearance {
                            presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                        }
                        
                        var generalMessageContentKind: MessageContentKind?
                        for message in messages {
                            let currentKind = messageContentKind(contentSettings: strongSelf.context.currentContentSettings.with { $0 }, message: message, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: strongSelf.context.account.peerId)
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
                    
                        let deleteAction: ([EngineMessage]) -> Void = { messages in
                            if let strongSelf = self {
                                strongSelf.commitDeleteMessages(messages, ask: false)
                            }
                        }
                    
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        actionSheet.dismissed = { [weak self] _ in
                            self?.interacting?(false)
                        }
                        let items: [ActionSheetItem] = [
                            ActionSheetButtonItem(title: singleText, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                deleteAction([EngineMessage(currentMessage)])
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

    private func commitDeleteMessages(_ messages: [EngineMessage], ask: Bool) {
        self.messageContextDisposable.set((self.context.sharedContext.chatAvailableMessageActions(engine: self.context.engine, accountPeerId: self.context.account.peerId, messageIds: Set(messages.map { $0.id }), keepUpdated: false) |> deliverOnMainQueue).start(next: { [weak self] actions in
            if let strongSelf = self, let controllerInteration = strongSelf.controllerInteraction, !actions.options.isEmpty {
                var presentationData = strongSelf.presentationData
                if !presentationData.theme.overallDarkAppearance {
                    presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                var personalPeerName: String?
                var isChannel = false
                let peerId: PeerId = messages[0].id.peerId
                if let user = messages[0].peers[messages[0].id.peerId] as? TelegramUser {
                    personalPeerName = EnginePeer(user).compactDisplayTitle
                } else if let channel = messages[0].peers[messages[0].id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                    isChannel = true
                }
                
                if actions.options.contains(.deleteGlobally) {
                    let globalTitle: String
                    if isChannel {
                        globalTitle = strongSelf.strings.Common_Delete
                    } else if let personalPeerName = personalPeerName {
                        globalTitle = strongSelf.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                    } else {
                        globalTitle = strongSelf.strings.Conversation_DeleteMessagesForEveryone
                    }
                    items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: messages.map { $0.id }, type: .forEveryone).start()
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
                            let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: messages.map { $0.id }, type: .forLocalPeer).start()
                            strongSelf.controllerInteraction?.dismissController()
                        }
                    }))
                }
                if !ask && items.count == 1 {
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: messages.map { $0.id }, type: .forEveryone).start()
                    strongSelf.controllerInteraction?.dismissController()
                } else if !items.isEmpty {
                    strongSelf.interacting?(true)
                    actionSheet.dismissed = { [weak self] _ in
                        self?.interacting?(false)
                    }
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
        self.interacting?(true)
        
        if let currentMessage = self.currentMessage {
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.MessageGroup(id: currentMessage.id))
            |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self, !messages.isEmpty {
                    var presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    var forceTheme: PresentationTheme?
                    if !presentationData.theme.overallDarkAppearance {
                        forceTheme = defaultDarkColorPresentationTheme
                        presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                    }
                    var generalMessageContentKind: MessageContentKind?
                    var beganContentKindScanning = false
                    var messageContentKinds = Set<MessageContentKindKey>()
                    
                    for message in messages {
                        let currentKind = messageContentKind(contentSettings: strongSelf.context.currentContentSettings.with { $0 }, message: message, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: strongSelf.context.account.peerId)
                        if beganContentKindScanning, let messageContentKind = generalMessageContentKind, !messageContentKind.isSemanticallyEqual(to: currentKind) {
                            generalMessageContentKind = nil
                        } else if !beganContentKindScanning || currentKind == generalMessageContentKind {
                            beganContentKindScanning = true
                            generalMessageContentKind = currentKind
                        }
                        messageContentKinds.insert(currentKind.key)
                    }
                    
                    var preferredAction = ShareControllerPreferredAction.default
                    var actionCompletionText: String?
                    if let generalMessageContentKind = generalMessageContentKind {
                        switch generalMessageContentKind {
                            case .image:
                                preferredAction = .saveToCameraRoll
                                actionCompletionText = strongSelf.presentationData.strings.Gallery_ImageSaved
                            case .video:
                                if let message = messages.first, let channel = message.peers[message.id.peerId] as? TelegramChannel, channel.addressName != nil {
                                } else {
                                    preferredAction = .saveToCameraRoll
                                }
                                actionCompletionText = strongSelf.presentationData.strings.Gallery_VideoSaved
                            case .file:
                                preferredAction = .saveToCameraRoll
                            default:
                                break
                        }
                    } else if messageContentKinds.count == 2 && messageContentKinds.contains(.image) && messageContentKinds.contains(.video) {
                        preferredAction = .saveToCameraRoll
                        actionCompletionText = strongSelf.presentationData.strings.Gallery_ImagesAndVideosSaved
                    }
                    
                    if messages.count == 1 {
                        var subject: ShareControllerSubject = ShareControllerSubject.messages(messages.map { $0._asMessage() })
                        for m in messages[0].media {
                            if let image = m as? TelegramMediaImage {
                                subject = .image(image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: .media(media: .message(message: MessageReference(messages[0]._asMessage()), media: m), resource: $0.resource)) }))
                            } else if let webpage = m as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                if content.embedType == "iframe" {
                                    let item = OpenInItem.url(url: content.url)
                                    if availableOpenInOptions(context: strongSelf.context, item: item).count > 1 {
                                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Conversation_FileOpenIn, action: { [weak self] in
                                            if let strongSelf = self {
                                                let openInController = OpenInActionSheetController(context: strongSelf.context, forceTheme: defaultDarkColorPresentationTheme, item: item, additionalAction: nil, openUrl: { [weak self] url in
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
                                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: file), nil)
                                        preferredAction = .saveToCameraRoll
                                    } else if let image = content.image {
                                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: image), nil)
                                        preferredAction = .saveToCameraRoll
                                        actionCompletionText = strongSelf.presentationData.strings.Gallery_ImageSaved
                                    }
                                }
                            } else if let file = m as? TelegramMediaFile {
                                subject = .media(.message(message: MessageReference(messages[0]._asMessage()), media: file), strongSelf.shareMediaParameters?())
                                if file.isAnimated {
                                    if messages[0].id.peerId.namespace == Namespaces.Peer.SecretChat {
                                        preferredAction = .default
                                    } else {
                                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Preview_SaveGif, action: { [weak self] in
                                            if let strongSelf = self {
                                                let message = messages[0]
                                                
                                                let context = strongSelf.context
                                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                                let controllerInteraction = strongSelf.controllerInteraction
                                                let _ = (toggleGifSaved(account: context.account, fileReference: .message(message: MessageReference(message._asMessage()), media: file), saved: true)
                                                |> deliverOnMainQueue).start(next: { result in
                                                    switch result {
                                                    case .generic:
                                                        controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved, customUndoText: nil, timeout: nil), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), nil)
                                                    case let .limitExceeded(limit, premiumLimit):
                                                        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                                        let text: String
                                                        if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                                            text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                                        } else {
                                                            text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                                        }
                                                        controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text, customUndoText: nil, timeout: nil), elevatedLayout: true, animateInAsReplacement: false, action: { action in
                                                            if case .info = action {
                                                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .savedGifs, forceDark: false, dismissed: nil)
                                                                controllerInteraction?.pushController(controller)
                                                                return true
                                                            }
                                                            return false
                                                        }), nil)
                                                    }
                                                })
                                            }
                                        }))
                                    }
                                } else if file.mimeType.hasPrefix("image/") {
                                    preferredAction = .saveToCameraRoll
                                    actionCompletionText = strongSelf.presentationData.strings.Gallery_ImageSaved
                                } else if file.mimeType.hasPrefix("video/") {
                                    preferredAction = .saveToCameraRoll
                                    actionCompletionText = strongSelf.presentationData.strings.Gallery_VideoSaved
                                }
                            }
                        }
                        
                        var hasExternalShare = true
                        for media in currentMessage.media {
                            if let _ = media as? TelegramMediaPaidContent {
                                hasExternalShare = false
                                break
                            } else if let invoice = media as? TelegramMediaInvoice, let _ = invoice.extendedMedia {
                                hasExternalShare = false
                                break
                            }
                        }
                        
                        let shareController = ShareController(context: strongSelf.context, subject: subject, preferredAction: preferredAction, externalShare: hasExternalShare, forceTheme: forceTheme)
                        shareController.dismissed = { [weak self] _ in
                            self?.interacting?(false)
                        }
                        shareController.onMediaTimestampLinkCopied = { [weak self] timestamp in
                            guard let self else {
                                return
                            }
                            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                            let text: String
                            if let timestamp {
                                let startTimeString: String
                                let hours = timestamp / (60 * 60)
                                let minutes = timestamp % (60 * 60) / 60
                                let seconds = timestamp % 60
                                if hours != 0 {
                                    startTimeString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                                } else {
                                    startTimeString = String(format: "%d:%02d", minutes, seconds)
                                }
                                text = presentationData.strings.Conversation_VideoTimeLinkCopied(startTimeString).string
                            } else {
                                text = presentationData.strings.Conversation_LinkCopied
                            }
                            
                            self.controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: text), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return true }), nil)
                        }
                        
                        shareController.actionCompleted = { [weak self] in
                            if let strongSelf = self, let actionCompletionText = actionCompletionText {
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                strongSelf.controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .mediaSaved(text: actionCompletionText), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return true }), nil)
                            }
                        }
                        shareController.completed = { [weak self] peerIds in
                            if let strongSelf = self {
                                let _ = (strongSelf.context.engine.data.get(
                                    EngineDataList(
                                        peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                    )
                                )
                                |> deliverOnMainQueue).start(next: { [weak self] peerList in
                                    if let strongSelf = self {
                                        let peers = peerList.compactMap { $0 }
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        
                                        let text: String
                                        var savedMessages = false
                                        if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                            text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
                                            savedMessages = true
                                        } else {
                                            if peers.count == 1, let peer = peers.first {
                                                var peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                                text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                                var firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                                var secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                                text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                                            } else if let peer = peers.first {
                                                var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                                text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(peers.count - 1)").string
                                            } else {
                                                text = ""
                                            }
                                        }
                                        
                                        strongSelf.controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: true, animateInAsReplacement: true, action: { _ in return false }), nil)
                                    }
                                })
                            }
                        }
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
                                let shareController = ShareController(context: strongSelf.context, subject: .messages(messages), preferredAction: preferredAction, forceTheme: forceTheme)
                                shareController.dismissed = { [weak self] _ in
                                    self?.interacting?(false)
                                }
                                shareController.actionCompleted = { [weak self, weak shareController] in
                                    if let strongSelf = self, let shareController = shareController, shareController.actionIsMediaSaving {
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        strongSelf.controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .mediaSaved(text: presentationData.strings.Gallery_ImageSaved), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return true }), nil)
                                    }
                                }
                                shareController.completed = { [weak self] peerIds in
                                    if let strongSelf = self {
                                        let _ = (strongSelf.context.engine.data.get(
                                            EngineDataList(
                                                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                            )
                                        )
                                        |> deliverOnMainQueue).start(next: { [weak self] peerList in
                                            if let strongSelf = self {
                                                let peers = peerList.compactMap { $0 }
                                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                                
                                                let text: String
                                                var savedMessages = false
                                                if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                                    text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
                                                    savedMessages = true
                                                } else {
                                                    if peers.count == 1, let peer = peers.first {
                                                        var peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                                                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                                                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                                        var firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                        firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                                        var secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                        secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                                                    } else if let peer = peers.first {
                                                        var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                                                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(peers.count - 1)").string
                                                    } else {
                                                        text = ""
                                                    }
                                                }
                                                
                                                strongSelf.controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: true, animateInAsReplacement: true, action: { _ in return false }), nil)
                                            }
                                        })
                                    }
                                }
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
                                shareAction(messages.map { $0._asMessage() })
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
            var presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            var forceTheme: PresentationTheme?
            if !presentationData.theme.overallDarkAppearance {
                forceTheme = defaultDarkColorPresentationTheme
                presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
            }
            
            var preferredAction = ShareControllerPreferredAction.default
            var subject = ShareControllerSubject.media(.webPage(webPage: WebpageReference(webPage), media: media), self.shareMediaParameters?())
            
            if let file = media as? TelegramMediaFile {
                if file.isAnimated {
                    preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Preview_SaveGif, action: { [weak self] in
                        if let strongSelf = self {
                            let context = strongSelf.context
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let controllerInteraction = strongSelf.controllerInteraction
                            let _ = (toggleGifSaved(account: context.account, fileReference: .webPage(webPage: WebpageReference(webPage), media: file), saved: true)
                            |> deliverOnMainQueue).start(next: { result in
                                switch result {
                                    case .generic:
                                        controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved, customUndoText: nil, timeout: nil), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), nil)
                                    case let .limitExceeded(limit, premiumLimit):
                                        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                        let text: String
                                        if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                            text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                        } else {
                                            text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                        }
                                        controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text, customUndoText: nil, timeout: nil), elevatedLayout: true, animateInAsReplacement: false, action: { action in
                                            if case .info = action {
                                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .savedGifs, forceDark: false, dismissed: nil)
                                                controllerInteraction?.pushController(controller)
                                                return true
                                            }
                                            return false
                                        }), nil)
                                }
                            })
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
                                let openInController = OpenInActionSheetController(context: strongSelf.context, forceTheme: forceTheme, item: item, additionalAction: nil, openUrl: { [weak self] url in
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
                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: file), self.shareMediaParameters?())
                        preferredAction = .saveToCameraRoll
                    } else if let image = content.image {
                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: image), self.shareMediaParameters?())
                        preferredAction = .saveToCameraRoll
                    }
                }
            }
            let shareController = ShareController(context: self.context, subject: subject, preferredAction: preferredAction, forceTheme: forceTheme)
            shareController.dismissed = { [weak self] _ in
                self?.interacting?(false)
            }
            shareController.completed = { [weak self] peerIds in
                if let strongSelf = self {
                    let _ = (strongSelf.context.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] peerList in
                        if let strongSelf = self {
                            let peers = peerList.compactMap { $0 }
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            
                            let text: String
                            var savedMessages = false
                            if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                                savedMessages = true
                            } else {
                                if peers.count == 1, let peer = peers.first {
                                    var peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    peerName = peerName.replacingOccurrences(of: "**", with: "")
                                    text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                                } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                    var firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                    var secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                    text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                } else if let peer = peers.first {
                                    var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    peerName = peerName.replacingOccurrences(of: "**", with: "")
                                    text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                } else {
                                    text = ""
                                }
                            }
                            
                            strongSelf.controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: true, animateInAsReplacement: true, action: { _ in return false }), nil)
                        }
                    })
                }
            }
            self.controllerInteraction?.presentController(shareController, nil)
        }
    }
    
    @objc func editButtonPressed() {
        guard let message = self.currentMessage else {
            return
        }
        self.controllerInteraction?.editMedia(message.id)
    }
    
    @objc func playbackControlPressed() {
        self.playbackControl?()
    }
    
    @objc func backwardButtonPressed() {
        self.interacting?(true)
        self.seekBackward?(15.0)
        self.interacting?(false)
    }
    
    @objc func forwardButtonPressed() {
        self.interacting?(true)
        self.seekForward?(15.0)
        self.interacting?(false)
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
//                videoFramePreviewNode.addSubnode(videoFrameTextNode)
                
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

private enum PlayPauseIconNodeState: Equatable {
    case play
    case pause
}

private final class PlayPauseIconNode: ManagedAnimationNode {
    private let duration: Double = 0.35
    private var iconState: PlayPauseIconNodeState = .pause
    
    init() {
        super.init(size: CGSize(width: 40.0, height: 40.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
    }
    
    func enqueueState(_ state: PlayPauseIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .pause:
                switch state {
                    case .play:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 83), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .pause:
                        break
                }
            case .play:
                switch state {
                    case .pause:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 41), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
                        }
                    case .play:
                        break
                }
        }
    }
}

private let circleDiameter: CGFloat = 80.0

private final class PlaybackButtonNode: HighlightTrackingButtonNode {
    let backgroundIconNode: ASImageNode
    let textNode: ImmediateTextNode
    
    var forward: Bool = false

    var isPressing = false {
        didSet {
            if self.isPressing != oldValue && !self.isPressing {
                self.highligthedChanged(false)
            }
        }
    }
    
    init() {
        self.backgroundIconNode = ASImageNode()
        self.backgroundIconNode.isLayerBacked = true
        self.backgroundIconNode.displaysAsynchronously = false
        self.backgroundIconNode.displayWithoutProcessing = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.attributedText = NSAttributedString(string: "15", font: Font.with(size: 11.0, design: .round, weight: .semibold, traits: []), textColor: .white)
        
        super.init(pointerStyle: nil)
        
        self.addSubnode(self.backgroundIconNode)
        self.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundIconNode.alpha = 0.4
                    
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                    
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.18, curve: .linear)
                    let angle = CGFloat.pi / 4.0 + 0.226
                    transition.updateTransformRotation(node: strongSelf.backgroundIconNode, angle: strongSelf.forward ? angle : -angle)
                } else if !strongSelf.isPressing {
                    strongSelf.backgroundIconNode.alpha = 1.0
                    strongSelf.backgroundIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .linear)
                    transition.updateTransformRotation(node: strongSelf.backgroundIconNode, angle: 0.0)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        self.backgroundIconNode.frame = self.bounds
        
        let size = self.bounds.size
        let textSize = self.textNode.updateLayout(size)
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0) + UIScreenPixel), size: textSize)
    }
}
