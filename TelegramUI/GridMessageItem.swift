import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit

private let videoAccessoryFont: UIFont = Font.regular(11)

private final class GridMessageVideoAccessoryNode : ASDisplayNode {
    
    private let textNode: ImmediateTextNode = ImmediateTextNode()

    override init() {
        super.init()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 1
        self.textNode.isUserInteractionEnabled = false
        self.textNode.textAlignment = .left
        self.textNode.lineSpacing = 0.1
        addSubnode(self.textNode)
        backgroundColor = UIColor(white: 0.0, alpha: 0.6)
    }
    
    var contentSize: CGSize {
        return CGSize(width: textSize.width + 10, height: 16)
    }
    private var textSize: CGSize = CGSize()
    
    func setup(_ duration: String) {
        textNode.attributedText = NSAttributedString(string: duration, font: videoAccessoryFont, textColor: .white, paragraphAlignment: nil)
        textSize = self.textNode.updateLayout(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
    }
    
    override func layout() {
        if let _ = self.textNode.attributedText {
            self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((frame.width - textSize.width) / 2.0), y: floorToScreenPixels((frame.height - textSize.height) / 2.0) + 0.5), size: textSize)
        }
    }

    
}

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

private let timezoneOffset: Int32 = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int32(timeinfoNow.tm_gmtoff)
}()

final class GridMessageItemSection: GridSection {
    let height: CGFloat = 36.0
    
    fileprivate let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let roundedTimestamp: Int32
    private let month: Int32
    private let year: Int32
    
    var hashValue: Int {
        return self.roundedTimestamp.hashValue
    }
    
    init(timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
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
        return GridMessageItemSectionNode(theme: self.theme, strings: self.strings, roundedTimestamp: self.roundedTimestamp, month: self.month, year: self.year)
    }
}

private let sectionTitleFont = Font.regular(14.0)

final class GridMessageItemSectionNode: ASDisplayNode {
    var theme: PresentationTheme
    var strings: PresentationStrings
    let titleNode: ASTextNode
    
    init(theme: PresentationTheme, strings: PresentationStrings, roundedTimestamp: Int32, month: Int32, year: Int32) {
        self.theme = theme
        self.strings = strings
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.backgroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.9)
        
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
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 8.0), size: titleSize)
    }
}

final class GridMessageItem: GridItem {
    fileprivate let theme: PresentationTheme
    private let strings: PresentationStrings
    private let account: Account
    fileprivate let message: Message
    private let controllerInteraction: ChatControllerInteraction
    let section: GridSection?
    
    init(theme: PresentationTheme, strings: PresentationStrings, account: Account, message: Message, controllerInteraction: ChatControllerInteraction) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.message = message
        self.controllerInteraction = controllerInteraction
        self.section = GridMessageItemSection(timestamp: message.timestamp, theme: theme, strings: strings)
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = GridMessageItemNode()
        if let media = mediaForMessage(self.message) {
            node.setup(account: self.account, item: self, media: media, messageId: self.message.id, controllerInteraction: self.controllerInteraction)
        }
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? GridMessageItemNode else {
            assertionFailure()
            return
        }
        if let media = mediaForMessage(self.message) {
            node.setup(account: self.account, item: self, media: media, messageId: self.message.id, controllerInteraction: self.controllerInteraction)
        }
    }
}

final class GridMessageItemNode: GridItemNode {
    private var currentState: (Account, Media, CGSize)?
    private let imageNode: TransformImageNode
    private(set) var messageId: MessageId?
    private var item: GridMessageItem?
    private var controllerInteraction: ChatControllerInteraction?
    private var statusNode: RadialStatusNode
    private let videoAccessoryNode = GridMessageVideoAccessoryNode()

    private var selectionNode: GridMessageSelectionNode?
    
    private let fetchStatusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var resourceStatus: MediaResourceStatus?
    
    override init() {
        self.imageNode = TransformImageNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
        self.statusNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.imageNode.addSubnode(videoAccessoryNode)
    }
    
    deinit {
        self.fetchStatusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.imageNode.view.addGestureRecognizer(recognizer)
    }
    
