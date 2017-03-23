import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

struct ItemListRecentSessionItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
    
    static func ==(lhs: ItemListRecentSessionItemEditing, rhs: ItemListRecentSessionItemEditing) -> Bool {
        if lhs.editable != rhs.editable {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.revealed != rhs.revealed {
            return false
        }
        return true
    }
}

enum ItemListRecentSessionItemText {
    case presence
    case text(String)
    case none
}

final class ItemListRecentSessionItem: ListViewItem, ItemListItem {
    let session: RecentAccountSession
    let enabled: Bool
    let editable: Bool
    let editing: Bool
    let revealed: Bool
    let sectionId: ItemListSectionId
    let setSessionIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let removeSession: (Int64) -> Void
    
    init(session: RecentAccountSession, enabled: Bool, editable: Bool, editing: Bool, revealed: Bool, sectionId: ItemListSectionId, setSessionIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, removeSession: @escaping (Int64) -> Void) {
        self.session = session
        self.enabled = enabled
        self.editable = editable
        self.editing = editing
        self.revealed = revealed
        self.sectionId = sectionId
        self.setSessionIdWithRevealedOptions = setSessionIdWithRevealedOptions
        self.removeSession = removeSession
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListRecentSessionItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(false) })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListRecentSessionItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
}

private let titleFont = Font.medium(15.0)
private let textFont = Font.regular(13.0)

class ItemListRecentSessionItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    private let titleNode: TextNode
    private let appNode: TextNode
    private let locationNode: TextNode
    private let labelNode: TextNode
    
    private var layoutParams: (ItemListRecentSessionItem, CGFloat, ItemListNeighbors)?
    
    private var editableControlNode: ItemListEditableControlNode?
    
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
        
        self.appNode = TextNode()
        self.appNode.isLayerBacked = true
        self.appNode.contentMode = .left
        self.appNode.contentsScale = UIScreen.main.scale
        
        self.locationNode = TextNode()
        self.locationNode.isLayerBacked = true
        self.locationNode.contentMode = .left
        self.locationNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.appNode)
        self.addSubnode(self.locationNode)
        self.addSubnode(self.labelNode)
    }
    
    func asyncLayout() -> (_ item: ItemListRecentSessionItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeAppLayout = TextNode.asyncLayout(self.appNode)
        let makeLocationLayout = TextNode.asyncLayout(self.locationNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        return { item, width, neighbors in
            var titleAttributedString: NSAttributedString?
            var appAttributedString: NSAttributedString?
            var locationAttributedString: NSAttributedString?
            var labelAttributedString: NSAttributedString?
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.editable && item.enabled {
                peerRevealOptions = [ItemListRevealOption(key: 0, title: "Terminate", icon: nil, color: UIColor(0xff3824))]
            } else {
                peerRevealOptions = []
            }
            
            let rightInset: CGFloat = 0.0
            
            titleAttributedString = NSAttributedString(string: "\(item.session.appName) \(item.session.appVersion)", font: titleFont, textColor: UIColor.black)
            
            var appString = ""
            if !item.session.deviceModel.isEmpty {
                appString = item.session.deviceModel
            }
            
            if !item.session.platform.isEmpty {
                if !appString.isEmpty {
                    appString += ", "
                }
                appString += item.session.platform
            }
            
            if !item.session.systemVersion.isEmpty {
                if !appString.isEmpty {
                    appString += ", "
                }
                appString += item.session.systemVersion
            }
            
            appAttributedString = NSAttributedString(string: appString, font: textFont, textColor: UIColor.black)
            locationAttributedString = NSAttributedString(string: "\(item.session.ip) — \(item.session.country)", font: textFont, textColor: UIColor(0x6d6d6d))
            if item.session.isCurrent {
                labelAttributedString = NSAttributedString(string: "online", font: textFont, textColor: UIColor(0x007ee5))
            } else {
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                let dateText = stringForRelativeTimestamp(item.session.activityDate, relativeTo: timestamp)
                labelAttributedString = NSAttributedString(string: dateText, font: textFont, textColor: UIColor(0x6d6d6d))
            }
            
            let leftInset: CGFloat = 15.0
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            
            let editingOffset: CGFloat
            if item.editing {
                let sizeAndApply = editableControlLayout(75.0)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0.width
            } else {
                editingOffset = 0.0
            }
            
            let (labelLayout, labelApply) = makeLabelLayout(labelAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - editingOffset - rightInset - labelLayout.size.width - 5.0, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            let (appLayout, appApply) = makeAppLayout(appAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            let (locationLayout, locationApply) = makeLocationLayout(locationAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            let contentSize = CGSize(width: width, height: 75.0)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                    currentDisabledOverlayNode?.backgroundColor = UIColor(white: 1.0, alpha: 0.5)
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, width, neighbors)
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.addSubnode(currentDisabledOverlayNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
                        }
                    } else if let disabledOverlayNode = strongSelf.disabledOverlayNode {
                        transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                            disabledOverlayNode?.removeFromSupernode()
                        })
                        strongSelf.disabledOverlayNode = nil
                    }
                    
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        if strongSelf.editableControlNode == nil {
                            let editableControlNode = editableControlSizeAndApply.1()
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.titleNode)
                            let editableControlFrame = CGRect(origin: CGPoint(x: revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: editableControlFrame.midX - editableControlFrame.size.width, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        }
                        strongSelf.editableControlNode?.isHidden = !item.editable
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    let _ = labelApply()
                    let _ = titleApply()
                    let _ = appApply()
                    let _ = locationApply()
                    
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
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset + editingOffset
                            bottomStripeOffset = -separatorHeight
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.labelNode, frame: CGRect(origin: CGPoint(x: revealOffset + width - labelLayout.size.width - 15.0 - rightInset, y: 10.0), size: labelLayout.size))
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 10.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.appNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 30.0), size: appLayout.size))
                    transition.updateFrame(node: strongSelf.locationNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 50.0), size: locationLayout.size))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: 75.0 + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.setRevealOptions(peerRevealOptions)
                    strongSelf.setRevealOptionsOpened(item.revealed, animated: animated)
                }
            })
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
        
        let leftInset: CGFloat = 15.0
        let width = self.bounds.size.width
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: revealOffset + width - self.labelNode.bounds.size.width - 15.0, y: self.labelNode.frame.minY), size: self.labelNode.bounds.size))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.appNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.appNode.frame.minY), size: self.appNode.bounds.size))
        transition.updateFrame(node: self.locationNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.locationNode.frame.minY), size: self.locationNode.bounds.size))
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let (item, _, _) = self.layoutParams {
            item.setSessionIdWithRevealedOptions(item.session.hash, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let (item, _, _) = self.layoutParams {
            item.setSessionIdWithRevealedOptions(nil, item.session.hash)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let (item, _, _) = self.layoutParams {
            item.removeSession(item.session.hash)
        }
    }
}
