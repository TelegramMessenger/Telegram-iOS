import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext

final class CommandChatInputPanelItem: ListViewItem {
    fileprivate let context: AccountContext
    fileprivate let theme: PresentationTheme
    fileprivate let fontSize: PresentationFontSize
    fileprivate let command: PeerCommand
    fileprivate let commandSelected: (PeerCommand, Bool) -> Void
    
    let selectable: Bool = true
    
    public init(context: AccountContext, theme: PresentationTheme, fontSize: PresentationFontSize, command: PeerCommand, commandSelected: @escaping (PeerCommand, Bool) -> Void) {
        self.context = context
        self.theme = theme
        self.fontSize = fontSize
        self.command = command
        self.commandSelected = commandSelected
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = CommandChatInputPanelItemNode()
            
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
            if let nodeValue = node() as? CommandChatInputPanelItemNode {
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
        self.commandSelected(self.command, true)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

final class CommandChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 42.0
    
    private var item: CommandChatInputPanelItem?
    private let avatarNode: AvatarNode
    private let textNode: TextNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let arrowNode: ASButtonNode
    
    init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.textNode = TextNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.arrowNode = HighlightableButtonNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.arrowNode)
        
        self.arrowNode.addTarget(self, action: #selector(self.arrowButtonPressed), forControlEvents: [.touchUpInside])
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? CommandChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: CommandChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let textFont = Font.medium(floor(item.fontSize.baseDisplaySize * 14.0 / 17.0))
            let descriptionFont = Font.regular(floor(item.fontSize.baseDisplaySize * 14.0 / 17.0))
            
            let leftInset: CGFloat = 55.0 + params.leftInset
            let rightInset: CGFloat = 10.0 + params.rightInset
            
            let commandString = NSMutableAttributedString()
            commandString.append(NSAttributedString(string: "/" + item.command.command.text, font: textFont, textColor: item.theme.list.itemPrimaryTextColor))
            
            if !item.command.command.description.isEmpty {
                commandString.append(NSAttributedString(string: "  " + item.command.command.description, font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor))
            }
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: commandString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 40.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: HashtagChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            let iconImage = PresentationResourcesChat.chatCommandPanelArrowImage(item.theme)
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.topSeparatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.backgroundColor = item.theme.list.plainBackgroundColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    
                    strongSelf.arrowNode.setImage(iconImage, for: [])
                    
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.theme, peer: EnginePeer(item.command.peer), emptyColor: item.theme.list.mediaPlaceholderColor)
                    
                    let _ = textApply()
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 12.0, y: floor((nodeLayout.contentSize.height - 30.0) / 2.0)), size: CGSize(width: 30.0, height: 30.0))
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                    
                    let arrowSize = CGSize(width: 42.0, height: nodeLayout.contentSize.height)
                    strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: nodeLayout.size.width - arrowSize.width - params.rightInset, y: 0.0), size: arrowSize)
                    
                    strongSelf.topSeparatorNode.isHidden = mergedTop
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))
                    
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.arrowNode.frame.contains(point) {
            return self.arrowNode.view
        } else {
            return super.hitTest(point, with: event)
        }
    }
    
    @objc func arrowButtonPressed() {
        if let item = self.item {
            item.commandSelected(item.command, false)
        }
    }
}
