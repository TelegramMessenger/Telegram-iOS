import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

final class VerticalListContextResultsChatInputPanelItem: ListViewItem {
    fileprivate let account: Account
    fileprivate let result: ChatContextResult
    private let resultSelected: (ChatContextResult) -> Void
    
    let selectable: Bool = true
    
    public init(account: Account, result: ChatContextResult, resultSelected: @escaping (ChatContextResult) -> Void) {
        self.account = account
        self.result = result
        self.resultSelected = resultSelected
    }
    
    public func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = VerticalListContextResultsChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
            let (layout, apply) = nodeLayout(self, width, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(.None) })
            })
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? VerticalListContextResultsChatInputPanelItemNode {
            Queue.mainQueue().async {
                let nodeLayout = node.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
                    let (layout, apply) = nodeLayout(self, width, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animation)
                        })
                    }
                }
            }
        } else {
            assertionFailure()
        }
    }
    
    func selected(listView: ListView) {
        self.resultSelected(self.result)
    }
}

private let titleFont = Font.medium(16.0)
private let textFont = Font.regular(15.0)
private let iconFont = Font.medium(25.0)
private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(0xdfdfdf))

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
    
    private var currentIconImageResource: TelegramMediaResource?
    
    init() {
        self.titleNode = TextNode()
        self.textNode = TextNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = UIColor(0xC9CDD1)
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(0xD6D6DA)
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.iconTextBackgroundNode = ASImageNode()
        self.iconTextBackgroundNode.isLayerBacked = true
        self.iconTextBackgroundNode.displaysAsynchronously = false
        self.iconTextBackgroundNode.displayWithoutProcessing = true
        
        self.iconTextNode = TextNode()
        self.iconTextNode.isLayerBacked = true
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.isLayerBacked = true
        self.iconImageNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.backgroundColor = .white
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.iconImageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    override public func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? VerticalListContextResultsChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, width, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: VerticalListContextResultsChatInputPanelItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let iconTextMakeLayout = TextNode.asyncLayout(self.iconTextNode)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        let currentIconImageResource = self.currentIconImageResource
        
        return { [weak self] item, width, mergedTop, mergedBottom in
            let leftInset: CGFloat = 80.0
            let rightInset: CGFloat = 10.0
            
            let applyIconTextBackgroundImage = iconTextBackgroundImage
            
            var titleString: NSAttributedString?
            var textString: NSAttributedString?
            var iconText: NSAttributedString?
            
            var iconImageRepresentation: TelegramMediaImageRepresentation?
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            if let title = item.result.title {
                titleString = NSAttributedString(string: title, font: titleFont, textColor: .black)
            }
            
            if let text = item.result.description {
                textString = NSAttributedString(string: text, font: textFont, textColor: UIColor(0x8e8e93))
            }
            
            var imageResource: TelegramMediaResource?
            switch item.result {
                case let .externalReference(_, _, title, _, url, thumbnailUrl, contentUrl, _, dimensions, _, _):
                    if let thumbnailUrl = thumbnailUrl {
                        imageResource = HttpReferenceMediaResource(url: thumbnailUrl, size: nil)
                    }
                    var selectedUrl: String?
                    if let url = url {
                        selectedUrl = url
                    } else if let contentUrl = contentUrl {
                        selectedUrl = contentUrl
                    }
                    if let selectedUrl = selectedUrl, let parsedUrl = URL(string: selectedUrl) {
                        if let host = parsedUrl.host, !host.isEmpty {
                            iconText = NSAttributedString(string: host.substring(to: host.index(after: host.startIndex)).uppercased(), font: iconFont, textColor: UIColor.white)
                        }
                    }
                case let .internalReference(_, _, title, _, image, file, _):
                    if let image = image {
                        imageResource = smallestImageRepresentation(image.representations)?.resource
                    } else if let file = file {
                        imageResource = smallestImageRepresentation(file.previewRepresentations)?.resource
                    }
            }
            
            if iconText == nil {
                if let title = item.result.title, !title.isEmpty {
                    let titleText = title.substring(to: title.index(after: title.startIndex)).uppercased()
                    iconText = NSAttributedString(string: titleText, font: iconFont, textColor: UIColor.white)
                }
            }
            
            var iconImageApply: (() -> Void)?
            if let imageResource = imageResource {
                let iconSize = CGSize(width: 55.0, height: 55.0)
                let imageCorners = ImageCorners(topLeft: .Corner(2.0), topRight: .Corner(2.0), bottomLeft: .Corner(2.0), bottomRight: .Corner(2.0))
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets())
                iconImageApply = iconImageLayout(arguments)
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
                    let tmpRepresentation = TelegramMediaImageRepresentation(dimensions: CGSize(width: 55.0, height: 55.0), resource: imageResource)
                    let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [tmpRepresentation])
                    updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: tmpImage)
                } else {
                    updateIconImageSignal = .complete()
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(titleString, nil, 1, .end, CGSize(width: width - leftInset - rightInset, height: 100.0), .natural, nil)
            
            let (textLayout, textApply) = makeTextLayout(textString, nil, 2, .end, CGSize(width: width - leftInset - rightInset, height: 100.0), .natural, nil)
            
            let (iconTextLayout, iconTextApply) = iconTextMakeLayout(iconText, nil, 1, .end, CGSize(width: 38.0, height: CGFloat.infinity), .natural, nil)
            
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
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: VerticalListContextResultsChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    titleApply()
                    textApply()
                    
                    if let titleFrame = titleFrame {
                        strongSelf.titleNode.frame = titleFrame
                    }
                    if let textFrame = textFrame {
                        strongSelf.textNode.frame = textFrame
                    }
                    
                    let iconFrame = CGRect(origin: CGPoint(x: 12.0, y: 11.0), size: CGSize(width: 55.0, height: 55.0))
                    strongSelf.iconTextNode.frame = CGRect(origin: CGPoint(x: iconFrame.minX + floor((55.0 - iconTextLayout.size.width) / 2.0), y: iconFrame.minY + floor((55.0 - iconTextLayout.size.height) / 2.0) + 2.0), size: iconTextLayout.size)
                    
                    let _ = iconTextApply()
                    
                    strongSelf.currentIconImageResource = imageResource
                    
                    if let iconImageApply = iconImageApply {
                        if let updateImageSignal = updateIconImageSignal {
                            strongSelf.iconImageNode.setSignal(account: item.account, signal: updateImageSignal)
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
                    
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: nodeLayout.size.height + UIScreenPixel))
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
}
