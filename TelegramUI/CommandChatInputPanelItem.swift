import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

final class CommandChatInputPanelItem: ListViewItem {
    fileprivate let account: Account
    fileprivate let command: PeerCommand
    fileprivate let commandSelected: (PeerCommand, Bool) -> Void
    
    let selectable: Bool = true
    
    public init(account: Account, command: PeerCommand, commandSelected: @escaping (PeerCommand, Bool) -> Void) {
        self.account = account
        self.command = command
        self.commandSelected = commandSelected
    }
    
    public func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = CommandChatInputPanelItemNode()
            
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
        if let node = node as? CommandChatInputPanelItemNode {
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
        self.commandSelected(self.command, true)
    }
}

private let avatarFont: UIFont = UIFont(name: "ArialRoundedMTBold", size: 16.0)!
private let textFont = Font.medium(14.0)
private let descriptionFont = Font.regular(14.0)
private let descriptionColor = UIColor(rgb: 0x9099A2)

private let arrowImage = generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context.scaleBy(x: 1.0, y: -1.0)
    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    context.setStrokeColor(UIColor(rgb: 0xC7CCD0).cgColor)
    context.setLineCap(.round)
    context.setLineWidth(2.0)
    context.setLineJoin(.round)
    
    context.beginPath()
    context.move(to: CGPoint(x: 1.0, y: 2.0))
    context.addLine(to: CGPoint(x: 1.0, y: 10.0))
    context.addLine(to: CGPoint(x: 9.0, y: 10.0))
    context.strokePath()
    
    context.beginPath()
    context.move(to: CGPoint(x: 1.0, y: 10.0))
    context.addLine(to: CGPoint(x: 10.0, y: 1.0))
    context.strokePath()
})

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
        self.topSeparatorNode.backgroundColor = UIColor(rgb: 0xC9CDD1)
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(rgb: 0xD6D6DA)
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(rgb: 0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.arrowNode = HighlightableButtonNode()
        self.arrowNode.setImage(arrowImage, for: [])
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.backgroundColor = .white
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.arrowNode)
        
        self.arrowNode.addTarget(self, action: #selector(self.arrowButtonPressed), forControlEvents: [.touchUpInside])
    }
    
    override public func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? CommandChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, width, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: CommandChatInputPanelItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        return { [weak self] item, width, mergedTop, mergedBottom in
            let leftInset: CGFloat = 55.0
            let rightInset: CGFloat = 10.0
            
            let commandString = NSMutableAttributedString()
            commandString.append(NSAttributedString(string: "/" + item.command.command.text, font: textFont, textColor: .black))
            
            if !item.command.command.description.isEmpty {
                commandString.append(NSAttributedString(string: "  " + item.command.command.description, font: descriptionFont, textColor: descriptionColor))
            }
            
            let (textLayout, textApply) = makeTextLayout(commandString, nil, 1, .end, CGSize(width: width - leftInset - rightInset, height: 100.0), .natural, nil, UIEdgeInsets())
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: HashtagChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.avatarNode.setPeer(account: item.account, peer: item.command.peer)
                    
                    textApply()
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 12.0, y: floor((nodeLayout.contentSize.height - 30.0) / 2.0)), size: CGSize(width: 30.0, height: 30.0))
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                    
                    let arrowSize = CGSize(width: 42.0, height: nodeLayout.contentSize.height)
                    strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: nodeLayout.size.width - arrowSize.width, y: 0.0), size: arrowSize)
                    
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
