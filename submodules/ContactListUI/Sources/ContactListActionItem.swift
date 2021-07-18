import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ContactsPeerItem
import AccountContext

public enum ContactListActionItemHighlight {
    case cell
    case alpha
}

public class ContactListActionItem: ListViewItem, ListViewItemWithHeader {
    let presentationData: ItemListPresentationData
    let title: String
    let icon: ContactListActionItemIcon
    let highlight: ContactListActionItemHighlight
    let clearHighlightAutomatically: Bool
    let accessible: Bool
    let action: () -> Void
    public let header: ListViewItemHeader?
    
    public init(presentationData: ItemListPresentationData, title: String, icon: ContactListActionItemIcon, highlight: ContactListActionItemHighlight = .cell, clearHighlightAutomatically: Bool = true, accessible: Bool = true, header: ListViewItemHeader?, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.title = title
        self.icon = icon
        self.highlight = highlight
        self.header = header
        self.clearHighlightAutomatically = clearHighlightAutomatically
        self.accessible = accessible
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ContactListActionItemNode()
            let (_, last, firstWithHeader) = ContactListActionItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (layout, apply) = node.asyncLayout()(self, params, firstWithHeader, last)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ContactListActionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (_, last, firstWithHeader) = ContactListActionItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (layout, apply) = makeLayout(self, params, firstWithHeader, last)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool = true
    
    public func selected(listView: ListView){
        self.action()
        if self.clearHighlightAutomatically {
            listView.clearHighlightAnimated(true)
        }
    }
    
    static func mergeType(item: ContactListActionItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ContactsPeerItem {
                    firstWithHeader = header.id != previousItem.header?.id
                } else if let previousItem = previousItem as? ContactListActionItem {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        if let nextItem = nextItem {
            if let nextItem = nextItem as? ContactsPeerItem {
                last = item.header?.id != nextItem.header?.id
            } else if let nextItem = nextItem as? ContactListActionItem {
                last = item.header?.id != nextItem.header?.id
            } else {
                last = true
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader)
    }
}

class ContactListActionItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ContactListActionItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activateArea)
        
        self.activateArea.activate = { [weak self] in
            self?.item?.action()
            return true
        }
    }
    
    func asyncLayout() -> (_ item: ContactListActionItem, _ params: ListViewItemLayoutParams, _ firstWithHeader: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let currentItem = self.item
        
        return { item, params, firstWithHeader, last in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            var leftInset: CGFloat = 16.0 + params.leftInset
            if case .generic = item.icon {
                leftInset += 49.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - 10.0 - leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentHeight: CGFloat = item.highlight == .alpha ? 50.0 : 12.0 * 2.0 + titleLayout.size.height
            
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: layout.contentSize.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.iconNode.image = generateTintedImage(image: item.icon.image, color: item.presentationData.theme.list.itemAccentColor)
                    }
                    
                    if item.accessible && strongSelf.activateArea.supernode == nil {
                        strongSelf.view.accessibilityElementsHidden = false
                        strongSelf.addSubnode(strongSelf.activateArea)
                    } else if !item.accessible && strongSelf.activateArea.supernode != nil {
                        strongSelf.view.accessibilityElementsHidden = true
                        strongSelf.activateArea.removeFromSupernode()
                    }
                    
                    let _ = titleApply()

                    var titleOffset = leftInset
                    var hideBottomStripe: Bool = last
                    if let image = item.icon.image {
                        var iconFrame: CGRect
                        switch item.icon {
                            case let .inline(_, position):
                                hideBottomStripe = true
                                let iconSpacing: CGFloat = 4.0
                                let totalWidth: CGFloat = titleLayout.size.width + image.size.width + iconSpacing
                                switch position {
                                case .left:
                                    iconFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((contentSize.width - params.leftInset - params.rightInset - totalWidth) / 2.0), y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                                    titleOffset = iconFrame.minX + iconSpacing
                                case .right:
                                    iconFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((contentSize.width - params.leftInset - params.rightInset - totalWidth) / 2.0) + totalWidth - image.size.width, y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                                    titleOffset = iconFrame.maxX - totalWidth
                                }
                            default:
                                iconFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - image.size.width) / 2.0) + 3.0, y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                        }
                        strongSelf.iconNode.frame = iconFrame
                    }
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    
                    strongSelf.topStripeNode.isHidden = true
                    strongSelf.bottomStripeNode.isHidden = hideBottomStripe
                    
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: titleOffset, y: floor((contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if let item = self.item, case .alpha = item.highlight {
            if highlighted {
                self.titleNode.alpha = 0.4
                self.iconNode.alpha = 0.4
            } else {
                if animated {
                    self.titleNode.layer.animateAlpha(from: self.titleNode.alpha, to: 1.0, duration: 0.2)
                    self.iconNode.layer.animateAlpha(from: self.iconNode.alpha, to: 1.0, duration: 0.2)
                }
                self.titleNode.alpha = 1.0
                self.iconNode.alpha = 1.0
            }
        } else {
            if highlighted {
                self.highlightedBackgroundNode.alpha = 1.0
                if self.highlightedBackgroundNode.supernode == nil {
                    var anchorNode: ASDisplayNode?
                    if self.bottomStripeNode.supernode != nil {
                        anchorNode = self.bottomStripeNode
                    } else if self.topStripeNode.supernode != nil {
                        anchorNode = self.topStripeNode
                    } else if self.backgroundNode.supernode != nil {
                        anchorNode = self.backgroundNode
                    }
                    if let anchorNode = anchorNode {
                        self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                    } else {
                        self.addSubnode(self.highlightedBackgroundNode)
                    }
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
}
