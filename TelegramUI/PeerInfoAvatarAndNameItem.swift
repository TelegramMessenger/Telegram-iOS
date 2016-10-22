import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

struct PeerInfoAvatarAndNameItemEditingState: Equatable {
    static func ==(lhs: PeerInfoAvatarAndNameItemEditingState, rhs: PeerInfoAvatarAndNameItemEditingState) -> Bool {
        return true
    }
}

class PeerInfoAvatarAndNameItem: ListViewItem, PeerInfoItem {
    let account: Account
    let peer: Peer?
    let cachedData: CachedPeerData?
    let editingState: PeerInfoAvatarAndNameItemEditingState?
    let sectionId: PeerInfoItemSectionId
    let style: PeerInfoListStyle
    
    init(account: Account, peer: Peer?, cachedData: CachedPeerData?, editingState: PeerInfoAvatarAndNameItemEditingState?, sectionId: PeerInfoItemSectionId, style: PeerInfoListStyle) {
        self.account = account
        self.peer = peer
        self.cachedData = cachedData
        self.editingState = editingState
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = PeerInfoAvatarAndNameItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply(false)
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? PeerInfoAvatarAndNameItemNode {
            var animated = true
            if case .None = animation {
                animated = false
            }
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
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
        
    }
}

private let nameFont = Font.medium(19.0)
private let statusFont = Font.regular(15.0)

class PeerInfoAvatarAndNameItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let nameNode: TextNode
    private let statusNode: TextNode
    
    private var inputSeparator: ASDisplayNode?
    private var inputFirstField: ASEditableTextNode?
    private var inputSecondField: ASEditableTextNode?
    
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
        
        self.avatarNode = AvatarNode(font: Font.regular(20.0))
        
