import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import AccountContext
import RadialStatusNode
import PhotoResources
import GridMessageSelectionNode
import ContextUI
import ChatMessageInteractiveMediaBadge

private func mediaForMessage(_ message: Message) -> Media? {
    for media in message.media {
        if let media = media as? TelegramMediaImage {
            return media
        } else if let file = media as? TelegramMediaFile {
            if file.mimeType.hasPrefix("audio/") {
                return nil
            } else if !file.isVideo && file.mimeType.hasPrefix("video/") {
                return file
            } else {
                return file
            }
        }
    }
    return nil
}

private let mediaBadgeBackgroundColor = UIColor(white: 0.0, alpha: 0.6)
private let mediaBadgeTextColor = UIColor.white

final class GridMessageItemSection: GridSection {
    let height: CGFloat = 36.0
    
    fileprivate let theme: PresentationTheme
    private let strings: PresentationStrings
    private let fontSize: PresentationFontSize
    
    private let roundedTimestamp: Int32
    private let month: Int32
    private let year: Int32
    
    var hashValue: Int {
        return self.roundedTimestamp.hashValue
    }
    
    init(timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        
        var now = time_t(timestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        self.roundedTimestamp = timeinfoNow.tm_year * 100 + timeinfoNow.tm_mon
        self.month = timeinfoNow.tm_mon
        self.year = timeinfoNow.tm_year
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? GridMessageItemSection {
            return self.roundedTimestamp == to.roundedTimestamp && theme === to.theme
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return GridMessageItemSectionNode(theme: self.theme, strings: self.strings, fontSize: self.fontSize, roundedTimestamp: self.roundedTimestamp, month: self.month, year: self.year)
    }
}

final class GridMessageItemSectionNode: ASDisplayNode {
    var theme: PresentationTheme
    var strings: PresentationStrings
    var fontSize: PresentationFontSize
    let titleNode: ASTextNode
    
    init(theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, roundedTimestamp: Int32, month: Int32, year: Int32) {
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.backgroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.9)
        
        let sectionTitleFont = Font.regular(floor(fontSize.baseDisplaySize * 14.0 / 17.0))
        
        let dateText = stringForMonth(strings: strings, month: month, ofYear: year)
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: dateText, font: sectionTitleFont, textColor: theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: floor((bounds.size.height - titleSize.height) / 2.0)), size: titleSize)
    }
}

final class GridMessageItem: GridItem {
    fileprivate let theme: PresentationTheme
    private let strings: PresentationStrings
    private let context: AccountContext
    fileprivate let message: Message
    private let controllerInteraction: ChatControllerInteraction
    let section: GridSection?
    
    init(theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, context: AccountContext, message: Message, controllerInteraction: ChatControllerInteraction) {
        self.theme = theme
        self.strings = strings
        self.context = context
        self.message = message
        self.controllerInteraction = controllerInteraction
        self.section = GridMessageItemSection(timestamp: message.timestamp, theme: theme, strings: strings, fontSize: fontSize)
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = GridMessageItemNode()
        if let media = mediaForMessage(self.message) {
            node.setup(context: self.context, item: self, media: media, messageId: self.message.id, controllerInteraction: self.controllerInteraction, synchronousLoad: synchronousLoad)
        }
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? GridMessageItemNode else {
            assertionFailure()
            return
        }
        if let media = mediaForMessage(self.message) {
            node.setup(context: self.context, item: self, media: media, messageId: self.message.id, controllerInteraction: self.controllerInteraction, synchronousLoad: false)
        }
    }
}

final class GridMessageItemNode: GridItemNode {
    private var currentState: (AccountContext, Media, CGSize)?
    private let containerNode: ContextControllerSourceNode
    private let imageNode: TransformImageNode
    private(set) var messageId: MessageId?
    private var item: GridMessageItem?
    private var controllerInteraction: ChatControllerInteraction?
    private var statusNode: RadialStatusNode
    private let mediaBadgeNode: ChatMessageInteractiveMediaBadge

    private var selectionNode: GridMessageSelectionNode?
    
    private let fetchStatusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var resourceStatus: MediaResourceStatus?
    
