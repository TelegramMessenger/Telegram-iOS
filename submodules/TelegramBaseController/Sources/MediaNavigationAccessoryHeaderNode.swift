import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import UniversalMediaPlayer
import AccountContext
import TelegramStringFormatting

private let titleFont = Font.regular(12.0)
private let subtitleFont = Font.regular(10.0)

private class MediaHeaderItemNode: ASDisplayNode {
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, playbackItem: SharedMediaPlaylistItem?, transition: ContainedViewLayoutTransition) -> (NSAttributedString?, NSAttributedString?, Bool) {
        var rateButtonHidden = false
        var titleString: NSAttributedString?
        var subtitleString: NSAttributedString?
        if let playbackItem = playbackItem, let displayData = playbackItem.displayData {
            switch displayData {
                case let .music(title, performer, _, long):
                    rateButtonHidden = !long
                    let titleText: String = title ?? strings.MediaPlayer_UnknownTrack
                    let subtitleText: String = performer ?? strings.MediaPlayer_UnknownArtist
                    
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)
                    subtitleString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: theme.rootController.navigationBar.secondaryTextColor)
                case let .voice(author, peer):
                    rateButtonHidden = false
                    let titleText: String = author?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""
                    let subtitleText: String
                    if let peer = peer {
                        if peer is TelegramGroup || peer is TelegramChannel {
                            subtitleText = peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                        } else {
                            subtitleText = strings.MusicPlayer_VoiceNote
                        }
                    } else {
                        subtitleText = strings.MusicPlayer_VoiceNote
                    }
                    
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)
                    subtitleString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: theme.rootController.navigationBar.secondaryTextColor)
                case let .instantVideo(author, peer, timestamp):
                    rateButtonHidden = false
                    let titleText: String = author?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""
                    var subtitleText: String
                    
                    if let peer = peer {
                        if peer is TelegramGroup || peer is TelegramChannel {
                            subtitleText = peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                        } else {
                            subtitleText = strings.Message_VideoMessage
                        }
                    } else {
                        subtitleText = strings.Message_VideoMessage
                    }
                    
                    if titleText == subtitleText {
                        subtitleText = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: timestamp)
                    }
                    
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: theme.rootController.navigationBar.primaryTextColor)
                    subtitleString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: theme.rootController.navigationBar.secondaryTextColor)
            }
        }
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        
        var titleSideInset: CGFloat = 12.0
        if !rateButtonHidden {
            titleSideInset += 52.0
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
        
        return (titleString, subtitleString, rateButtonHidden)
    }
}

private func generateMaskImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 12.0, height: 2.0), opaque: false, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let gradientColors = [color.cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 12.0, y: 0.0), options: CGGradientDrawingOptions())
    })
}

final class MediaNavigationAccessoryHeaderNode: ASDisplayNode, UIScrollViewDelegate {
    static let minimizedHeight: CGFloat = 37.0
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    private var nameDisplayOrder: PresentationPersonNameOrder
    
    private let scrollNode: ASScrollNode
    private var initialContentOffset: CGFloat?
    
    private let leftMaskNode: ASImageNode
    private let rightMaskNode: ASImageNode
    
    private let currentItemNode: MediaHeaderItemNode
    private let previousItemNode: MediaHeaderItemNode
    private let nextItemNode: MediaHeaderItemNode
    
    private let closeButton: HighlightableButtonNode
    private let actionButton: HighlightTrackingButtonNode
    private let actionPauseNode: ASImageNode
    private let actionPlayNode: ASImageNode
    private let rateButton: HighlightableButtonNode
    private let accessibilityAreaNode: AccessibilityAreaNode
    
    private let scrubbingNode: MediaPlayerScrubbingNode
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
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
    var playPrevious: (() -> Void)?
    var playNext: (() -> Void)?
    
