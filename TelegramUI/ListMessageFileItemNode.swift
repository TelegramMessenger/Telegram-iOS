import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let extensionImageCache = Atomic<[UInt32: UIImage]>(value: [:])

private let redColors: (UInt32, UInt32) = (0xf0625d, 0xde524e)
private let greenColors: (UInt32, UInt32) = (0x72ce76, 0x54b658)
private let blueColors: (UInt32, UInt32) = (0x60b0e8, 0x4597d1)
private let yellowColors: (UInt32, UInt32) = (0xf5c565, 0xe5a64e)

private let extensionColorsMap: [String: (UInt32, UInt32)] = [
    "ppt": redColors,
    "pptx": redColors,
    "pdf": redColors,
    "key": redColors,
    
    "xls": greenColors,
    "xlsx": greenColors,
    "csv": greenColors,
    
    "zip": yellowColors,
    "rar": yellowColors,
    "gzip": yellowColors,
    "ai": yellowColors
]

private func generateExtensionImage(colors: (UInt32, UInt32)) -> UIImage? {
    return generateImage(CGSize(width: 42.0, height: 42.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 1.0, y: -size.height / 2.0 + 1.0)
        
        let radius: CGFloat = 2.0
        let cornerSize: CGFloat = 10.0
        let size = CGSize(width: 42.0, height: 42.0)
        
        context.setFillColor(UIColor(colors.0).cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: 0.0, y: radius))
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: radius, y: 0.0), radius: radius)
        }
        context.addLine(to: CGPoint(x: size.width - cornerSize, y: 0.0))
        context.addLine(to: CGPoint(x: size.width - cornerSize + cornerSize / 4.0, y: cornerSize - cornerSize / 4.0))
        context.addLine(to: CGPoint(x: size.width, y: cornerSize))
        context.addLine(to: CGPoint(x: size.width, y: size.height - radius))
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: size.width, y: size.height), tangent2End: CGPoint(x: size.width - radius, y: size.height), radius: radius)
        }
        context.addLine(to: CGPoint(x: radius, y: size.height))
        
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: 0.0, y: size.height), tangent2End: CGPoint(x: 0.0, y: size.height - radius), radius: radius)
        }
        context.closePath()
        context.fillPath()
        
        context.setFillColor(UIColor(colors.1).cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: size.width - cornerSize, y: 0.0))
        context.addLine(to: CGPoint(x: size.width, y: cornerSize))
        context.addLine(to: CGPoint(x: size.width - cornerSize + radius, y: cornerSize))
        
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: size.width - cornerSize, y: cornerSize), tangent2End: CGPoint(x: size.width - cornerSize, y: cornerSize - radius), radius: radius)
        }
        
        context.closePath()
        context.fillPath()
    })
}

private func extensionImage(fileExtension: String?) -> UIImage? {
    let colors: (UInt32, UInt32)
    if let fileExtension = fileExtension {
        if let extensionColors = extensionColorsMap[fileExtension] {
            colors = extensionColors
        } else {
            colors = blueColors
        }
    } else {
        colors = blueColors
    }
    
    if let cachedImage = (extensionImageCache.with { dict in
        return dict[colors.0]
    }) {
        return cachedImage
    } else if let image = generateExtensionImage(colors: colors) {
        let _ = extensionImageCache.modify { dict in
            var dict = dict
            dict[colors.0] = image
            return dict
        }
        return image
    } else {
        return nil
    }
}

private let titleFont = Font.medium(16.0)
private let descriptionFont = Font.regular(13.0)
private let extensionFont = Font.medium(13.0)

