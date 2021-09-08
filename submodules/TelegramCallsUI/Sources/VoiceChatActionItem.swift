import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

public enum VoiceChatActionItemIcon : Equatable {
    case none
    case generic(UIImage)
    
    public var image: UIImage? {
        switch self {
        case .none:
            return nil
        case let .generic(image):
            return image
        }
    }
    
    public static func ==(lhs: VoiceChatActionItemIcon, rhs: VoiceChatActionItemIcon) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case let .generic(image):
            if case .generic(image) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

class VoiceChatActionItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let title: String
    let icon: VoiceChatActionItemIcon
    let action: () -> Void
    
    init(presentationData: ItemListPresentationData, title: String, icon: VoiceChatActionItemIcon, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VoiceChatActionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, previousItem == nil || previousItem is VoiceChatTilesGridItem, nextItem == nil)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? VoiceChatActionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, previousItem == nil || previousItem is VoiceChatTilesGridItem, nextItem == nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    func selected(listView: ListView){
        self.action()
        listView.clearHighlightAnimated(true)
    }
}

class VoiceChatActionItemNode: ListViewItemNode {
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightContainerNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: VoiceChatActionItem?
    
    init() {
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
        
        self.highlightContainerNode = ASDisplayNode()
        self.highlightContainerNode.clipsToBounds = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.highlightContainerNode.addSubnode(self.highlightedBackgroundNode)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activateArea)
        
        self.activateArea.activate = { [weak self] in
            self?.item?.action()
            return true
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.highlightContainerNode.layer.cornerCurve = .continuous
        }
    }
    
    func asyncLayout() -> (_ item: VoiceChatActionItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let currentItem = self.item
        
        return { item, params, first, last in
            var updatedTheme: PresentationTheme?
            var updatedContent = false
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            if currentItem?.title != item.title {
                updatedContent = true
            }
            
            let titleFont = Font.regular(17.0)
            
            var leftInset: CGFloat = 8.0 + params.leftInset
            if case .generic = item.icon {
                leftInset += 49.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - 10.0 - leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentHeight: CGFloat = 12.0 * 2.0 + titleLayout.size.height
            
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = UIEdgeInsets()
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    guard params.width > 0.0 else {
                        return
                    }
                    
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: layout.contentSize.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
                        strongSelf.bottomStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.iconNode.image = generateTintedImage(image: item.icon.image, color: item.presentationData.theme.list.itemAccentColor)
                    } else if updatedContent {
                        strongSelf.iconNode.image = generateTintedImage(image: item.icon.image, color: item.presentationData.theme.list.itemAccentColor)
                    }
                    
                    let _ = titleApply()

                    let titleOffset = leftInset
                    let hideBottomStripe: Bool = last
                    if let image = item.icon.image {
                        let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - image.size.width) / 2.0) - 1.0, y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                        strongSelf.iconNode.frame = iconFrame
                    }
                
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 0)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 1)
                    }
                    
                    strongSelf.topStripeNode.isHidden = true
                    strongSelf.bottomStripeNode.isHidden = hideBottomStripe
                    
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: titleOffset + 1.0, y: floor((contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    
                    strongSelf.highlightContainerNode.frame = CGRect(origin: CGPoint(x: params.leftInset, y: -UIScreenPixel), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel + 11.0))
                    
                    strongSelf.highlightContainerNode.cornerRadius = first ? 11.0 : 0.0
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightContainerNode.alpha = 1.0
            if self.highlightContainerNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightContainerNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightContainerNode)
                }
            }
        } else {
            if self.highlightContainerNode.supernode != nil {
                if animated {
                    self.highlightContainerNode.layer.animateAlpha(from: self.highlightContainerNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightContainerNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightContainerNode.alpha = 0.0
                } else {
                    self.highlightContainerNode.removeFromSupernode()
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
        return nil
    }
}
