import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import UniversalMediaPlayer
import TelegramUIPreferences
import AccountContext
import PhotoResources
import AppBundle
import ManagedAnimationNode
import RangeSet

private func generateBackground(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 10.0 + 8.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setShadow(offset: CGSize(width: 0.0, height: -4.0), blur: 20.0, color: UIColor(white: 0.0, alpha: 0.3).cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: CGSize(width: 20.0, height: 20.0)))
    })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 10 + 8)
}

private func generateCollapseIcon(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 38.0, height: 5.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 2.5)
        context.setFillColor(theme.list.controlSecondaryColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
    })
}

private let digitsSet = CharacterSet(charactersIn: "0123456789")
private func timestampLabelWidthForDuration(_ timestamp: Double) -> CGFloat {
    let text: String
    if timestamp > 0 {
        let timestamp = Int32(timestamp)
        let hours = timestamp / (60 * 60)
        let minutes = timestamp % (60 * 60) / 60
        let seconds = timestamp % 60
        if hours != 0 {
            text = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            text = String(format: "%d:%02d", minutes, seconds)
        }
    } else {
        text = "-:--"
    }
    
    let convertedString = text.components(separatedBy: digitsSet).joined(separator: "8")
    let string = NSAttributedString(string: convertedString, font: Font.regular(13.0), textColor: .black)
    let size = string.boundingRect(with: CGSize(width: 200.0, height: 100.0), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil).size
    return size.width
}

private let titleFont = Font.semibold(18.0)
private let descriptionFont = Font.regular(18.0)

private func stringsForDisplayData(_ data: SharedMediaPlaybackDisplayData?, presentationData: PresentationData) -> (NSAttributedString?, NSAttributedString?, Bool) {
    var titleString: NSAttributedString?
    var descriptionString: NSAttributedString?
    var hasArtist = false
    
    if let data = data {
        let titleText: String
        let subtitleText: String
        switch data {
            case let .music(title, performer, _, _):
                titleText = title ?? presentationData.strings.MediaPlayer_UnknownTrack
                subtitleText = performer ?? presentationData.strings.MediaPlayer_UnknownArtist
                hasArtist = performer != nil
            case .voice, .instantVideo:
                titleText = ""
                subtitleText = ""
        }
        
        titleString = NSAttributedString(string: titleText, font: titleFont, textColor: presentationData.theme.list.itemPrimaryTextColor)
        descriptionString = NSAttributedString(string: subtitleText, font: descriptionFont, textColor: hasArtist ? presentationData.theme.list.itemAccentColor : presentationData.theme.list.itemSecondaryTextColor)
    }
    
    return (titleString, descriptionString, hasArtist)
}

final class OverlayPlayerControlsNode: ASDisplayNode {
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let postbox: Postbox
    private let engine: TelegramEngine
    private var presentationData: PresentationData
    
    private let backgroundNode: ASImageNode
    
    private let collapseNode: HighlightableButtonNode
    
    private let albumArtNode: TransformImageNode
    private var largeAlbumArtNode: TransformImageNode?
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let shareNode: HighlightableButtonNode
    private let artistButton: HighlightTrackingButtonNode
    
    private let scrubberNode: MediaPlayerScrubbingNode
    private let leftDurationLabel: MediaPlayerTimeTextNode
    private let rightDurationLabel: MediaPlayerTimeTextNode
    
    private let backwardButton: IconButtonNode
    private let forwardButton: IconButtonNode
    
    private var seekTimer: SwiftSignalKit.Timer?
    private var seekRate: AudioPlaybackRate = .x2
    private var previousRate: AudioPlaybackRate?
    
    private var currentIsPaused: Bool?
    private let playPauseButton: IconButtonNode
    private let playPauseIconNode: PlayPauseIconNode
    
    private var currentOrder: MusicPlaybackSettingsOrder?
    private let orderButton: IconButtonNode
    
    private var currentLooping: MusicPlaybackSettingsLooping?
    private let loopingButton: IconButtonNode
    
    private var currentRate: AudioPlaybackRate?
    private let rateButton: HighlightableButtonNode
    
    let separatorNode: ASDisplayNode
    
    var isExpanded = false
    var updateIsExpanded: (() -> Void)?
    
    var requestCollapse: (() -> Void)?
    var requestShare: ((MessageId) -> Void)?
    var requestSearchByArtist: ((String) -> Void)?
    
    var updateOrder: ((MusicPlaybackSettingsOrder) -> Void)?
    var control: ((SharedMediaPlayerControlAction) -> Void)?
    
    private(set) var currentItemId: SharedMediaPlaylistItemId?
    private var displayData: SharedMediaPlaybackDisplayData?
    private var currentAlbumArtInitialized = false
    private var currentAlbumArt: SharedMediaPlaybackAlbumArt?
    private var currentFileReference: FileMediaReference?
    private var statusDisposable: Disposable?
    
