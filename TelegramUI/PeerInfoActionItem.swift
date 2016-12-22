import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

enum PeerInfoActionKind {
    case generic
    case destructive
}

enum PeerInfoActionAlignment {
    case natural
    case center
}

class PeerInfoActionItem: ListViewItem, PeerInfoItem {
    let title: String
    let kind: PeerInfoActionKind
    let alignment: PeerInfoActionAlignment
    let sectionId: PeerInfoItemSectionId
    let style: PeerInfoListStyle
    let action: () -> Void
    
    init(title: String, kind: PeerInfoActionKind, alignment: PeerInfoActionAlignment, sectionId: PeerInfoItemSectionId, style: PeerInfoListStyle, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.alignment = alignment
        self.sectionId = sectionId
        self.style = style
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = PeerInfoActionItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? PeerInfoActionItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.regular(17.0)

class PeerInfoActionItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: TextNode
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
    }
    
    func asyncLayout() -> (_ item: PeerInfoActionItem, _ width: CGFloat, _ neighbors: PeerInfoItemNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, width, neighbors in
            let sectionInset: CGFloat = 22.0
            
            let (titleLayout, titleApply) = makeTitleLayout(NSAttributedString(string: item.title, font: titleFont, textColor: item.kind == .destructive ? UIColor(0xff3b30) : UIColor(0x007ee5)), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            switch item.style {
                case .plain:
                    contentSize = CGSize(width: width, height: 44.0)
                    insets = peerInfoItemNeighborsPlainInsets(neighbors)
                case .blocks:
                    contentSize = CGSize(width: width, height: 44.0)
                    let topInset: CGFloat
                    switch neighbors.top {
                        case .sameSection, .none:
                            topInset = 0.0
                        case .otherSection:
                            topInset = separatorHeight + 35.0
                    }
                    let bottomInset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection, .otherSection:
                            bottomInset = 0.0
                        case .none:
                            bottomInset = separatorHeight + 35.0
                    }
                    insets = UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    let _ = titleApply()
                    
                    let leftInset: CGFloat
                    
                    switch item.style {
                        case .plain:
                            leftInset = 35.0
                            
                            if strongSelf.backgroundNode.supernode != nil {
                               strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                            }
                        
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: width - leftInset, height: separatorHeight))
                        case .blocks:
                            leftInset = 16.0
                            
                            if strongSelf.backgroundNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                            }
                            if strongSelf.topStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                            }
                            switch neighbors.top {
                                case .sameSection:
                                    strongSelf.topStripeNode.isHidden = true
                                case .none, .otherSection:
                                    strongSelf.topStripeNode.isHidden = false
                            }
                            let bottomStripeInset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection:
                                    bottomStripeInset = 16.0
                                case .none, .otherSection:
                                    bottomStripeInset = 0.0
                            }
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    switch item.alignment {
                        case .natural:
                            strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: titleLayout.size)
                        case .center:
                            strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((width - titleLayout.size.width) / 2.0), y: 12.0), size: titleLayout.size)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: 44.0 + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
