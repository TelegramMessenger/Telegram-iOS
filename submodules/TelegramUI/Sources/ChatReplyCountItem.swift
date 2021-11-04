import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode

private let titleFont = UIFont.systemFont(ofSize: 13.0)

class ChatReplyCountItem: ListViewItem {
    let index: MessageIndex
    let isComments: Bool
    let count: Int
    let presentationData: ChatPresentationData
    let header: ChatMessageDateHeader
    let controllerInteraction: ChatControllerInteraction
    
    init(index: MessageIndex, isComments: Bool, count: Int, presentationData: ChatPresentationData, context: AccountContext, controllerInteraction: ChatControllerInteraction) {
        self.index = index
        self.isComments = isComments
        self.count = count
        self.presentationData = presentationData
        self.header = ChatMessageDateHeader(timestamp: index.timestamp, scheduled: false, presentationData: presentationData, context: context)
        self.controllerInteraction = controllerInteraction
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatReplyCountItemNode()
            Queue.mainQueue().async {
                node.layoutForParams(params, item: self, previousItem: previousItem, nextItem: nextItem)
                completion(node, {
                    return (nil, { _ in })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatReplyCountItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let dateAtBottom = !chatItemsHaveCommonDateHeader(self, nextItem)
                    
                    let (layout, apply) = nodeLayout(self, params, dateAtBottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

class ChatReplyCountItemNode: ListViewItemNode {
    var item: ChatReplyCountItem?
    private let labelNode: TextNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    private let backgroundColorNode: ASDisplayNode
    
    private var theme: ChatPresentationThemeData?
    
    private let layoutConstants = ChatMessageItemLayoutConstants.default

    private var absoluteRect: (CGRect, CGSize)?
    
    init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false

        self.backgroundColorNode = ASDisplayNode()
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)

        self.addSubnode(self.labelNode)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.scrollPositioningInsets = UIEdgeInsets(top: 5.0, left: 0.0, bottom: 6.0, right: 0.0)
        self.canBeUsedAsScrollToItemAnchor = false
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
            if let item = item as? ChatReplyCountItem {
            let dateAtBottom = !chatItemsHaveCommonDateHeader(item, nextItem)
            let (layout, apply) = self.asyncLayout()(item, params, dateAtBottom)
            apply()
            self.contentSize = layout.contentSize
            self.insets = layout.insets
        }
    }
    
    func asyncLayout() -> (_ item: ChatReplyCountItem, _ params: ListViewItemLayoutParams, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        let layoutConstants = self.layoutConstants
        
        return { item, params, dateAtBottom in
            let text: String
            if item.count == 0 {
                text = item.presentationData.strings.Conversation_DiscussionNotStarted
            } else {
                text = item.presentationData.strings.Conversation_DiscussionStarted
            }
            
            let textColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
            
            let attributedString = NSAttributedString(string: text, font: Font.regular(13.0), textColor: textColor)
            
            let (labelLayout, apply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            var labelRects = labelLayout.linesRects()
            if labelRects.count > 1 {
                let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                for i in 0 ..< sortedIndices.count {
                    let index = sortedIndices[i]
                    for j in -1 ... 1 {
                        if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                            if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                                labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                                labelRects[index].size.width = labelRects[index + j].size.width
                            }
                        }
                    }
                }
            }
            for i in 0 ..< labelRects.count {
                labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
                labelRects[i].size.height = 20.0
                labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
            }
            
            let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: backgroundSize.height), insets: UIEdgeInsets(top: 6.0 + (dateAtBottom ? layoutConstants.timestampHeaderHeight : 0.0), left: 0.0, bottom: 5.0, right: 0.0)), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.theme = item.presentationData.theme
                    
                    let _ = apply()

                    if strongSelf.backgroundNode == nil {
                        if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            strongSelf.backgroundNode = backgroundNode
                            backgroundNode.addSubnode(strongSelf.backgroundColorNode)
                            strongSelf.insertSubnode(backgroundNode, at: 0)
                        }
                    }
                    
                    let labelFrame = CGRect(origin: CGPoint(x: floor((params.width - backgroundSize.width) / 2.0) + 8.0, y: floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame

                    strongSelf.backgroundColorNode.backgroundColor = selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)

                    let baseBackgroundFrame = CGRect(origin: CGPoint(x: labelFrame.minX - 6.0, y: labelFrame.minY - 2.0), size: CGSize(width: labelFrame.width + 6.0 * 2.0, height: labelFrame.height + 2.0 * 2.0))

                    if let backgroundNode = strongSelf.backgroundNode {
                        backgroundNode.frame = baseBackgroundFrame

                        backgroundNode.clipsToBounds = true
                        backgroundNode.cornerRadius = baseBackgroundFrame.height / 2.0

                        if let (rect, size) = strongSelf.absoluteRect {
                            strongSelf.updateAbsoluteRect(rect, within: size)
                        }
                    }

                    strongSelf.backgroundColorNode.frame = CGRect(origin: CGPoint(), size: baseBackgroundFrame.size)
                }
            })
        }
    }

    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y = containerSize.height - rect.maxY + self.insets.top
        
        self.absoluteRect = (rect, containerSize)

        if let backgroundNode = self.backgroundNode {
            var backgroundFrame = backgroundNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            
            backgroundNode.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }

    override func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offset(value: CGPoint(x: value.x, y: -value.y), animationCurve: animationCurve, duration: duration)
        }
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return [item.header]
        } else {
            return nil
        }
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
