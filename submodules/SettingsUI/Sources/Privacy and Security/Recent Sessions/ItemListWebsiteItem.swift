import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import LocalizedPeerData
import AccountContext
import AppBundle

struct ItemListWebsiteItemEditing: Equatable {
    let editing: Bool
    let revealed: Bool
    
    static func ==(lhs: ItemListWebsiteItemEditing, rhs: ItemListWebsiteItemEditing) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.revealed != rhs.revealed {
            return false
        }
        return true
    }
}

final class ItemListWebsiteItem: ListViewItem, ItemListItem, ItemListRevealOptionsStatefulItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let systemStyle: ItemListSystemStyle
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let website: WebAuthorization
    let peer: EnginePeer?
    let enabled: Bool
    let editing: Bool
    let revealed: Bool
    let sectionId: ItemListSectionId
    let setSessionIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let removeSession: (Int64) -> Void
    let action: (() -> Void)?

    var hasActiveRevealOptions: Bool {
        return self.revealed
    }
    
    init(context: AccountContext, presentationData: ItemListPresentationData, systemStyle: ItemListSystemStyle, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, website: WebAuthorization, peer: EnginePeer?, enabled: Bool, editing: Bool, revealed: Bool, sectionId: ItemListSectionId, setSessionIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, removeSession: @escaping (Int64) -> Void, action: (() -> Void)?) {
        self.context = context
        self.presentationData = presentationData
        self.systemStyle = systemStyle
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.website = website
        self.peer = peer
        self.enabled = enabled
        self.editing = editing
        self.revealed = revealed
        self.sectionId = sectionId
        self.setSessionIdWithRevealedOptions = setSessionIdWithRevealedOptions
        self.removeSession = removeSession
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListWebsiteItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListWebsiteItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool = true
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        
        if self.enabled {
            self.action?()
        }
    }
}

private let avatarFont = avatarPlaceholderFont(size: 13.0)

private func trimmedLocationName(_ session: WebAuthorization) -> String {
    var country = session.region
    country = country.replacingOccurrences(of: "United Arab Emirates", with: "UAE")
    return country
}


class ItemListWebsiteItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    private let maskNode: ASImageNode
    
    let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let appNode: TextNode
    private let locationNode: TextNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    private let activateArea: AccessibilityAreaNode
    
    private var layoutParams: (ItemListWebsiteItem, ListViewItemLayoutParams, ItemListNeighbors)?
    
    private var editableControlNode: ItemListEditableControlNode?
    private var isHighlighted = false
    
    override public var canBeSelected: Bool {
        if let item = self.layoutParams?.0, let _ = item.action {
            return true
        } else {
            return false
        }
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
        
        self.containerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.cornerRadius = 7.0
        self.avatarNode.clipsToBounds = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.appNode = TextNode()
        self.appNode.isUserInteractionEnabled = false
        self.appNode.contentMode = .left
        self.appNode.contentsScale = UIScreen.main.scale
        
        self.locationNode = TextNode()
        self.locationNode.isUserInteractionEnabled = false
        self.locationNode.contentMode = .left
        self.locationNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.appNode)
        self.containerNode.addSubnode(self.locationNode)
        
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: ItemListWebsiteItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeAppLayout = TextNode.asyncLayout(self.appNode)
        let makeLocationLayout = TextNode.asyncLayout(self.locationNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.medium(floor(item.presentationData.fontSize.itemListBaseFontSize * 17.0 / 17.0))
            let textFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            
            let verticalInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 1.0
            let textSpacing: CGFloat = 2.0
            
            if currentItem?.presentationData !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            var titleAttributedString: NSAttributedString?
            var appAttributedString: NSAttributedString?
            var locationAttributedString: NSAttributedString?
            
            let peerRevealOptions = [ItemListRevealOption(key: 0, title: item.presentationData.strings.AuthSessions_LogOut, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, iconColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor, textColor: item.presentationData.theme.list.itemSecondaryTextColor)]
            
            let rightInset: CGFloat = params.rightInset
            
            if let peer = item.peer, case .user = peer {
                titleAttributedString = NSAttributedString(string: peer.displayTitle(strings: item.presentationData.strings, displayOrder: item.nameDisplayOrder), font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            }
            
            var appString = ""
            if !item.website.domain.isEmpty {
                appString = item.website.domain
            }
            
            if !item.website.browser.isEmpty {
                if !appString.isEmpty {
                    appString += ", "
                }
                appString += item.website.browser
            }
            
            if !item.website.platform.isEmpty {
                if !appString.isEmpty {
                    appString += ", "
                }
                appString += item.website.platform
            }
            
            appAttributedString = NSAttributedString(string: appString, font: textFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let label = stringForRelativeActivityTimestamp(strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, relativeTimestamp: item.website.dateActive, relativeTo: timestamp)
            
            locationAttributedString = NSAttributedString(string: "\(trimmedLocationName(item.website)) • \(label)", font: textFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 59.0 + params.leftInset
            
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            
            let editingOffset: CGFloat
            if item.editing {
                let sizeAndApply = editableControlLayout(item.presentationData.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
            } else {
                editingOffset = 0.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 16.0 - editingOffset - rightInset - 5.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (appLayout, appApply) = makeAppLayout(TextNodeLayoutArguments(attributedString: appAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (locationLayout, locationApply) = makeLocationLayout(TextNodeLayoutArguments(attributedString: locationAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + titleSpacing + appLayout.size.height + textSpacing + locationLayout.size.height - 4.0)
            let separatorHeight = UIScreenPixel
            let separatorRightInset: CGFloat = item.systemStyle == .glass ? 16.0 : 0.0
            
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
                    strongSelf.layoutParams = (item, params, neighbors)
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    
                    strongSelf.activateArea.accessibilityLabel = titleAttributedString?.string ?? ""
                    
                    var value = ""
                    if let string = appAttributedString?.string {
                        value += string
                    }
                    if let string = locationAttributedString?.string {
                        if !value.isEmpty {
                            value += "\n"
                        }
                        value += string
                    }
                    strongSelf.activateArea.accessibilityValue = value
                    
                    if item.enabled {
                        strongSelf.activateArea.accessibilityTraits = []
                    } else {
                        strongSelf.activateArea.accessibilityTraits = .notEnabled
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, authorOfMessage: nil, overrideImage: nil, emptyColor: nil, clipStyle: .none, synchronousLoad: false)
                    }
                    
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
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.containerNode)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        } else {
                            strongSelf.editableControlNode?.frame = editableControlFrame
                        }
                        strongSelf.editableControlNode?.isHidden = false
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
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.addSubnode(strongSelf.maskNode)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    let topStripeIsHidden: Bool
                    switch neighbors.top {
                        case .sameSection(false):
                            topStripeIsHidden = true
                        default:
                            hasTopCorners = true
                            topStripeIsHidden = hasCorners
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    let bottomStripeIsHidden: Bool
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset + editingOffset
                            bottomStripeOffset = -separatorHeight
                            bottomStripeIsHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            bottomStripeIsHidden = hasCorners
                    }
                    strongSelf.updateRevealOptionsSeparatorNodes(top: strongSelf.topStripeNode, bottom: strongSelf.bottomStripeNode, topIsHidden: topStripeIsHidden, bottomIsHidden: bottomStripeIsHidden, topHiddenByPreviousRevealOptions: neighbors.topHasActiveRevealOptions, bottomHiddenByNextRevealOptions: neighbors.bottomHasActiveRevealOptions)
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: item.systemStyle == .glass) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: strongSelf.backgroundNode.frame.size)
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset - params.rightInset - separatorRightInset, height: separatorHeight)))
                    
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 16.0, y: 15.0), size: CGSize(width: 30.0, height: 30.0)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: verticalInset - 2.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.appNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: appLayout.size))
                    transition.updateFrame(node: strongSelf.locationNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: strongSelf.appNode.frame.maxY + textSpacing), size: locationLayout.size))
                    
                    strongSelf.updateRevealOptionsHighlightedBackgroundFrame(strongSelf.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight))), transition: transition)
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.revealed, animated: animated)
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        self.isHighlighted = highlighted && (self.layoutParams?.0.enabled ?? false)
        self.updateRevealOptionsHighlightedBackgroundNode(self.highlightedBackgroundNode, isHighlighted: self.isHighlighted || self.isRevealOptionsActive, transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate, aboveNodes: [self.bottomStripeNode, self.topStripeNode, self.backgroundNode])
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let params = self.layoutParams?.1 else {
            return
        }
        
        let leftInset: CGFloat = 59.0 + params.leftInset
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + self.revealOffset + editingOffset + 16.0, y: self.avatarNode.frame.minY), size: self.avatarNode.bounds.size))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + self.revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.appNode, frame: CGRect(origin: CGPoint(x: leftInset + self.revealOffset + editingOffset, y: self.appNode.frame.minY), size: self.appNode.bounds.size))
        transition.updateFrame(node: self.locationNode, frame: CGRect(origin: CGPoint(x: leftInset + self.revealOffset + editingOffset, y: self.locationNode.frame.minY), size: self.locationNode.bounds.size))
    }

    override func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        super.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)

        self.updateRevealOptionsHighlightedBackgroundNode(self.highlightedBackgroundNode, isHighlighted: self.isHighlighted || self.isRevealOptionsActive, transition: transition, aboveNodes: [self.bottomStripeNode, self.topStripeNode, self.backgroundNode])
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let (item, _, _) = self.layoutParams {
            item.setSessionIdWithRevealedOptions(item.website.hash, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let (item, _, _) = self.layoutParams {
            item.setSessionIdWithRevealedOptions(nil, item.website.hash)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let (item, _, _) = self.layoutParams {
            item.removeSession(item.website.hash)
        }
    }
}

final class ItemListConnectedBotSessionItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let systemStyle: ItemListSystemStyle
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let bot: TelegramAccountConnectedBot
    let peer: EnginePeer?
    let enabled: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    
    init(
        context: AccountContext,
        presentationData: ItemListPresentationData,
        systemStyle: ItemListSystemStyle,
        dateTimeFormat: PresentationDateTimeFormat,
        nameDisplayOrder: PresentationPersonNameOrder,
        bot: TelegramAccountConnectedBot,
        peer: EnginePeer?,
        enabled: Bool,
        sectionId: ItemListSectionId,
        action: (() -> Void)?
    ) {
        self.context = context
        self.presentationData = presentationData
        self.systemStyle = systemStyle
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.bot = bot
        self.peer = peer
        self.enabled = enabled
        self.sectionId = sectionId
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListConnectedBotSessionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListConnectedBotSessionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                let animated: Bool
                if case .None = animation {
                    animated = false
                } else {
                    animated = true
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool = true
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        if self.enabled {
            self.action?()
        }
    }
}

private final class ItemListConnectedBotSessionItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    private let maskNode: ASImageNode
    
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let appNode: TextNode
    private let locationNode: TextNode
    
    private let containerNode: ASDisplayNode
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    private let activateArea: AccessibilityAreaNode
    
    private var layoutParams: (ItemListConnectedBotSessionItem, ListViewItemLayoutParams, ItemListNeighbors)?
    private var isHighlighted = false
    
    override public var canBeSelected: Bool {
        if let item = self.layoutParams?.0, let _ = item.action {
            return true
        } else {
            return false
        }
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
        
        self.containerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.cornerRadius = 7.0
        self.avatarNode.clipsToBounds = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.appNode = TextNode()
        self.appNode.isUserInteractionEnabled = false
        self.appNode.contentMode = .left
        self.appNode.contentsScale = UIScreen.main.scale
        
        self.locationNode = TextNode()
        self.locationNode.isUserInteractionEnabled = false
        self.locationNode.contentMode = .left
        self.locationNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.appNode)
        self.containerNode.addSubnode(self.locationNode)
        
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: ItemListConnectedBotSessionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeAppLayout = TextNode.asyncLayout(self.appNode)
        let makeLocationLayout = TextNode.asyncLayout(self.locationNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 17.0 / 17.0))
            let textFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
        
            let verticalInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 1.0
            let textSpacing: CGFloat = 2.0
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let titleString = item.peer?.displayTitle(strings: item.presentationData.strings, displayOrder: item.nameDisplayOrder) ?? "Bot"
            let titleAttributedString = NSAttributedString(string: titleString, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            
            let appAttributedString = NSAttributedString(
                string: item.presentationData.strings.RecentSession_ConnectedBot_Subtitle,
                font: textFont,
                textColor: item.presentationData.theme.list.itemPrimaryTextColor
            )
            
            let timeString: String
            if let date = item.bot.date {
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                timeString = stringForRelativeActivityTimestamp(strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, relativeTimestamp: date, relativeTo: timestamp)
            } else {
                timeString = ""
            }
            let locationAttributedString = NSAttributedString(string: item.presentationData.strings.RecentSessions_ConnectedBot_ConnectedTime(timeString).string, font: textFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let rightInset: CGFloat = params.rightInset
            let leftInset: CGFloat = 59.0 + params.leftInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 16.0 - rightInset - 5.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (appLayout, appApply) = makeAppLayout(TextNodeLayoutArguments(attributedString: appAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (locationLayout, locationApply) = makeLocationLayout(TextNodeLayoutArguments(attributedString: locationAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + titleSpacing + appLayout.size.height + textSpacing + locationLayout.size.height  - 4.0)
            let separatorHeight = UIScreenPixel
            let separatorRightInset: CGFloat = item.systemStyle == .glass ? 16.0 : 0.0
            
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
                guard let self else {
                    return
                }
                
                self.layoutParams = (item, params, neighbors)
                
                self.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                self.activateArea.accessibilityLabel = titleAttributedString.string
                
                var accessibilityValue = appAttributedString.string
                if !locationAttributedString.string.isEmpty {
                    accessibilityValue += "\n\(locationAttributedString.string)"
                }
                self.activateArea.accessibilityValue = accessibilityValue
                self.activateArea.accessibilityTraits = item.enabled ? [] : .notEnabled
                
                if let updatedTheme {
                    let _ = updatedTheme
                    self.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    self.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    self.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    self.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                }
                
                if let peer = item.peer {
                    self.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, authorOfMessage: nil, overrideImage: nil, emptyColor: nil, clipStyle: .none, synchronousLoad: false)
                    self.avatarNode.alpha = 1.0
                } else {
                    self.avatarNode.alpha = 0.0
                }
                
                let transition: ContainedViewLayoutTransition
                if animated {
                    transition = .animated(duration: 0.4, curve: .spring)
                } else {
                    transition = .immediate
                }
                
                if let currentDisabledOverlayNode {
                    if currentDisabledOverlayNode != self.disabledOverlayNode {
                        self.disabledOverlayNode = currentDisabledOverlayNode
                        self.addSubnode(currentDisabledOverlayNode)
                        currentDisabledOverlayNode.alpha = 0.0
                        transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                        currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                    } else {
                        transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
                    }
                } else if let disabledOverlayNode = self.disabledOverlayNode {
                    transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                        disabledOverlayNode?.removeFromSupernode()
                    })
                    self.disabledOverlayNode = nil
                }
                
                let _ = titleApply()
                let _ = appApply()
                let _ = locationApply()
                
                if self.backgroundNode.supernode == nil {
                    self.insertSubnode(self.backgroundNode, at: 0)
                }
                if self.topStripeNode.supernode == nil {
                    self.insertSubnode(self.topStripeNode, at: 1)
                }
                if self.bottomStripeNode.supernode == nil {
                    self.insertSubnode(self.bottomStripeNode, at: 2)
                }
                if self.maskNode.supernode == nil {
                    self.addSubnode(self.maskNode)
                }
                
                let hasCorners = itemListHasRoundedBlockLayout(params)
                var hasTopCorners = false
                var hasBottomCorners = false
                let topStripeIsHidden: Bool
                switch neighbors.top {
                case .sameSection(false):
                    topStripeIsHidden = true
                default:
                    hasTopCorners = true
                    topStripeIsHidden = hasCorners
                }
                let bottomStripeInset: CGFloat
                let bottomStripeOffset: CGFloat
                let bottomStripeIsHidden: Bool
                switch neighbors.bottom {
                case .sameSection(false):
                    bottomStripeInset = leftInset
                    bottomStripeOffset = -separatorHeight
                    bottomStripeIsHidden = false
                default:
                    bottomStripeInset = 0.0
                    bottomStripeOffset = 0.0
                    hasBottomCorners = true
                    bottomStripeIsHidden = hasCorners
                }
                self.updateRevealOptionsSeparatorNodes(top: self.topStripeNode, bottom: self.bottomStripeNode, topIsHidden: topStripeIsHidden, bottomIsHidden: bottomStripeIsHidden, topHiddenByPreviousRevealOptions: neighbors.topHasActiveRevealOptions, bottomHiddenByNextRevealOptions: neighbors.bottomHasActiveRevealOptions)
                
                self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: item.systemStyle == .glass) : nil
                
                self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                self.containerNode.frame = CGRect(origin: CGPoint(), size: self.backgroundNode.frame.size)
                self.maskNode.frame = self.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                transition.updateFrame(node: self.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                transition.updateFrame(node: self.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset - params.rightInset - separatorRightInset, height: separatorHeight)))
                
                transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + 16.0, y: 15.0), size: CGSize(width: 30.0, height: 30.0)))
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset - 2.0), size: titleLayout.size))
                transition.updateFrame(node: self.appNode, frame: CGRect(origin: CGPoint(x: leftInset, y: self.titleNode.frame.maxY + titleSpacing), size: appLayout.size))
                transition.updateFrame(node: self.locationNode, frame: CGRect(origin: CGPoint(x: leftInset, y: self.appNode.frame.maxY + textSpacing), size: locationLayout.size))
                
                self.updateRevealOptionsHighlightedBackgroundFrame(self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight))), transition: transition)
                self.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                self.setRevealOptions((left: [], right: []))
            })
        }
    }

    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)

        self.isHighlighted = highlighted && (self.layoutParams?.0.enabled ?? false)
        self.updateRevealOptionsHighlightedBackgroundNode(self.highlightedBackgroundNode, isHighlighted: self.isHighlighted || self.isRevealOptionsActive, transition: (animated && !highlighted) ? .animated(duration: 0.4, curve: .easeInOut) : .immediate, aboveNodes: [self.bottomStripeNode, self.topStripeNode, self.backgroundNode])
    }

    override func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        super.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)

        self.updateRevealOptionsHighlightedBackgroundNode(self.highlightedBackgroundNode, isHighlighted: self.isHighlighted || self.isRevealOptionsActive, transition: transition, aboveNodes: [self.bottomStripeNode, self.topStripeNode, self.backgroundNode])
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
