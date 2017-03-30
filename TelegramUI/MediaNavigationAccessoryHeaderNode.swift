import Foundation
import AsyncDisplayKit
import Display

private let closeButtonImage = generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0x9099A2).cgColor)
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
    context.strokePath()
    context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
    context.strokePath()
})

private let titleFont = Font.regular(12.0)
private let subtitleFont = Font.regular(10.0)
private let maximizedTitleFont = Font.bold(17.0)
private let maximizedSubtitleFont = Font.regular(12.0)

private let titleColor = UIColor.black
private let subtitleColor = UIColor(0x8b8b8b)

private let playIcon = UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPlay")?.precomposed()
private let pauseIcon = UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPause")?.precomposed()
private let maximizedPlayIcon = UIImage(bundleImageName: "GlobalMusicPlayer/Play")?.precomposed()
private let maximizedPauseIcon = UIImage(bundleImageName: "GlobalMusicPlayer/Pause")?.precomposed()
private let maximizedPreviousIcon = UIImage(bundleImageName: "GlobalMusicPlayer/Previous")?.precomposed()
private let maximizedNextIcon = UIImage(bundleImageName: "GlobalMusicPlayer/Next")?.precomposed()
private let maximizedShuffleIcon = UIImage(bundleImageName: "GlobalMusicPlayer/Shuffle")?.precomposed()
private let maximizedRepeatIcon = UIImage(bundleImageName: "GlobalMusicPlayer/Repeat")?.precomposed()

final class MediaNavigationAccessoryHeaderNode: ASDisplayNode {
    static let minimizedHeight: CGFloat = 37.0
    static let maximizedHeight: CGFloat = 166.0
    
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let maximizedTitleNode: TextNode
    private let maximizedSubtitleNode: TextNode
    
    private let closeButton: HighlightableButtonNode
    private let actionButton: HighlightTrackingButtonNode
    private let actionPauseNode: ASImageNode
    private let actionPlayNode: ASImageNode
    
    private let maximizedLeftTimestampNode: MediaPlayerTimeTextNode
    private let maximizedRightTimestampNode: MediaPlayerTimeTextNode
    private let maximizedActionButton: HighlightableButtonNode
    private let maximizedActionPauseNode: ASImageNode
    private let maximizedActionPlayNode: ASImageNode
    private let maximizedPreviousButton: HighlightableButtonNode
    private let maximizedNextButton: HighlightableButtonNode
    private let maximizedShuffleButton: HighlightableButtonNode
    private let maximizedRepeatButton: HighlightableButtonNode
    
    private let scrubbingNode: MediaPlayerScrubbingNode
    private let maximizedScrubbingNode: MediaPlayerScrubbingNode
    
    private var tapRecognizer: UITapGestureRecognizer?
    
    var expand: (() -> Void)?
    
    var close: (() -> Void)?
    var togglePlayPause: (() -> Void)?
    var previous: (() -> Void)?
    var next: (() -> Void)?
    var seek: ((Double) -> Void)?
    
    var stateAndStatus: AudioPlaylistStateAndStatus? {
        didSet {
            if self.stateAndStatus != oldValue {
                self.updateLayout(size: self.bounds.size, transition: .immediate)
                self.scrubbingNode.status = stateAndStatus?.status
                self.maximizedScrubbingNode.status = stateAndStatus?.status
                self.maximizedLeftTimestampNode.status = stateAndStatus?.status
                self.maximizedRightTimestampNode.status = stateAndStatus?.status
            }
        }
    }
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.subtitleNode = TextNode()
        self.subtitleNode.isLayerBacked = true
        
        self.maximizedTitleNode = TextNode()
        self.maximizedTitleNode.isLayerBacked = true
        self.maximizedSubtitleNode = TextNode()
        self.maximizedSubtitleNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.setImage(closeButtonImage, for: [])
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.actionButton = HighlightTrackingButtonNode()
        self.actionButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.actionButton.displaysAsynchronously = false
        