    var playbackBaseRate: AudioPlaybackRate? = nil {
        didSet {
            guard self.playbackBaseRate != oldValue, let playbackBaseRate = self.playbackBaseRate else {
                return
            }
            switch playbackBaseRate {
                case .x1:
                    self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerRateInactiveIcon(self.theme), for: [])
                    self.rateButton.accessibilityLabel = self.strings.VoiceOver_Media_PlaybackRate
                    self.rateButton.accessibilityValue = self.strings.VoiceOver_Media_PlaybackRateNormal
                    self.rateButton.accessibilityHint = self.strings.VoiceOver_Media_PlaybackRateChange
                case .x2:
                    self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerRateActiveIcon(self.theme), for: [])
                    self.rateButton.accessibilityLabel = self.strings.VoiceOver_Media_PlaybackRate
                    self.rateButton.accessibilityValue = self.strings.VoiceOver_Media_PlaybackRateFast
                    self.rateButton.accessibilityHint = self.strings.VoiceOver_Media_PlaybackRateChange
            }
        }
    }
    
    var playbackStatus: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            self.scrubbingNode.status = self.playbackStatus
        }
    }
    
    var playbackItems: (SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?)? {
        didSet {
            if !arePlaylistItemsEqual(self.playbackItems?.0, oldValue?.0) || !arePlaylistItemsEqual(self.playbackItems?.1, oldValue?.1) || !arePlaylistItemsEqual(self.playbackItems?.2, oldValue?.2), let layout = validLayout {
                self.updateLayout(size: layout.0, leftInset: layout.1, rightInset: layout.2, transition: .immediate)
            }
        }
    }
    
    init(presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.dateTimeFormat = presentationData.dateTimeFormat
        self.nameDisplayOrder = presentationData.nameDisplayOrder
        
        self.scrollNode = ASScrollNode()
        
        self.currentItemNode = MediaHeaderItemNode()
        self.previousItemNode = MediaHeaderItemNode()
        self.nextItemNode = MediaHeaderItemNode()
        
        self.leftMaskNode = ASImageNode()
        self.leftMaskNode.contentMode = .scaleToFill
        self.rightMaskNode = ASImageNode()
        self.rightMaskNode.contentMode = .scaleToFill
        
        let maskImage = generateMaskImage(color: self.theme.rootController.navigationBar.backgroundColor)
        self.leftMaskNode.image = maskImage
        self.rightMaskNode.image = maskImage
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.accessibilityLabel = presentationData.strings.VoiceOver_Media_PlaybackStop
        self.closeButton.setImage(PresentationResourcesRootController.navigationPlayerCloseButton(self.theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 2.0)
        self.closeButton.displaysAsynchronously = false
        
        self.rateButton = HighlightableButtonNode()
        
        self.rateButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -4.0, bottom: -8.0, right: -4.0)
        self.rateButton.displaysAsynchronously = false
        
        self.accessibilityAreaNode = AccessibilityAreaNode()
        
        self.actionButton = HighlightTrackingButtonNode()
        self.actionButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
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
        
        self.scrubbingNode = MediaPlayerScrubbingNode(content: .standard(lineHeight: 2.0, lineCap: .square, scrubberHandle: .none, backgroundColor: .clear, foregroundColor: self.theme.rootController.navigationBar.accentTextColor, bufferingColor: self.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(0.5)))
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.currentItemNode)
        self.scrollNode.addSubnode(self.previousItemNode)
        self.scrollNode.addSubnode(self.nextItemNode)
        
        self.addSubnode(self.leftMaskNode)
        self.addSubnode(self.rightMaskNode)
        
        self.addSubnode(self.closeButton)
        self.addSubnode(self.rateButton)
        self.addSubnode(self.accessibilityAreaNode)
        
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
                strongSelf.playbackBaseRate = baseRate
            } else {
                strongSelf.playbackBaseRate = .x1
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
                strongSelf.actionButton.accessibilityLabel = paused ? strongSelf.strings.VoiceOver_Media_PlaybackPlay : strongSelf.strings.VoiceOver_Media_PlaybackPause
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.alwaysBounceHorizontal = true
        self.scrollNode.view.delegate = self
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.nameDisplayOrder = presentationData.nameDisplayOrder
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        let maskImage = generateMaskImage(color: self.theme.rootController.navigationBar.backgroundColor)
        self.leftMaskNode.image = maskImage
        self.rightMaskNode.image = maskImage
        
        self.closeButton.setImage(PresentationResourcesRootController.navigationPlayerCloseButton(self.theme), for: [])
        self.actionPlayNode.image = PresentationResourcesRootController.navigationPlayerPlayIcon(self.theme)
        self.actionPauseNode.image = PresentationResourcesRootController.navigationPlayerPauseIcon(self.theme)
        self.separatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        self.scrubbingNode.updateContent(.standard(lineHeight: 2.0, lineCap: .square, scrubberHandle: .none, backgroundColor: .clear, foregroundColor: self.theme.rootController.navigationBar.accentTextColor, bufferingColor: self.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(0.5)))
        
        if let playbackBaseRate = self.playbackBaseRate {
            switch playbackBaseRate {
                case .x1:
                    self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerRateInactiveIcon(self.theme), for: [])
                case .x2:
                    self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerRateActiveIcon(self.theme), for: [])
            }
        }
        if let (size, leftInset, rightInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView.isDecelerating {
            self.changeTrack()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.changeTrack()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else {
            return
        }
        self.changeTrack()
    }
    
    private func changeTrack() {
        guard let initialContentOffset = self.initialContentOffset, abs(initialContentOffset - self.scrollNode.view.contentOffset.x) > self.bounds.width / 2.0 else {
            return
        }
        if self.scrollNode.view.contentOffset.x < initialContentOffset {
            self.playPrevious?()
        } else if self.scrollNode.view.contentOffset.x > initialContentOffset {
            self.playNext?()
        }
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset)
        
        let minHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
        
        let inset: CGFloat = 40.0 + leftInset
        let constrainedSize = CGSize(width: size.width - inset * 2.0, height: size.height)
        let (titleString, subtitleString, rateButtonHidden) = self.currentItemNode.updateLayout(size: constrainedSize, leftInset: leftInset, rightInset: rightInset, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, playbackItem: self.playbackItems?.0, transition: transition)
        self.accessibilityAreaNode.accessibilityLabel = "\(titleString?.string ?? ""). \(subtitleString?.string ?? "")"
        self.rateButton.isHidden = rateButtonHidden
        
        let _ = self.previousItemNode.updateLayout(size: constrainedSize, leftInset: 0.0, rightInset: 0.0, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, playbackItem: self.playbackItems?.1, transition: transition)
        let _ = self.nextItemNode.updateLayout(size: constrainedSize, leftInset: 0.0, rightInset: 0.0, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, nameDisplayOrder: self.nameDisplayOrder, playbackItem: self.playbackItems?.2, transition: transition)
        
        let constrainedBounds = CGRect(origin: CGPoint(), size: constrainedSize)
        transition.updateFrame(node: self.scrollNode, frame: constrainedBounds.offsetBy(dx: inset, dy: 0.0))
        
        var contentSize = constrainedSize
        var contentOffset: CGFloat = 0.0
        if self.playbackItems?.1 != nil {
            contentSize.width += constrainedSize.width
            contentOffset = constrainedSize.width
        }
        if self.playbackItems?.2 != nil {
            contentSize.width += constrainedSize.width
        }
        
        self.previousItemNode.frame = constrainedBounds.offsetBy(dx: contentOffset - constrainedSize.width, dy: 0.0)
        self.currentItemNode.frame = constrainedBounds.offsetBy(dx: contentOffset, dy: 0.0)
        self.nextItemNode.frame = constrainedBounds.offsetBy(dx: contentOffset + constrainedSize.width, dy: 0.0)
        
        self.leftMaskNode.frame = CGRect(x: inset, y: 0.0, width: 12.0, height: minHeight)
        self.rightMaskNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        self.rightMaskNode.frame = CGRect(x: size.width - inset - 12.0, y: 0.0, width: 12.0, height: minHeight)
        
        self.scrollNode.view.contentSize = contentSize
        self.scrollNode.view.contentOffset = CGPoint(x: contentOffset, y: 0.0)
        self.initialContentOffset = contentOffset
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: bounds.size.width - 44.0 - rightInset, y: 0.0), size: CGSize(width: 44.0, height: minHeight)))
        let rateButtonSize = CGSize(width: 24.0, height: minHeight)
        transition.updateFrame(node: self.rateButton, frame: CGRect(origin: CGPoint(x: bounds.size.width - 18.0 - closeButtonSize.width - 17.0 - rateButtonSize.width - rightInset, y: 0.0), size: rateButtonSize))
        transition.updateFrame(node: self.actionPlayNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.actionPauseNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.actionButton, frame: CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.scrubbingNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 37.0 - 2.0), size: CGSize(width: size.width, height: 2.0)))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: minHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        self.accessibilityAreaNode.frame = CGRect(origin: CGPoint(x: self.actionButton.frame.maxX, y: 0.0), size: CGSize(width: self.rateButton.frame.minX - self.actionButton.frame.maxX, height: minHeight))
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
