import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import SwitchNode
import AppBundle
import CheckNode

public enum ItemListExpandableSwitchItemNodeType {
    case regular
    case icon
}

public class ItemListExpandableSwitchItem: ListViewItem, ItemListItem {
    public struct SubItem: Equatable {
        public var id: AnyHashable
        public var title: String
        public var isSelected: Bool
        public var isEnabled: Bool
        
        public init(
            id: AnyHashable,
            title: String,
            isSelected: Bool,
            isEnabled: Bool
        ) {
            self.id = id
            self.title = title
            self.isSelected = isSelected
            self.isEnabled = isEnabled
        }
    }
    
    let presentationData: ItemListPresentationData
    let icon: UIImage?
    let title: String
    let value: Bool
    let isExpanded: Bool
    let subItems: [SubItem]
    let type: ItemListExpandableSwitchItemNodeType
    let enableInteractiveChanges: Bool
    let enabled: Bool
    let displayLocked: Bool
    let disableLeadingInset: Bool
    let maximumNumberOfLines: Int
    let noCorners: Bool
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let updated: (Bool) -> Void
    let activatedWhileDisabled: () -> Void
    let selectAction: () -> Void
    let subAction: (SubItem) -> Void
    public let tag: ItemListItemTag?
    
    public let selectable: Bool = true
    
    public init(presentationData: ItemListPresentationData, icon: UIImage? = nil, title: String, value: Bool, isExpanded: Bool, subItems: [SubItem], type: ItemListExpandableSwitchItemNodeType = .regular, enableInteractiveChanges: Bool = true, enabled: Bool = true, displayLocked: Bool = false, disableLeadingInset: Bool = false, maximumNumberOfLines: Int = 1, noCorners: Bool = false, sectionId: ItemListSectionId, style: ItemListStyle, updated: @escaping (Bool) -> Void, activatedWhileDisabled: @escaping () -> Void = {}, selectAction: @escaping () -> Void, subAction: @escaping (SubItem) -> Void, tag: ItemListItemTag? = nil) {
        self.presentationData = presentationData
        self.icon = icon
        self.title = title
        self.value = value
        self.isExpanded = isExpanded
        self.subItems = subItems
        self.type = type
        self.enableInteractiveChanges = enableInteractiveChanges
        self.enabled = enabled
        self.displayLocked = displayLocked
        self.disableLeadingInset = disableLeadingInset
        self.maximumNumberOfLines = maximumNumberOfLines
        self.noCorners = noCorners
        self.sectionId = sectionId
        self.style = style
        self.updated = updated
        self.activatedWhileDisabled = activatedWhileDisabled
        self.selectAction = selectAction
        self.subAction = subAction
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListExpandableSwitchItemNode(type: self.type)
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(ListViewItemUpdateAnimation.None) })
                })
            }
        }
    }
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        self.selectAction()
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListExpandableSwitchItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
}

private final class SubItemNode: HighlightTrackingButtonNode {
    private let textNode: ImmediateTextNode
    private var checkNode: CheckNode?
    private let separatorNode: ASDisplayNode
    
    private var theme: PresentationTheme?
    private var item: ItemListExpandableSwitchItem.SubItem?
    private var action: ((ItemListExpandableSwitchItem.SubItem) -> Void)?
    
    init() {
        self.textNode = ImmediateTextNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.textNode)
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressed() {
        guard let item = self.item, item.isEnabled, let action = self.action else {
            return
        }
        action(item)
    }
    
