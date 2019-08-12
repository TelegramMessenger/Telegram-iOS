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

private func generateBackground(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 10.0 + 8.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setShadow(offset: CGSize(width: 0.0, height: -4.0), blur: 20.0, color: UIColor(white: 0.0, alpha: 0.3).cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: CGSize(width: 20.0, height: 20.0)))
    })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 10 + 8)
}

private func generateShareIcon(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 19.0, height: 5.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(theme.list.itemAccentColor.cgColor)
        for i in 0 ..< 3 {
            context.fillEllipse(in: CGRect(origin: CGPoint(x: CGFloat(i) * (5.0 + 2.0), y: 0.0), size: CGSize(width: 5.0, height: 5.0)))
        }
    })
}

private let titleFont = Font.medium(16.0)
private let descriptionFont = Font.regular(12.0)

private func stringsForDisplayData(_ data: SharedMediaPlaybackDisplayData?, theme: PresentationTheme) -> (NSAttributedString?, NSAttributedString?) {
    var titleString: NSAttributedString?
    var descriptionString: NSAttributedString?
    
    if let data = data {
        let titleText: String
        let subtitleText: String
        switch data {
            case let .music(title, performer, _):
                titleText = title ?? "Unknown Track"
                subtitleText = performer ?? "Unknown Artist"
            case .voice, .instantVideo:
                titleText = ""
                subtitleText = ""
        }
        
        titleString = NSAttributedString(string: titleText, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
        descriptionString = NSAttributedString(string: subtitleText, font: descriptionFont, textColor: theme.list.itemSecondaryTextColor)
    }
    
    return (titleString, descriptionString)
}

final class OverlayPlayerControlsNode: ASDisplayNode {
    private let accountManager: AccountManager
    private let postbox: Postbox
    private var theme: PresentationTheme
    
    private let backgroundNode: ASImageNode
    
    private let collapseNode: HighlightableButtonNode
    
    private let albumArtNode: TransformImageNode
    private var largeAlbumArtNode: TransformImageNode?
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let shareNode: HighlightableButtonNode
    
    private let scrubberNode: MediaPlayerScrubbingNode
    private let leftDurationLabel: MediaPlayerTimeTextNode
    private let rightDurationLabel: MediaPlayerTimeTextNode
    
    private let backwardButton: IconButtonNode
    private let forwardButton: IconButtonNode
    
    private var currentIsPaused: Bool?
    private let playPauseButton: IconButtonNode
    
    private var currentOrder: MusicPlaybackSettingsOrder?
    private let orderButton: IconButtonNode
    
    private var currentLooping: MusicPlaybackSettingsLooping?
    private let loopingButton: IconButtonNode
    
    let separatorNode: ASDisplayNode
    
    var isExpanded = false
    var updateIsExpanded: (() -> Void)?
    
    var requestCollapse: (() -> Void)?
    var requestShare: ((MessageId) -> Void)?
    
    var updateOrder: ((MusicPlaybackSettingsOrder) -> Void)?
    var control: ((SharedMediaPlayerControlAction) -> Void)?
    
    private(set) var currentItemId: SharedMediaPlaylistItemId?
    private var displayData: SharedMediaPlaybackDisplayData?
    private var currentAlbumArtInitialized = false
    private var currentAlbumArt: SharedMediaPlaybackAlbumArt?
    private var currentFileReference: FileMediaReference?
    private var statusDisposable: Disposable?
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat)?
    
    init(account: Account, accountManager: AccountManager, theme: PresentationTheme, status: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading)?, NoError>) {
        self.accountManager = accountManager
        self.postbox = account.postbox
        self.theme = theme
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = generateBackground(theme: theme)
        
        self.collapseNode = HighlightableButtonNode()
        self.collapseNode.displaysAsynchronously = false
        self.collapseNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/CollapseArrow"), color: theme.list.controlSecondaryColor), for: [])
        
        self.albumArtNode = TransformImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isUserInteractionEnabled = false
        self.descriptionNode.displaysAsynchronously = false
        
        self.shareNode = HighlightableButtonNode()
        self.shareNode.setImage(generateShareIcon(theme: theme), for: [])
        
        self.scrubberNode = MediaPlayerScrubbingNode(content: .standard(lineHeight: 3.0, lineCap: .round, scrubberHandle: .circle, backgroundColor: theme.list.controlSecondaryColor, foregroundColor: theme.list.itemAccentColor))
        self.leftDurationLabel = MediaPlayerTimeTextNode(textColor: theme.list.itemSecondaryTextColor)
        self.leftDurationLabel.displaysAsynchronously = false
        self.rightDurationLabel = MediaPlayerTimeTextNode(textColor: theme.list.itemSecondaryTextColor)
        self.rightDurationLabel.displaysAsynchronously = false
        self.rightDurationLabel.mode = .reversed
        self.rightDurationLabel.alignment = .right
        
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
        
        self.backwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Previous"), color: theme.list.itemPrimaryTextColor)
        self.forwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Next"), color: theme.list.itemPrimaryTextColor)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.list.itemPlainSeparatorColor
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.collapseNode)
        
        self.addSubnode(self.albumArtNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.shareNode)
        
        self.addSubnode(self.scrubberNode)
        self.addSubnode(self.leftDurationLabel)
        self.addSubnode(self.rightDurationLabel)
        
        self.addSubnode(self.orderButton)
        self.addSubnode(self.loopingButton)
        self.addSubnode(self.backwardButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.playPauseButton)
        
        self.addSubnode(self.separatorNode)
        
        let accountId = account.id
        let delayedStatus = status
        |> mapToSignal { value -> Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading)?, NoError> in
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
            if let (_, valueOrLoading) = value, case let .state(value) = valueOrLoading {
                return MediaPlayerStatus(generationTimestamp: value.status.generationTimestamp, duration: value.status.duration, dimensions: value.status.dimensions, timestamp: scrubbingTimestamp ?? value.status.timestamp, baseRate: value.status.baseRate, seekId: value.status.seekId, status: value.status.status, soundEnabled: value.status.soundEnabled)
            } else {
                return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
            }
        }
        self.scrubberNode.status = mappedStatus
        self.leftDurationLabel.status = mappedStatus
        self.rightDurationLabel.status = mappedStatus
        
        self.statusDisposable = (delayedStatus
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                var valueItemId: SharedMediaPlaylistItemId?
                if let (_, value) = value, case let .state(state) = value {
                    valueItemId = state.item.id
                }
                if !areSharedMediaPlaylistItemIdsEqual(valueItemId, strongSelf.currentItemId) {
                    strongSelf.currentItemId = valueItemId
                    strongSelf.scrubberNode.ignoreSeekId = nil
                }
                strongSelf.shareNode.isHidden = false
                var displayData: SharedMediaPlaybackDisplayData?
                if let (_, valueOrLoading) = value, case let .state(value) = valueOrLoading {
                    let isPaused: Bool
                    switch value.status.status {
                        case .playing:
                            isPaused = false
                        case .paused:
                            isPaused = true
                        case let .buffering(_, whilePlaying):
                            isPaused = !whilePlaying
                    }
                    if strongSelf.currentIsPaused != isPaused {
                        strongSelf.currentIsPaused = isPaused
                        
                        strongSelf.updatePlayPauseButton(paused: isPaused)
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
                } else {
                    strongSelf.playPauseButton.isEnabled = false
                    strongSelf.backwardButton.isEnabled = false
                    strongSelf.forwardButton.isEnabled = false
                    displayData = nil
                }
                
                if strongSelf.displayData != displayData {
                    strongSelf.displayData = displayData
                    
                    if let (_, valueOrLoading) = value, case let .state(value) = valueOrLoading, let source = value.item.playbackData?.source {
                        switch source {
                            case let .telegramFile(fileReference):
                                strongSelf.currentFileReference = fileReference
                                if let size = fileReference.media.size {
                                    strongSelf.scrubberNode.bufferingStatus = strongSelf.postbox.mediaBox.resourceRangesStatus(fileReference.media.resource)
                                    |> map { ranges -> (IndexSet, Int) in
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
                }
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
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.albumArtNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.albumArtTap(_:))))
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        guard self.theme !== theme else {
            return
        }
        self.theme = theme
        
        self.backgroundNode.image = generateBackground(theme: theme)
        self.collapseNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/CollapseArrow"), color: theme.list.controlSecondaryColor), for: [])
        self.shareNode.setImage(generateShareIcon(theme: theme), for: [])
        self.scrubberNode.updateColors(backgroundColor: theme.list.controlSecondaryColor, foregroundColor: theme.list.itemAccentColor)
        self.leftDurationLabel.textColor = theme.list.itemSecondaryTextColor
        self.rightDurationLabel.textColor = theme.list.itemSecondaryTextColor
        self.backwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Previous"), color: theme.list.itemPrimaryTextColor)
        self.forwardButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Next"), color: theme.list.itemPrimaryTextColor)
        if let isPaused = self.currentIsPaused {
            self.updatePlayPauseButton(paused: isPaused)
        }
        if let order = self.currentOrder {
            self.updateOrderButton(order)
        }
        if let looping = self.currentLooping {
            self.updateLoopButton(looping)
        }
        self.separatorNode.backgroundColor = theme.list.itemPlainSeparatorColor
    }
    
    private func updateLabels(transition: ContainedViewLayoutTransition) {
        guard let (width, leftInset, rightInset, maxHeight) = self.validLayout else {
            return
        }
        
        let panelHeight = OverlayPlayerControlsNode.heightForLayout(width: width, leftInset: leftInset, rightInset: rightInset, maxHeight: maxHeight, isExpanded: self.isExpanded)
        
        let sideInset: CGFloat = 20.0
        
        let infoLabelsLeftInset: CGFloat = 64.0
        let infoLabelsRightInset: CGFloat = 32.0
        
        let infoVerticalOrigin: CGFloat = panelHeight - OverlayPlayerControlsNode.basePanelHeight + 36.0
        
        let (titleString, descriptionString) = stringsForDisplayData(self.displayData, theme: self.theme)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - sideInset * 2.0 - leftInset - rightInset - infoLabelsLeftInset - infoLabelsRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: descriptionString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - sideInset * 2.0 - leftInset - rightInset - infoLabelsLeftInset - infoLabelsRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: self.isExpanded ? floor((width - titleLayout.size.width) / 2.0) : (leftInset + sideInset + infoLabelsLeftInset), y: infoVerticalOrigin + 1.0), size: titleLayout.size))
        let _ = titleApply()
        
        transition.updateFrame(node: self.descriptionNode, frame: CGRect(origin: CGPoint(x: self.isExpanded ? floor((width - descriptionLayout.size.width) / 2.0) : (leftInset + sideInset + infoLabelsLeftInset), y: infoVerticalOrigin + 27.0), size: descriptionLayout.size))
        let _ = descriptionApply()
        
        var albumArt: SharedMediaPlaybackAlbumArt?
        if let displayData = self.displayData {
            switch displayData {
                case let .music(_, _, value):
                    albumArt = value
                default:
                    break
            }
        }
        if self.currentAlbumArt != albumArt || !self.currentAlbumArtInitialized {
            self.currentAlbumArtInitialized = true
            self.currentAlbumArt = albumArt
            self.albumArtNode.setSignal(playerAlbumArt(postbox: self.postbox, fileReference: self.currentFileReference, albumArt: albumArt, thumbnail: true))
            if let largeAlbumArtNode = self.largeAlbumArtNode {
                largeAlbumArtNode.setSignal(playerAlbumArt(postbox: self.postbox, fileReference: self.currentFileReference, albumArt: albumArt, thumbnail: false))
            }
        }
    }
    
    private func updatePlayPauseButton(paused: Bool) {
        if paused {
            self.playPauseButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Play"), color: self.theme.list.itemPrimaryTextColor)
        } else {
            self.playPauseButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Pause"), color: self.theme.list.itemPrimaryTextColor)
        }
    }
    
    private func updateOrderButton(_ order: MusicPlaybackSettingsOrder) {
        let baseColor = self.theme.list.itemSecondaryTextColor
        switch order {
            case .regular:
                self.orderButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/OrderReverse"), color: baseColor)
            case .reversed:
                self.orderButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/OrderReverse"), color: self.theme.list.itemAccentColor)
            case .random:
                self.orderButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/OrderRandom"), color: self.theme.list.itemAccentColor)
        }
    }
    
    private func updateLoopButton(_ looping: MusicPlaybackSettingsLooping) {
        let baseColor = self.theme.list.itemSecondaryTextColor
        switch looping {
            case .none:
                self.loopingButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Repeat"), color: baseColor)
            case .item:
                self.loopingButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/RepeatOne"), color: self.theme.list.itemAccentColor)
            case .all:
                self.loopingButton.icon = generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Repeat"), color: self.theme.list.itemAccentColor)
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
        let sideButtonsInset: CGFloat = sideInset + 30.0
        
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
                    largeAlbumArtNode.setSignal(playerAlbumArt(postbox: self.postbox, fileReference: self.currentFileReference, albumArt: self.currentAlbumArt, thumbnail: false))
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
                    transition.animatePositionAdditive(layer: copyView.layer, offset: CGPoint(x: previousAlbumArtNodeFrame.center.x - largeAlbumArtFrame.center.x, y: previousAlbumArtNodeFrame.center.y - largeAlbumArtFrame.center.y), completion: { [weak copyView] in
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
        transition.updateFrame(node: self.leftDurationLabel, frame: CGRect(origin: CGPoint(x: leftInset + sideInset, y: scrubberVerticalOrigin + 12.0), size: CGSize(width: 100.0, height: 20.0)))
        transition.updateFrame(node: self.rightDurationLabel, frame: CGRect(origin: CGPoint(x: width - sideInset - rightInset - 100.0, y: scrubberVerticalOrigin + 12.0), size: CGSize(width: 100.0, height: 20.0)))
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: CGSize(width: width, height: panelHeight + 8.0)))
        
        let buttonSize = CGSize(width: 64.0, height: 64.0)
        let buttonsWidth = min(width - leftInset - rightInset - sideButtonsInset * 2.0, 320.0)
        let buttonsRect = CGRect(origin: CGPoint(x: floor((width - buttonsWidth) / 2.0), y: scrubberVerticalOrigin + 36.0), size: CGSize(width: buttonsWidth, height: buttonSize.height))
        
        transition.updateFrame(node: self.orderButton, frame: CGRect(origin: CGPoint(x: leftInset + sideInset - 22.0, y: buttonsRect.minY), size: buttonSize))
        transition.updateFrame(node: self.loopingButton, frame: CGRect(origin: CGPoint(x: width - rightInset - sideInset - buttonSize.width + 22.0, y: buttonsRect.minY), size: buttonSize))
        
        transition.updateFrame(node: self.backwardButton, frame: CGRect(origin: buttonsRect.origin, size: buttonSize))
        transition.updateFrame(node: self.forwardButton, frame: CGRect(origin: CGPoint(x: buttonsRect.maxX - buttonSize.width, y: buttonsRect.minY), size: buttonSize))
        transition.updateFrame(node: self.playPauseButton, frame: CGRect(origin: CGPoint(x: buttonsRect.minX + floor((buttonsRect.width - buttonSize.width) / 2.0), y: buttonsRect.minY), size: buttonSize))
        
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result == self.view {
            return nil
        }
        return result
    }
}
