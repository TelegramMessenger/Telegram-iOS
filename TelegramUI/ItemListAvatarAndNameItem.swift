import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

enum ItemListAvatarAndNameInfoItemName: Equatable {
    case personName(firstName: String, lastName: String)
    case title(title: String)
    
    init(_ name: PeerIndexNameRepresentation) {
        switch name {
            case let .personName(first, last, _):
                self = .personName(firstName: first, lastName: last)
            case let .title(title, _):
                self = .title(title: title)
        }
    }
    
    var composedTitle: String {
        switch self {
            case let .personName(firstName, lastName):
                if !firstName.isEmpty && !lastName.isEmpty {
                    return firstName + " " + lastName
                } else if !firstName.isEmpty {
                    return firstName
                } else {
                    return lastName
                }
            case let .title(title):
                return title
        }
    }
    
    var isEmpty: Bool {
        switch self {
            case let .personName(firstName, lastName):
                return firstName.isEmpty
            case let .title(title):
                return title.isEmpty
        }
    }
    
    static func ==(lhs: ItemListAvatarAndNameInfoItemName, rhs: ItemListAvatarAndNameInfoItemName) -> Bool {
        switch lhs {
            case let .personName(firstName, lastName):
                if case .personName(firstName, lastName) = rhs {
                    return true
                } else {
                    return false
                }
            case let .title(title):
                if case .title(title) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct ItemListAvatarAndNameInfoItemState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    let updatingName: ItemListAvatarAndNameInfoItemName?
    
    static func ==(lhs: ItemListAvatarAndNameInfoItemState, rhs: ItemListAvatarAndNameInfoItemState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.updatingName != rhs.updatingName {
            return false
        }
        return true
    }
}

class ItemListAvatarAndNameInfoItem: ListViewItem, ItemListItem {
    let account: Account
    let peer: Peer?
    let presence: PeerPresence?
    let cachedData: CachedPeerData?
    let state: ItemListAvatarAndNameInfoItemState
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let editingNameUpdated: (ItemListAvatarAndNameInfoItemName) -> Void
    
    init(account: Account, peer: Peer?, presence: PeerPresence?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, sectionId: ItemListSectionId, style: ItemListStyle, editingNameUpdated: @escaping (ItemListAvatarAndNameInfoItemName) -> Void) {
        self.account = account
        self.peer = peer
        self.presence = presence
        self.cachedData = cachedData
        self.state = state
        self.sectionId = sectionId
        self.style = style
        self.editingNameUpdated = editingNameUpdated
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListAvatarAndNameInfoItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(false) })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListAvatarAndNameInfoItemNode {
            var animated = true
            if case .None = animation {
                animated = false
            }
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
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

private let nameFont = Font.medium(19.0)
private let statusFont = Font.regular(15.0)

class ItemListAvatarAndNameInfoItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let nameNode: TextNode
    private let statusNode: TextNode
    
    private var inputSeparator: ASDisplayNode?
    private var inputFirstField: UITextField?
    private var inputSecondField: UITextField?
    
    private var item: ItemListAvatarAndNameInfoItem?
    private var layoutWidthAndNeighbors: (width: CGFloat, neighbors: ItemListNeighbors)?
    private var peerPresenceManager: PeerPresenceStatusManager?
    
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
        
        self.avatarNode = AvatarNode(font: Font.regular(28.0))
        
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
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let item = strongSelf.item, let layoutWidthAndNeighbors = strongSelf.layoutWidthAndNeighbors {
                let (_, apply) = strongSelf.asyncLayout()(item, layoutWidthAndNeighbors.0, layoutWidthAndNeighbors.1)
                apply(true)
            }
        })
    }
    
    func asyncLayout() -> (_ item: ItemListAvatarAndNameInfoItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let layoutNameNode = TextNode.asyncLayout(self.nameNode)
        let layoutStatusNode = TextNode.asyncLayout(self.statusNode)
        
        return { item, width, neighbors in
            let displayTitle: ItemListAvatarAndNameInfoItemName
            if let updatingName = item.state.updatingName {
                displayTitle = updatingName
            } else if let peer = item.peer {
                displayTitle = ItemListAvatarAndNameInfoItemName(peer.indexName)
            } else {
                displayTitle = .title(title: "")
            }
            
            let (nameNodeLayout, nameNodeApply) = layoutNameNode(NSAttributedString(string: displayTitle.composedTitle, font: nameFont, textColor: UIColor.black), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let statusText: String
            let statusColor: UIColor
            if let presence = item.presence as? TelegramUserPresence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                let (string, activity) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                statusText = string
                if activity {
                    statusColor = UIColor(0x007ee5)
                } else {
                    statusColor = UIColor(0xb3b3b3)
                }
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
            
            let (statusNodeLayout, statusNodeApply) = layoutStatusNode(NSAttributedString(string: statusText, font: statusFont, textColor: statusColor), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let separatorHeight = UIScreenPixel
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            switch item.style {
                case .plain:
                    contentSize = CGSize(width: width, height: 96.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
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
                    strongSelf.item = item
                    strongSelf.layoutWidthAndNeighbors = (width, neighbors)
                    
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
                    
                    /*if let _ = item.state.updatingName {
                        if !strongSelf.nameNode.alpha.isEqual(to: 0.5) {
                            strongSelf.nameNode.alpha = 0.5
                            if animated {
                                strongSelf.nameNode.layer.animateAlpha(from: 1.0, to: 0.5, duration: 0.4)
                            }
                        }
                    } else {
                        if !strongSelf.nameNode.alpha.isEqual(to: 1.0) {
                            strongSelf.nameNode.alpha = 1.0
                            if animated {
                                strongSelf.nameNode.layer.animateAlpha(from: 0.5, to: 1.0, duration: 0.4)
                            }
                        }
                    }*/
                    
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: peer)
                    }
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 15.0, y: avatarOriginY), size: CGSize(width: 66.0, height: 66.0))
                    strongSelf.nameNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0), size: nameNodeLayout.size)
                    
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: 94.0, y: 25.0 + nameNodeLayout.size.height + 4.0), size: statusNodeLayout.size)
                    
                    if let editingName = item.state.editingName {
                        var animateIn = false
                        if strongSelf.inputSeparator == nil {
                            animateIn = true
                        }
                        switch editingName {
                            case let .personName(firstName, lastName):
                                if strongSelf.inputSeparator == nil {
                                    let inputSeparator = ASDisplayNode()
                                    inputSeparator.backgroundColor = UIColor(0xc8c7cc)
                                    inputSeparator.isLayerBacked = true
                                    strongSelf.addSubnode(inputSeparator)
                                    strongSelf.inputSeparator = inputSeparator
                                }
                                
                                if strongSelf.inputFirstField == nil {
                                    let inputFirstField = TextFieldNodeView()
                                    inputFirstField.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
                                    //inputFirstField.backgroundColor = UIColor.lightGray
                                    inputFirstField.autocorrectionType = .no
                                    inputFirstField.attributedPlaceholder = NSAttributedString(string: "First Name", font: Font.regular(17.0), textColor: UIColor(0xc8c8ce))
                                    inputFirstField.attributedText = NSAttributedString(string: firstName, font: Font.regular(17.0), textColor: UIColor.black)
                                    strongSelf.inputFirstField = inputFirstField
                                    strongSelf.view.addSubview(inputFirstField)
                                    inputFirstField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputFirstField?.text != firstName {
                                    strongSelf.inputFirstField?.text = firstName
                                }
                                
                                if strongSelf.inputSecondField == nil {
                                    let inputSecondField = TextFieldNodeView()
                                    inputSecondField.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
                                    inputSecondField.autocorrectionType = .no
                                    inputSecondField.attributedPlaceholder = NSAttributedString(string: "Last Name", font: Font.regular(17.0), textColor: UIColor(0xc8c8ce))
                                    inputSecondField.attributedText = NSAttributedString(string: lastName, font: Font.regular(17.0), textColor: UIColor.black)
                                    strongSelf.inputSecondField = inputSecondField
                                    strongSelf.view.addSubview(inputSecondField)
                                    inputSecondField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputSecondField?.text != lastName {
                                    strongSelf.inputSecondField?.text = lastName
                                }
                                
                                strongSelf.inputSeparator?.frame = CGRect(origin: CGPoint(x: 100.0, y: 46.0), size: CGSize(width: width - 100.0, height: separatorHeight))
                                strongSelf.inputFirstField?.frame = CGRect(origin: CGPoint(x: 111.0, y: 12.0), size: CGSize(width: width - 111.0 - 8.0, height: 30.0))
                                strongSelf.inputSecondField?.frame = CGRect(origin: CGPoint(x: 111.0, y: 52.0), size: CGSize(width: width - 111.0 - 8.0, height: 30.0))
                                
                                if animated && animateIn {
                                    strongSelf.inputSeparator?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputFirstField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputSecondField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                }
                            case let .title(title):
                                if strongSelf.inputSeparator == nil {
                                    let inputSeparator = ASDisplayNode()
                                    inputSeparator.backgroundColor = UIColor(0xc8c7cc)
                                    inputSeparator.isLayerBacked = true
                                    strongSelf.addSubnode(inputSeparator)
                                    strongSelf.inputSeparator = inputSeparator
                                }
                                
                                if strongSelf.inputFirstField == nil {
                                    let inputFirstField = TextFieldNodeView()
                                    inputFirstField.typingAttributes = [NSFontAttributeName: Font.regular(19.0)]
                                    //inputFirstField.backgroundColor = UIColor.lightGray
                                    inputFirstField.autocorrectionType = .no
                                    inputFirstField.attributedPlaceholder = NSAttributedString(string: "Title", font: Font.regular(19.0), textColor: UIColor(0xc8c8ce))
                                    inputFirstField.attributedText = NSAttributedString(string: title, font: Font.regular(19.0), textColor: UIColor.black)
                                    strongSelf.inputFirstField = inputFirstField
                                    strongSelf.view.addSubview(inputFirstField)
                                    inputFirstField.addTarget(self, action: #selector(strongSelf.textFieldDidChange(_:)), for: .editingChanged)
                                } else if strongSelf.inputFirstField?.text != title {
                                    strongSelf.inputFirstField?.text = title
                                }
                                
                                strongSelf.inputSeparator?.frame = CGRect(origin: CGPoint(x: 100.0, y: 62.0), size: CGSize(width: width - 100.0, height: separatorHeight))
                                strongSelf.inputFirstField?.frame = CGRect(origin: CGPoint(x: 102.0, y: 26.0), size: CGSize(width: width - 102.0 - 8.0, height: 35.0))
                                
                                if animated && animateIn {
                                    strongSelf.inputSeparator?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                    strongSelf.inputFirstField?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                }
                        }
                        
                        if animated && animateIn {
                            strongSelf.statusNode.layer.animateAlpha(from: CGFloat(strongSelf.statusNode.layer.opacity), to: 0.0, duration: 0.3)
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.nameNode.layer.animateAlpha(from: CGFloat(strongSelf.nameNode.layer.opacity), to: 0.0, duration: 0.3)
                            strongSelf.nameNode.alpha = 0.0
                        } else {
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.nameNode.alpha = 0.0
                        }
                    } else {
                        var animateOut = false
                        if let inputSeparator = strongSelf.inputSeparator {
                            animateOut = true
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
                                    inputFirstField?.removeFromSuperview()
                                })
                            } else {
                                inputFirstField.removeFromSuperview()
                            }
                        }
                        if let inputSecondField = strongSelf.inputSecondField {
                            strongSelf.inputSecondField = nil
                            if animated {
                                inputSecondField.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak inputSecondField] _ in
                                    inputSecondField?.removeFromSuperview()
                                })
                            } else {
                                inputSecondField.removeFromSuperview()
                            }
                        }
                        if animated && animateOut {
                            strongSelf.statusNode.layer.animateAlpha(from: CGFloat(strongSelf.statusNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.nameNode.layer.animateAlpha(from: CGFloat(strongSelf.nameNode.layer.opacity), to: 1.0, duration: 0.3)
                            strongSelf.nameNode.alpha = 1.0
                        } else {
                            strongSelf.statusNode.alpha = 1.0
                            strongSelf.nameNode.alpha = 1.0
                        }
                    }
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                }
            })
        }
    }
    
    @objc func textFieldDidChange(_ inputField: UITextField) {
        if let item = self.item {
            var editingName: ItemListAvatarAndNameInfoItemName?
            if let inputFirstField = self.inputFirstField, let inputSecondField = self.inputSecondField {
                editingName = .personName(firstName: inputFirstField.text ?? "", lastName: inputSecondField.text ?? "")
            } else if let inputFirstField = self.inputFirstField {
                editingName = .title(title: inputFirstField.text ?? "")
            }
            if let editingName = editingName {
                item.editingNameUpdated(editingName)
            }
        }
    }
}