    func update(presentationData: ItemListPresentationData, item: ItemListExpandableSwitchItem.SubItem, action: @escaping (ItemListExpandableSwitchItem.SubItem) -> Void, size: CGSize, transition: ContainedViewLayoutTransition) {
        let themeUpdated = self.theme !== presentationData.theme
        
        self.item = item
        self.action = action
        
        let leftInset: CGFloat = 60.0
        
        if themeUpdated {
            self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        }
        
        let checkNode: CheckNode
        if let current = self.checkNode {
            checkNode = current
            if themeUpdated {
                checkNode.theme = CheckNodeTheme(theme: presentationData.theme, style: .plain)
            }
        } else {
            checkNode = CheckNode(theme: CheckNodeTheme(theme: presentationData.theme, style: .plain))
            checkNode.isUserInteractionEnabled = false
            self.checkNode = checkNode
            self.addSubnode(checkNode)
        }
        
        let checkSize = CGSize(width: 22.0, height: 22.0)
        checkNode.frame = CGRect(origin: CGPoint(x: floor((leftInset - checkSize.width) / 2.0), y: floor((size.height - checkSize.height) / 2.0)), size: checkSize)
        
        checkNode.setSelected(item.isSelected, animated: transition.isAnimated)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: leftInset, y: size.height - UIScreenPixel), size: CGSize(width: size.width - leftInset, height: UIScreenPixel)))
        
        self.textNode.attributedText = NSAttributedString(string: item.title, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        let titleSize = self.textNode.updateLayout(CGSize(width: size.width - leftInset, height: 100.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
        
        self.alpha = item.isEnabled ? 1.0 : 0.5
    }
}

public class ItemListExpandableSwitchItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomTopStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    private let titleValueNode: TextNode
    private let expandArrowNode: ASImageNode
    private var switchNode: ASDisplayNode & ItemListSwitchNodeImpl
    private let switchGestureNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    private var lockedIconNode: ASImageNode?
    
    private let subItemContainer: ASDisplayNode
    private var subItemNodes: [AnyHashable: SubItemNode] = [:]
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListExpandableSwitchItem?
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init(type: ItemListExpandableSwitchItemNodeType) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomTopStripeNode = ASDisplayNode()
        self.bottomTopStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        switch type {
            case .regular:
                self.switchNode = SwitchNode()
            case .icon:
                self.switchNode = IconSwitchNode()
        }
        
        self.titleValueNode = TextNode()
        self.titleValueNode.isUserInteractionEnabled = false
        
        self.expandArrowNode = ASImageNode()
        self.expandArrowNode.displaysAsynchronously = false
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.switchGestureNode = ASDisplayNode()
        
        self.activateArea = AccessibilityAreaNode()
        
        self.subItemContainer = ASDisplayNode()
        self.subItemContainer.clipsToBounds = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.titleValueNode)
        self.addSubnode(self.expandArrowNode)
        self.addSubnode(self.switchNode)
        self.addSubnode(self.switchGestureNode)
        self.addSubnode(self.activateArea)
        self.addSubnode(self.subItemContainer)
        
        self.activateArea.activate = { [weak self] in
            guard let strongSelf = self, let item = strongSelf.item, item.enabled else {
                return false
            }
            let value = !strongSelf.switchNode.isOn
            if item.enableInteractiveChanges {
                strongSelf.switchNode.setOn(value, animated: true)
            }
            item.updated(value)
            return true
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        (self.switchNode.view as? UISwitch)?.addTarget(self, action: #selector(self.switchValueChanged(_:)), for: .valueChanged)
        self.switchGestureNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func asyncLayout() -> (_ item: ItemListExpandableSwitchItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTitleValueLayout = TextNode.asyncLayout(self.titleValueNode)
        
        let currentItem = self.item
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        return { item, params, neighbors in
            var contentSize: CGSize
            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            var updateIcon = false
            if currentItem?.icon != item.icon {
                updateIcon = true
            }
            
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                contentSize = CGSize(width: params.width, height: 44.0)
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                contentSize = CGSize(width: params.width, height: 44.0)
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            var leftInset = 16.0 + params.leftInset
            if let _ = item.icon {
                leftInset += 43.0
            }
            
            if item.disableLeadingInset {
                insets.top = 0.0
                insets.bottom = 0.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: item.maximumNumberOfLines, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - params.rightInset - 64.0 - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleValue = "\(item.subItems.filter(\.isSelected).count)/\(item.subItems.count)"
            let (titleValueLayout, titleValueApply) = makeTitleValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: titleValue, font: Font.bold(14.0), textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - params.rightInset - 64.0 - titleLayout.size.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            contentSize.height = max(contentSize.height, titleLayout.size.height + 22.0)
            
            let mainContentHeight = contentSize.height
            var effectiveSubItemsHeight: CGFloat = 0.0
            if item.isExpanded {
                effectiveSubItemsHeight = CGFloat(item.subItems.count) * 44.0
            }
            contentSize.height += effectiveSubItemsHeight
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: mainContentHeight))
                    
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.accessibilityValue = item.value ? item.presentationData.strings.VoiceOver_Common_On : item.presentationData.strings.VoiceOver_Common_Off
                    strongSelf.activateArea.accessibilityHint = item.presentationData.strings.VoiceOver_Common_SwitchHint
                    var accessibilityTraits = UIAccessibilityTraits()
                    if item.enabled {
                    } else {
                        accessibilityTraits.insert(.notEnabled)
                    }
                    strongSelf.activateArea.accessibilityTraits = accessibilityTraits
                    
                    if let icon = item.icon {
                        if strongSelf.iconNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconNode)
                        }
                        if updateIcon {
                            strongSelf.iconNode.image = icon
                        }
                        let iconY = floor((mainContentHeight - icon.size.height) / 2.0)
                        strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((leftInset - params.leftInset - icon.size.width) / 2.0), y: iconY), size: icon.size)
                    } else if strongSelf.iconNode.supernode != nil {
                        strongSelf.iconNode.image = nil
                        strongSelf.iconNode.removeFromSupernode()
                    }
                    
                    let transition: ContainedViewLayoutTransition = animation.transition
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.insertSubnode(currentDisabledOverlayNode, belowSubnode: strongSelf.switchGestureNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: mainContentHeight - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: mainContentHeight - separatorHeight)))
                        }
                        currentDisabledOverlayNode.backgroundColor = itemBackgroundColor.withAlphaComponent(0.6)
                    } else if let disabledOverlayNode = strongSelf.disabledOverlayNode {
                        transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                            disabledOverlayNode?.removeFromSupernode()
                        })
                        strongSelf.disabledOverlayNode = nil
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomTopStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        
                        strongSelf.switchNode.frameColor = item.presentationData.theme.list.itemSwitchColors.frameColor
                        strongSelf.switchNode.contentColor = item.presentationData.theme.list.itemSwitchColors.contentColor
                        strongSelf.switchNode.handleColor = item.presentationData.theme.list.itemSwitchColors.handleColor
                        strongSelf.switchNode.positiveContentColor = item.presentationData.theme.list.itemSwitchColors.positiveColor
                        strongSelf.switchNode.negativeContentColor = item.presentationData.theme.list.itemSwitchColors.negativeColor
                        
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    
                    switch item.style {
                        case .plain:
                            if strongSelf.backgroundNode.supernode != nil {
                                strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                            }
                            if strongSelf.bottomTopStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomTopStripeNode, at: 1)
                            }
                            if strongSelf.maskNode.supernode != nil {
                                strongSelf.maskNode.removeFromSupernode()
                            }
                            strongSelf.bottomTopStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: mainContentHeight - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: layout.contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                        case .blocks:
                            if strongSelf.backgroundNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                            }
                            if strongSelf.topStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                            }
                            if strongSelf.bottomTopStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomTopStripeNode, at: 3)
                            }
                            if strongSelf.maskNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.maskNode, aboveSubnode: strongSelf.switchGestureNode)
                            }
                            
                            let hasCorners = itemListHasRoundedBlockLayout(params) && !item.noCorners
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
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = leftInset
                                    strongSelf.bottomStripeNode.isHidden = false
                                    strongSelf.bottomTopStripeNode.isHidden = false
                                default:
                                    bottomStripeInset = 0.0
                                    hasBottomCorners = true
                                    strongSelf.bottomStripeNode.isHidden = hasCorners
                                    strongSelf.bottomTopStripeNode.isHidden = false
                            }
                            
                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                            
                            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            animation.animator.updateFrame(layer: strongSelf.backgroundNode.layer, frame: backgroundFrame, completion: nil)
                            animation.animator.updateFrame(layer: strongSelf.maskNode.layer, frame: backgroundFrame.insetBy(dx: params.leftInset, dy: 0.0), completion: nil)
                            animation.animator.updateFrame(layer: strongSelf.topStripeNode.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)), completion: nil)
                            animation.animator.updateFrame(layer: strongSelf.bottomTopStripeNode.layer, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: mainContentHeight - separatorHeight), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)), completion: nil)
                            animation.animator.updateFrame(layer: strongSelf.bottomStripeNode.layer, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)), completion: nil)
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((mainContentHeight - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    
                    let _ = titleValueApply()
                    strongSelf.titleValueNode.frame = CGRect(origin: CGPoint(x: strongSelf.titleNode.frame.maxX + 9.0, y: strongSelf.titleNode.frame.minY + floor((titleLayout.size.height - titleValueLayout.size.height) / 2.0)), size: titleValueLayout.size)
                    
                    if let updatedTheme {
                        strongSelf.expandArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/DisclosureArrow"), color: updatedTheme.list.itemPrimaryTextColor)
                    }
                    if let image = strongSelf.expandArrowNode.image {
                        strongSelf.expandArrowNode.position = CGPoint(x: strongSelf.titleValueNode.frame.maxX + 9.0, y: strongSelf.titleValueNode.frame.midY)
                        let scaleFactor: CGFloat = 0.8
                        strongSelf.expandArrowNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor))
                        transition.updateTransformRotation(node: strongSelf.expandArrowNode, angle: item.isExpanded ? CGFloat.pi * -0.5 : CGFloat.pi * 0.5)
                    }
                    
                    if let switchView = strongSelf.switchNode.view as? UISwitch {
                        if strongSelf.switchNode.bounds.size.width.isZero {
                            switchView.sizeToFit()
                        }
                        let switchSize = switchView.bounds.size
                        
                        strongSelf.switchNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - switchSize.width - 15.0, y: floor((mainContentHeight - switchSize.height) / 2.0)), size: switchSize)
                        strongSelf.switchGestureNode.frame = strongSelf.switchNode.frame
                        if switchView.isOn != item.value {
                            switchView.setOn(item.value, animated: animation.isAnimated)
                        }
                        switchView.isUserInteractionEnabled = item.enableInteractiveChanges
                    }
                    strongSelf.switchGestureNode.isHidden = item.enableInteractiveChanges && item.enabled
                    
                    if item.displayLocked {
                        var updateLockedIconImage = false
                        if let _ = updatedTheme {
                            updateLockedIconImage = true
                        }
                        
                        let lockedIconNode: ASImageNode
                        if let current = strongSelf.lockedIconNode {
                            lockedIconNode = current
                        } else {
                            updateLockedIconImage = true
                            lockedIconNode = ASImageNode()
                            strongSelf.lockedIconNode = lockedIconNode
                            strongSelf.insertSubnode(lockedIconNode, aboveSubnode: strongSelf.switchNode)
                        }
                        
                        if updateLockedIconImage, let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon"), color: item.presentationData.theme.list.itemSecondaryTextColor) {
                            lockedIconNode.image = image
                        }
                        
                        let switchFrame = strongSelf.switchNode.frame
                        
                        if let icon = lockedIconNode.image {
                            lockedIconNode.frame = CGRect(origin: CGPoint(x: switchFrame.minX + 10.0 + UIScreenPixel, y: switchFrame.minY + 9.0), size: icon.size)
                        }
                    } else if let lockedIconNode = strongSelf.lockedIconNode {
                        strongSelf.lockedIconNode = nil
                        lockedIconNode.removeFromSupernode()
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: 44.0 + UIScreenPixel + UIScreenPixel))
                    
                    animation.animator.updateFrame(layer: strongSelf.subItemContainer.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: mainContentHeight), size: CGSize(width: params.width, height: effectiveSubItemsHeight)), completion: nil)
                    
                    var validIds: [AnyHashable] = []
                    let subItemSize = CGSize(width: params.width - params.leftInset - params.rightInset, height: 44.0)
                    var nextSubItemPosition = CGPoint(x: params.leftInset, y: 0.0)
                    for subItem in item.subItems {
                        validIds.append(subItem.id)
                        
                        let subItemNode: SubItemNode
                        var subItemNodeTransition = transition
                        if let current = strongSelf.subItemNodes[subItem.id] {
                            subItemNode = current
                        } else {
                            subItemNodeTransition = .immediate
                            subItemNode = SubItemNode()
                            strongSelf.subItemNodes[subItem.id] = subItemNode
                            strongSelf.subItemContainer.addSubnode(subItemNode)
                        }
                        let subItemFrame = CGRect(origin: nextSubItemPosition, size: subItemSize)
                        subItemNode.update(presentationData: item.presentationData, item: subItem, action: item.subAction, size: subItemSize, transition: subItemNodeTransition)
                        subItemNodeTransition.updateFrame(node: subItemNode, frame: subItemFrame)
                        
                        nextSubItemPosition.y += subItemSize.height
                    }
                    var removeIds: [AnyHashable] = []
                    for (id, itemNode) in strongSelf.subItemNodes {
                        if !validIds.contains(id) {
                            removeIds.append(id)
                            itemNode.removeFromSupernode()
                        }
                    }
                    for id in removeIds {
                        strongSelf.subItemNodes.removeValue(forKey: id)
                    }
                }
            })
        }
    }
    
    override public func accessibilityActivate() -> Bool {
        guard let item = self.item else {
            return false
        }
        if !item.enabled {
            return false
        }
        if let switchNode = self.switchNode as? IconSwitchNode {
            switchNode.isOn = !switchNode.isOn
            item.updated(switchNode.isOn)
        } else if let switchNode = self.switchNode as? SwitchNode {
            switchNode.isOn = !switchNode.isOn
            item.updated(switchNode.isOn)
        }
        return true
    }
    
    override public func visibleForSelection(at point: CGPoint) -> Bool {
        if !self.canBeSelected {
            return false
        }
        if point.y > self.subItemContainer.frame.minY {
            return false
        }
        
        return true
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        var highlighted = highlighted
        if point.y > self.subItemContainer.frame.minY {
            highlighted = false
        }
        
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4, completion: { [weak self] _ in
            self?.layer.allowsGroupOpacity = false
        })
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc private func switchValueChanged(_ switchView: UISwitch) {
        if let item = self.item {
            let value = switchView.isOn
            item.updated(value)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if let item = self.item, let switchView = self.switchNode.view as? UISwitch, case .ended = recognizer.state {
            if item.enabled {
                let value = switchView.isOn
                item.updated(!value)
            } else {
                item.activatedWhileDisabled()
            }
        }
    }
}
