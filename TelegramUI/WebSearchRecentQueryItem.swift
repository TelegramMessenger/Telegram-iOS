import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore

private enum RevealOptionKey: Int32 {
    case delete
}

class WebSearchRecentQueryItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let account: Account
    let query: String
    let controllerInteraction: WebSearchControllerInteraction
    
    let header: ListViewItemHeader?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, query: String, controllerInteraction: WebSearchControllerInteraction, header: ListViewItemHeader) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.query = query
        self.controllerInteraction = controllerInteraction
        self.header = header
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WebSearchRecentQueryItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem == nil, previousItem == nil)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? WebSearchRecentQueryItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem == nil, previousItem == nil)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { info in
                            apply().1(info)
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool {
        return true
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.controllerInteraction.setSearchQuery(self.query)
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

class WebSearchRecentQueryItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var textNode: TextNode?
    
    private var item: WebSearchRecentQueryItem?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, nextItem == nil, previousItem == nil)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
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
    
    func asyncLayout() -> (_ item: WebSearchRecentQueryItem, _ params: ListViewItemLayoutParams, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let textLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, last, firstWithHeader in
            
            let leftInset: CGFloat = 15.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            
            let attributedString = NSAttributedString(string: item.query, font: Font.regular(17.0), textColor: .black)
            let textApply = textLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 44.0), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.theme !== item.theme {
                    updatedTheme = item.theme
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                            strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        }
                        
                        let (textLayout, textApply) = textApply
                        let textNode = textApply()
                        if strongSelf.textNode == nil {
                            strongSelf.textNode = textNode
                            strongSelf.addSubnode(textNode)
                        }
                        
                        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((44.0 - textLayout.size.height) / 2.0)), size: textLayout.size)
                        textNode.frame = textFrame

                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = (firstWithHeader || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                        strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = last
                        
                        strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        
                        strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func header() -> ListViewItemHeader? {
        if let item = self.item {
            return item.header
        } else {
            return nil
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
//        if let _ = self.item, let params = self.layoutParams?.5 {
//            let editingOffset: CGFloat
//            if let selectableControlNode = self.selectableControlNode {
//                editingOffset = selectableControlNode.bounds.size.width
//                var selectableControlFrame = selectableControlNode.frame
//                selectableControlFrame.origin.x = params.leftInset + offset
//                transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame)
//            } else {
//                editingOffset = 0.0
//            }
//
//            if let reorderControlNode = self.reorderControlNode {
//                var reorderControlFrame = reorderControlNode.frame
//                reorderControlFrame.origin.x = params.width - params.rightInset - reorderControlFrame.size.width + offset
//                transition.updateFrame(node: reorderControlNode, frame: reorderControlFrame)
//            }
//
//            let leftInset: CGFloat = params.leftInset + 78.0
//
//            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: 8.0), size: CGSize(width: params.width - leftInset - params.rightInset - 10.0 - 1.0 - editingOffset, height: itemHeight - 12.0 - 9.0))
//
//            let contentRect = rawContentRect.offsetBy(dx: editingOffset + leftInset + offset, dy: 0.0)
//
//            var avatarFrame = self.avatarNode.frame
//            avatarFrame.origin.x = leftInset - 78.0 + editingOffset + 10.0 + offset
//            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
//            if let multipleAvatarsNode = self.multipleAvatarsNode {
//                transition.updateFrame(node: multipleAvatarsNode, frame: avatarFrame)
//            }
//
//            var titleOffset: CGFloat = 0.0
//            if let secretIconNode = self.secretIconNode, let image = secretIconNode.image {
//                transition.updateFrame(node: secretIconNode, frame: CGRect(origin: CGPoint(x: contentRect.minX, y: secretIconNode.frame.minY), size: image.size))
//                titleOffset += image.size.width + 3.0
//            }
//
//            let titleFrame = self.titleNode.frame
//            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: titleFrame.origin.y), size: titleFrame.size))
//
//            let authorFrame = self.authorNode.frame
//            transition.updateFrame(node: self.authorNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: authorFrame.origin.y), size: authorFrame.size))
//
//            transition.updateFrame(node: self.inputActivitiesNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: self.inputActivitiesNode.frame.minY), size: self.inputActivitiesNode.bounds.size))
//
//            let textFrame = self.textNode.frame
//            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: textFrame.origin.y), size: textFrame.size))
//
//            let dateFrame = self.dateNode.frame
//            transition.updateFrame(node: self.dateNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width, y: dateFrame.minY), size: dateFrame.size))
//
//            let statusFrame = self.statusNode.frame
//            transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width - 2.0 - statusFrame.size.width, y: statusFrame.minY), size: statusFrame.size))
//
//            var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleFrame.size.width + 3.0 + titleOffset
//
//            if let verificationIconNode = self.verificationIconNode {
//                transition.updateFrame(node: verificationIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: verificationIconNode.frame.origin.y), size: verificationIconNode.bounds.size))
//                nextTitleIconOrigin += verificationIconNode.bounds.size.width + 5.0
//            }
//
//            let mutedIconFrame = self.mutedIconNode.frame
//            transition.updateFrame(node: self.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: contentRect.origin.y + 6.0), size: mutedIconFrame.size))
//            nextTitleIconOrigin += mutedIconFrame.size.width + 3.0
//
//            let badgeBackgroundFrame = self.badgeBackgroundNode.frame
//            let updatedBadgeBackgroundFrame = CGRect(origin: CGPoint(x: contentRect.maxX - badgeBackgroundFrame.size.width, y: contentRect.maxY - badgeBackgroundFrame.size.height - 2.0), size: badgeBackgroundFrame.size)
//            transition.updateFrame(node: self.badgeBackgroundNode, frame: updatedBadgeBackgroundFrame)
//
//            if self.mentionBadgeNode.supernode != nil {
//                let mentionBadgeSize = self.mentionBadgeNode.bounds.size
//                let mentionBadgeOffset: CGFloat
//                if updatedBadgeBackgroundFrame.size.width.isZero || self.badgeBackgroundNode.image == nil {
//                    mentionBadgeOffset = contentRect.maxX - mentionBadgeSize.width
//                } else {
//                    mentionBadgeOffset = contentRect.maxX - updatedBadgeBackgroundFrame.size.width - 6.0 - mentionBadgeSize.width
//                }
//
//                let badgeBackgroundWidth = mentionBadgeSize.width
//                let badgeBackgroundFrame = CGRect(x: mentionBadgeOffset, y: self.mentionBadgeNode.frame.origin.y, width: badgeBackgroundWidth, height: mentionBadgeSize.height)
//                transition.updateFrame(node: self.mentionBadgeNode, frame: badgeBackgroundFrame)
//            }
//
//            let badgeTextFrame = self.badgeTextNode.frame
//            transition.updateFrame(node: self.badgeTextNode, frame: CGRect(origin: CGPoint(x: updatedBadgeBackgroundFrame.midX - badgeTextFrame.size.width / 2.0, y: badgeTextFrame.minY), size: badgeTextFrame.size))
//        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        var close = true
        if let item = self.item {
            switch option.key {
                case RevealOptionKey.delete.rawValue:
                    item.controllerInteraction.deleteRecentQuery(item.query)
                default:
                    break
            }
        }
        if close {
            self.setRevealOptionsOpened(false, animated: true)
            self.revealOptionsInteractivelyClosed()
        }
    }
}
