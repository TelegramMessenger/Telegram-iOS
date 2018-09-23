import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore

private let titleFont = Font.regular(12.0)
private let subtitleFont = Font.regular(10.0)

final class MediaNavigationAccessoryHeaderNode: ASDisplayNode {
    static let minimizedHeight: CGFloat = 37.0
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    
    private let closeButton: HighlightableButtonNode
    private let actionButton: HighlightTrackingButtonNode
    private let actionPauseNode: ASImageNode
    private let actionPlayNode: ASImageNode
    private let rateButton: HighlightableButtonNode
    
    private let scrubbingNode: MediaPlayerScrubbingNode
    
    var displayScrubber: Bool = true {
        didSet {
            self.scrubbingNode.isHidden = !self.displayScrubber
        }
    }
    
    private let separatorNode: ASDisplayNode
    
    private var tapRecognizer: UITapGestureRecognizer?
    
    var tapAction: (() -> Void)?
    var close: (() -> Void)?
    var toggleRate: (() -> Void)?
    var togglePlayPause: (() -> Void)?
    
    var voiceBaseRate: AudioPlaybackRate? = nil {
        didSet {
            guard self.voiceBaseRate != oldValue, let voiceBaseRate = self.voiceBaseRate else {
                return
            }
            switch voiceBaseRate {
                case .x1:
                    self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerRateInactiveIcon(self.theme), for: [])
                case .x2:
                    self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerRateActiveIcon(self.theme), for: [])
            }
        }
    }
    
    var playbackStatus: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            self.scrubbingNode.status = self.playbackStatus
        }
    }
    
    var playbackItem: SharedMediaPlaylistItem? {
        didSet {
            if !arePlaylistItemsEqual(self.playbackItem, oldValue) {
                self.updateLayout(size: self.bounds.size, transition: .immediate)
            }
        }
    }
    
    init(presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.subtitleNode = TextNode()
        self.subtitleNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.setImage(PresentationResourcesRootController.navigationPlayerCloseButton(self.theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.rateButton = HighlightableButtonNode()
        
        self.rateButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -4.0, -8.0, -4.0)
        self.rateButton.displaysAsynchronously = false
        
        self.actionButton = HighlightTrackingButtonNode()
        self.actionButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.actionButton.displaysAsynchronously = false
        
        self.actionPauseNode = ASImageNode()
        self.actionPauseNode.contentMode = .center
        self.actionPauseNode.isLayerBacked = true
        self.actionPauseNode.displaysAsynchronously = false
        self.actionPauseNode.displayWithoutProcessing = true
        self.actionPauseNode.image = PresentationResourcesRootController.navigationPlayerPauseIcon(self.theme)
        
        self.actionPlayNode = ASImageNode()
        self.actionPlayNode.contentMode = .center
        self.actionPlayNode.isLayerBacked = true
        self.actionPlayNode.displaysAsynchronously = false
        self.actionPlayNode.displayWithoutProcessing = true
        self.actionPlayNode.image = PresentationResourcesRootController.navigationPlayerPlayIcon(self.theme)
        self.actionPlayNode.isHidden = true
        
        self.scrubbingNode = MediaPlayerScrubbingNode(content: .standard(lineHeight: 2.0, lineCap: .square, scrubberHandle: .none, backgroundColor: .clear, foregroundColor: self.theme.rootController.navigationBar.accentTextColor))
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        
        self.addSubnode(self.closeButton)
        self.addSubnode(self.rateButton)
        
        self.actionButton.addSubnode(self.actionPauseNode)
        self.actionButton.addSubnode(self.actionPlayNode)
        self.addSubnode(self.actionButton)
        
        self.closeButton.addTarget(self, action: #selector(self.closeButtonPressed), forControlEvents: .touchUpInside)
        self.rateButton.addTarget(self, action: #selector(self.rateButtonPressed), forControlEvents: .touchUpInside)
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        
        self.addSubnode(self.scrubbingNode)
        
        self.addSubnode(self.separatorNode)
        
        self.actionButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.actionButton.layer.removeAnimation(forKey: "opacity")
                    strongSelf.actionButton.alpha = 0.4
                } else {
                    strongSelf.actionButton.alpha = 1.0
                    strongSelf.actionButton.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.scrubbingNode.playerStatusUpdated = { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            if let status = status {
                let baseRate: AudioPlaybackRate
                if status.baseRate.isEqual(to: 1.0) {
                    baseRate = .x1
                } else {
                    baseRate = .x2
                }
                strongSelf.voiceBaseRate = baseRate
            } else {
                strongSelf.voiceBaseRate = .x1
            }
        }
        
        self.scrubbingNode.playbackStatusUpdated = { [weak self] status in
            if let strongSelf = self {
                let paused: Bool
                if let status = status {
                    switch status {
                        case .paused:
                            paused = true
                        case let .buffering(_, whilePlaying):
                            paused = !whilePlaying
                        case .playing:
                            paused = false
                    }
                } else {
                    paused = true
                }
                strongSelf.actionPlayNode.isHidden = !paused
                strongSelf.actionPauseNode.isHidden = paused
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        self.closeButton.setImage(PresentationResourcesRootController.navigationPlayerCloseButton(self.theme), for: [])
        self.actionPlayNode.image = PresentationResourcesRootController.navigationPlayerPlayIcon(self.theme)
        self.actionPauseNode.image = PresentationResourcesRootController.navigationPlayerPauseIcon(self.theme)
        self.separatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        self.scrubbingNode.updateContent(.standard(lineHeight: 2.0, lineCap: .square, scrubberHandle: .none, backgroundColor: .clear, foregroundColor: self.theme.rootController.navigationBar.accentTextColor))
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let minHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
        
        var titleString: NSAttributedString?
        var subtitleString: NSAttributedString?
        if let playbackItem = self.playbackItem, let displayData = playbackItem.displayData {
            switch displayData {
                case let .music(title, performer, _):
                    self.rateButton.isHidden = true
                    let titleText: String = title ?? "Unknown Track"
                    let subtitleText: String = performer ?? "Unknown Artist"
                    
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: self.theme.rootController.navigationBar.primaryTextColor)
                    subtitleString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                case let .voice(author, peer):
                    self.rateButton.isHidden = false
                    let titleText: String = author?.displayTitle ?? ""
                    let subtitleText: String
                    if let peer = peer {
                        if peer is TelegramGroup || peer is TelegramChannel {
                            subtitleText = peer.displayTitle
                        } else {
                            subtitleText = self.strings.MusicPlayer_VoiceNote
                        }
                    } else {
                        subtitleText = self.strings.MusicPlayer_VoiceNote
                    }
                    
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: self.theme.rootController.navigationBar.primaryTextColor)
                    subtitleString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                case let .instantVideo(author, peer, timestamp):
                    self.rateButton.isHidden = false
                    let titleText: String = author?.displayTitle ?? ""
                    var subtitleText: String
                    
                    if let peer = peer {
                        if peer is TelegramGroup || peer is TelegramChannel {
                            subtitleText = peer.displayTitle
                        } else {
                            subtitleText = self.strings.Message_VideoMessage
                        }
                    } else {
                        subtitleText = self.strings.Message_VideoMessage
                    }
                    
                    if titleText == subtitleText {
                        subtitleText = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: timestamp)
                    }
                    
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: self.theme.rootController.navigationBar.primaryTextColor)
                    subtitleString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: self.theme.rootController.navigationBar.secondaryTextColor)
            }
        }
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        
        var titleSideInset: CGFloat = 80.0
        if !self.rateButton.isHidden {
            titleSideInset += 46.0
        }
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: size.width - titleSideInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: size.width - titleSideInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let _ = titleApply()
        let _ = subtitleApply()
        
        let minimizedTitleOffset: CGFloat = subtitleString == nil ? 6.0 : 0.0
        
        let minimizedTitleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleLayout.size.width) / 2.0), y: 4.0 + minimizedTitleOffset), size: titleLayout.size)
        let minimizedSubtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleLayout.size.width) / 2.0), y: 20.0), size: subtitleLayout.size)
        
        transition.updateFrame(node: self.titleNode, frame: minimizedTitleFrame)
        transition.updateFrame(node: self.subtitleNode, frame: minimizedSubtitleFrame)
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: bounds.size.width - 18.0 - closeButtonSize.width, y: minimizedTitleFrame.minY + 8.0), size: closeButtonSize))
        let rateButtonSize = CGSize(width: 24.0, height: minHeight)
        transition.updateFrame(node: self.rateButton, frame: CGRect(origin: CGPoint(x: bounds.size.width - 18.0 - closeButtonSize.width - 18.0 - rateButtonSize.width, y: 0.0), size: rateButtonSize))
        transition.updateFrame(node: self.actionPlayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.actionPauseNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.actionButton, frame: CGRect(origin: CGPoint(x: 0.0, y: minimizedTitleFrame.minY - 4.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.scrubbingNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 37.0 - 2.0), size: CGSize(width: size.width, height: 2.0)))

        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: minHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
    }
    
    @objc func closeButtonPressed() {
        self.close?()
    }
    
    @objc func rateButtonPressed() {
        self.toggleRate?()
    }
    
    @objc func actionButtonPressed() {
        self.togglePlayPause?()
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapAction?()
        }
    }
}
