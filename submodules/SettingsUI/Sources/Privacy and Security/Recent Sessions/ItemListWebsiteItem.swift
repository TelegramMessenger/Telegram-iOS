import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import LocalizedPeerData
import AccountContext

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

final class ItemListWebsiteItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let website: WebAuthorization
    let peer: Peer?
    let enabled: Bool
    let editing: Bool
    let revealed: Bool
    let sectionId: ItemListSectionId
    let setSessionIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let removeSession: (Int64) -> Void
    let action: (() -> Void)?
    
    init(context: AccountContext, presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, website: WebAuthorization, peer: Peer?, enabled: Bool, editing: Bool, revealed: Bool, sectionId: ItemListSectionId, setSessionIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, removeSession: @escaping (Int64) -> Void, action: (() -> Void)?) {
        self.context = context
        self.presentationData = presentationData
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
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListWebsiteItemNode()
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
            if let nodeValue = node() as? ItemListWebsiteItemNode {
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
    
    public var selectable: Bool = true
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        
        if self.enabled {
            self.action?()
        }
    }
}

private let avatarFont = avatarPlaceholderFont(size: 11.0)

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
    
    private var layoutParams: (ItemListWebsiteItem, ListViewItemLayoutParams, ItemListNeighbors)?
    
    private var editableControlNode: ItemListEditableControlNode?
    
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
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.appNode)
        self.containerNode.addSubnode(self.locationNode)
    }
    
    func asyncLayout() -> (_ item: ItemListWebsiteItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeAppLayout = TextNode.asyncLayout(self.appNode)
        let makeLocationLayout = TextNode.asyncLayout(self.locationNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        let currentItem = self.layoutParams?.0
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.medium(floor(item.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            let textFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            if currentItem?.presentationData !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            var titleAttributedString: NSAttributedString?
            var appAttributedString: NSAttributedString?
            var locationAttributedString: NSAttributedString?
            
            let peerRevealOptions = [ItemListRevealOption(key: 0, title: item.presentationData.strings.AuthSessions_LogOut, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]
            
            let rightInset: CGFloat = params.rightInset
            
            if let user = item.peer as? TelegramUser {
                titleAttributedString = NSAttributedString(string: EnginePeer(user).displayTitle(strings: item.presentationData.strings, displayOrder: item.nameDisplayOrder), font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
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
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset - 5.0 - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (appLayout, appApply) = makeAppLayout(TextNodeLayoutArguments(attributedString: appAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (locationLayout, locationApply) = makeLocationLayout(TextNodeLayoutArguments(attributedString: locationAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: 75.0)
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
                    strongSelf.layoutParams = (item, params, neighbors)
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(peer), authorOfMessage: nil, overrideImage: nil, emptyColor: nil, clipStyle: .none, synchronousLoad: false)
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
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: strongSelf.backgroundNode.frame.size)
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    
                    transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 16.0, y: 12.0), size: CGSize(width: 30.0, height: 30.0)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 10.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.appNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 30.0), size: appLayout.size))
                    transition.updateFrame(node: strongSelf.locationNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 50.0), size: locationLayout.size))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.revealed, animated: animated)
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted && (self.layoutParams?.0.enabled ?? false) {
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
