import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private let messageFont = Font.medium(14.0)

final class ChatEmptyItem: ListViewItem {
    fileprivate let presentationData: ChatPresentationData
    fileprivate let tagMask: MessageTags?
    
    init(presentationData: ChatPresentationData, tagMask: MessageTags?) {
        self.presentationData = presentationData
        self.tagMask = tagMask
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        let configure = {
            let node = ChatEmptyItemNode(rotated: self.tagMask == nil)
            
            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, params)
            
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatEmptyItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = nodeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
}

final class ChatEmptyItemNode: ListViewItemNode {
    private let rotated: Bool
    
    var controllerInteraction: ChatControllerInteraction?
    
    let offsetContainer: ASDisplayNode
    let backgroundNode: ASImageNode
    let iconNode: ASImageNode
    let textNode: TextNode
    
    private var theme: PresentationTheme?
    
    private var item: ChatEmptyItem?
    
    init(rotated: Bool) {
        self.rotated = rotated
        self.offsetContainer = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.iconNode = ASImageNode()
        self.textNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: rotated)
        
        if rotated {
            self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        }
        
        self.addSubnode(self.offsetContainer)
        self.offsetContainer.addSubnode(self.backgroundNode)
        self.offsetContainer.addSubnode(self.iconNode)
        self.offsetContainer.addSubnode(self.textNode)
        self.wantsTrailingItemSpaceUpdates = true
    }
    
    func asyncLayout() -> (_ item: ChatEmptyItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let currentTheme = self.theme
        return { [weak self] item, params in
            self?.item = item
            
            let width = params.width
            var updatedBackgroundImage: UIImage?
            
            let iconImage: UIImage? = PresentationResourcesChat.chatEmptyItemIconImage(item.presentationData.theme.theme)
            
            if currentTheme !== item.presentationData.theme {
                updatedBackgroundImage = PresentationResourcesChat.chatEmptyItemBackgroundImage(item.presentationData.theme.theme)
            }
            
            let attributedText: NSAttributedString
            if let tagMask = item.tagMask {
                let text: String
                if tagMask == .photoOrVideo {
                    text = item.presentationData.strings.SharedMedia_EmptyText
                } else if tagMask == .file {
                    text = item.presentationData.strings.SharedMedia_EmptyFilesText
                } else {
                    text = ""
                }
                attributedText = NSAttributedString(string: text, font: messageFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor, paragraphAlignment: .center)
            } else {
                attributedText = NSAttributedString(string: item.presentationData.strings.Conversation_EmptyPlaceholder, font: messageFont, textColor: item.presentationData.theme.theme.chat.serviceMessage.serviceMessagePrimaryTextColor, paragraphAlignment: .center)
            }
                
            let horizontalEdgeInset: CGFloat = 10.0
            let horizontalContentInset: CGFloat = 12.0
            let verticalItemInset: CGFloat = 10.0
            let verticalContentInset: CGFloat = 14.0
            
            var imageSize = CGSize(width: 80.0, height: 80.0)
            if let iconImage = iconImage {
                imageSize = iconImage.size
            }
            let imageSpacing: CGFloat = 18.0
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - horizontalEdgeInset * 2.0 - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentWidth = max(textLayout.size.width, 120.0)
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((width - contentWidth - horizontalContentInset * 2.0) / 2.0), y: verticalItemInset + 4.0), size: CGSize(width: contentWidth + horizontalContentInset * 2.0, height: textLayout.size.height + imageSize.height + imageSpacing + verticalContentInset * 2.0))
            let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + horizontalContentInset + floor((contentWidth - textLayout.size.width) / 2.0), y: backgroundFrame.origin.y + verticalContentInset + imageSize.height + imageSpacing), size: textLayout.size)
            let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + horizontalContentInset + floor((contentWidth - imageSize.width) / 2.0), y: backgroundFrame.origin.y + verticalContentInset), size: imageSize)
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: imageSize.height + imageSpacing + textLayout.size.height + verticalItemInset * 2.0 + verticalContentInset * 2.0 + 4.0), insets: UIEdgeInsets())
            return (itemLayout, { _ in
                if let strongSelf = self {
                    strongSelf.theme = item.presentationData.theme.theme
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    strongSelf.iconNode.image = iconImage
                    
                    let _ = textApply()
                    strongSelf.offsetContainer.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                    strongSelf.backgroundNode.frame = backgroundFrame
                    strongSelf.textNode.frame = textFrame
                    strongSelf.iconNode.frame = iconFrame
                }
            })
        }
    }
    
    override func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        if height.isLessThanOrEqualTo(0.0) {
            transition.updateBounds(node: self.offsetContainer, bounds: CGRect(origin: CGPoint(), size: self.offsetContainer.bounds.size))
        } else {
            transition.updateBounds(node: self.offsetContainer, bounds: CGRect(origin: CGPoint(x: 0.0, y: self.rotated ? (floor(height) / 2.0) : (-floor(height) / 4.0)), size: self.offsetContainer.bounds.size))
        }
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public var wantsScrollDynamics: Bool {
        if let disableAnimations = self.item?.presentationData.disableAnimations {
            return !disableAnimations
        }
        return true
    }
}
