import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit

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
    let height: CGFloat = 44.0
    
    private let roundedTimestamp: Int32
    private let month: Int32
    private let year: Int32
    
    var hashValue: Int {
        return self.roundedTimestamp.hashValue
    }
    
    init(timestamp: Int32) {
        var now = time_t(timestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        self.roundedTimestamp = timeinfoNow.tm_year * 100 + timeinfoNow.tm_mon
        self.month = timeinfoNow.tm_mon
        self.year = timeinfoNow.tm_year
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? GridMessageItemSection {
            return self.roundedTimestamp == to.roundedTimestamp
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return GridMessageItemSectionNode(roundedTimestamp: self.roundedTimestamp, month: self.month, year: self.year)
    }
}

private let sectionTitleFont = Font.regular(17.0)

final class GridMessageItemSectionNode: ASDisplayNode {
    let titleNode: ASTextNode
    
    init(roundedTimestamp: Int32, month: Int32, year: Int32) {
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        
        super.init()
        
        self.backgroundColor = UIColor(white: 1.0, alpha: 0.9)
        
        let dateText = stringForMonth(month, ofYear: year)
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: dateText, font: sectionTitleFont, textColor: .black)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 18.0), size: titleSize)
    }
}

final class GridMessageItem: GridItem {
    private let account: Account
    private let message: Message
    private let controllerInteraction: ChatControllerInteraction
    
    let section: GridSection?
    
    init(account: Account, message: Message, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.message = message
        self.controllerInteraction = controllerInteraction
        self.section = GridMessageItemSection(timestamp: message.timestamp)
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = GridMessageItemNode()
        if let media = mediaForMessage(self.message) {
            node.setup(account: self.account, media: media, messageId: self.message.id, controllerInteraction: self.controllerInteraction)
        }
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? GridMessageItemNode else {
            assertionFailure()
            return
        }
        if let media = mediaForMessage(self.message) {
            node.setup(account: self.account, media: media, messageId: self.message.id, controllerInteraction: self.controllerInteraction)
        }
    }
}

final class GridMessageItemNode: GridItemNode {
    private var currentState: (Account, Media, CGSize)?
    private let imageNode: TransformImageNode
    private var messageId: MessageId?
    private var controllerInteraction: ChatControllerInteraction?
    private var progressNode: RadialProgressNode
    
    private var selectionNode: GridMessageSelectionNode?
    
    private let fetchStatusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var resourceStatus: MediaResourceStatus?
    
    override init() {
        self.imageNode = TransformImageNode()
        self.progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: UIColor(white: 0.0, alpha: 0.6), foregroundColor: UIColor.white, icon: nil))
        self.progressNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.fetchStatusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, media: Media, messageId: MessageId, controllerInteraction: ChatControllerInteraction) {
        if self.currentState == nil || self.currentState!.0 !== account || !self.currentState!.1.isEqual(media) {
            var mediaDimensions: CGSize?
            if let image = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions {
                mediaDimensions = largestSize
                self.imageNode.setSignal(account: account, signal: mediaGridMessagePhoto(account: account, photo: image), dispatchOnDisplayLink: true)
                
                self.fetchStatusDisposable.set(nil)
                self.progressNode.removeFromSupernode()
                self.progressNode.isHidden = true
                self.resourceStatus = nil
            } else if let file = media as? TelegramMediaFile, file.isVideo {
                mediaDimensions = file.dimensions
                self.imageNode.setSignal(account: account, signal: mediaGridMessageVideo(account: account, video: file))
                
                self.resourceStatus = nil
                self.fetchStatusDisposable.set((account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        strongSelf.resourceStatus = status
                        switch status {
                            case let .Fetching(progress):
                                strongSelf.progressNode.state = .Fetching(progress: progress)
                                strongSelf.progressNode.isHidden = false
                            case .Local:
                                strongSelf.progressNode.state = .None
                                strongSelf.progressNode.isHidden = true
                            case .Remote:
                                strongSelf.progressNode.state = .Remote
                                strongSelf.progressNode.isHidden = false
                        }
                    }
                }))
                if self.progressNode.supernode == nil {
                    self.addSubnode(self.progressNode)
                }
            }
            
            if let mediaDimensions = mediaDimensions {
                self.currentState = (account, media, mediaDimensions)
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
        
        let imageFrame = self.bounds.insetBy(dx: 1.0, dy: 1.0)
        self.imageNode.frame = imageFrame
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets()))()
        }
        
        self.selectionNode?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        let progressDiameter: CGFloat = 40.0
        self.progressNode.frame = CGRect(origin: CGPoint(x: imageFrame.minX + floor((imageFrame.size.width - progressDiameter) / 2.0), y: imageFrame.minY + floor((imageFrame.size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
    }
    
    func updateSelectionState(animated: Bool) {
        if let messageId = self.messageId, let controllerInteraction = self.controllerInteraction {
            if let selectionState = controllerInteraction.selectionState {
                let selected = selectionState.selectedIds.contains(messageId)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let selectionNode = GridMessageSelectionNode(toggle: { [weak self] in
                        if let strongSelf = self, let messageId = strongSelf.messageId {
                            strongSelf.controllerInteraction?.toggleMessageSelection(messageId)
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
    
    func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        if self.messageId == id {
            return self.imageNode
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
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, case .ended = recognizer.state {
            if let (account, media, _) = self.currentState {
                if let file = media as? TelegramMediaFile {
                    if let resourceStatus = self.resourceStatus {
                        switch resourceStatus {
                            case .Fetching:
                                account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
                            case .Local:
                                controllerInteraction.openMessage(messageId)
                            case .Remote:
                                self.fetchDisposable.set(account.postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .file)).start())
                        }
                    }
                } else {
                    controllerInteraction.openMessage(messageId)
                }
            }
        }
    }
}
