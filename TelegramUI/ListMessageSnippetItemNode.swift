import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let titleFont = Font.medium(16.0)
private let descriptionFont = Font.regular(14.0)
private let iconFont = Font.medium(22.0)

private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(rgb: 0xdfdfdf))

final class ListMessageSnippetItemNode: ListMessageNode {
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    
    private let iconTextBackgroundNode: ASImageNode
    private let iconTextNode: TextNode
    private let iconImageNode: TransformImageNode
    
    private var currentIconImageRepresentation: TelegramMediaImageRepresentation?
    private var currentMedia: Media?
    
    private var appliedItem: ListMessageItem?
    
    public required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isLayerBacked = true
        
        self.iconTextBackgroundNode = ASImageNode()
        self.iconTextBackgroundNode.isLayerBacked = true
        self.iconTextBackgroundNode.displaysAsynchronously = false
        self.iconTextBackgroundNode.displayWithoutProcessing = true
        
        self.iconTextNode = TextNode()
        self.iconTextNode.isLayerBacked = true
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.isLayerBacked = true
        self.iconImageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.iconImageNode)
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
        let iconTextMakeLayout = TextNode.asyncLayout(self.iconTextNode)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        
        let currentIconImageRepresentation = self.currentIconImageRepresentation
        
        let currentItem = self.appliedItem
        
        return { [weak self] item, width, _, _, _ in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let leftInset: CGFloat = 65.0
            
            var title: NSAttributedString?
            var descriptionText: NSAttributedString?
            var iconText: NSAttributedString?
            
            var iconImageRepresentation: TelegramMediaImageRepresentation?
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            let applyIconTextBackgroundImage = iconTextBackgroundImage
            
            var selectedMedia: TelegramMediaWebpage?
            for media in item.message.media {
                if let webpage = media as? TelegramMediaWebpage {
                    selectedMedia = webpage
                    
                    if case let .Loaded(content) = webpage.content {
                        var hostName: String = ""
                        if let url = URL(string: content.url), let host = url.host, !host.isEmpty {
                            hostName = host
                            iconText = NSAttributedString(string: host.substring(to: host.index(after: host.startIndex)).uppercased(), font: iconFont, textColor: UIColor.white)
                        }
                        
                        title = NSAttributedString(string: content.title ?? content.websiteName ?? hostName, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                        
                        if let image = content.image {
                            iconImageRepresentation = smallestImageRepresentation(image.representations)
                        } else if let file = content.file {
                            iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations)
                        }
                        
                        let mutableDescriptionText = NSMutableAttributedString()
                        if let text = content.text {
                            mutableDescriptionText.append(NSAttributedString(string: text + "\n", font: descriptionFont, textColor: item.theme.list.itemPrimaryTextColor))
                        }
                        
                        mutableDescriptionText.append(NSAttributedString(string: content.displayUrl, font: descriptionFont, textColor: item.theme.list.itemAccentColor))
                        
                        let style = NSMutableParagraphStyle()
                        style.lineSpacing = 4.0
                        mutableDescriptionText.addAttribute(NSAttributedStringKey.paragraphStyle, value: style, range: NSMakeRange(0, mutableDescriptionText.length))
                        
                        descriptionText = mutableDescriptionText
                    }
                    
                    break
                }
            }
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(title, nil, 1, .middle, CGSize(width: width - leftInset - 8.0, height: CGFloat.infinity), .natural, nil, UIEdgeInsets())
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(descriptionText, nil, 0, .end, CGSize(width: width - leftInset - 8.0 - 12.0, height: CGFloat.infinity), .natural, nil, UIEdgeInsets())
            
            let (iconTextLayout, iconTextApply) = iconTextMakeLayout(iconText, nil, 1, .end, CGSize(width: 38.0, height: CGFloat.infinity), .natural, nil, UIEdgeInsets())
            
            var iconImageApply: (() -> Void)?
            if let iconImageRepresentation = iconImageRepresentation {
                let iconSize = CGSize(width: 42.0, height: 42.0)
                let imageCorners = ImageCorners(topLeft: .Corner(2.0), topRight: .Corner(2.0), bottomLeft: .Corner(2.0), bottomRight: .Corner(2.0))
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
            
            let contentHeight = 39.0 + descriptionNodeLayout.size.height
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: contentHeight), insets: UIEdgeInsets()), { _ in
                if let strongSelf = self {
                    strongSelf.appliedItem = item
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.theme.list.itemSeparatorColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentHeight - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: contentHeight + UIScreenPixel))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 9.0), size: titleNodeLayout.size)
                    let _ = titleNodeApply()
                    
                    strongSelf.descriptionNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 29.0), size: descriptionNodeLayout.size)
                    let _ = descriptionNodeApply()
                    
                    let iconFrame = CGRect(origin: CGPoint(x: 9.0, y: 12.0), size: CGSize(width: 42.0, height: 42.0))
                    strongSelf.iconTextNode.frame = CGRect(origin: CGPoint(x: iconFrame.minX + floor((42.0 - iconTextLayout.size.width) / 2.0), y: iconFrame.minY + floor((42.0 - iconTextLayout.size.height) / 2.0) + 3.0), size: iconTextLayout.size)
                    
                    let _ = iconTextApply()
                    
                    strongSelf.currentIconImageRepresentation = iconImageRepresentation
                    
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
        return nil
    }
    
    override func updateHiddenMedia() {
    }
    
    override func updateSelectionState(animated: Bool) {
    }
    
    func activateMedia() {
        if let webpage = self.currentMedia as? TelegramMediaWebpage {
            
        }
    }
}