    private var scrubbingDisposable: Disposable?
    private var leftDurationLabelPushed = false
    private var rightDurationLabelPushed = false
    
    private var currentDuration: Double = 0.0
    private var currentPosition: Double = 0.0
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat)?
    
    init(account: Account, engine: TelegramEngine, accountManager: AccountManager<TelegramAccountManagerTypes>, presentationData: PresentationData, status: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError>) {
        self.accountManager = accountManager
        self.postbox = account.postbox
        self.engine = engine
        self.presentationData = presentationData
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = generateBackground(theme: presentationData.theme)
        
        self.collapseNode = HighlightableButtonNode()
        self.collapseNode.displaysAsynchronously = false
        self.collapseNode.setImage(generateCollapseIcon(theme: presentationData.theme), for: [])
        
        self.albumArtNode = TransformImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isUserInteractionEnabled = false
        self.descriptionNode.displaysAsynchronously = false
        
        self.artistButton = HighlightTrackingButtonNode()
        
        self.shareNode = HighlightableButtonNode()
        self.shareNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Share"), color: presentationData.theme.list.itemAccentColor), for: [])
        
        self.scrubberNode = MediaPlayerScrubbingNode(content: .standard(lineHeight: 3.0, lineCap: .round, scrubberHandle: .circle, backgroundColor: presentationData.theme.list.controlSecondaryColor, foregroundColor: presentationData.theme.list.itemAccentColor, bufferingColor: presentationData.theme.list.itemAccentColor.withAlphaComponent(0.4), chapters: []))
        self.leftDurationLabel = MediaPlayerTimeTextNode(textColor: presentationData.theme.list.itemSecondaryTextColor)
        self.leftDurationLabel.displaysAsynchronously = false
        self.leftDurationLabel.keepPreviousValueOnEmptyState = true
        self.rightDurationLabel = MediaPlayerTimeTextNode(textColor: presentationData.theme.list.itemSecondaryTextColor)
        self.rightDurationLabel.displaysAsynchronously = false
        self.rightDurationLabel.mode = .reversed
        self.rightDurationLabel.alignment = .right
        self.rightDurationLabel.keepPreviousValueOnEmptyState = true
        
        self.rateButton = HighlightableButtonNode()
        self.rateButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -4.0, bottom: -8.0, right: -4.0)
        self.rateButton.displaysAsynchronously = false
        
        self.backwardButton = IconButtonNode()
        self.backwardButton.displaysAsynchronously = false
        
        self.forwardButton = IconButtonNode()
        self.forwardButton.displaysAsynchronously = false
        
        self.orderButton = IconButtonNode()
        self.orderButton.displaysAsynchronously = false
        
        self.loopingButton = IconButtonNode()
        self.loopingButton.displaysAsynchronously = false
        
        self.playPauseButton = IconButtonNode()
        self.playPauseButton.displaysAsynchronously = false
        
        self.playPauseIconNode = PlayPauseIconNode()
        
        self.backwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Previous"), color: presentationData.theme.list.itemPrimaryTextColor)
        self.forwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Next"), color: presentationData.theme.list.itemPrimaryTextColor)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = presentationData.theme.list.itemPlainSeparatorColor
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.collapseNode)
        
        self.addSubnode(self.albumArtNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.artistButton)
        self.addSubnode(self.shareNode)
        
        self.addSubnode(self.leftDurationLabel)
        self.addSubnode(self.rightDurationLabel)
        self.addSubnode(self.rateButton)
        self.addSubnode(self.scrubberNode)
        
        self.addSubnode(self.orderButton)
        self.addSubnode(self.loopingButton)
        self.addSubnode(self.backwardButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.playPauseButton)
        self.playPauseButton.addSubnode(self.playPauseIconNode)
        
        self.addSubnode(self.separatorNode)
        
        let accountId = account.id
        let delayedStatus = status
        |> mapToSignal { value -> Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> in
            guard let value = value, value.0.id == accountId else {
                return .single(nil)
            }
            switch value.1 {
                case .state:
                    return .single(value)
                case .loading:
                    return .single(value)
                    |> delay(0.1, queue: .mainQueue())
            }
        }
        
        let mappedStatus = combineLatest(delayedStatus, self.scrubberNode.scrubbingTimestamp) |> map { value, scrubbingTimestamp -> MediaPlayerStatus in
            if let (_, valueOrLoading, _) = value, case let .state(value) = valueOrLoading {
                return MediaPlayerStatus(generationTimestamp: scrubbingTimestamp != nil ? 0 : value.status.generationTimestamp, duration: value.status.duration, dimensions: value.status.dimensions, timestamp: scrubbingTimestamp ?? value.status.timestamp, baseRate: value.status.baseRate, seekId: value.status.seekId, status: value.status.status, soundEnabled: value.status.soundEnabled)
            } else {
                return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
            }
        }
        self.scrubberNode.status = mappedStatus
        self.leftDurationLabel.status = mappedStatus
        self.rightDurationLabel.status = mappedStatus
        
        self.scrubbingDisposable = (self.scrubberNode.scrubbingPosition
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            let leftDurationLabelPushed: Bool
            let rightDurationLabelPushed: Bool
            if let value = value {
                leftDurationLabelPushed = value < 0.16
                rightDurationLabelPushed = value > (strongSelf.rateButton.isHidden ? 0.84 : 0.74)
            } else {
                leftDurationLabelPushed = false
                rightDurationLabelPushed = false
            }
            if leftDurationLabelPushed != strongSelf.leftDurationLabelPushed || rightDurationLabelPushed != strongSelf.rightDurationLabelPushed {
                strongSelf.leftDurationLabelPushed = leftDurationLabelPushed
                strongSelf.rightDurationLabelPushed = rightDurationLabelPushed
                
                if let layout = strongSelf.validLayout {
                    let _ = strongSelf.updateLayout(width: layout.0, leftInset: layout.1, rightInset: layout.2, maxHeight: layout.3, transition: .animated(duration: 0.35, curve: .spring))
                }
            }
        })
        
        self.statusDisposable = (delayedStatus
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            var valueItemId: SharedMediaPlaylistItemId?
            if let (_, value, _) = value, case let .state(state) = value {
                valueItemId = state.item.id
            }
            if !areSharedMediaPlaylistItemIdsEqual(valueItemId, strongSelf.currentItemId) {
                strongSelf.currentItemId = valueItemId
                strongSelf.scrubberNode.ignoreSeekId = nil
            }
            
            var rateButtonIsHidden = true
            var displayData: SharedMediaPlaybackDisplayData?
            if let (_, valueOrLoading, _) = value, case let .state(value) = valueOrLoading {
                var isPaused: Bool
                switch value.status.status {
                    case .playing:
                        isPaused = false
                    case .paused:
                        isPaused = true
                    case let .buffering(_, whilePlaying, _, _):
                        isPaused = !whilePlaying
                }
                if strongSelf.wasPlaying {
                    isPaused = false
                }
                
                let isFirstTime = strongSelf.currentIsPaused == nil
                if strongSelf.currentIsPaused != isPaused {
                    strongSelf.currentIsPaused = isPaused
                    
                    strongSelf.updatePlayPauseButton(paused: isPaused, animated: !isFirstTime)
                }
                
                strongSelf.playPauseButton.isEnabled = true
                strongSelf.backwardButton.isEnabled = true
                strongSelf.forwardButton.isEnabled = true
                
                displayData = value.item.displayData
                
                if value.order != strongSelf.currentOrder {
                    strongSelf.updateOrder?(value.order)
                    strongSelf.currentOrder = value.order
                    strongSelf.updateOrderButton(value.order)
                }
                if value.looping != strongSelf.currentLooping {
                    strongSelf.currentLooping = value.looping
                    strongSelf.updateLoopButton(value.looping)
                }
                
                let baseRate: AudioPlaybackRate
                if !value.status.baseRate.isEqual(to: 1.0) {
                    baseRate = .x2
                } else {
                    baseRate = .x1
                }
                if baseRate != strongSelf.currentRate {
                    strongSelf.currentRate = baseRate
                    strongSelf.updateRateButton(baseRate)
                }
                
                if let displayData = displayData, case let .music(_, _, _, long) = displayData, long {
                    strongSelf.scrubberNode.enableFineScrubbing = true
                    rateButtonIsHidden = false
                } else {
                    strongSelf.scrubberNode.enableFineScrubbing = false
                    rateButtonIsHidden = true
                }
                
                let duration = value.status.duration
                if duration != strongSelf.currentDuration && !duration.isZero {
                    strongSelf.currentDuration = duration
                    if let layout = strongSelf.validLayout {
                        let _ = strongSelf.updateLayout(width: layout.0, leftInset: layout.1, rightInset: layout.2, maxHeight: layout.3, transition: .immediate)
                    }
                }
                
                strongSelf.rateButton.isHidden = rateButtonIsHidden
                
                strongSelf.currentPosition = value.status.timestamp
            } else {
                strongSelf.playPauseButton.isEnabled = false
                strongSelf.backwardButton.isEnabled = false
                strongSelf.forwardButton.isEnabled = false
                strongSelf.rateButton.isHidden = true
                displayData = nil
            }
            
            if strongSelf.displayData != displayData {
                strongSelf.displayData = displayData
                          
                var canShare = true
                if let (_, valueOrLoading, _) = value, case let .state(value) = valueOrLoading, let source = value.item.playbackData?.source {
                    switch source {
                        case let .telegramFile(fileReference, isCopyProtected):
                            canShare = !isCopyProtected
                            strongSelf.currentFileReference = fileReference
                            if let size = fileReference.media.size {
                                strongSelf.scrubberNode.bufferingStatus = strongSelf.postbox.mediaBox.resourceRangesStatus(fileReference.media.resource)
                                |> map { ranges -> (RangeSet<Int64>, Int64) in
                                    return (ranges, size)
                                }
                            } else {
                                strongSelf.scrubberNode.bufferingStatus = nil
                            }
                    }
                } else {
                    strongSelf.scrubberNode.bufferingStatus = nil
                }
                strongSelf.updateLabels(transition: .immediate)
                
                strongSelf.shareNode.isHidden = !canShare
            }
        })
        
        self.scrubberNode.seek = { [weak self] value in
            self?.control?(.seek(value))
        }
        
        self.collapseNode.addTarget(self, action: #selector(self.collapsePressed), forControlEvents: .touchUpInside)
        self.shareNode.addTarget(self, action: #selector(self.sharePressed), forControlEvents: .touchUpInside)
        self.orderButton.addTarget(self, action: #selector(self.orderPressed), forControlEvents: .touchUpInside)
        self.loopingButton.addTarget(self, action: #selector(self.loopingPressed), forControlEvents: .touchUpInside)
        self.backwardButton.addTarget(self, action: #selector(self.backwardPressed), forControlEvents: .touchUpInside)
        self.forwardButton.addTarget(self, action: #selector(self.forwardPressed), forControlEvents: .touchUpInside)
        self.playPauseButton.addTarget(self, action: #selector(self.playPausePressed), forControlEvents: .touchUpInside)
        self.rateButton.addTarget(self, action: #selector(self.rateButtonPressed), forControlEvents: .touchUpInside)
        self.artistButton.addTarget(self, action: #selector(self.artistPressed), forControlEvents: .touchUpInside)
        
        self.artistButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.descriptionNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.descriptionNode.alpha = 0.4
                } else {
                    strongSelf.descriptionNode.alpha = 1.0
                    strongSelf.descriptionNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.playPauseButton.circleColor = presentationData.theme.list.controlSecondaryColor.withAlphaComponent(0.35)
        self.backwardButton.circleColor = presentationData.theme.list.controlSecondaryColor.withAlphaComponent(0.35)
        self.forwardButton.circleColor = presentationData.theme.list.controlSecondaryColor.withAlphaComponent(0.35)
    }
    
    deinit {
        self.statusDisposable?.dispose()
        self.scrubbingDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.albumArtNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.albumArtTap(_:))))
        
        let backwardLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.seekBackwardLongPress(_:)))
        backwardLongPressGestureRecognizer.minimumPressDuration = 0.3
        self.backwardButton.view.addGestureRecognizer(backwardLongPressGestureRecognizer)
        
        let forwardLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.seekForwardLongPress(_:)))
        forwardLongPressGestureRecognizer.minimumPressDuration = 0.3
        self.forwardButton.view.addGestureRecognizer(forwardLongPressGestureRecognizer)
    }
    
    private var wasPlaying = false
    @objc private func seekBackwardLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
            case .began:
                self.wasPlaying = !(self.currentIsPaused ?? true)
                self.backwardButton.isPressing = true
                self.previousRate = self.currentRate
                self.control?(.playback(.pause))
                
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
                        
                        let newPosition = strongSelf.currentPosition - delta
                        strongSelf.currentPosition = newPosition
                        strongSelf.control?(.seek(newPosition))
                    }
                }, queue: Queue.mainQueue())
                self.seekTimer = seekTimer
                seekTimer.start()
            case .ended, .cancelled:
                self.backwardButton.isPressing = false
                self.seekTimer?.invalidate()
                self.seekTimer = nil
                if self.wasPlaying {
                    self.control?(.playback(.play))
                    self.wasPlaying = false
                }
            default:
                break
        }
    }
    
    @objc private func seekForwardLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
            case .began:
                self.forwardButton.isPressing = true
                self.previousRate = self.currentRate
                self.seekRate = .x4
                self.control?(.setBaseRate(self.seekRate))
                let seekTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
                    if let strongSelf = self {
                        if strongSelf.seekRate == .x4 {
                            strongSelf.seekRate = .x8
                        } else if strongSelf.seekRate == .x8 {
                            strongSelf.seekRate = .x16
                        }
                        strongSelf.control?(.setBaseRate(strongSelf.seekRate))
                        if strongSelf.seekRate == .x16 {
                            strongSelf.seekTimer?.invalidate()
                            strongSelf.seekTimer = nil
                        }
                    }
                }, queue: Queue.mainQueue())
                self.seekTimer = seekTimer
                seekTimer.start()
            case .ended, .cancelled:
                self.forwardButton.isPressing = false
                self.control?(.setBaseRate(self.previousRate ?? .x1))
                self.seekTimer?.invalidate()
                self.seekTimer = nil
            default:
                break
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        guard self.presentationData.theme !== presentationData.theme else {
            return
        }
        self.presentationData = presentationData
        
        self.playPauseButton.circleColor = presentationData.theme.list.controlSecondaryColor.withAlphaComponent(0.35)
        self.backwardButton.circleColor = presentationData.theme.list.controlSecondaryColor.withAlphaComponent(0.35)
        self.forwardButton.circleColor = presentationData.theme.list.controlSecondaryColor.withAlphaComponent(0.35)
        
        self.backgroundNode.image = generateBackground(theme: presentationData.theme)
        self.collapseNode.setImage(generateCollapseIcon(theme: presentationData.theme), for: [])
        self.shareNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Share"), color: presentationData.theme.list.itemAccentColor), for: [])
        self.scrubberNode.updateColors(backgroundColor: presentationData.theme.list.controlSecondaryColor, foregroundColor: presentationData.theme.list.itemAccentColor)
        self.leftDurationLabel.textColor = presentationData.theme.list.itemSecondaryTextColor
        self.rightDurationLabel.textColor = presentationData.theme.list.itemSecondaryTextColor
        self.backwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Previous"), color: presentationData.theme.list.itemPrimaryTextColor)
        self.forwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Next"), color: presentationData.theme.list.itemPrimaryTextColor)
        if let isPaused = self.currentIsPaused {
            self.updatePlayPauseButton(paused: isPaused, animated: false)
        }
        if let order = self.currentOrder {
            self.updateOrderButton(order)
        }
        if let looping = self.currentLooping {
            self.updateLoopButton(looping)
        }
        if let rate = self.currentRate {
            self.updateRateButton(rate)
        }
        self.separatorNode.backgroundColor = presentationData.theme.list.itemPlainSeparatorColor
    }
    
    private func updateLabels(transition: ContainedViewLayoutTransition) {
        guard let (width, leftInset, rightInset, maxHeight) = self.validLayout else {
            return
        }
        
        let panelHeight = OverlayPlayerControlsNode.heightForLayout(width: width, leftInset: leftInset, rightInset: rightInset, maxHeight: maxHeight, isExpanded: self.isExpanded)
        
        let sideInset: CGFloat = 20.0
        
        let infoLabelsLeftInset: CGFloat = 60.0
        let infoLabelsRightInset: CGFloat = 32.0
        
        let infoVerticalOrigin: CGFloat = panelHeight - OverlayPlayerControlsNode.basePanelHeight + 36.0
        
        let (titleString, descriptionString, hasArtist) = stringsForDisplayData(self.displayData, presentationData: self.presentationData)
        self.artistButton.isUserInteractionEnabled = hasArtist
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - sideInset * 2.0 - leftInset - rightInset - infoLabelsLeftInset - infoLabelsRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: descriptionString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - sideInset * 2.0 - leftInset - rightInset - infoLabelsLeftInset - infoLabelsRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: self.isExpanded ? floor((width - titleLayout.size.width) / 2.0) : (leftInset + sideInset + infoLabelsLeftInset), y: infoVerticalOrigin + 1.0), size: titleLayout.size))
        let _ = titleApply()
        
        let descriptionFrame = CGRect(origin: CGPoint(x: self.isExpanded ? floor((width - descriptionLayout.size.width) / 2.0) : (leftInset + sideInset + infoLabelsLeftInset), y: infoVerticalOrigin + 24.0), size: descriptionLayout.size)
        transition.updateFrame(node: self.descriptionNode, frame: descriptionFrame)
        let _ = descriptionApply()
        
        self.artistButton.frame = descriptionFrame.insetBy(dx: -8.0, dy: -8.0)
        
        var albumArt: SharedMediaPlaybackAlbumArt?
        if let displayData = self.displayData {
            switch displayData {
                case let .music(_, _, value, _):
                    albumArt = value
                default:
                    break
            }
        }
        if self.currentAlbumArt != albumArt || !self.currentAlbumArtInitialized {
            self.currentAlbumArtInitialized = true
            self.currentAlbumArt = albumArt
            self.albumArtNode.setSignal(playerAlbumArt(postbox: self.postbox, engine: self.engine, fileReference: self.currentFileReference, albumArt: albumArt, thumbnail: true))
            if let largeAlbumArtNode = self.largeAlbumArtNode {
                largeAlbumArtNode.setSignal(playerAlbumArt(postbox: self.postbox, engine: self.engine, fileReference: self.currentFileReference, albumArt: albumArt, thumbnail: false))
            }
        }
    }
    
    private func updatePlayPauseButton(paused: Bool, animated: Bool) {
        self.playPauseIconNode.customColor = self.presentationData.theme.list.itemPrimaryTextColor
        if paused {
            self.playPauseIconNode.enqueueState(.play, animated: animated)
        } else {
            self.playPauseIconNode.enqueueState(.pause, animated: animated)
        }
    }
    
    private func updateOrderButton(_ order: MusicPlaybackSettingsOrder) {
        let baseColor = self.presentationData.theme.list.itemSecondaryTextColor
        switch order {
            case .regular:
                self.orderButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/OrderReverse"), color: baseColor)
            case .reversed:
                self.orderButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/OrderReverse"), color: self.presentationData.theme.list.itemAccentColor)
            case .random:
                self.orderButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/OrderRandom"), color: self.presentationData.theme.list.itemAccentColor)
        }
    }
    
    private func updateLoopButton(_ looping: MusicPlaybackSettingsLooping) {
        let baseColor = self.presentationData.theme.list.itemSecondaryTextColor
        switch looping {
            case .none:
                self.loopingButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Repeat"), color: baseColor)
            case .item:
                self.loopingButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/RepeatOne"), color: self.presentationData.theme.list.itemAccentColor)
            case .all:
                self.loopingButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Repeat"), color: self.presentationData.theme.list.itemAccentColor)
        }
    }
    
    private func updateRateButton(_ baseRate: AudioPlaybackRate) {
        switch baseRate {
            case .x2:
                self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerMaximizedRateActiveIcon(self.presentationData.theme), for: [])
            default:
                self.rateButton.setImage(PresentationResourcesRootController.navigationPlayerMaximizedRateInactiveIcon(self.presentationData.theme), for: [])
        }
    }
    
    static let basePanelHeight: CGFloat = 220.0
    
    static func heightForLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, isExpanded: Bool) -> CGFloat {
        var panelHeight: CGFloat = OverlayPlayerControlsNode.basePanelHeight
        if isExpanded {
            let sideInset: CGFloat = 20.0
            panelHeight += width - leftInset - rightInset - sideInset * 2.0 + 24.0
        }
        return min(panelHeight, maxHeight)
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, leftInset, rightInset, maxHeight)
    
        let panelHeight = OverlayPlayerControlsNode.heightForLayout(width: width, leftInset: leftInset, rightInset: rightInset, maxHeight: maxHeight, isExpanded: self.isExpanded)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight), size: CGSize(width: width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.collapseNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: CGSize(width: width, height: 30.0)))
        
        let sideInset: CGFloat = 20.0
        let sideButtonsInset: CGFloat = sideInset + 36.0
        
        let infoVerticalOrigin: CGFloat = panelHeight - OverlayPlayerControlsNode.basePanelHeight + 36.0
        
        self.updateLabels(transition: transition)
        
        transition.updateFrame(node: self.shareNode, frame: CGRect(origin: CGPoint(x: width - rightInset - sideInset - 32.0, y: infoVerticalOrigin + 2.0), size: CGSize(width: 42.0, height: 42.0)))
        
        let albumArtSize = CGSize(width: 48.0, height: 48.0)
        let makeAlbumArtLayout = self.albumArtNode.asyncLayout()
        let applyAlbumArt = makeAlbumArtLayout(TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: albumArtSize, boundingSize: albumArtSize, intrinsicInsets: UIEdgeInsets()))
        applyAlbumArt()
        let albumArtFrame = CGRect(origin: CGPoint(x: leftInset + sideInset, y: infoVerticalOrigin - 1.0), size: albumArtSize)
        let previousAlbumArtNodeFrame = self.albumArtNode.frame
        transition.updateFrame(node: self.albumArtNode, frame: albumArtFrame)
        
        if self.isExpanded {
            let largeAlbumArtNode: TransformImageNode
            var animateIn = false
            if let current = self.largeAlbumArtNode {
                largeAlbumArtNode = current
            } else {
                animateIn = true
                largeAlbumArtNode = TransformImageNode()
                if self.isNodeLoaded {
                    largeAlbumArtNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.albumArtTap(_:))))
                }
                self.largeAlbumArtNode = largeAlbumArtNode
                self.addSubnode(largeAlbumArtNode)
                if self.currentAlbumArtInitialized {
                    largeAlbumArtNode.setSignal(playerAlbumArt(postbox: self.postbox, engine: self.engine, fileReference: self.currentFileReference, albumArt: self.currentAlbumArt, thumbnail: false))
                }
            }
            
            let albumArtHeight = max(1.0, panelHeight - OverlayPlayerControlsNode.basePanelHeight - 24.0)
            
            let largeAlbumArtSize = CGSize(width: albumArtHeight, height: albumArtHeight)
            let makeLargeAlbumArtLayout = largeAlbumArtNode.asyncLayout()
            let applyLargeAlbumArt = makeLargeAlbumArtLayout(TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: largeAlbumArtSize, boundingSize: largeAlbumArtSize, intrinsicInsets: UIEdgeInsets()))
            applyLargeAlbumArt()
            
            let largeAlbumArtFrame = CGRect(origin: CGPoint(x: floor((width - largeAlbumArtSize.width) / 2.0), y: 34.0), size: largeAlbumArtSize)
            
            if animateIn && transition.isAnimated {
                largeAlbumArtNode.frame = largeAlbumArtFrame
                transition.animatePositionAdditive(node: largeAlbumArtNode, offset: CGPoint(x: previousAlbumArtNodeFrame.center.x - largeAlbumArtFrame.center.x, y: previousAlbumArtNodeFrame.center.y - largeAlbumArtFrame.center.y))
                //largeAlbumArtNode.layer.animatePosition(from: CGPoint(x: -50.0, y: 0.0), to: CGPoint(), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, additive: true)
                transition.animateTransformScale(node: largeAlbumArtNode, from: previousAlbumArtNodeFrame.size.height / largeAlbumArtFrame.size.height)
                largeAlbumArtNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                if let copyView = self.albumArtNode.view.snapshotContentTree() {
                    copyView.frame = previousAlbumArtNodeFrame
                    copyView.center = largeAlbumArtFrame.center
                    self.view.insertSubview(copyView, belowSubview: largeAlbumArtNode.view)
                    transition.animatePositionAdditive(layer: copyView.layer, offset: CGPoint(x: previousAlbumArtNodeFrame.center.x - largeAlbumArtFrame.center.x, y: previousAlbumArtNodeFrame.center.y - largeAlbumArtFrame.center.y), completion: { [weak copyView] _ in
                        copyView?.removeFromSuperview()
                    })
                    //copyView.layer.animatePosition(from: CGPoint(x: -50.0, y: 0.0), to: CGPoint(), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, additive: true)
                    copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.28, removeOnCompletion: false)
                    transition.updateTransformScale(layer: copyView.layer, scale: largeAlbumArtFrame.size.height / previousAlbumArtNodeFrame.size.height)
                }
            } else {
                transition.updateFrame(node: largeAlbumArtNode, frame: largeAlbumArtFrame)
            }
            self.albumArtNode.isHidden = true
        } else if let largeAlbumArtNode = self.largeAlbumArtNode {
            self.largeAlbumArtNode = nil
            self.albumArtNode.isHidden = false
            if transition.isAnimated {
                transition.animatePosition(node: self.albumArtNode, from: largeAlbumArtNode.frame.center)
                transition.animateTransformScale(node: self.albumArtNode, from: largeAlbumArtNode.frame.height / self.albumArtNode.frame.height)
                self.albumArtNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                
                transition.updatePosition(node: largeAlbumArtNode, position: self.albumArtNode.frame.center, completion: { [weak largeAlbumArtNode] _ in
                    largeAlbumArtNode?.removeFromSupernode()
                })
                largeAlbumArtNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.28, removeOnCompletion: false)
                transition.updateTransformScale(node: largeAlbumArtNode, scale: self.albumArtNode.frame.height / largeAlbumArtNode.frame.height)
            } else {
                largeAlbumArtNode.removeFromSupernode()
            }
        }
        
        let scrubberVerticalOrigin: CGFloat = infoVerticalOrigin + 64.0
        
        transition.updateFrame(node: self.scrubberNode, frame: CGRect(origin: CGPoint(x: leftInset +  sideInset, y: scrubberVerticalOrigin - 8.0), size: CGSize(width: width - sideInset * 2.0 - leftInset - rightInset, height: 10.0 + 8.0 * 2.0)))
        
        let leftLabelVerticalOffset: CGFloat = self.leftDurationLabelPushed ? 6.0 : 0.0
        transition.updateFrame(node: self.leftDurationLabel, frame: CGRect(origin: CGPoint(x: leftInset + sideInset, y: scrubberVerticalOrigin + 14.0 + leftLabelVerticalOffset), size: CGSize(width: 100.0, height: 20.0)))
        
        let rightLabelVerticalOffset: CGFloat = self.rightDurationLabelPushed ? 6.0 : 0.0
        transition.updateFrame(node: self.rightDurationLabel, frame: CGRect(origin: CGPoint(x: width - sideInset - rightInset - 100.0, y: scrubberVerticalOrigin + 14.0 + rightLabelVerticalOffset), size: CGSize(width: 100.0, height: 20.0)))
        
        let rateRightOffset = timestampLabelWidthForDuration(self.currentDuration)
        transition.updateFrame(node: self.rateButton, frame: CGRect(origin: CGPoint(x: width - sideInset - rightInset - rateRightOffset - 28.0, y: scrubberVerticalOrigin + 10.0 + rightLabelVerticalOffset), size: CGSize(width: 24.0, height: 24.0)))
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: CGSize(width: width, height: panelHeight + 8.0)))
        
        let buttonSize = CGSize(width: 64.0, height: 64.0)
        let buttonsWidth = min(width - leftInset - rightInset - sideButtonsInset * 2.0, 320.0)
        let buttonsRect = CGRect(origin: CGPoint(x: floor((width - buttonsWidth) / 2.0), y: scrubberVerticalOrigin + 36.0), size: CGSize(width: buttonsWidth, height: buttonSize.height))
        
        transition.updateFrame(node: self.orderButton, frame: CGRect(origin: CGPoint(x: leftInset + sideInset - 22.0, y: buttonsRect.minY), size: buttonSize))
        transition.updateFrame(node: self.loopingButton, frame: CGRect(origin: CGPoint(x: width - rightInset - sideInset - buttonSize.width + 22.0, y: buttonsRect.minY), size: buttonSize))
        
        transition.updateFrame(node: self.backwardButton, frame: CGRect(origin: buttonsRect.origin, size: buttonSize))
        transition.updateFrame(node: self.forwardButton, frame: CGRect(origin: CGPoint(x: buttonsRect.maxX - buttonSize.width, y: buttonsRect.minY), size: buttonSize))
        
        let playPauseFrame = CGRect(origin: CGPoint(x: buttonsRect.minX + floor((buttonsRect.width - buttonSize.width) / 2.0), y: buttonsRect.minY), size: buttonSize)
        transition.updateFrame(node: self.playPauseButton, frame: playPauseFrame)
        transition.updateFrame(node: self.playPauseIconNode, frame: CGRect(origin: CGPoint(x: -6.0, y: -6.0), size: CGSize(width: 76.0, height: 76.0)))
        
        return panelHeight
    }
    
    func collapse() {
        if self.isExpanded {
            self.isExpanded = false
            self.updateIsExpanded?()
        }
    }
    
    @objc func collapsePressed() {
        self.requestCollapse?()
    }
    
    @objc func sharePressed() {
        if let itemId = self.currentItemId as? PeerMessagesMediaPlaylistItemId {
            self.requestShare?(itemId.messageId)
        }
    }
    
    @objc func orderPressed() {
        if let order = self.currentOrder {
            let nextOrder: MusicPlaybackSettingsOrder
            switch order {
                case .regular:
                    nextOrder = .reversed
                case .reversed:
                    nextOrder = .random
                case .random:
                    nextOrder = .regular
            }
            let _ = updateMusicPlaybackSettingsInteractively(accountManager: self.accountManager, {
                return $0.withUpdatedOrder(nextOrder)
            }).start()
            self.control?(.setOrder(nextOrder))
        }
    }
    
    @objc func loopingPressed() {
        if let looping = self.currentLooping {
            let nextLooping: MusicPlaybackSettingsLooping
            switch looping {
                case .none:
                    nextLooping = .item
                case .item:
                    nextLooping = .all
                case .all:
                    nextLooping = .none
            }
            let _ = updateMusicPlaybackSettingsInteractively(accountManager: self.accountManager, {
                return $0.withUpdatedLooping(nextLooping)
            }).start()
            self.control?(.setLooping(nextLooping))
        }
    }
    
    @objc func backwardPressed() {
        self.control?(.previous)
    }
    
    @objc func forwardPressed() {
        self.control?(.next)
    }
    
    @objc func playPausePressed() {
        self.control?(.playback(.togglePlayPause))
    }
    
    @objc func rateButtonPressed() {
        var nextRate: AudioPlaybackRate
        if let currentRate = self.currentRate {
            switch currentRate {
                case .x1:
                    nextRate = .x2
                default:
                    nextRate = .x1
            }
        } else {
            nextRate = .x2
        }
        self.control?(.setBaseRate(nextRate))
    }
    
    @objc func albumArtTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let supernode = self.supernode {
                let bounds = supernode.bounds
                if bounds.width > bounds.height {
                    return
                }
            }
            self.isExpanded = !self.isExpanded
            self.updateIsExpanded?()
        }
    }
    
    @objc func artistPressed() {
        let (_, descriptionString, _) = stringsForDisplayData(self.displayData, presentationData: self.presentationData)
        if let artist = descriptionString?.string {
            self.requestSearchByArtist?(artist)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result == self.view {
            return nil
        }
        return result
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
        super.init(size: CGSize(width: 76.0, height: 76.0))
        
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