private let downloadFileStartIcon = generateTintedImage(image: UIImage(bundleImageName: "List Menu/ListDownloadStartIcon"), color: UIColor(0x007ee5))
private let downloadFilePauseIcon = generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    
    context.setFillColor(UIColor(0x007ee5).cgColor)

    context.fill(CGRect(x: 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
    context.fill(CGRect(x: 2.0 + 2.0 + 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
})

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

final class ListMessageFileItemNode: ListMessageNode {
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    
    private let extensionIconNode: ASImageNode
    private let extensionIconText: TextNode
    private let iconImageNode: TransformImageNode
    
    private var currentIconImageRepresentation: TelegramMediaImageRepresentation?
    private var currentMedia: Media?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var resourceStatus: FileMediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    private var downloadStatusIconNode: ASImageNode
    private var linearProgressNode: ASDisplayNode
    
    private let progressNode: RadialProgressNode
    
    private var account: Account?
    private (set) var message: Message?
    
    public required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(0xc8c7cc)
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isLayerBacked = true
        
        self.extensionIconNode = ASImageNode()
        self.extensionIconNode.isLayerBacked = true
        self.extensionIconNode.displaysAsynchronously = false
        self.extensionIconNode.displayWithoutProcessing = true
        
        self.extensionIconText = TextNode()
        self.extensionIconText.isLayerBacked = true
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.displaysAsynchronously = false
        
        self.downloadStatusIconNode = ASImageNode()
        self.downloadStatusIconNode.isLayerBacked = true
        self.downloadStatusIconNode.displaysAsynchronously = false
        self.downloadStatusIconNode.displayWithoutProcessing = true
        
        self.progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: UIColor(0x007ee5), foregroundColor: UIColor.white, icon: nil))
        self.progressNode.isLayerBacked = true
        
        self.linearProgressNode = ASDisplayNode()
        self.linearProgressNode.backgroundColor = UIColor(0x007ee5)
        self.linearProgressNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.extensionIconNode)
        self.addSubnode(self.extensionIconText)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setupItem(_ item: ListMessageItem) {
        self.item = item
    }
    
    override public func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ListMessageItem {
            let doLayout = self.asyncLayout()
            let merged = (top: false, bottom: false, dateAtBottom: false)//item.mergedWithItems(top: previousItem, bottom: nextItem)
            let (layout, apply) = doLayout(item, width, merged.top, merged.bottom, merged.dateAtBottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.transitionOffset = self.bounds.size.height * 1.6
        self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
        //self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height * 1.4, to: 0.0, duration: duration)
    }
    
    override func asyncLayout() -> (_ item: ListMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let titleNodeMakeLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionNodeMakeLayout = TextNode.asyncLayout(self.descriptionNode)
        let extensionIconTextMakeLayout = TextNode.asyncLayout(self.extensionIconText)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        
        let currentMedia = self.currentMedia
        let currentMessage = self.message
        let currentIconImageRepresentation = self.currentIconImageRepresentation
        
        return { [weak self] item, width, mergedTop, _, _ in
            let leftInset: CGFloat = 65.0
            
            var extensionIconImage: UIImage?
            var titleText: NSAttributedString?
            var descriptionText: NSAttributedString?
            var extensionText: NSAttributedString?
            
            var iconImageRepresentation: TelegramMediaImageRepresentation?
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedStatusSignal: Signal<FileMediaResourceStatus, NoError>?
            var updatedFetchControls: FetchControls?
            
            var isAudio = false
            
            let message = item.message
            
            var selectedMedia: TelegramMediaFile?
            for media in message.media {
                if let file = media as? TelegramMediaFile {
                    selectedMedia = file
                    
                    for attribute in file.attributes {
                        if case let .Audio(voice, duration, title, performer, waveform) = attribute {
                            isAudio = true
                            
                            titleText = NSAttributedString(string: title ?? "Unknown Track", font: titleFont, textColor: UIColor.black)
                            
                            let descriptionString: String
                            if let performer = performer {
                                descriptionString = performer
                            } else if let size = file.size {
                                descriptionString = dataSizeString(size)
                            } else {
                                descriptionString = ""
                            }
                            
                            descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: UIColor(0xa8a8a8))
                        }
                    }
                    
                    if !isAudio {
                        let fileName: String = file.fileName ?? ""
                        titleText = NSAttributedString(string: fileName, font: titleFont, textColor: UIColor.black)
                        
                        var fileExtension: String?
                        if let range = fileName.range(of: ".", options: [.backwards]) {
                            fileExtension = fileName.substring(from: range.upperBound).lowercased()
                        }
                        extensionIconImage = extensionImage(fileExtension: fileExtension)
                        if let fileExtension = fileExtension {
                            extensionText = NSAttributedString(string: fileExtension, font: extensionFont, textColor: UIColor.white)
                        }
                        
                        iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations)
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM d, yyyy 'at' h a"
                        
                        let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: Double(item.message.timestamp)))
                        
                        let descriptionString: String
                        if let size = file.size {
                            descriptionString = "\(dataSizeString(size)) • \(dateString)"
                        } else {
                            descriptionString = "\(dateString)"
                        }
                    
                        descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: UIColor(0xa8a8a8))
                    }
                    
                    break
                }
            }
            
            var mediaUpdated = false
            if let currentMedia = currentMedia {
                if let selectedMedia = selectedMedia {
                    mediaUpdated = !selectedMedia.isEqual(currentMedia)
                } else {
                    mediaUpdated = true
                }
            } else {
                mediaUpdated = selectedMedia != nil
            }
            
            var statusUpdated = mediaUpdated
            if currentMessage?.id != message.id || currentMessage?.flags != message.flags {
                statusUpdated = true
            }
            
            if let selectedMedia = selectedMedia {
                if mediaUpdated {
                    let account = item.account
                    updatedFetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(chatMessageFileInteractiveFetched(account: account, file: selectedMedia).start())
                        }
                    }, cancel: {
                        chatMessageFileCancelInteractiveFetch(account: account, file: selectedMedia)
                    })
                }
                
                if statusUpdated {
                    updatedStatusSignal = fileMediaResourceStatus(account: item.account, file: selectedMedia, message: message)
                    
                    if isAudio {
                        if let currentUpdatedStatusSignal = updatedStatusSignal {
                            updatedStatusSignal = currentUpdatedStatusSignal |> map { status in
                                switch status {
                                case .fetchStatus:
                                    return .fetchStatus(.Local)
                                case .playbackStatus:
                                    return status
                                }
                            }
                        }
                    }
                }
            }
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(titleText, nil, 1, .middle, CGSize(width: width - leftInset - 8.0, height: CGFloat.infinity), nil)
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(descriptionText, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - 12.0, height: CGFloat.infinity), nil)
            
            let (extensionTextLayout, extensionTextApply) = extensionIconTextMakeLayout(extensionText, nil, 1, .end, CGSize(width: 38.0, height: CGFloat.infinity), nil)
            
            var iconImageApply: (() -> Void)?
            if let iconImageRepresentation = iconImageRepresentation {
                let iconSize = CGSize(width: 42.0, height: 42.0)
                let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageRepresentation.dimensions.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets())
                iconImageApply = iconImageLayout(arguments)
            }
            
            if currentIconImageRepresentation != iconImageRepresentation {
                if let iconImageRepresentation = iconImageRepresentation {
                    let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation])
                    updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: tmpImage)
                } else {
                    updateIconImageSignal = .complete()
                }
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: isAudio ? 54.0 : 52.0), insets: UIEdgeInsets(top: mergedTop ? 0.0 : 2.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.currentMedia = selectedMedia
                    strongSelf.message = message
                    strongSelf.account = item.account
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel - nodeLayout.insets.top), size: CGSize(width: width, height: nodeLayout.size.height + UIScreenPixel))
                    
                    if isAudio {
                        if strongSelf.progressNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.progressNode)
                            strongSelf.progressNode.state = .Play
                        }
                        strongSelf.progressNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 6.0), size: CGSize(width: 42.0, height: 42.0))
                    } else if strongSelf.progressNode.supernode != nil {
                        strongSelf.progressNode.removeFromSupernode()
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 9.0), size: titleNodeLayout.size)
                    let _ = titleNodeApply()
                    
                    var descriptionOffset: CGFloat = 0.0
                    if let resourceStatus = strongSelf.resourceStatus {
                        switch resourceStatus {
                            case .playbackStatus:
                                break
                            case let .fetchStatus(fetchStatus):
                                switch fetchStatus {
                                    case .Remote, .Fetching:
                                        descriptionOffset = 14.0
                                    case .Local:
                                        break
                                }
                        }
                    }
                    
                    strongSelf.descriptionNode.frame = CGRect(origin: CGPoint(x: leftInset + descriptionOffset, y: 29.0), size: descriptionNodeLayout.size)
                    let _ = descriptionNodeApply()
                    
                    let iconFrame = CGRect(origin: CGPoint(x: 9.0, y: 5.0), size: CGSize(width: 42.0, height: 42.0))
                    strongSelf.extensionIconNode.frame = iconFrame
                    strongSelf.extensionIconNode.image = extensionIconImage
                    strongSelf.extensionIconText.frame = CGRect(origin: CGPoint(x: 9.0 + floor((42.0 - extensionTextLayout.size.width) / 2.0), y: 5.0 + floor((42.0 - extensionTextLayout.size.height) / 2.0)), size: extensionTextLayout.size)
                    
                    let _ = extensionTextApply()
                    
                    strongSelf.currentIconImageRepresentation = iconImageRepresentation
                    
                    if let iconImageApply = iconImageApply {
                        if let updateImageSignal = updateIconImageSignal {
                            strongSelf.iconImageNode.setSignal(account: item.account, signal: updateImageSignal)
                        }
                        
                        strongSelf.iconImageNode.frame = iconFrame
                        if strongSelf.iconImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconImageNode)
                        }
                        
                        iconImageApply()
                        
                        if strongSelf.extensionIconNode.supernode != nil {
                            strongSelf.extensionIconNode.removeFromSupernode()
                        }
                        if strongSelf.extensionIconText.supernode != nil {
                            strongSelf.extensionIconText.removeFromSupernode()
                        }
                    } else if strongSelf.iconImageNode.supernode != nil {
                        strongSelf.iconImageNode.removeFromSupernode()
                        
                        if strongSelf.extensionIconNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.extensionIconNode)
                        }
                        if strongSelf.extensionIconText.supernode == nil {
                            strongSelf.addSubnode(strongSelf.extensionIconText)
                        }
                    }
                    
                    if let updatedStatusSignal = updatedStatusSignal {
                        strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                            displayLinkDispatcher.dispatch {
                                if let strongSelf = strongSelf {
                                    strongSelf.resourceStatus = status
                                    
                                    if !isAudio {
                                        strongSelf.updateProgressFrame(size: strongSelf.bounds.size)
                                    } else {
                                        switch status {
                                            case let .fetchStatus(fetchStatus):
                                                switch fetchStatus {
                                                    case let .Fetching(progress):
                                                        strongSelf.progressNode.state = .Fetching(progress: progress)
                                                    case .Local:
                                                        if isAudio {
                                                            strongSelf.progressNode.state = .Play
                                                        } else {
                                                            strongSelf.progressNode.state = .Icon
                                                        }
                                                    case .Remote:
                                                        if isAudio {
                                                            strongSelf.progressNode.state = .Play
                                                        } else {
                                                            strongSelf.progressNode.state = .Remote
                                                        }
                                                }
                                            case let .playbackStatus(playbackStatus):
                                                switch playbackStatus {
                                                    case .playing:
                                                        strongSelf.progressNode.state = .Pause
                                                    case .paused:
                                                        strongSelf.progressNode.state = .Play
                                                }
                                        }
                                    }
                                }
                            }
                        }))
                    }
                    
                    strongSelf.updateProgressFrame(size: CGSize(width: width, height: 52.0))
                    strongSelf.downloadStatusIconNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 32.0), size: CGSize(width: 11.0, height: 11.0))
                    
                    if let updatedFetchControls = updatedFetchControls {
                        let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                    }
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        if let item = self.item, item.message.id == id, self.iconImageNode.supernode != nil {
            return self.iconImageNode
        }
        return nil
    }
    
    override func updateHiddenMedia() {
        if let controllerInteraction = self.controllerInteraction, let item = self.item, controllerInteraction.hiddenMedia[item.message.id] != nil {
            self.iconImageNode.isHidden = true
        } else {
            self.iconImageNode.isHidden = false
        }
    }
    
    override func updateSelectionState(animated: Bool) {
    }
    
    private func updateProgressFrame(size: CGSize) {
        var descriptionOffset: CGFloat = 0.0
        
        if let resourceStatus = self.resourceStatus {
            var maybeFetchStatus: MediaResourceStatus = .Local
            switch resourceStatus {
                case .playbackStatus:
                    break
                case let .fetchStatus(fetchStatus):
                    maybeFetchStatus = fetchStatus
                    switch fetchStatus {
                        case .Remote, .Fetching:
                            descriptionOffset = 14.0
                        case .Local:
                            break
                    }
            }
            
            switch maybeFetchStatus {
                case let .Fetching(progress):
                    let progressFrame = CGRect(x: 65.0, y: size.height - 2.0, width: floor((size.width - 65.0) * CGFloat(progress)), height: 2.0)
                    if self.linearProgressNode.supernode == nil {
                        self.addSubnode(self.linearProgressNode)
                    }
                    if !self.linearProgressNode.frame.equalTo(progressFrame) {
                        self.linearProgressNode.frame = progressFrame
                    }
                    if self.downloadStatusIconNode.supernode == nil {
                        self.addSubnode(self.downloadStatusIconNode)
                    }
                    self.downloadStatusIconNode.image = downloadFilePauseIcon
                case .Local:
                    if self.linearProgressNode.supernode != nil {
                        self.linearProgressNode.removeFromSupernode()
                    }
                    if self.downloadStatusIconNode.supernode != nil {
                        self.downloadStatusIconNode.removeFromSupernode()
                    }
                    self.downloadStatusIconNode.image = nil
                case .Remote:
                    if self.linearProgressNode.supernode != nil {
                        self.linearProgressNode.removeFromSupernode()
                    }
                    if self.downloadStatusIconNode.supernode == nil {
                        self.addSubnode(self.downloadStatusIconNode)
                    }
                    self.downloadStatusIconNode.image = downloadFileStartIcon
                }
        } else {
            if self.linearProgressNode.supernode != nil {
                self.linearProgressNode.removeFromSupernode()
            }
            if self.downloadStatusIconNode.supernode != nil {
                self.downloadStatusIconNode.removeFromSupernode()
            }
        }
        
        var descriptionFrame = self.descriptionNode.frame
        if !descriptionFrame.origin.x.isEqual(to: 65.0 + descriptionOffset) {
            descriptionFrame.origin.x = 65.0 + descriptionOffset
            self.descriptionNode.frame = descriptionFrame
        }
    }
    
    func activateMedia() {
        self.progressPressed()
    }
    
    func progressPressed() {
        if let resourceStatus = self.resourceStatus {
            switch resourceStatus {
            case let .fetchStatus(fetchStatus):
                switch fetchStatus {
                case .Fetching:
                    if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                        cancel()
                    }
                case .Remote:
                    if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                        fetch()
                    }
                case .Local:
                    if let item = self.item, let controllerInteraction = self.controllerInteraction {
                        controllerInteraction.openMessage(item.message.id)
                    }
                }
            case .playbackStatus:
                if let account = self.account, let applicationContext = account.applicationContext as? TelegramApplicationContext {
                    applicationContext.mediaManager.playlistPlayerControl(.playback(.togglePlayPause))
                }
            }
        }
    }
}
