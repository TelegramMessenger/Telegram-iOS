import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AppBundle
import PhoneNumberFormat

private let titleFont = Font.regular(17.0)

public class ContactsAddItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let phoneNumber: String
    let action: () -> Void
    
    public let header: ListViewItemHeader?
    
    public init(theme: PresentationTheme, strings: PresentationStrings, phoneNumber: String, header: ListViewItemHeader?, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.phoneNumber = phoneNumber
        self.action = action
        self.header = header
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ContactsAddItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = ContactsAddItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (nodeLayout, nodeApply) = makeLayout(self, params, first, last, firstWithHeader)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets

            completion(node, {
                return (nil, { _ in nodeApply(false) })
            })
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ContactsAddItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = ContactsAddItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool {
        return true
    }
    
    public func selected(listView: ListView) {
        self.action()
    }
    
    static func mergeType(item: ContactsAddItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ContactsAddItem {
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
            if let header = item.header {
                if let nextItem = nextItem as? ContactsAddItem {
                    last = header.id != nextItem.header?.id
                } else {
                    last = true
                }
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader)
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

class ContactsAddItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let iconNode: ASImageNode
    private let titleNode: TextNode
  
    
    private var layoutParams: (ContactsAddItem, ListViewItemLayoutParams, Bool, Bool, Bool)?
    private var item: ContactsAddItem? {
        return self.layoutParams?.0
    }
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.titleNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let (item, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = ContactsAddItem.mergeType(item: item, previousItem: previousItem, nextItem: nextItem)
            self.layoutParams = (item, params, first, last, firstWithHeader)
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, first, last, firstWithHeader)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply(false)
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
    
    func asyncLayout() -> (_ item: ContactsAddItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, first, last, firstWithHeader in
            var updatedTheme: PresentationTheme?
            var updatedIcon: UIImage?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updatedIcon = generateTintedImage(image: UIImage(bundleImageName: "Contact List/AddMemberIcon"), color: item.theme.list.itemAccentColor)
            }
            let leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = 10.0 + params.rightInset

            let titleAttributedString = NSAttributedString(string: item.strings.Contacts_AddPhoneNumber(formatPhoneNumber(item.phoneNumber)).string, font: titleFont, textColor: item.theme.list.itemAccentColor)
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 50.0), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 14.0), size: titleLayout.size)

            return (nodeLayout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, first, last, firstWithHeader)
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                    
                    if let updatedIcon = updatedIcon {
                        strongSelf.iconNode.image = updatedIcon
                    }
                    transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(x: params.leftInset + 14.0, y: 5.0, width: 40.0, height: 40.0))
                    
                    let topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: max(0.0, nodeLayout.size.width - leftInset), height: separatorHeight))
                    strongSelf.separatorNode.isHidden = last
                }
            })
        }
    }
    
    override func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let (item, _, _, _, _) = self.layoutParams {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
}
