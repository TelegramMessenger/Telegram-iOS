import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

struct ItemListPeerItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
    
    static func ==(lhs: ItemListPeerItemEditing, rhs: ItemListPeerItemEditing) -> Bool {
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

enum ItemListPeerItemText {
    case presence
    case text(String)
    case none
}

final class ItemListPeerItem: ListViewItem, ItemListItem {
    let account: Account
    let peer: Peer
    let presence: PeerPresence?
    let text: ItemListPeerItemText
    let label: String?
    let editing: ItemListPeerItemEditing
    let switchValue: Bool?
    let enabled: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    let toggleUpdated: ((Bool) -> Void)?
    
    init(account: Account, peer: Peer, presence: PeerPresence?, text: ItemListPeerItemText, label: String?, editing: ItemListPeerItemEditing, switchValue: Bool?, enabled: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void, toggleUpdated: ((Bool) -> Void)? = nil) {
        self.account = account
        self.peer = peer
        self.presence = presence
        self.text = text
        self.label = label
        self.editing = editing
        self.switchValue = switchValue
        self.enabled = enabled
        self.sectionId = sectionId
        self.action = action
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.toggleUpdated = toggleUpdated
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListPeerItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (node.avatarNode.ready, { apply(false) })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListPeerItemNode {
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
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let titleFont = Font.regular(17.0)
private let titleBoldFont = Font.medium(17.0)
private let statusFont = Font.regular(14.0)
private let labelFont = Font.regular(13.0)
private let avatarFont = Font.regular(17.0)

class ItemListPeerItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    fileprivate let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let statusNode: TextNode
    private var switchNode: SwitchNode?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (ItemListPeerItem, CGFloat, ItemListNeighbors)?
    
    private var editableControlNode: ItemListEditableControlNode?
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil || self.disabledOverlayNode != nil {
            return false
        }
        if let item = self.layoutParams?.0, item.action != nil {
            return true
        } else {
            return false
        }
    }
    
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
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.labelNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2)
                apply(true)
            }
        })
    }
    
    func asyncLayout() -> (_ item: ItemListPeerItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        var currentSwitchNode = self.switchNode
        
        return { item, width, neighbors in
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var labelAttributedString: NSAttributedString?
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.editing.editable && item.enabled {
                peerRevealOptions = [ItemListRevealOption(key: 0, title: "Remove", icon: nil, color: UIColor(0xff3824))]
            } else {
                peerRevealOptions = []
            }
            
            var rightInset: CGFloat = 0.0
            let switchSize = CGSize(width: 51.0, height: 31.0)
            
            if let _ = item.switchValue {
                if currentSwitchNode == nil {
                    currentSwitchNode = SwitchNode()
                }
                rightInset += switchSize.width
            } else {
                currentSwitchNode = nil
            }
            
            if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    string.append(NSAttributedString(string: firstName, font: titleFont, textColor: .black))
                    string.append(NSAttributedString(string: " ", font: titleFont, textColor: .black))
                    string.append(NSAttributedString(string: lastName, font: titleBoldFont, textColor: .black))
                    titleAttributedString = string
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: UIColor.black)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: UIColor.black)
                } else {
                    titleAttributedString = NSAttributedString(string: "Deleted User", font: titleBoldFont, textColor: UIColor(0xa6a6a6))
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: UIColor.black)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: UIColor.black)
            }
            
            switch item.text {
                case .presence:
                    if let presence = item.presence as? TelegramUserPresence {
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        let (string, activity) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                        statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? UIColor(0x007ee5) : UIColor(0xa6a6a6))
                    } else {
                        statusAttributedString = NSAttributedString(string: "last seen recently", font: statusFont, textColor: UIColor(0xa6a6a6))
                    }
                case let .text(text):
                    statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: UIColor(0xa6a6a6))
                case .none:
                    break
            }
            
            if let label = item.label {
                labelAttributedString = NSAttributedString(string: label, font: labelFont, textColor: UIColor(0xa6a6a6))
            }
            
            let leftInset: CGFloat = 65.0
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            
            let editingOffset: CGFloat
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(48.0)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0.width
            } else {
                editingOffset = 0.0
            }
            
            let (labelLayout, labelApply) = makeLabelLayout(labelAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - labelLayout.size.width - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            let (statusLayout, statusApply) = makeStatusLayout(statusAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - (labelLayout.size.width > 0.0 ? (labelLayout.size.width) + 15.0 : 0.0) - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            let contentSize = CGSize(width: width, height: 48.0)
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
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.avatarNode)
                            let editableControlFrame = CGRect(origin: CGPoint(x: revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: editableControlFrame.midX - editableControlFrame.size.width, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
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
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    let _ = labelApply()
                    
                    strongSelf.labelNode.isHidden = labelAttributedString == nil
                    
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
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: statusAttributedString == nil ? 13.0 : 5.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 25.0), size: statusLayout.size))
                    
                    if let currentSwitchNode = currentSwitchNode {
                        if currentSwitchNode !== strongSelf.switchNode {
                            strongSelf.switchNode = currentSwitchNode
                            if let disabledOverlayNode = strongSelf.disabledOverlayNode, disabledOverlayNode.supernode != nil {
                                strongSelf.insertSubnode(currentSwitchNode, belowSubnode: disabledOverlayNode)
                            } else {
                                strongSelf.addSubnode(currentSwitchNode)
                            }
                            currentSwitchNode.valueUpdated = { value in
                                if let strongSelf = self {
                                    strongSelf.toggleUpdated(value)
                                }
                            }
                        }
                        currentSwitchNode.frame = CGRect(origin: CGPoint(x: revealOffset + width - switchSize.width - 15.0, y: floor((contentSize.height - switchSize.height) / 2.0)), size: switchSize)
                        if let switchValue = item.switchValue {
                            currentSwitchNode.setOn(switchValue, animated: animated)
                        }
                    } else if let switchNode = strongSelf.switchNode {
                        switchNode.removeFromSupernode()
                        strongSelf.switchNode = nil
                    }

                    transition.updateFrame(node: strongSelf.labelNode, frame: CGRect(origin: CGPoint(x: revealOffset + width - labelLayout.size.width - 15.0 - rightInset, y: floor((contentSize.height - labelLayout.size.height) / 2.0 - labelLayout.size.height / 10.0)), size: labelLayout.size))
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + 12.0, y: 4.0), size: CGSize(width: 40.0, height: 40.0)))
                    strongSelf.avatarNode.setPeer(account: item.account, peer: item.peer)
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: 48.0 + UIScreenPixel + UIScreenPixel))
                    
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                    
                    strongSelf.setRevealOptions(peerRevealOptions)
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
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
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        let leftInset: CGFloat = 65.0
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
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 25.0), size: self.statusNode.bounds.size))
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: revealOffset + width - self.labelNode.bounds.size.width - 15.0, y: floor((self.contentSize.height - self.labelNode.bounds.size.height) / 2.0 - self.labelNode.bounds.size.height / 10.0)), size: self.labelNode.bounds.size))
        
        transition.updateFrame(node: avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + 12.0, y: 4.0), size: CGSize(width: 40.0, height: 40.0)))
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let (item, _, _) = self.layoutParams {
            item.setPeerIdWithRevealedOptions(item.peer.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let (item, _, _) = self.layoutParams {
            item.setPeerIdWithRevealedOptions(nil, item.peer.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let (item, _, _) = self.layoutParams {
            item.removePeer(item.peer.id)
        }
    }
    
    private func toggleUpdated(_ value: Bool) {
        if let (item, _, _) = self.layoutParams {
            item.toggleUpdated?(value)
        }
    }
}
