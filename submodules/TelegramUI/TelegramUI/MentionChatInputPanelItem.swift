import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext

final class MentionChatInputPanelItem: ListViewItem {
    fileprivate let context: AccountContext
    fileprivate let theme: PresentationTheme
    fileprivate let fontSize: PresentationFontSize
    fileprivate let inverted: Bool
    fileprivate let peer: Peer
    private let peerSelected: (Peer) -> Void
    
    let selectable: Bool = true
    
    public init(context: AccountContext, theme: PresentationTheme, fontSize: PresentationFontSize, inverted: Bool, peer: Peer, peerSelected: @escaping (Peer) -> Void) {
        self.context = context
        self.theme = theme
        self.fontSize = fontSize
        self.inverted = inverted
        self.peer = peer
        self.peerSelected = peerSelected
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = MentionChatInputPanelItemNode()
            
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
            if let nodeValue = node() as? MentionChatInputPanelItemNode {
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
    
    func selected(listView: ListView) {
        self.peerSelected(self.peer)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

final class MentionChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 42.0
    
    private var item: MentionChatInputPanelItem?
    
    private let avatarNode: AvatarNode
    private let textNode: TextNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.textNode = TextNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.textNode)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? MentionChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: MentionChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let previousItem = self.item
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let primaryFont = Font.medium(floor(item.fontSize.baseDisplaySize * 14.0 / 17.0))
            let secondaryFont = Font.regular(floor(item.fontSize.baseDisplaySize * 14.0 / 17.0))
            
            let leftInset: CGFloat = 55.0 + params.leftInset
            let rightInset: CGFloat = 10.0 + params.rightInset
            
            var updatedInverted: Bool?
            if previousItem?.inverted != item.inverted {
                updatedInverted = item.inverted
            }
            
            let string = NSMutableAttributedString()
            string.append(NSAttributedString(string: item.peer.debugDisplayTitle, font: primaryFont, textColor: item.theme.list.itemPrimaryTextColor))
            if let addressName = item.peer.addressName, !addressName.isEmpty {
                string.append(NSAttributedString(string: " @\(addressName)", font: secondaryFont, textColor: item.theme.list.itemSecondaryTextColor))
            }
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: HashtagChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let updatedInverted = updatedInverted {
                        if updatedInverted {
                            strongSelf.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
                        } else {
                            strongSelf.transform = CATransform3DIdentity
                        }
                    }
                    
                    strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.topSeparatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.backgroundColor = item.theme.list.plainBackgroundColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.theme, peer: item.peer, emptyColor: item.theme.list.mediaPlaceholderColor)
                    
                    let _ = textApply()
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 12.0, y: floor((nodeLayout.contentSize.height - 30.0) / 2.0)), size: CGSize(width: 30.0, height: 30.0))
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                    
                    strongSelf.topSeparatorNode.isHidden = mergedTop
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: item.inverted ? (nodeLayout.contentSize.height - UIScreenPixel) : 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: !item.inverted ? (nodeLayout.contentSize.height - UIScreenPixel) : 0.0), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))
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
}
