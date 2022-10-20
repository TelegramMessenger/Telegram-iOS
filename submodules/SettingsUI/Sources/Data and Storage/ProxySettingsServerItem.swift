import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ActivityIndicator
import UrlEscaping

private let activitySize = CGSize(width: 24.0, height: 24.0)

struct ProxySettingsServerItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
}

final class ProxySettingsServerItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let server: ProxyServerSettings
    let activity: Bool
    let active: Bool
    let color: ItemListCheckboxItemColor
    let label: String
    let labelAccent: Bool
    let editing: ProxySettingsServerItemEditing
    let sectionId: ItemListSectionId
    let action: () -> Void
    let infoAction: () -> Void
    let setServerWithRevealedOptions: (ProxyServerSettings?, ProxyServerSettings?) -> Void
    let removeServer: (ProxyServerSettings) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, server: ProxyServerSettings, activity: Bool, active: Bool, color: ItemListCheckboxItemColor, label: String, labelAccent: Bool, editing: ProxySettingsServerItemEditing, sectionId: ItemListSectionId, action: @escaping () -> Void, infoAction: @escaping () -> Void, setServerWithRevealedOptions: @escaping (ProxyServerSettings?, ProxyServerSettings?) -> Void, removeServer: @escaping (ProxyServerSettings) -> Void) {
        self.theme = theme
        self.strings = strings
        self.server = server
        self.activity = activity
        self.active = active
        self.color = color
        self.label = label
        self.labelAccent = labelAccent
        self.editing = editing
        self.sectionId = sectionId
        self.action = action
        self.infoAction = infoAction
        self.setServerWithRevealedOptions = setServerWithRevealedOptions
        self.removeServer = removeServer
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ProxySettingsServerItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ProxySettingsServerItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animated)
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
private let statusFont = Font.regular(14.0)

