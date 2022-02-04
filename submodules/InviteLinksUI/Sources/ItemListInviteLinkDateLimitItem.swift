import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData
import LegacyComponents
import ItemListUI
import PresentationDataUtils

enum InviteLinkTimeLimit: Equatable {
    case hour
    case day
    case week
    case unlimited
    case custom(Int32)
    
    init(position: Int) {
        switch position {
        case 0:
            self = .hour
        case 1:
            self = .day
        case 2:
            self = .week
        default:
            self = .unlimited
        }
    }
    
    var value: Int32? {
        switch self {
        case .hour:
            return 3600
        case .day:
            return 86400
        case .week:
            return 604800
        case .unlimited:
            return nil
        case let .custom(value):
            return value
        }
    }
    
    var position: Int {
        switch self {
        case .hour:
            return 0
        case .day:
            return 1
        case .week:
            return 2
        case .unlimited:
            return 3
        case let .custom(value):
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let relativeValue = value - currentTime
            if relativeValue < 3600 {
                return 0
            } else if relativeValue < 86400 {
                return 1
            } else if relativeValue < 604800 {
                return 2
            } else {
                return 3
            }
        }
    }
}

final class ItemListInviteLinkTimeLimitItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: InviteLinkTimeLimit
    let enabled: Bool
    let sectionId: ItemListSectionId
    let updated: (InviteLinkTimeLimit) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, value: InviteLinkTimeLimit, enabled: Bool, sectionId: ItemListSectionId, updated: @escaping (InviteLinkTimeLimit) -> Void) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.enabled = enabled
        self.sectionId = sectionId
        self.updated = updated
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListInviteLinkTimeLimitItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListInviteLinkTimeLimitItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

private final class ItemListInviteLinkTimeLimitItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let lowTextNode: TextNode
    private let mediumTextNode: TextNode
    private let highTextNode: TextNode
    private let unlimitedTextNode: TextNode
    private let customTextNode: TextNode
    private var sliderView: TGPhotoEditorSliderView?
    
    private var item: ItemListInviteLinkTimeLimitItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.lowTextNode = TextNode()
        self.lowTextNode.isUserInteractionEnabled = false
        self.lowTextNode.displaysAsynchronously = false
        
        self.mediumTextNode = TextNode()
        self.mediumTextNode.isUserInteractionEnabled = false
        self.mediumTextNode.displaysAsynchronously = false
        
        self.highTextNode = TextNode()
        self.highTextNode.isUserInteractionEnabled = false
        self.highTextNode.displaysAsynchronously = false
        
        self.unlimitedTextNode = TextNode()
        self.unlimitedTextNode.isUserInteractionEnabled = false
        self.unlimitedTextNode.displaysAsynchronously = false
      
        self.customTextNode = TextNode()
        self.customTextNode.isUserInteractionEnabled = false
        self.customTextNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.lowTextNode)
        self.addSubnode(self.mediumTextNode)
        self.addSubnode(self.highTextNode)
        self.addSubnode(self.unlimitedTextNode)
        self.addSubnode(self.customTextNode)
    }
    
    func updateSliderView() {
        if let sliderView = self.sliderView, let item = self.item {
            if case .custom = item.value {
                sliderView.maximumValue = 3.0 + 1
                sliderView.positionsCount = 4 + 1
            } else {
                sliderView.maximumValue = 3.0
                sliderView.positionsCount = 4
            }
            sliderView.value = CGFloat(item.value.position)
            
            sliderView.isUserInteractionEnabled = item.enabled
            sliderView.alpha = item.enabled ? 1.0 : 0.4
            sliderView.layer.allowsGroupOpacity = !item.enabled
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 2.0
        sliderView.lineSize = 4.0
        sliderView.dotSize = 5.0
        sliderView.minimumValue = 0.0
        sliderView.startValue = 0.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        if let item = self.item, case .custom = item.value {
            sliderView.maximumValue = 3.0 + 1
            sliderView.positionsCount = 4 + 1
        } else {
            sliderView.maximumValue = 3.0
            sliderView.positionsCount = 4
        }
        sliderView.useLinesForPositions = true
        if let item = self.item, let params = self.layoutParams {
            sliderView.value = CGFloat(item.value.position)
            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.startColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.trackColor = item.theme.list.itemAccentColor
            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
            
            sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
            sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
        }
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
        
        self.updateSliderView()
    }
    
    func asyncLayout() -> (_ item: ItemListInviteLinkTimeLimitItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeLowTextLayout = TextNode.asyncLayout(self.lowTextNode)
        let makeMediumTextLayout = TextNode.asyncLayout(self.mediumTextNode)
        let makeHighTextLayout = TextNode.asyncLayout(self.highTextNode)
        let makeUnlimitedTextLayout = TextNode.asyncLayout(self.unlimitedTextNode)
        let makeCustomTextLayout = TextNode.asyncLayout(self.customTextNode)
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let (lowTextLayout, lowTextApply) = makeLowTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: timeIntervalString(strings: item.strings, value: 3600), font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))

            let (mediumTextLayout, mediumTextApply) = makeMediumTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: timeIntervalString(strings: item.strings, value: 86400), font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (highTextLayout, highTextApply) = makeHighTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: timeIntervalString(strings: item.strings, value: 604800), font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (unlimitedTextLayout, unlimitedTextApply) = makeUnlimitedTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.InviteLink_Create_TimeLimitNoLimit, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let customTextString: String
            if case let .custom(value) = item.value {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                let relativeValue = value - currentTime
                if relativeValue > 0 {
                    customTextString = timeIntervalString(strings: item.strings, value: relativeValue)
                } else {
                    customTextString = ""
                }
            } else {
                customTextString = ""
            }
            
            let (customTextLayout, customTextApply) = makeCustomTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: customTextString, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            contentSize = CGSize(width: params.width, height: 88.0)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
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
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
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
                        bottomStripeInset = 0.0 //params.leftInset + 16.0
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
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    let _ = lowTextApply()
                    let _ = mediumTextApply()
                    let _ = highTextApply()
                    let _ = unlimitedTextApply()
                    let _ = customTextApply()
                    
                    var textNodes: [(TextNode, CGSize)] = [(strongSelf.lowTextNode, lowTextLayout.size),
                                                           (strongSelf.mediumTextNode, mediumTextLayout.size),
                                                           (strongSelf.highTextNode, highTextLayout.size),
                                                           (strongSelf.unlimitedTextNode, unlimitedTextLayout.size)]
                    if case .custom = item.value {
                        textNodes.insert((strongSelf.customTextNode, customTextLayout.size), at: item.value.position)
                    }
                    
                    let delta = (params.width - params.leftInset - params.rightInset - 18.0 * 2.0) / CGFloat(textNodes.count - 1)
                    for i in 0 ..< textNodes.count {
                        let (textNode, textSize) = textNodes[i]
                        
                        var position = params.leftInset + 18.0 + delta * CGFloat(i)
                        if i == textNodes.count - 1 {
                            position -= textSize.width
                        } else if i > 0 {
                            position -= textSize.width / 2.0
                        }
                        
                        textNode.frame = CGRect(origin: CGPoint(x: position, y: 15.0), size: textSize)
                    }
                    
                    if let sliderView = strongSelf.sliderView {
                        if themeUpdated {
                            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
                            sliderView.startColor = item.theme.list.itemSwitchColors.frameColor
                            sliderView.trackColor = item.theme.list.itemAccentColor
                            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
                        }
                        
                        sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
                        sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
                        
                        strongSelf.updateSliderView()
                    }
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
    
    @objc func sliderValueChanged() {
        guard let sliderView = self.sliderView else {
            return
        }
        
        let position = Int(sliderView.value)
        let value = InviteLinkTimeLimit(position: position)
        self.item?.updated(value)
    }
}