        self.nameNode = TextNode()
        self.nameNode.isLayerBacked = true
        self.nameNode.contentMode = .left
        self.nameNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.nameNode)
        self.addSubnode(self.statusNode)
    }
    
    func asyncLayout() -> (_ item: PeerInfoAvatarAndNameItem, _ width: CGFloat, _ neighbors: PeerInfoItemNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let layoutNameNode = TextNode.asyncLayout(self.nameNode)
        let layoutStatusNode = TextNode.asyncLayout(self.statusNode)
        
        return { item, width, neighbors in
            let (nameNodeLayout, nameNodeApply) = layoutNameNode(NSAttributedString(string: item.peer?.displayTitle ?? "", font: nameFont, textColor: UIColor.black), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let statusText: String
            let statusColor: UIColor
            if let user = item.peer as? TelegramUser {
                statusText = "online"
                statusColor = UIColor(0x007ee5)
            } else if let channel = item.peer as? TelegramChannel {
                if let cachedChannelData = item.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                    statusText = "\(memberCount) members"
                    statusColor = UIColor(0xb3b3b3)
                } else {
                    switch channel.info {
                        case .broadcast:
                            statusText = "channel"
                            statusColor = UIColor(0xb3b3b3)
                        case .group:
                            statusText = "group"
                            statusColor = UIColor(0xb3b3b3)
                    }
                }
            } else if let group = item.peer as? TelegramGroup {
                statusText = "\(group.participantCount) members"
                statusColor = UIColor(0xb3b3b3)
            } else {
                statusText = ""
                statusColor = UIColor.black
            }
            
            let (statusNodeLayout, statusNodeApply) = layoutStatusNode(NSAttributedString(string: statusText, font: statusFont, textColor: statusColor), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let separatorHeight = UIScreenPixel
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            switch item.style {
                case .plain:
                    contentSize = CGSize(width: width, height: 96.0)
                    insets = peerInfoItemNeighborsPlainInsets(neighbors)
                case .blocks:
                    contentSize = CGSize(width: width, height: 92.0)
                    let topInset: CGFloat
                    switch neighbors.top {
                        case .sameSection, .none:
                            topInset = 0.0
                        case .otherSection:
                            topInset = separatorHeight + 35.0
                    }
                    insets = UIEdgeInsets(top: topInset, left: 0.0, bottom: separatorHeight, right: 0.0)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    let avatarOriginY: CGFloat
                    switch item.style {
                        case .plain:
                            avatarOriginY = 15.0
                            
                            if strongSelf.backgroundNode.supernode != nil {
                               strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode != nil {
                                strongSelf.bottomStripeNode.removeFromSupernode()
                            }
                        case .blocks:
                            avatarOriginY = 13.0
                            
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
                                case .sameSection:
                                    strongSelf.topStripeNode.isHidden = true
                                case .none, .otherSection:
                                    strongSelf.topStripeNode.isHidden = false
                            }
                            
                            let bottomStripeInset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection:
                                    bottomStripeInset = 16.0
                                case .none, .otherSection:
                                    bottomStripeInset = 0.0
                            }
                        
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top), size: CGSize(width: width, height: layoutSize.height))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: layoutSize.height - insets.top - separatorHeight), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let _ = nameNodeApply()
                    let _ = statusNodeApply()
                    
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: peer)
                    }
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 15.0, y: avatarOriginY), size: CGSize(width: 66.0, height: 66.0))
                    strongSelf.nameNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0), size: nameNodeLayout.size)
                    
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0 + nameNodeLayout.size.height + 4.0), size: statusNodeLayout.size)
                    
                    if let editingState = item.editingState {
                        if let user = item.peer as? TelegramUser {
                            if strongSelf.inputSeparator == nil {
                                let inputSeparator = ASDisplayNode()
                                inputSeparator.backgroundColor = UIColor(0xc8c7cc)
                                inputSeparator.isLayerBacked = true
                                strongSelf.addSubnode(inputSeparator)
                                strongSelf.inputSeparator = inputSeparator
                            }
                            
                            if strongSelf.inputFirstField == nil {
                                let inputFirstField = ASEditableTextNode()
                                inputFirstField.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
                                //inputFirstField.backgroundColor = UIColor.lightGray
                                inputFirstField.attributedPlaceholderText = NSAttributedString(string: "First Name", font: Font.regular(17.0), textColor: UIColor(0xc8c8ce))
                                inputFirstField.attributedText = NSAttributedString(string: user.firstName ?? "", font: Font.regular(17.0), textColor: UIColor.black)
                                strongSelf.inputFirstField = inputFirstField
                                strongSelf.view.addSubnode(inputFirstField)
                            }
                            
                            if strongSelf.inputSecondField == nil {
                                let inputSecondField = ASEditableTextNode()
                                inputSecondField.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
                                //inputSecondField.backgroundColor = UIColor.lightGray
                                inputSecondField.attributedPlaceholderText = NSAttributedString(string: "Last Name", font: Font.regular(17.0), textColor: UIColor(0xc8c8ce))
                                inputSecondField.attributedText = NSAttributedString(string: user.lastName ?? "", font: Font.regular(17.0), textColor: UIColor.black)
                                strongSelf.inputSecondField = inputSecondField
                                strongSelf.view.addSubnode(inputSecondField)
                            }
                            
                            strongSelf.inputSeparator?.frame = CGRect(origin: CGPoint(x: 100.0, y: 49.0), size: CGSize(width: width - 100.0, height: separatorHeight))
                            strongSelf.inputFirstField?.frame = CGRect(origin: CGPoint(x: 111.0, y: 16.0), size: CGSize(width: width - 111.0 - 8.0, height: 30.0))
                            strongSelf.inputSecondField?.frame = CGRect(origin: CGPoint(x: 111.0, y: 59.0), size: CGSize(width: width - 111.0 - 8.0, height: 30.0))
                            
                            if animated {
                                strongSelf.inputSeparator?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                strongSelf.inputFirstField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                strongSelf.inputSecondField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                            }
                        }
                        
                        if animated {
                            strongSelf.statusNode.layer.animateAlpha(from: CGFloat(strongSelf.statusNode.layer.opacity), to: 0.0, duration: 0.3)
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.nameNode.layer.animateAlpha(from: CGFloat(strongSelf.nameNode.layer.opacity), to: 0.0, duration: 0.3)
                            strongSelf.nameNode.alpha = 0.0
                        } else {
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.nameNode.alpha = 0.0
                        }
                    } else {
                        if let inputSeparator = strongSelf.inputSeparator {
                            strongSelf.inputSeparator = nil
                            
                            if animated {
                                inputSeparator.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputSeparator] _ in
                                    inputSeparator?.removeFromSupernode()
                                })
                            } else {
                                inputSeparator.removeFromSupernode()
                            }
                        }
                        if let inputFirstField = strongSelf.inputFirstField {
                            strongSelf.inputFirstField = nil
                            if animated {
                                inputFirstField.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputFirstField] _ in
                                    inputFirstField?.removeFromSupernode()
                                })
                            } else {
                                inputFirstField.removeFromSupernode()
                            }
                        }
                        if let inputSecondField = strongSelf.inputSecondField {
                            strongSelf.inputSecondField = nil
                            if animated {
                                inputSecondField.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputSecondField] _ in
                                    inputSecondField?.removeFromSupernode()
                                })
                            } else {
                                inputSecondField.removeFromSupernode()
                            }
                        }
                        if animated {
                            strongSelf.statusNode.layer.animateAlpha(from: CGFloat(strongSelf.statusNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.nameNode.layer.animateAlpha(from: CGFloat(strongSelf.nameNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.nameNode.alpha = 1.0
                        } else {
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.nameNode.alpha = 1.0
                        }
                    }
                }
            })
        }
    }
}