        self.actionPauseNode = ASImageNode()
        self.actionPauseNode.contentMode = .center
        self.actionPauseNode.isLayerBacked = true
        self.actionPauseNode.displaysAsynchronously = false
        self.actionPauseNode.displayWithoutProcessing = true
        self.actionPauseNode.image = pauseIcon
        
        self.actionPlayNode = ASImageNode()
        self.actionPlayNode.contentMode = .center
        self.actionPlayNode.isLayerBacked = true
        self.actionPlayNode.displaysAsynchronously = false
        self.actionPlayNode.displayWithoutProcessing = true
        self.actionPlayNode.image = playIcon
        self.actionPlayNode.isHidden = true
        
        self.maximizedLeftTimestampNode = MediaPlayerTimeTextNode(textColor: UIColor(0x686669))
        self.maximizedRightTimestampNode = MediaPlayerTimeTextNode(textColor: UIColor(0x686669))
        self.maximizedLeftTimestampNode.alignment = .right
        self.maximizedRightTimestampNode.mode = .reversed
        
        self.maximizedActionButton = HighlightableButtonNode()
        self.maximizedActionButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.maximizedActionButton.displaysAsynchronously = false
        
        self.maximizedActionPauseNode = ASImageNode()
        self.maximizedActionPauseNode.isLayerBacked = true
        self.maximizedActionPauseNode.displaysAsynchronously = false
        self.maximizedActionPauseNode.displayWithoutProcessing = true
        self.maximizedActionPauseNode.image = maximizedPauseIcon
        
        self.maximizedActionPlayNode = ASImageNode()
        self.maximizedActionPlayNode.isLayerBacked = true
        self.maximizedActionPlayNode.displaysAsynchronously = false
        self.maximizedActionPlayNode.displayWithoutProcessing = true
        self.maximizedActionPlayNode.image = maximizedPlayIcon
        self.maximizedActionPlayNode.isHidden = true
        
        let maximizedActionButtonSize = CGSize(width: 66.0, height: 50.0)
        self.maximizedActionButton.frame = CGRect(origin: CGPoint(), size: maximizedActionButtonSize)
        if let maximizedPauseIcon = maximizedPauseIcon {
            self.maximizedActionPauseNode.frame = CGRect(origin: CGPoint(x: floor((maximizedActionButtonSize.width - maximizedPauseIcon.size.width) / 2.0), y: floor((maximizedActionButtonSize.height - maximizedPauseIcon.size.height) / 2.0)), size: maximizedPauseIcon.size)
        }
        if let maximizedPlayIcon = maximizedPlayIcon {
            self.maximizedActionPlayNode.frame = CGRect(origin: CGPoint(x: floor((maximizedActionButtonSize.width - maximizedPlayIcon.size.width) / 2.0) + 2.0, y: floor((maximizedActionButtonSize.height - maximizedPlayIcon.size.height) / 2.0)), size: maximizedPlayIcon.size)
        }
        
        self.maximizedPreviousButton = HighlightableButtonNode()
        self.maximizedPreviousButton.setImage(maximizedPreviousIcon, for: [])
        self.maximizedPreviousButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.maximizedPreviousButton.displaysAsynchronously = false
        
        self.maximizedNextButton = HighlightableButtonNode()
        self.maximizedNextButton.setImage(maximizedNextIcon, for: [])
        self.maximizedNextButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.maximizedNextButton.displaysAsynchronously = false
        
        self.maximizedShuffleButton = HighlightableButtonNode()
        self.maximizedShuffleButton.setImage(maximizedShuffleIcon, for: [])
        self.maximizedShuffleButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.maximizedShuffleButton.displaysAsynchronously = false
        
        self.maximizedRepeatButton = HighlightableButtonNode()
        self.maximizedRepeatButton.setImage(maximizedRepeatIcon, for: [])
        self.maximizedRepeatButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.maximizedRepeatButton.displaysAsynchronously = false
        
