import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

private enum RevealOptionKey: Int32 {
    case delete
}

class SettingsSearchRecentItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let account: Account
    let title: String
    let breadcrumbs: [String]
    let isFaq: Bool
    let action: () -> Void
    let deleted: () -> Void
    
    let header: ListViewItemHeader?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, title: String, breadcrumbs: [String], isFaq: Bool, action: @escaping () -> Void, deleted: @escaping () -> Void, header: ListViewItemHeader) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.title = title
        self.breadcrumbs = breadcrumbs
        self.isFaq = isFaq
        self.action = action
        self.deleted = deleted
        self.header = header
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = SettingsSearchRecentItemNode()
            let makeLayout = node.asyncLayout()
            
            var previousHeader: ListViewItemHeader?
            if let previousItem = previousItem as? SettingsSearchRecentItem {
                previousHeader = previousItem.header
            }
            var nextHeader: ListViewItemHeader?
            if let nextItem = nextItem as? SettingsSearchRecentItem {
                nextHeader = nextItem.header
            }
            
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem == nil || nextHeader?.id != self.header?.id, !(previousItem is SettingsSearchRecentItem) || previousHeader?.id != self.header?.id)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? SettingsSearchRecentItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    var previousHeader: ListViewItemHeader?
                    if let previousItem = previousItem as? SettingsSearchRecentItem {
                        previousHeader = previousItem.header
                    }
                    var nextHeader: ListViewItemHeader?
                    if let nextItem = nextItem as? SettingsSearchRecentItem {
                        nextHeader = nextItem.header
                    }
                    
                    let (nodeLayout, apply) = layout(self, params, nextItem == nil || nextHeader?.id != self.header?.id, !(previousItem is SettingsSearchRecentItem) || previousHeader?.id != self.header?.id)
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
        self.action()
    }
}

private let titleFont = Font.regular(17.0)
private let subtitleFont = Font.regular(13.0)

class SettingsSearchRecentItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    
    private var item: SettingsSearchRecentItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreenScale
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.contentMode = .left
        self.subtitleNode.contentsScale = UIScreenScale
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
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
    
    func asyncLayout() -> (_ item: SettingsSearchRecentItem, _ params: ListViewItemLayoutParams, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        
        let currentItem = self.item
        
        return { [weak self] item, params, last, firstWithHeader in
            let leftInset: CGFloat = 15.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 16.0 - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let subtitle = item.breadcrumbs.joined(separator: " → ")
            
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: subtitle, font: subtitleFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 16.0 - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var height = titleLayout.size.height
            if subtitle.isEmpty {
                height += 22.0
            } else {
                height += 39.0
            }
            let contentSize = CGSize(width: params.width, height: height)
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.theme !== item.theme {
                    updatedTheme = item.theme
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                            strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        }
                        
                        let _ = titleApply()
                        let _ = subtitleApply()
                        
                        let titleY: CGFloat = subtitle.isEmpty ? 11.0 : 11.0
                        strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: titleY), size: titleLayout.size)
                        strongSelf.subtitleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: titleY + titleLayout.size.height + 1.0), size: subtitleLayout.size)
                        
                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = (firstWithHeader || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                        strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = last
                        
                        strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        
                        var revealOptions: [ItemListRevealOption] = []
                        if item.isFaq {
                        } else {
                            revealOptions.append(ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor))
                        }
                        strongSelf.setRevealOptions((left: [], right: revealOptions))
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
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let params = self.layoutParams {
            let leftInset: CGFloat = 15.0 + params.leftInset
        
            var titleFrame = self.titleNode.frame
            titleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            var subtitleFrame = self.subtitleNode.frame
            subtitleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.subtitleNode, frame: subtitleFrame)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            switch option.key {
            case RevealOptionKey.delete.rawValue:
                item.deleted()
            default:
                break
            }
        }
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}
