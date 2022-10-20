import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import RadialStatusNode
import PhotoResources
import StickerResources

final class VerticalListContextResultsChatInputPanelItem: ListViewItem {
    fileprivate let account: Account
    fileprivate let theme: PresentationTheme
    fileprivate let result: ChatContextResult
    fileprivate let resultSelected: (ChatContextResult, ASDisplayNode, CGRect) -> Bool
    
    let selectable: Bool = true
    
    public init(account: Account, theme: PresentationTheme, result: ChatContextResult, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) {
        self.account = account
        self.theme = theme
        self.result = result
        self.resultSelected = resultSelected
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = VerticalListContextResultsChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
            let (layout, apply) = nodeLayout(self, params, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? VerticalListContextResultsChatInputPanelItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

private let titleFont = Font.medium(16.0)
private let textFont = Font.regular(15.0)
private let iconFont = Font.medium(25.0)
private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(rgb: 0xdfdfdf))

final class VerticalListContextResultsChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 75.0
    
    private let iconTextBackgroundNode: ASImageNode
    private let iconTextNode: TextNode
    private let iconImageNode: TransformImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var statusDisposable = MetaDisposable()
    private let statusNode: RadialStatusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
    private var resourceStatus: MediaResourceStatus?

    private var currentIconImageResource: TelegramMediaResource?
    
    private var item: VerticalListContextResultsChatInputPanelItem?
    
    init() {
        self.titleNode = TextNode()
        self.textNode = TextNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.iconTextBackgroundNode = ASImageNode()
        self.iconTextBackgroundNode.isLayerBacked = true
        self.iconTextBackgroundNode.displaysAsynchronously = false
        self.iconTextBackgroundNode.displayWithoutProcessing = true
        
        self.iconTextNode = TextNode()
        self.iconTextNode.isUserInteractionEnabled = false
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.contentAnimations = [.subsequentUpdates]
        self.iconImageNode.isLayerBacked = !smartInvertColorsEnabled()
        self.iconImageNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.iconImageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.statusNode)
    }
    
    deinit {
        statusDisposable.dispose()
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? VerticalListContextResultsChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: VerticalListContextResultsChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let iconTextMakeLayout = TextNode.asyncLayout(self.iconTextNode)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        let currentIconImageResource = self.currentIconImageResource
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let leftInset: CGFloat = 80.0 + params.leftInset
            let rightInset: CGFloat = 10.0 + params.rightInset
            
            let applyIconTextBackgroundImage = iconTextBackgroundImage
            
            var titleString: NSAttributedString?
            var textString: NSAttributedString?
            var iconText: NSAttributedString?
            
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?

            if let title = item.result.title {
                titleString = NSAttributedString(string: title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
            }
            
            if let text = item.result.description {
                textString = NSAttributedString(string: text, font: textFont, textColor: item.theme.list.itemSecondaryTextColor)
            }
            
            var imageResource: TelegramMediaResource?
            var stickerFile: TelegramMediaFile?
            switch item.result {
                case let .externalReference(externalReference):
                    if let thumbnail = externalReference.thumbnail {
                        imageResource = thumbnail.resource
                    }
                    var selectedUrl: String?
                    if let url = externalReference.url {
                        selectedUrl = url
                    } else if let content = externalReference.content {
                        if let resource = content.resource as? HttpReferenceMediaResource {
                            selectedUrl = resource.url
                        } else if let resource = content.resource as? WebFileReferenceMediaResource {
                            selectedUrl = resource.url
                        }
                    }
                    if let selectedUrl = selectedUrl, let parsedUrl = URL(string: selectedUrl) {
                        if let host = parsedUrl.host, !host.isEmpty {
                            iconText = NSAttributedString(string: String(host[..<host.index(after: host.startIndex)].uppercased()), font: iconFont, textColor: UIColor.white)
                        }
                    }
                case let .internalReference(internalReference):
                    if let image = internalReference.image {
                        imageResource = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 200, height: 200))?.resource
                    } else if let file = internalReference.file {
                        if file.isSticker {
                            stickerFile = file
                            imageResource = file.resource
                        } else {
                            imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                        }
                    }
            }
            
            if iconText == nil {
                if let title = item.result.title, !title.isEmpty {
                    let titleText = String(title[..<title.index(after: title.startIndex)].uppercased())
                    iconText = NSAttributedString(string: titleText, font: iconFont, textColor: UIColor.white)
                }
            }
            
            var iconImageApply: (() -> Void)?
            if let imageResource = imageResource {
                let boundingSize = CGSize(width: 55.0, height: 55.0)
                let iconSize: CGSize
                if let stickerFile = stickerFile, let dimensions = stickerFile.dimensions {
                    iconSize = dimensions.cgSize.fitted(boundingSize)
                } else {
                    iconSize = boundingSize
                }
                let imageCorners = ImageCorners(topLeft: .Corner(2.0), topRight: .Corner(2.0), bottomLeft: .Corner(2.0), bottomRight: .Corner(2.0))
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
                iconImageApply = iconImageLayout(arguments)
                
                updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(imageResource)

            }
            