    override init() {
        self.containerNode = ContextControllerSourceNode()
        self.imageNode = TransformImageNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        let progressDiameter: CGFloat = 40.0
        self.statusNode.frame = CGRect(x: 0.0, y: 0.0, width: progressDiameter, height: progressDiameter)
        self.statusNode.isUserInteractionEnabled = false
        
        self.mediaBadgeNode = ChatMessageInteractiveMediaBadge()
        self.mediaBadgeNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 50.0, height: 50.0))
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.mediaBadgeNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let controllerInteraction = strongSelf.controllerInteraction else {
                gesture.cancel()
                return
            }
            controllerInteraction.openMessageContextActions(item.message, strongSelf.containerNode, strongSelf.containerNode.bounds, gesture)
        }
    }
    
    deinit {
        self.fetchStatusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.mediaBadgeNode.pressed = { [weak self] in
            self?.progressPressed()
        }
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.imageNode.view.addGestureRecognizer(recognizer)
    }
    
    func setup(context: AccountContext, item: GridMessageItem, media: Media, messageId: MessageId, controllerInteraction: ChatControllerInteraction, synchronousLoad: Bool) {
        self.item = item
        
        if self.currentState == nil || self.currentState!.0 !== context || !self.currentState!.1.isEqual(to: media) {
            var mediaDimensions: CGSize?
            if let image = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions {
                mediaDimensions = largestSize.cgSize
               
                self.imageNode.setSignal(mediaGridMessagePhoto(account: context.account, photoReference: .message(message: MessageReference(item.message), media: image), synchronousLoad: synchronousLoad), attemptSynchronously: synchronousLoad, dispatchOnDisplayLink: true)
                
                self.fetchStatusDisposable.set(nil)
                self.statusNode.transitionToState(.none, completion: { [weak self] in
                    self?.statusNode.isHidden = true
                })
                self.mediaBadgeNode.isHidden = true
                self.resourceStatus = nil
            } else if let file = media as? TelegramMediaFile, file.isVideo {
                mediaDimensions = file.dimensions?.cgSize
                self.imageNode.setSignal(mediaGridMessageVideo(postbox: context.account.postbox, videoReference: .message(message: MessageReference(item.message), media: file), synchronousLoad: synchronousLoad, autoFetchFullSizeThumbnail: true), attemptSynchronously: synchronousLoad)
                
                self.mediaBadgeNode.isHidden = false
                
                self.resourceStatus = nil
                self.fetchStatusDisposable.set((messageMediaFileStatus(context: context, messageId: messageId, file: file) |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self, let item = strongSelf.item {
                        strongSelf.resourceStatus = status
                        
                        let isStreamable = isMediaStreamable(message: item.message, media: file)
                        
                        let statusState: RadialStatusNodeState
                        if isStreamable {
                            statusState = .none
                        } else {
                            switch status {
                                case let .Fetching(_, progress):
                                    let adjustedProgress = max(progress, 0.027)
                                    statusState = .progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true, animateRotation: true)
                                case .Local:
                                    statusState = .none
                                case .Remote, .Paused:
                                    statusState = .download(.white)
                            }
                        }
                        
                        switch statusState {
                            case .none:
                                 break
                            default:
                                strongSelf.statusNode.isHidden = false
                        }
                        
                        strongSelf.statusNode.transitionToState(statusState, animated: true, completion: {
                            if let strongSelf = self {
                                if case .none = statusState {
                                    strongSelf.statusNode.isHidden = true
                                }
                            }
                        })
                        
                        if let duration = file.duration {
                            let durationString = stringForDuration(duration)
                            
                            var badgeContent: ChatMessageInteractiveMediaBadgeContent?
                            var mediaDownloadState: ChatMessageInteractiveMediaDownloadState?
                            
                            if isStreamable {
                                switch status {
                                    case let .Fetching(_, progress):
                                        let progressString = String(format: "%d%%", Int(progress * 100.0))
                                        badgeContent = .text(inset: 12.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: progressString))
                                        mediaDownloadState = .compactFetching(progress: 0.0)
                                    case .Local:
                                        badgeContent = .text(inset: 0.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: durationString))
                                    case .Remote, .Paused:
                                        badgeContent = .text(inset: 12.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: durationString))
                                        mediaDownloadState = .compactRemote
                                }
                            } else {
                                badgeContent = .text(inset: 0.0, backgroundColor: mediaBadgeBackgroundColor, foregroundColor: mediaBadgeTextColor, text: NSAttributedString(string: durationString))
                            }
                            
                            strongSelf.mediaBadgeNode.update(theme: item.theme, content: badgeContent, mediaDownloadState: mediaDownloadState, alignment: .right, animated: false, badgeAnimated: false)
                        }
                    }
                }))
                if self.statusNode.supernode == nil {
                    self.imageNode.addSubnode(self.statusNode)
                }
            } else {
                self.mediaBadgeNode.isHidden = true
            }
            
            if let mediaDimensions = mediaDimensions {
                self.currentState = (context, media, mediaDimensions)
                self.setNeedsLayout()
            }
        }
        
        self.messageId = messageId
        self.controllerInteraction = controllerInteraction
        
        self.updateSelectionState(animated: false)
        self.updateHiddenMedia()
    }
    
    override func layout() {
        super.layout()
        
        let imageFrame = self.bounds
        
        self.containerNode.frame = imageFrame
        
        self.imageNode.frame = imageFrame
        
        if let item = self.item, let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor))()
        }
        
        self.selectionNode?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        let progressDiameter: CGFloat = 40.0
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - progressDiameter) / 2.0), y: floor((imageFrame.size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
        
        self.mediaBadgeNode.frame = CGRect(origin: CGPoint(x: imageFrame.width - 3.0, y: imageFrame.height - 18.0 - 3.0), size: CGSize(width: 50.0, height: 50.0))
    }
    
    func updateSelectionState(animated: Bool) {
        if let messageId = self.messageId, let controllerInteraction = self.controllerInteraction {
            if let selectionState = controllerInteraction.selectionState {
                guard let item = self.item else {
                    return
                }
                
                let selected = selectionState.selectedIds.contains(messageId)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let selectionNode = GridMessageSelectionNode(theme: item.theme, toggle: { [weak self] value in
                        if let strongSelf = self, let messageId = strongSelf.messageId {
                            strongSelf.controllerInteraction?.toggleMessagesSelection([messageId], value)
                        }
                    })
                    
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    self.containerNode.addSubnode(selectionNode)
                    self.selectionNode = selectionNode
                    selectionNode.updateSelected(selected, animated: false)
                    if animated {
                        selectionNode.animateIn()
                    }
                }
            } else {
                if let selectionNode = self.selectionNode {
                    self.selectionNode = nil
                    if animated {
                        selectionNode.animateOut { [weak selectionNode] in
                            selectionNode?.removeFromSupernode()
                        }
                    } else {
                        selectionNode.removeFromSupernode()
                    }
                }
            }
        }
    }
    
    func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.messageId == id {
            let imageNode = self.imageNode
            return (self.imageNode, self.imageNode.bounds, { [weak self, weak imageNode] in
                var statusNodeHidden = false
                var accessoryHidden = false
                if let strongSelf = self {
                    statusNodeHidden = strongSelf.statusNode.isHidden
                    accessoryHidden = strongSelf.mediaBadgeNode.isHidden
                    strongSelf.statusNode.isHidden = true
                    strongSelf.mediaBadgeNode.isHidden = true
                }
                let view = imageNode?.view.snapshotContentTree(unhide: true)
                if let strongSelf = self {
                    strongSelf.statusNode.isHidden = statusNodeHidden
                    strongSelf.mediaBadgeNode.isHidden = accessoryHidden
                }
                return (view, nil)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia() {
        if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, controllerInteraction.hiddenMedia[messageId] != nil {
            self.imageNode.isHidden = true
            self.mediaBadgeNode.alpha = 0.0
            self.statusNode.alpha = 0.0
        } else {
            self.imageNode.isHidden = false
            if self.statusNode.alpha < 1.0 {
                self.statusNode.alpha = 1.0
                self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            if self.mediaBadgeNode.alpha < 1.0 {
                self.mediaBadgeNode.alpha = 1.0
                self.mediaBadgeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
    }
    
    private func progressPressed() {
        guard let controllerInteraction = self.controllerInteraction, let message = self.item?.message else {
            return
        }
        
        if let (context, media, _) = self.currentState, let resourceStatus = self.resourceStatus, let file = media as? TelegramMediaFile {
            switch resourceStatus {
                case .Fetching:
                    messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, file: file)
                case .Local:
                    let _ = controllerInteraction.openMessage(message, .default)
                case .Remote, .Paused:
                    self.fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, message: message, file: file, userInitiated: true).start())
            }
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        guard let controllerInteraction = self.controllerInteraction, let message = self.item?.message else {
            return
        }
        
        switch recognizer.state {
            case .ended:
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let (_, media, _) = self.currentState, let file = media as? TelegramMediaFile {
                                if isMediaStreamable(message: message, media: file) {
                                    let _ = controllerInteraction.openMessage(message, .default)
                                } else {
                                    self.progressPressed()
                                }
                            } else {
                                let _ = controllerInteraction.openMessage(message, .default)
                            }
                        case .longTap:
                            break
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
}
