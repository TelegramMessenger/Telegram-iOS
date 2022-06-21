import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import SwitchNode

public enum ItemListSwitchItemNodeType {
    case regular
    case icon
}

public class ItemListSwitchItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: String
    let value: Bool
    let type: ItemListSwitchItemNodeType
    let enableInteractiveChanges: Bool
    let enabled: Bool
    let disableLeadingInset: Bool
    let maximumNumberOfLines: Int
    let noCorners: Bool
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let updated: (Bool) -> Void
    let activatedWhileDisabled: () -> Void
    public let tag: ItemListItemTag?
    
    public init(presentationData: ItemListPresentationData, title: String, value: Bool, type: ItemListSwitchItemNodeType = .regular, enableInteractiveChanges: Bool = true, enabled: Bool = true, disableLeadingInset: Bool = false, maximumNumberOfLines: Int = 1, noCorners: Bool = false, sectionId: ItemListSectionId, style: ItemListStyle, updated: @escaping (Bool) -> Void, activatedWhileDisabled: @escaping () -> Void = {}, tag: ItemListItemTag? = nil) {
        self.presentationData = presentationData
        self.title = title
        self.value = value
        self.type = type
        self.enableInteractiveChanges = enableInteractiveChanges
        self.enabled = enabled
        self.disableLeadingInset = disableLeadingInset
        self.maximumNumberOfLines = maximumNumberOfLines
        self.noCorners = noCorners
        self.sectionId = sectionId
        self.style = style
        self.updated = updated
        self.activatedWhileDisabled = activatedWhileDisabled
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListSwitchItemNode(type: self.type)
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListSwitchItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            var animated = true
                            if case .None = animation {
                                animated = false
                            }
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
}

private protocol ItemListSwitchNodeImpl {
    var frameColor: UIColor { get set }
    var contentColor: UIColor { get set }
    var handleColor: UIColor { get set }
    var positiveContentColor: UIColor { get set }
    var negativeContentColor: UIColor { get set }
    
    var isOn: Bool { get }
    func setOn(_ value: Bool, animated: Bool)
}

extension SwitchNode: ItemListSwitchNodeImpl {
    var positiveContentColor: UIColor {
        get {
            return .white
        } set(value) {
            
        }
    }
    var negativeContentColor: UIColor {
        get {
            return .white
        } set(value) {
            
        }
    }
}

extension IconSwitchNode: ItemListSwitchNodeImpl {
}

public class ItemListSwitchItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let titleNode: TextNode
    private var switchNode: ASDisplayNode & ItemListSwitchNodeImpl
    private let switchGestureNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListSwitchItem?
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init(type: ItemListSwitchItemNodeType) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        switch type {
            case .regular:
                self.switchNode = SwitchNode()
            case .icon:
                self.switchNode = IconSwitchNode()
        }
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.switchGestureNode = ASDisplayNode()
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.switchNode)
        self.addSubnode(self.switchGestureNode)
        self.addSubnode(self.activateArea)
        
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
    
    func asyncLayout() -> (_ item: ItemListSwitchItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
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
            
            if item.disableLeadingInset {
                insets.top = 0.0
                insets.bottom = 0.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: item.maximumNumberOfLines, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 80.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            contentSize.height = max(contentSize.height, titleLayout.size.height + 22.0)
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    
                    strongSelf.activateArea.accessibilityLabel = item.title
                    strongSelf.activateArea.accessibilityValue = item.value ? item.presentationData.strings.VoiceOver_Common_On : item.presentationData.strings.VoiceOver_Common_Off
                    strongSelf.activateArea.accessibilityHint = item.presentationData.strings.VoiceOver_Common_SwitchHint
                    var accessibilityTraits = UIAccessibilityTraits()
                    if item.enabled {
                    } else {
                        accessibilityTraits.insert(.notEnabled)
                    }
                    strongSelf.activateArea.accessibilityTraits = accessibilityTraits
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.insertSubnode(currentDisabledOverlayNode, belowSubnode: strongSelf.switchGestureNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
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
                    
                    let leftInset = 16.0 + params.leftInset
                    
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
                            if strongSelf.maskNode.supernode != nil {
                                strongSelf.maskNode.removeFromSupernode()
                            }
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
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
                                    bottomStripeInset = 16.0 + params.leftInset
                                    strongSelf.bottomStripeNode.isHidden = false
                                default:
                                    bottomStripeInset = 0.0
                                    hasBottomCorners = true
                                    strongSelf.bottomStripeNode.isHidden = hasCorners
                            }
                            
                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                            
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    if let switchView = strongSelf.switchNode.view as? UISwitch {
                        if strongSelf.switchNode.bounds.size.width.isZero {
                            switchView.sizeToFit()
                        }
                        let switchSize = switchView.bounds.size
                        
                        strongSelf.switchNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - switchSize.width - 15.0, y: floor((contentSize.height - switchSize.height) / 2.0)), size: switchSize)
                        strongSelf.switchGestureNode.frame = strongSelf.switchNode.frame
                        if switchView.isOn != item.value {
                            switchView.setOn(item.value, animated: animated)
                        }
                        switchView.isUserInteractionEnabled = item.enableInteractiveChanges
                    }
                    strongSelf.switchGestureNode.isHidden = item.enableInteractiveChanges && item.enabled
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: 44.0 + UIScreenPixel + UIScreenPixel))
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
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
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