    func setup(account: Account, item: GridMessageItem, media: Media, messageId: MessageId, controllerInteraction: ChatControllerInteraction) {
        if self.currentState == nil || self.currentState!.0 !== account || !self.currentState!.1.isEqual(to: media) {
            var mediaDimensions: CGSize?
            if let image = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions {
                mediaDimensions = largestSize
               
                self.imageNode.setSignal(mediaGridMessagePhoto(account: account, photoReference: .message(message: MessageReference(item.message), media: image)), dispatchOnDisplayLink: true)
                
                self.fetchStatusDisposable.set(nil)
                self.statusNode.transitionToState(.none, completion: { [weak self] in
                    self?.statusNode.isHidden = true
                })
                videoAccessoryNode.isHidden = true
                self.resourceStatus = nil
            } else if let file = media as? TelegramMediaFile, file.isVideo {
                mediaDimensions = file.dimensions
                self.imageNode.setSignal(mediaGridMessageVideo(postbox: account.postbox, videoReference: .message(message: MessageReference(item.message), media: file)))
                
                if let duration = file.duration {
                    videoAccessoryNode.setup(stringForDuration(duration))
                    videoAccessoryNode.isHidden = false
                } else {
                    videoAccessoryNode.isHidden = true
                }
                
                
                self.resourceStatus = nil
                self.fetchStatusDisposable.set((messageMediaFileStatus(account: account, messageId: messageId, file: file) |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        strongSelf.resourceStatus = status
                        let statusState: RadialStatusNodeState
                        switch status {
                            case let .Fetching(isActive, progress):
                                var adjustedProgress = progress
                                if isActive {
                                    adjustedProgress = max(adjustedProgress, 0.027)
                                }
                                statusState = .progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true)
                            case .Local:
                                statusState = .play(.white)
                            case .Remote:
                                statusState = .download(.white)
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
                    }
                }))
                if self.statusNode.supernode == nil {
                    self.imageNode.addSubnode(self.statusNode)
                }
            } else {
                videoAccessoryNode.isHidden = true
            }
            
            if let mediaDimensions = mediaDimensions {
                self.currentState = (account, media, mediaDimensions)
                self.setNeedsLayout()
            }
        }
        
        self.messageId = messageId
        self.item = item
        self.controllerInteraction = controllerInteraction
        
        self.updateSelectionState(animated: false)
        self.updateHiddenMedia()
    }
    
    override func layout() {
        super.layout()
        
        let imageFrame = self.bounds.insetBy(dx: 1.0, dy: 1.0)
        self.imageNode.frame = imageFrame
        
        if let item = self.item, let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor))()
        }
        
        self.selectionNode?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        let progressDiameter: CGFloat = 40.0
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - progressDiameter) / 2.0), y: floor((imageFrame.size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
        
        videoAccessoryNode.frame = CGRect(origin: CGPoint(x: imageFrame.maxX - videoAccessoryNode.contentSize.width - 5, y: imageFrame.maxY - videoAccessoryNode.contentSize.height - 5), size: videoAccessoryNode.contentSize)
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
                    self.addSubnode(selectionNode)
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
    
    func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, () -> UIView?)? {
        if self.messageId == id {
            let imageNode = self.imageNode
            return (self.imageNode, { [weak imageNode] in
                return imageNode?.view.snapshotContentTree(unhide: true)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia() {
        if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, controllerInteraction.hiddenMedia[messageId] != nil {
            self.imageNode.isHidden = true
        } else {
            self.imageNode.isHidden = false
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
                            if let (account, media, _) = self.currentState {
                                if let file = media as? TelegramMediaFile {
                                    if let resourceStatus = self.resourceStatus {
                                        switch resourceStatus {
                                        case .Fetching:
                                            messageMediaFileCancelInteractiveFetch(account: account, messageId: message.id, file: file)
                                        case .Local:
                                            let _ = controllerInteraction.openMessage(message, .default)
                                        case .Remote:
                                            self.fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, message: message, file: file, userInitiated: true).start())
                                        }
                                    }
                                } else {
                                    let _ = controllerInteraction.openMessage(message, .default)
                                }
                            }
                        case .longTap:
                            controllerInteraction.openMessageContextMenu(message, self, self.bounds)
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
}