        self.scrubbingNode = MediaPlayerScrubbingNode(lineHeight: 2.0, lineCap: .square, scrubberHandle: false, backgroundColor: .clear, foregroundColor: UIColor(0x007ee5))
        self.maximizedScrubbingNode = MediaPlayerScrubbingNode(lineHeight: 3.0, lineCap: .round, scrubberHandle: true, backgroundColor: UIColor(0xcfcccf), foregroundColor: UIColor(0x007ee5))

        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.maximizedTitleNode)
        self.addSubnode(self.maximizedSubtitleNode)
        
        self.addSubnode(self.closeButton)
        
        self.actionButton.addSubnode(self.actionPauseNode)
        self.actionButton.addSubnode(self.actionPlayNode)
        self.addSubnode(self.actionButton)
        
        self.addSubnode(self.maximizedLeftTimestampNode)
        self.addSubnode(self.maximizedRightTimestampNode)
        
        self.maximizedActionButton.addSubnode(self.maximizedActionPauseNode)
        self.maximizedActionButton.addSubnode(self.maximizedActionPlayNode)
        self.addSubnode(self.maximizedActionButton)
        self.addSubnode(self.maximizedPreviousButton)
        self.addSubnode(self.maximizedNextButton)
        self.addSubnode(self.maximizedShuffleButton)
        self.addSubnode(self.maximizedRepeatButton)
        
        self.closeButton.addTarget(self, action: #selector(self.closeButtonPressed), forControlEvents: .touchUpInside)
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        self.maximizedActionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        self.maximizedPreviousButton.addTarget(self, action: #selector(self.previousButtonPressed), forControlEvents: .touchUpInside)
        self.maximizedNextButton.addTarget(self, action: #selector(self.nextButtonPressed), forControlEvents: .touchUpInside)
        self.maximizedShuffleButton.addTarget(self, action: #selector(self.shuffleButtonPressed), forControlEvents: .touchUpInside)
        self.maximizedRepeatButton.addTarget(self, action: #selector(self.repeatButtonPressed), forControlEvents: .touchUpInside)
        
        self.addSubnode(self.maximizedScrubbingNode)
        self.addSubnode(self.scrubbingNode)
        
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
        
        self.scrubbingNode.playbackStatusUpdated = { [weak self] status in
            if let strongSelf = self {
                let paused: Bool
                if let status = status {
                    switch status {
                        case .paused:
                            paused = true
                        case let .buffering(whilePlaying):
                            paused = !whilePlaying
                        case .playing:
                            paused = false
                    }
                } else {
                    paused = true
                }
                strongSelf.actionPlayNode.isHidden = !paused
                strongSelf.actionPauseNode.isHidden = paused
                strongSelf.maximizedActionPlayNode.isHidden = !paused
                strongSelf.maximizedActionPauseNode.isHidden = paused
            }
        }
        
        self.maximizedScrubbingNode.seek = { [weak self] timestamp in
            self?.seek?(timestamp)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let minHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
        let maxHeight = MediaNavigationAccessoryHeaderNode.maximizedHeight
        let maximizationFactor = (size.height - minHeight) / (maxHeight - minHeight)
        
        let enableExpandTap = maximizationFactor.isEqual(to: 0.0)
        if let tapRecognizer = self.tapRecognizer, tapRecognizer.isEnabled != enableExpandTap {
            tapRecognizer.isEnabled = enableExpandTap
        }
        
        var titleString: NSAttributedString?
        var subtitleString: NSAttributedString?
        var maximizedTitleString: NSAttributedString?
        var maximizedSubtitleString: NSAttributedString?
        if let stateAndStatus = self.stateAndStatus, let item = stateAndStatus.state.item, let info = item.info {
            switch info.labelInfo {
                case let .music(title, performer):
                    let titleText: String = title ?? "Unknown Track"
                    let subtitleText: String = performer ?? "Unknown Artist"
                    
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: titleColor)
                    subtitleString = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: subtitleColor)
                
                    maximizedTitleString = NSAttributedString(string: titleText, font: maximizedTitleFont, textColor: titleColor)
                    maximizedSubtitleString = NSAttributedString(string: subtitleText, font: maximizedSubtitleFont, textColor: subtitleColor)
                case .voice:
                    let titleText: String = "Voice Message"
                    titleString = NSAttributedString(string: titleText, font: titleFont, textColor: titleColor)
                
                    maximizedTitleString = NSAttributedString(string: titleText, font: maximizedTitleFont, textColor: titleColor)
            }
        }
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeMaximizedTitleLayout = TextNode.asyncLayout(self.maximizedTitleNode)
        let makeMaximizedSubtitleLayout = TextNode.asyncLayout(self.maximizedSubtitleNode)
        
        let (titleLayout, titleApply) = makeTitleLayout(titleString, nil, 1, .middle, CGSize(width: size.width - 80.0, height: 100.0), .natural, nil, UIEdgeInsets())
        let (subtitleLayout, subtitleApply) = makeSubtitleLayout(subtitleString, nil, 1, .middle, CGSize(width: size.width - 80.0, height: 100.0), .natural, nil, UIEdgeInsets())
        
        let (maximizedTitleLayout, maximizedTitleApply) = makeMaximizedTitleLayout(maximizedTitleString, nil, 1, .middle, CGSize(width: size.width - 80.0, height: 100.0), .natural, nil, UIEdgeInsets())
        let (maximizedSubtitleLayout, maximizedSubtitleApply) = makeMaximizedSubtitleLayout(maximizedSubtitleString, nil, 1, .middle, CGSize(width: size.width - 80.0, height: 100.0), .natural, nil, UIEdgeInsets())
        
        let _ = titleApply()
        let _ = subtitleApply()
        let _ = maximizedTitleApply()
        let _ = maximizedSubtitleApply()
        
        let minimizedTitleOffset: CGFloat = subtitleString == nil ? 6.0 : 0.0
        let maximizedTitleOffset: CGFloat = subtitleString == nil ? 12.0 : 0.0
        
        let minimizedTitleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleLayout.size.width) / 2.0), y: 4.0 + minimizedTitleOffset), size: titleLayout.size)
        let minimizedSubtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleLayout.size.width) / 2.0), y: 20.0), size: subtitleLayout.size)
        
        let maximizedTitleFrame = CGRect(origin: CGPoint(x: floor((size.width - maximizedTitleLayout.size.width) / 2.0), y: 57.0 + maximizedTitleOffset), size: maximizedTitleLayout.size)
        let maximizedSubtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - maximizedSubtitleLayout.size.width) / 2.0), y: 80.0), size: maximizedSubtitleLayout.size)
        
        let maximizedTitleDistance = maximizedTitleFrame.midY - minimizedTitleFrame.midY
        let maximizedSubtitleDistance = maximizedSubtitleFrame.midY - minimizedSubtitleFrame.midY
        
        var updatedMinimizedTitleFrame = minimizedTitleFrame.offsetBy(dx: 0.0, dy: maximizedTitleDistance * maximizationFactor)
        var updatedMaximizedTitleFrame = maximizedTitleFrame.offsetBy(dx: 0.0, dy: -maximizedTitleDistance * (1.0 - maximizationFactor))
        
        transition.updateFrame(node: self.titleNode, frame: updatedMinimizedTitleFrame)
        transition.updateFrame(node: self.subtitleNode, frame: minimizedSubtitleFrame.offsetBy(dx: 0.0, dy: maximizedSubtitleDistance * maximizationFactor))
        
        updatedMinimizedTitleFrame.origin.y -= minimizedTitleOffset
        updatedMaximizedTitleFrame.origin.y -= maximizedTitleOffset
        
        transition.updateFrame(node: self.maximizedTitleNode, frame: updatedMaximizedTitleFrame)
        transition.updateFrame(node: self.maximizedSubtitleNode, frame: maximizedSubtitleFrame.offsetBy(dx: 0.0, dy: -maximizedSubtitleDistance * (1.0 - maximizationFactor)))
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: bounds.size.width - 18.0 - closeButtonSize.width, y: updatedMinimizedTitleFrame.minY + 8.0), size: closeButtonSize))
        transition.updateFrame(node: self.actionPlayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.actionPauseNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.actionButton, frame: CGRect(origin: CGPoint(x: 0.0, y: updatedMinimizedTitleFrame.minY - 4.0), size: CGSize(width: 40.0, height: 37.0)))
        transition.updateFrame(node: self.scrubbingNode, frame: CGRect(origin: CGPoint(x: 0.0, y: (37.0 + (maxHeight - minHeight) * maximizationFactor) - 2.0), size: CGSize(width: size.width, height: 2.0)))
        transition.updateFrame(node: self.maximizedScrubbingNode, frame: CGRect(origin: CGPoint(x: 57.0, y: updatedMaximizedTitleFrame.minY - 38.0), size: CGSize(width: size.width - 114.0, height: 15.0)))
        
        transition.updateFrame(node: self.maximizedLeftTimestampNode, frame: CGRect(origin: CGPoint(x: 0.0, y: updatedMaximizedTitleFrame.minY - 39.0), size: CGSize(width: 57.0 - 13.0, height: 20.0)))
        transition.updateFrame(node: self.maximizedRightTimestampNode, frame: CGRect(origin: CGPoint(x: size.width - 57.0 + 13.0, y: updatedMaximizedTitleFrame.minY - 39.0), size: CGSize(width: 57.0 - 13.0, height: 20.0)))
        
        let maximizedActionButtonSize = self.maximizedActionButton.bounds.size
        let maximizedActionButtonFrame = CGRect(origin: CGPoint(x: floor((size.width - maximizedActionButtonSize.width) / 2.0), y: updatedMaximizedTitleFrame.maxY + 26.0), size: maximizedActionButtonSize)
        transition.updateFrame(node: self.maximizedActionButton, frame: maximizedActionButtonFrame)
        
        let actionButtonSpacing: CGFloat = 10.0
        transition.updateFrame(node: self.maximizedPreviousButton, frame: CGRect(origin: CGPoint(x: maximizedActionButtonFrame.minX - maximizedActionButtonSize.width - actionButtonSpacing, y: maximizedActionButtonFrame.minY), size: maximizedActionButtonSize))
        transition.updateFrame(node: self.maximizedNextButton, frame: CGRect(origin: CGPoint(x: maximizedActionButtonFrame.maxX + actionButtonSpacing, y: maximizedActionButtonFrame.minY), size: maximizedActionButtonSize))
        transition.updateFrame(node: self.maximizedShuffleButton, frame: CGRect(origin: CGPoint(x: 0.0, y: maximizedActionButtonFrame.minY), size: CGSize(width: 56.0, height: 50.0)))
        transition.updateFrame(node: self.maximizedRepeatButton, frame: CGRect(origin: CGPoint(x: size.width - 56.0, y: maximizedActionButtonFrame.minY), size: CGSize(width: 56.0, height: 50.0)))
        
        transition.updateAlpha(node: self.actionButton, alpha: 1.0 - maximizationFactor)
        transition.updateAlpha(node: self.closeButton, alpha: 1.0 - maximizationFactor)
        
        transition.updateAlpha(node: self.maximizedActionButton, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedPreviousButton, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedNextButton, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedPreviousButton, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedShuffleButton, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedRepeatButton, alpha: maximizationFactor)
        
        transition.updateAlpha(node: self.titleNode, alpha: 1.0 - maximizationFactor)
        transition.updateAlpha(node: self.subtitleNode, alpha: 1.0 - maximizationFactor)
        transition.updateAlpha(node: self.scrubbingNode, alpha: 1.0 - maximizationFactor)
        transition.updateAlpha(node: self.maximizedScrubbingNode, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedTitleNode, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedSubtitleNode, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedLeftTimestampNode, alpha: maximizationFactor)
        transition.updateAlpha(node: self.maximizedRightTimestampNode, alpha: maximizationFactor)
    }
    
    @objc func closeButtonPressed() {
        if let close = self.close {
            close()
        }
    }
    
    @objc func actionButtonPressed() {
        if let togglePlayPause = self.togglePlayPause {
            togglePlayPause()
        }
    }
    
    @objc func previousButtonPressed() {
        if let previous = self.previous {
            previous()
        }
    }
    
    @objc func nextButtonPressed() {
        if let next = self.next {
            next()
        }
    }
    
    @objc func shuffleButtonPressed() {
        
    }
    
    @objc func repeatButtonPressed() {
        
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.expand?()
        }
    }
}