private final class ProxySettingsServerItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let titleNode: TextNode
    private let infoIconNode: ASImageNode
    private let infoButtonNode: HighlightableButtonNode
    private let statusNode: TextNode
    private let checkNode: ASImageNode
    private let activityNode: ActivityIndicator
    
    private let activateArea: AccessibilityAreaNode
    
    private var editableControlNode: ItemListEditableControlNode?
    private var reorderControlNode: ItemListEditableReorderControlNode?
    
    private var item: ProxySettingsServerItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil {
            return false
        }
        return true
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.infoIconNode = ASImageNode()
        self.infoIconNode.isLayerBacked = true
        self.infoIconNode.displayWithoutProcessing = true
        self.infoIconNode.displaysAsynchronously = false
        
        self.checkNode = ASImageNode()
        self.checkNode.isLayerBacked = true
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.activityNode = ActivityIndicator(type: .custom(.blue, activitySize.width, 2.0, false))
        self.activityNode.isHidden = true
        
        self.activateArea = AccessibilityAreaNode()
        
        self.infoButtonNode = HighlightableButtonNode()
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.infoIconNode)
        self.addSubnode(self.activityNode)
        self.addSubnode(self.infoButtonNode)
        self.addSubnode(self.activateArea)
        
        self.infoButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.infoIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.infoIconNode.alpha = 0.4
                } else {
                    strongSelf.infoIconNode.alpha = 1.0
                    strongSelf.infoIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.infoButtonNode.addTarget(self, action: #selector(self.infoButtonPressed), forControlEvents: .touchUpInside)
        
        self.activateArea.activate = { [weak self] in
            self?.item?.action()
            return true
        }
    }
    
    func asyncLayout() -> (_ item: ProxySettingsServerItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updateInfoIconImage: UIImage?
            var updateCheckImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updateInfoIconImage = PresentationResourcesCallList.infoButton(item.theme)
            }
            
            if currentItem?.theme !== item.theme || currentItem?.color != item.color {
                switch item.color {
                    case .accent:
                        updateCheckImage = PresentationResourcesItemList.checkIconImage(item.theme)
                    case .secondary:
                        updateCheckImage = PresentationResourcesItemList.secondaryCheckIconImage(item.theme)
                }
            }
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.editing.editable {
                peerRevealOptions = [ItemListRevealOption(key: 0, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]
            } else {
                peerRevealOptions = []
            }
            
            let titleAttributedString = NSMutableAttributedString()
            titleAttributedString.append(NSAttributedString(string: urlEncodedStringFromString(item.server.host), font: titleFont, textColor: item.theme.list.itemPrimaryTextColor))
            titleAttributedString.append(NSAttributedString(string: ":\(item.server.port)", font: titleFont, textColor: item.theme.list.itemSecondaryTextColor))
            let statusAttributedString = NSAttributedString(string: item.label, font: statusFont, textColor: item.labelAccent ? item.theme.list.itemAccentColor : item.theme.list.itemSecondaryTextColor)
            
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            var reorderControlSizeAndApply: (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode)?
            
            let editingOffset: CGFloat
            var reorderInset: CGFloat = 0.0
            
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(item.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
                
                let reorderSizeAndApply = reorderControlLayout(item.theme)
                reorderControlSizeAndApply = reorderSizeAndApply
                reorderInset = reorderSizeAndApply.0
            } else {
                editingOffset = 0.0
            }
            
            let leftInset: CGFloat = 50.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset + max(reorderInset, 55.0)
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: 64.0)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.infoButtonNode.accessibilityLabel = item.strings.Conversation_Info
                    strongSelf.activateArea.accessibilityLabel = "\(titleAttributedString.string)\n\(statusAttributedString.string)"
                    if item.active {
                        strongSelf.activateArea.accessibilityValue = item.strings.ProxyServer_VoiceOver_Active
                    } else {
                        strongSelf.activateArea.accessibilityValue = ""
                    }
                    
                    if let updateInfoIconImage = updateInfoIconImage {
                        strongSelf.infoIconNode.image = updateInfoIconImage
                    }
                    if let updateCheckImage = updateCheckImage {
                        strongSelf.checkNode.image = updateCheckImage
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.activityNode.type = .custom(item.theme.list.itemAccentColor, activitySize.width, 2.0, false)
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: CGSize(width: editableControlSizeAndApply.0, height: layout.contentSize.height))
                        if strongSelf.editableControlNode == nil {
                            let editableControlNode = editableControlSizeAndApply.1(layout.contentSize.height)
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.titleNode)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        } else {
                            strongSelf.editableControlNode?.frame = editableControlFrame
                        }
                        strongSelf.editableControlNode?.isHidden = !item.editing.editable
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    if let reorderControlSizeAndApply = reorderControlSizeAndApply {
                        if strongSelf.reorderControlNode == nil {
                            let reorderControlNode = reorderControlSizeAndApply.1(layout.contentSize.height, false, .immediate)
                            strongSelf.reorderControlNode = reorderControlNode
                            strongSelf.addSubnode(reorderControlNode)
                            reorderControlNode.alpha = 0.0
                            transition.updateAlpha(node: reorderControlNode, alpha: 1.0)
                        }
                        let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderControlSizeAndApply.0, y: 0.0), size: CGSize(width: reorderControlSizeAndApply.0, height: layout.contentSize.height))
                        strongSelf.reorderControlNode?.frame = reorderControlFrame
                    } else if let reorderControlNode = strongSelf.reorderControlNode {
                        strongSelf.reorderControlNode = nil
                        transition.updateAlpha(node: reorderControlNode, alpha: 0.0, completion: { [weak reorderControlNode] _ in
                            reorderControlNode?.removeFromSupernode()
                        })
                    }
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.addSubnode(strongSelf.maskNode)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset + editingOffset
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 12.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 37.0), size: statusLayout.size))
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 0.0), size: CGSize(width: params.width - params.rightInset - 56.0 - (leftInset + revealOffset + editingOffset), height: layout.contentSize.height))
                    
                    transition.updateAlpha(node: strongSelf.infoIconNode, alpha: item.editing.editing ? 0.0 : 1.0)
                    
                    if let checkImage = strongSelf.checkNode.image {
                        transition.updateFrame(node: strongSelf.checkNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + floor((50.0 - checkImage.size.width) / 2.0), y: floor((layout.contentSize.height - checkImage.size.height) / 2.0)), size: checkImage.size))
                    }
                    transition.updateFrame(node: strongSelf.activityNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + floor((50.0 - activitySize.width) / 2.0), y: floor((layout.contentSize.height - activitySize.height) / 2.0)), size: activitySize))
                    strongSelf.checkNode.isHidden = !item.active || item.activity
                    strongSelf.activityNode.isHidden = !item.activity
                    
                    if let infoImage = strongSelf.infoIconNode.image {
                        transition.updateFrame(node: strongSelf.infoIconNode, frame: CGRect(origin: CGPoint(x: revealOffset + params.width - params.rightInset - 55.0 + floor((55.0 - infoImage.size.width) / 2.0), y: floor((layout.contentSize.height - infoImage.size.height) / 2.0)), size: infoImage.size))
                    }
                    
                    strongSelf.infoButtonNode.isUserInteractionEnabled = revealOffset.isZero && !item.editing.editing
                    strongSelf.infoButtonNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 55.0, y: 0.0), size: CGSize(width: 55.0, height: layout.contentSize.height))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
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
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let params = self.layoutParams else {
            return
        }
        
        let leftInset: CGFloat = 50.0 + params.leftInset
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + offset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + offset + editingOffset, y: self.statusNode.frame.minY), size: self.statusNode.bounds.size))
        
        var checkFrame = self.checkNode.frame
        checkFrame.origin.x = params.leftInset + offset + editingOffset + floor((50.0 - checkFrame.width) / 2.0)
        transition.updateFrame(node: self.checkNode, frame: checkFrame)
        
        var activityFrame = self.activityNode.frame
        activityFrame.origin.x = params.leftInset + offset + editingOffset + floor((50.0 - activityFrame.width) / 2.0)
        transition.updateFrame(node: self.activityNode, frame: activityFrame)
        
        var infoIconFrame = self.infoIconNode.frame
        infoIconFrame.origin.x = offset + params.width - params.rightInset - 55.0 + floor((55.0 - infoIconFrame.width) / 2.0)
        transition.updateFrame(node: self.infoIconNode, frame: infoIconFrame)
        
        self.infoButtonNode.isUserInteractionEnabled = offset.isZero
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.setServerWithRevealedOptions(item.server, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.setServerWithRevealedOptions(nil, item.server)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
         if let item = self.item {
            item.removeServer(item.server)
        }
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
        if let reorderControlNode = self.reorderControlNode, reorderControlNode.frame.contains(point), !self.isDisplayingRevealedOptions {
            return true
        }
        return false
    }
    
    @objc private func infoButtonPressed() {
        self.item?.infoAction()
    }
}
