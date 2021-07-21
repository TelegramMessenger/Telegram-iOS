import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

final class CommandMenuChatInputPanelItem: ListViewItem {
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
            let node = CommandMenuChatInputPanelItemNode()
            
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
            if let nodeValue = node() as? CommandMenuChatInputPanelItemNode {
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

private extension String {
    func capitalizeFirstLetter() -> String {
        return self.prefix(1).capitalized + self.dropFirst()
    }
}

private let backgroundCornerRadius: CGFloat = 10.0
private let shadowBlur: CGFloat = 10.0

let shadowImage = generateImage(CGSize(width: (backgroundCornerRadius + shadowBlur) * 2.0, height: backgroundCornerRadius + shadowBlur), rotatedContext: { size, context in
    let diameter = backgroundCornerRadius * 2.0
    let shadow = UIColor(white: 0.0, alpha: 0.5)
    context.clear(CGRect(origin: CGPoint(), size: size))
    
    context.saveGState()
    context.setFillColor(shadow.cgColor)
    context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
    
    context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    
    context.setFillColor(UIColor.clear.cgColor)
    context.setBlendMode(.copy)
    
    context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    
    context.restoreGState()
})?.stretchableImage(withLeftCapWidth: Int(backgroundCornerRadius + shadowBlur), topCapHeight: 0)

final class CommandMenuChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 44.0
    
    private var item: CommandMenuChatInputPanelItem?
    private let textNode: TextNode
    private let commandNode: TextNode
    private let separatorNode: ASDisplayNode
    private let clippingNode: ASDisplayNode
    private let shadowNode: ASImageNode
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
        
    init() {
        self.textNode = TextNode()
        self.commandNode = TextNode()
                
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.shadowNode = ASImageNode()
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.contentMode = .scaleToFill
        self.shadowNode.image = shadowImage
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        
        super.init(layerBacked: false, dynamicBounce: false)
                
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.shadowNode)
        self.clippingNode.addSubnode(self.backgroundNode)
        
        self.backgroundNode.addSubnode(self.textNode)
        self.backgroundNode.addSubnode(self.commandNode)
        self.backgroundNode.addSubnode(self.separatorNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
        gestureRecognizer.minimumPressDuration = 0.3
        self.view.addGestureRecognizer(gestureRecognizer)
    }
    
    @objc private func longPressed(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
            case .began:
                if let item = self.item {
                    item.commandSelected(item.command, false)
                }
            default:
                break
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? CommandMenuChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: CommandMenuChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeCommandLayout = TextNode.asyncLayout(self.commandNode)
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let textFont = Font.regular(floor(item.fontSize.baseDisplaySize))
            let commandFont = Font.regular(floor(item.fontSize.baseDisplaySize * 14.0 / 17.0))
            
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            
            let textString: NSAttributedString
            let commandString: NSAttributedString
            if item.command.command.description.isEmpty {
                textString = NSAttributedString(string: item.command.command.text.capitalizeFirstLetter(), font: textFont, textColor: item.theme.list.itemPrimaryTextColor)
                commandString = NSAttributedString(string: "/" + item.command.command.text, font: commandFont, textColor: item.theme.list.itemSecondaryTextColor)
            } else {
                textString = NSAttributedString(string: item.command.command.description.capitalizeFirstLetter(), font: textFont, textColor: item.theme.list.itemPrimaryTextColor)
                commandString = NSAttributedString(string: "/" + item.command.command.text, font: commandFont, textColor: item.theme.list.itemSecondaryTextColor)
            }
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 130.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (commandLayout, commandApply) = makeCommandLayout(TextNodeLayoutArguments(attributedString: commandString, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: 120.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: max(CommandMenuChatInputPanelItemNode.itemHeight, textLayout.size.height + 14.0)), insets: UIEdgeInsets())
                        
            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    
                    let _ = textApply()
                    let _ = commandApply()
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                    strongSelf.commandNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - commandLayout.size.width, y: floor((nodeLayout.contentSize.height - commandLayout.size.height) / 2.0)), size: commandLayout.size)
                                        
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))
                    
                    if !mergedTop {
                        strongSelf.shadowNode.isHidden = false
                        strongSelf.shadowNode.frame = CGRect(origin: CGPoint(x: -shadowBlur, y: 0.0), size: CGSize(width: nodeLayout.size.width + shadowBlur * 2.0, height: backgroundCornerRadius + shadowBlur))
                        strongSelf.clippingNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -shadowBlur), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + shadowBlur))
                        strongSelf.backgroundNode.cornerRadius = backgroundCornerRadius
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: shadowBlur), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + backgroundCornerRadius))
                    } else {
                        strongSelf.shadowNode.isHidden = true
                        strongSelf.clippingNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.size)
                        strongSelf.backgroundNode.cornerRadius = 0.0
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.size)
                    }
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.backgroundNode.insertSubnode(self.highlightedBackgroundNode, at: 0)
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