            var updatedIconImageResource = false
            if let currentIconImageResource = currentIconImageResource, let imageResource = imageResource {
                if !currentIconImageResource.isEqual(to: imageResource) {
                    updatedIconImageResource = true
                }
            } else if (currentIconImageResource != nil) != (imageResource != nil) {
                updatedIconImageResource = true
            }
            
            if updatedIconImageResource {
                if let imageResource = imageResource {
                    if let stickerFile = stickerFile {
                        updateIconImageSignal = chatMessageSticker(account: item.account, file: stickerFile, small: false, fetched: true)
                    } else {
                        let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 55, height: 55), resource: imageResource, progressiveSizes: [], immediateThumbnailData: nil)
                        let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, photoReference: .standalone(media: tmpImage))
                    }
                } else {
                    updateIconImageSignal = .complete()
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (iconTextLayout, iconTextApply) = iconTextMakeLayout(TextNodeLayoutArguments(attributedString: iconText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var titleFrame: CGRect?
            if let _ = titleString {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 9.0), size: titleLayout.size)
            }
            
            var textFrame: CGRect?
            if let _ = textString {
                var topOffset: CGFloat = 9.0
                if let titleFrame = titleFrame {
                    topOffset = titleFrame.maxY + 1.0
                }
                textFrame = CGRect(origin: CGPoint(x: leftInset, y: topOffset), size: textLayout.size)
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: VerticalListContextResultsChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.topSeparatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.backgroundColor = item.theme.list.plainBackgroundColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    
                    let _ = titleApply()
                    let _ = textApply()
                    
                    if let titleFrame = titleFrame {
                        strongSelf.titleNode.frame = titleFrame
                    }
                    if let textFrame = textFrame {
                        strongSelf.textNode.frame = textFrame
                    }
                    
                    let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + 12.0, y: 11.0), size: CGSize(width: 55.0, height: 55.0))
                    strongSelf.iconTextNode.frame = CGRect(origin: CGPoint(x: iconFrame.minX + floor((55.0 - iconTextLayout.size.width) / 2.0), y: iconFrame.minY + floor((55.0 - iconTextLayout.size.height) / 2.0) + 2.0), size: iconTextLayout.size)
                    
                    let _ = iconTextApply()
                    
                    strongSelf.currentIconImageResource = imageResource
                    
                    if let iconImageApply = iconImageApply {
                        if let updateImageSignal = updateIconImageSignal {
                            strongSelf.iconImageNode.setSignal(updateImageSignal)
                        }
                        
                        if strongSelf.iconImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconImageNode)
                        }
                        
                        strongSelf.iconImageNode.frame = iconFrame
                        
                        iconImageApply()
                        
                        if strongSelf.iconTextBackgroundNode.supernode != nil {
                            strongSelf.iconTextBackgroundNode.removeFromSupernode()
                        }
                        if strongSelf.iconTextNode.supernode != nil {
                            strongSelf.iconTextNode.removeFromSupernode()
                        }
                    } else if strongSelf.iconImageNode.supernode != nil {
                        strongSelf.iconImageNode.removeFromSupernode()
                        
                        if strongSelf.iconTextBackgroundNode.supernode == nil {
                            strongSelf.iconTextBackgroundNode.image = applyIconTextBackgroundImage
                            strongSelf.addSubnode(strongSelf.iconTextBackgroundNode)
                        }
                        strongSelf.iconTextBackgroundNode.frame = iconFrame
                        if strongSelf.iconTextNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconTextNode)
                        }
                    }
                    
                    strongSelf.topSeparatorNode.isHidden = mergedTop
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))
                    
                    let progressSize = CGSize(width: 24.0, height: 24.0)
                    let progressFrame = CGRect(origin: CGPoint(x: iconFrame.minX + floorToScreenPixels((iconFrame.width - progressSize.width) / 2.0), y: iconFrame.minY + floorToScreenPixels((iconFrame.height - progressSize.height) / 2.0)), size: progressSize)
                    
                    if let updatedStatusSignal = updatedStatusSignal {
                        strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                            displayLinkDispatcher.dispatch {
                                if let strongSelf = strongSelf {
                                    strongSelf.resourceStatus = status
                                    
                                    strongSelf.statusNode.frame = progressFrame
                                    
                                    let state: RadialStatusNodeState
                                    let statusForegroundColor: UIColor = .white
                                    
                                    switch status {
                                    case let .Fetching(_, progress):
                                        state = RadialStatusNodeState.progress(color: statusForegroundColor, lineWidth: nil, value: CGFloat(max(progress, 0.2)), cancelEnabled: false, animateRotation: true)
                                    case .Remote, .Paused:
                                        state = .download(statusForegroundColor)
                                    case .Local:
                                        state = .none
                                    }
                                    
                                    
                                    strongSelf.statusNode.transitionToState(state, completion: { })
                                }
                            }
                        }))
                    } else {
                        strongSelf.statusNode.transitionToState(.none, completion: { })
                    }
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
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
    
    override func selected() {
        guard let item = self.item else {
            return
        }
        let _ = item.resultSelected(item.result, self, self.bounds)
    }
}
