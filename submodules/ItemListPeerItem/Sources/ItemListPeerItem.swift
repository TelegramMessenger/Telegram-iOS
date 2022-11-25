import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import PeerPresenceStatusManager
import ContextUI
import AccountContext
import ComponentFlow
import EmojiStatusComponent

private final class ShimmerEffectNode: ASDisplayNode {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageNodeContainer: ASDisplayNode
    private let imageNode: ASImageNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init() {
        self.imageNodeContainer = ASDisplayNode()
        self.imageNodeContainer.isLayerBacked = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.contentMode = .scaleToFill
        
        super.init()
        
        self.isLayerBacked = true
        self.clipsToBounds = true
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.addSubnode(self.imageNodeContainer)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor) {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        
        self.imageNode.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            }
        }
        
        if frameUpdated {
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 250.0
        self.imageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
        let animation = self.imageNode.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageNode.layer.add(animation, forKey: "shimmer")
    }
}

private final class LoadingShimmerNode: ASDisplayNode {
    enum Shape: Equatable {
        case circle(CGRect)
        case roundedRectLine(startPoint: CGPoint, width: CGFloat, diameter: CGFloat)
    }
    
    private let backgroundNode: ASDisplayNode
    private let effectNode: ShimmerEffectNode
    private let foregroundNode: ASImageNode
    
    private var currentShapes: [Shape] = []
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private var currentShimmeringColor: UIColor?
    private var currentSize = CGSize()
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        
        self.effectNode = ShimmerEffectNode()
        
        self.foregroundNode = ASImageNode()
        self.foregroundNode.displaysAsynchronously = false
        self.foregroundNode.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.foregroundNode)
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.effectNode.updateAbsoluteRect(rect, within: containerSize)
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor, shimmeringColor: UIColor, shapes: [Shape], size: CGSize) {
        if self.currentShapes == shapes, let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor), let currentShimmeringColor = self.currentShimmeringColor, currentShimmeringColor.isEqual(shimmeringColor), self.currentSize == size {
            return
        }
        
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        self.currentShimmeringColor = shimmeringColor
        self.currentShapes = shapes
        self.currentSize = size
        
        self.backgroundNode.backgroundColor = foregroundColor
        
        self.effectNode.update(backgroundColor: foregroundColor, foregroundColor: shimmeringColor)
        
        self.foregroundNode.image = generateImage(size, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.setBlendMode(.copy)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.setFillColor(UIColor.clear.cgColor)
            for shape in shapes {
                switch shape {
                case let .circle(frame):
                    context.fillEllipse(in: frame)
                case let .roundedRectLine(startPoint, width, diameter):
                    context.fillEllipse(in: CGRect(origin: startPoint, size: CGSize(width: diameter, height: diameter)))
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: startPoint.x + width - diameter, y: startPoint.y), size: CGSize(width: diameter, height: diameter)))
                    context.fill(CGRect(origin: CGPoint(x: startPoint.x + diameter / 2.0, y: startPoint.y), size: CGSize(width: width - diameter, height: diameter)))
                }
            }
        })
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.foregroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.effectNode.frame = CGRect(origin: CGPoint(), size: size)
    }
}

public struct ItemListPeerItemEditing: Equatable {
    public var editable: Bool
    public var editing: Bool
    public var canBeReordered: Bool
    public var revealed: Bool?
    
    public init(editable: Bool, editing: Bool, canBeReordered: Bool = false, revealed: Bool?) {
        self.editable = editable
        self.editing = editing
        self.canBeReordered = canBeReordered
        self.revealed = revealed
    }
}

public enum ItemListPeerItemHeight {
    case generic
    case peerList
}

public enum ItemListPeerItemText {
    public enum TextColor {
        case secondary
        case accent
        case constructive
    }
    
    case presence
    case text(String, TextColor)
    case none
}

public enum ItemListPeerItemLabelFont {
    case standard
    case custom(UIFont)
}

public enum ItemListPeerItemLabel {
    case none
    case text(String, ItemListPeerItemLabelFont)
    case disclosure(String)
    case badge(String)
}

public struct ItemListPeerItemSwitch {
    public var value: Bool
    public var style: ItemListPeerItemSwitchStyle
    
    public init(value: Bool, style: ItemListPeerItemSwitchStyle) {
        self.value = value
        self.style = style
    }
}

public enum ItemListPeerItemSwitchStyle {
    case standard
    case check
}

public enum ItemListPeerItemAliasHandling {
    case standard
    case threatSelfAsSaved
}

public enum ItemListPeerItemNameColor {
    case primary
    case secret
}

public enum ItemListPeerItemNameStyle {
    case distinctBold
    case plain
}

public enum ItemListPeerItemRevealOptionType {
    case neutral
    case warning
    case destructive
    case accent
}

public struct ItemListPeerItemRevealOption {
    public var type: ItemListPeerItemRevealOptionType
    public var title: String
    public var action: () -> Void
    
    public init(type: ItemListPeerItemRevealOptionType, title: String, action: @escaping () -> Void) {
        self.type = type
        self.title = title
        self.action = action
    }
}

public struct ItemListPeerItemRevealOptions {
    public var options: [ItemListPeerItemRevealOption]
    
    public init(options: [ItemListPeerItemRevealOption]) {
        self.options = options
    }
}

public struct ItemListPeerItemShimmering {
    public var alternationIndex: Int
    
    public init(alternationIndex: Int) {
        self.alternationIndex = alternationIndex
    }
}

public final class ItemListPeerItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peer: EnginePeer
    let threadInfo: EngineMessageHistoryThread.Info?
    let height: ItemListPeerItemHeight
    let aliasHandling: ItemListPeerItemAliasHandling
    let nameColor: ItemListPeerItemNameColor
    let nameStyle: ItemListPeerItemNameStyle
    let presence: EnginePeer.Presence?
    let text: ItemListPeerItemText
    let label: ItemListPeerItemLabel
    let editing: ItemListPeerItemEditing
    let revealOptions: ItemListPeerItemRevealOptions?
    let switchValue: ItemListPeerItemSwitch?
    let enabled: Bool
    let highlighted: Bool
    public let selectable: Bool
    public let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let removePeer: (EnginePeer.Id) -> Void
    let toggleUpdated: ((Bool) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let hasTopStripe: Bool
    let hasTopGroupInset: Bool
    let noInsets: Bool
    let noCorners: Bool
    public let tag: ItemListItemTag?
    let header: ListViewItemHeader?
    let shimmering: ItemListPeerItemShimmering?
    let displayDecorations: Bool
    let disableInteractiveTransitionIfNecessary: Bool
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, peer: EnginePeer, threadInfo: EngineMessageHistoryThread.Info? = nil, height: ItemListPeerItemHeight = .peerList, aliasHandling: ItemListPeerItemAliasHandling = .standard, nameColor: ItemListPeerItemNameColor = .primary, nameStyle: ItemListPeerItemNameStyle = .distinctBold, presence: EnginePeer.Presence?, text: ItemListPeerItemText, label: ItemListPeerItemLabel, editing: ItemListPeerItemEditing, revealOptions: ItemListPeerItemRevealOptions? = nil, switchValue: ItemListPeerItemSwitch?, enabled: Bool, highlighted: Bool = false, selectable: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, removePeer: @escaping (EnginePeer.Id) -> Void, toggleUpdated: ((Bool) -> Void)? = nil, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil, hasTopStripe: Bool = true, hasTopGroupInset: Bool = true, noInsets: Bool = false, noCorners: Bool = false, tag: ItemListItemTag? = nil, header: ListViewItemHeader? = nil, shimmering: ItemListPeerItemShimmering? = nil, displayDecorations: Bool = true, disableInteractiveTransitionIfNecessary: Bool = false) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.peer = peer
        self.threadInfo = threadInfo
        self.height = height
        self.aliasHandling = aliasHandling
        self.nameColor = nameColor
        self.nameStyle = nameStyle
        self.presence = presence
        self.text = text
        self.label = label
        self.editing = editing
        self.revealOptions = revealOptions
        self.switchValue = switchValue
        self.enabled = enabled
        self.highlighted = highlighted
        self.selectable = selectable
        self.sectionId = sectionId
        self.action = action
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.toggleUpdated = toggleUpdated
        self.contextAction = contextAction
        self.hasTopStripe = hasTopStripe
        self.hasTopGroupInset = hasTopGroupInset
        self.noInsets = noInsets
        self.noCorners = noCorners
        self.tag = tag
        self.header = header
        self.shimmering = shimmering
        self.displayDecorations = displayDecorations
        self.disableInteractiveTransitionIfNecessary = disableInteractiveTransitionIfNecessary
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListPeerItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), self.getHeaderAtTop(top: previousItem, bottom: nextItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (node.avatarNode.ready, { _ in apply(synchronousLoads, false) })
                })
            }
        }
    }
    
    private func getHeaderAtTop(top: ListViewItem?, bottom: ListViewItem?) -> Bool {
        var headerAtTop = false
        if let top = top as? ItemListPeerItem, top.header != nil {
            if top.header?.id != self.header?.id {
                headerAtTop = true
            }
        } else if self.header != nil {
            headerAtTop = true
        }
        
        return headerAtTop
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListPeerItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), self.getHeaderAtTop(top: previousItem, bottom: nextItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(false, animated)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let badgeFont = Font.regular(15.0)

public class ItemListPeerItemNode: ItemListRevealOptionsItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    private let maskNode: ASImageNode
    
    private let containerNode: ContextControllerSourceNode
    public override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    fileprivate let avatarNode: AvatarNode
    private var avatarIconComponent: EmojiStatusComponent?
    private var avatarIconView: ComponentView<Empty>?
    
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let labelBadgeNode: ASImageNode
    private var labelArrowNode: ASImageNode?
    private let statusNode: TextNode
    private var credibilityIconComponent: EmojiStatusComponent?
    private var credibilityIconView: ComponentHostView<Empty>?
    private var switchNode: SwitchNode?
    private var checkNode: ASImageNode?
    
    private var shimmerNode: LoadingShimmerNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (ItemListPeerItem, ListViewItemLayoutParams, ItemListNeighbors, Bool)?
    
    private var editableControlNode: ItemListEditableControlNode?
    private var reorderControlNode: ItemListEditableReorderControlNode?
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = self.visibilityStatus
            let isVisible: Bool
            switch self.visibility {
                case let .visible(fraction, _):
                    isVisible = fraction > 0.01
                case .none:
                    isVisible = false
            }
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                if let credibilityIconView = self.credibilityIconView, let credibilityIconComponent = self.credibilityIconComponent {
                    let _ = credibilityIconView.update(
                        transition: .immediate,
                        component: AnyComponent(credibilityIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: credibilityIconView.bounds.size
                    )
                }
                if let avatarIconView = self.avatarIconView, let avatarIconComponentView = avatarIconView.view, let avatarIconComponent = self.avatarIconComponent {
                    let _ = avatarIconView.update(
                        transition: .immediate,
                        component: AnyComponent(avatarIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: avatarIconComponentView.bounds.size
                    )
                }
            }
        }
    }
        
    override public var canBeSelected: Bool {
        if self.editableControlNode != nil || self.disabledOverlayNode != nil {
            return false
        }
        if let item = self.layoutParams?.0, item.action != nil {
            return true
        } else {
            return false
        }
    }
    
    public var tag: ItemListItemTag? {
        return self.layoutParams?.0.tag
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.containerNode = ContextControllerSourceNode()
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0)))
        //self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.labelBadgeNode = ASImageNode()
        self.labelBadgeNode.displayWithoutProcessing = true
        self.labelBadgeNode.displaysAsynchronously = false
        self.labelBadgeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.statusNode)
        self.containerNode.addSubnode(self.labelNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3)
                apply(false, true)
            }
        })
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.containerNode, gesture)
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.updateEnableGestures()
    }
    
    private func updateEnableGestures() {
        if let item = self.layoutParams?.0, item.disableInteractiveTransitionIfNecessary, let revealOptions = item.revealOptions, !revealOptions.options.isEmpty {
            self.view.disablesInteractiveTransitionGestureRecognizer = true
        } else {
            self.view.disablesInteractiveTransitionGestureRecognizer = false
        }
    }
    
    public func asyncLayout() -> (_ item: ItemListPeerItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors, _ headerAtTop: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        var currentSwitchNode = self.switchNode
        var currentCheckNode = self.checkNode
        
        let currentLabelArrowNode = self.labelArrowNode
        
        let currentItem = self.layoutParams?.0
        
        let currentHasBadge = self.labelBadgeNode.image != nil
        
        return { item, params, neighbors, headerAtTop in
            var updateArrowImage: UIImage?
            var updatedTheme: PresentationTheme?
            
            let statusFontSize: CGFloat = floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0)
            let labelFontSize: CGFloat = floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0)
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let titleBoldFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let statusFont = Font.regular(statusFontSize)
            let labelFont = Font.regular(labelFontSize)
            let labelDisclosureFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            var updatedLabelBadgeImage: UIImage?
            var credibilityIcon: EmojiStatusComponent.Content?
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 })
            
            if case .threatSelfAsSaved = item.aliasHandling, item.peer.id == item.context.account.peerId {
            } else {
                if item.peer.isScam {
                    credibilityIcon = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased())
                } else if item.peer.isFake {
                    credibilityIcon = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased())
                } else if case let .user(user) = item.peer, let emojiStatus = user.emojiStatus {
                    credibilityIcon = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 20.0, height: 20.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                } else if item.peer.isVerified {
                    credibilityIcon = .verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                } else if item.peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                    credibilityIcon = .premium(color: item.presentationData.theme.list.itemAccentColor)
                }
            }
            
            var titleIconsWidth: CGFloat = 0.0
            if let credibilityIcon = credibilityIcon {
                titleIconsWidth += 4.0
                switch credibilityIcon {
                case let .text(_, string):
                    let textString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: .black, paragraphAlignment: .center)
                    let stringRect = textString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                    titleIconsWidth += floor(stringRect.width) + 11.0
                default:
                    titleIconsWidth += 16.0
                }
            }
            
            var badgeColor: UIColor?
            if case .badge = item.label {
                badgeColor = item.presentationData.theme.list.itemAccentColor
            }
            
            let badgeDiameter: CGFloat = 20.0
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updateArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
                if let badgeColor = badgeColor {
                    updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
                }
            } else if let badgeColor = badgeColor, !currentHasBadge {
                updatedLabelBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: badgeColor)
            }
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var labelAttributedString: NSAttributedString?
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.editing.editable && item.enabled {
                if let revealOptions = item.revealOptions {
                    var mappedOptions: [ItemListRevealOption] = []
                    var index: Int32 = 0
                    for option in revealOptions.options {
                        let color: UIColor
                        let textColor: UIColor
                        switch option.type {
                            case .neutral:
                                color = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                                textColor = item.presentationData.theme.list.itemDisclosureActions.constructive.foregroundColor
                            case .warning:
                                color = item.presentationData.theme.list.itemDisclosureActions.warning.fillColor
                                textColor = item.presentationData.theme.list.itemDisclosureActions.warning.foregroundColor
                            case .destructive:
                                color = item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor
                                textColor = item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor
                            case .accent:
                                color = item.presentationData.theme.list.itemDisclosureActions.accent.fillColor
                                textColor = item.presentationData.theme.list.itemDisclosureActions.accent.foregroundColor
                        }
                        mappedOptions.append(ItemListRevealOption(key: index, title: option.title, icon: .none, color: color, textColor: textColor))
                        index += 1
                    }
                    peerRevealOptions = mappedOptions
                } else {
                    peerRevealOptions = [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]
                }
            } else {
                peerRevealOptions = []
            }
            
            var rightInset: CGFloat = params.rightInset
            let switchSize = CGSize(width: 51.0, height: 31.0)
            var checkImage: UIImage?
            
            if let switchValue = item.switchValue {
                switch switchValue.style {
                case .standard:
                    if currentSwitchNode == nil {
                        currentSwitchNode = SwitchNode()
                    }
                    rightInset += switchSize.width
                    currentCheckNode = nil
                case .check:
                    checkImage = PresentationResourcesItemList.checkIconImage(item.presentationData.theme)
                    if currentCheckNode == nil {
                        currentCheckNode = ASImageNode()
                    }
                    rightInset += 24.0
                    currentSwitchNode = nil
                }
            } else {
                currentSwitchNode = nil
                currentCheckNode = nil
            }
            
            let titleColor: UIColor
            switch item.nameColor {
            case .primary:
                titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            case .secret:
                titleColor = item.presentationData.theme.chatList.secretTitleColor
            }
            
            let currentBoldFont: UIFont
            switch item.nameStyle {
            case .distinctBold:
                currentBoldFont = titleBoldFont
            case .plain:
                currentBoldFont = titleFont
            }
            
            if let threadInfo = item.threadInfo {
                titleAttributedString = NSAttributedString(string: threadInfo.title, font: currentBoldFont, textColor: titleColor)
            } else if item.peer.id == item.context.account.peerId, case .threatSelfAsSaved = item.aliasHandling {
                titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: currentBoldFont, textColor: titleColor)
            } else if item.peer.id.isReplies {
                titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Replies, font: currentBoldFont, textColor: titleColor)
            } else if case let .user(user) = item.peer {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    switch item.nameDisplayOrder {
                    case .firstLast:
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                    case .lastFirst:
                        string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                    }
                    titleAttributedString = string
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: currentBoldFont, textColor: titleColor)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: currentBoldFont, textColor: titleColor)
                }
            } else if case let .legacyGroup(group) = item.peer {
                titleAttributedString = NSAttributedString(string: group.title, font: currentBoldFont, textColor: titleColor)
            } else if case let .channel(channel) = item.peer {
                titleAttributedString = NSAttributedString(string: channel.title, font: currentBoldFont, textColor: titleColor)
            }
            
            switch item.text {
            case .presence:
                if case let .user(user) = item.peer, let botInfo = user.botInfo {
                    let botStatus: String
                    if botInfo.flags.contains(.hasAccessToChatHistory) {
                        botStatus = item.presentationData.strings.Bot_GroupStatusReadsHistory
                    } else {
                        botStatus = item.presentationData.strings.Bot_GroupStatusDoesNotReadHistory
                    }
                    statusAttributedString = NSAttributedString(string: botStatus, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                } else if let presence = item.presence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    let (string, activity) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                    statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor)
                } else {
                    statusAttributedString = NSAttributedString(string: item.presentationData.strings.LastSeen_Offline, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                }
            case let .text(text, textColor):
                let textColorValue: UIColor
                switch textColor {
                case .secondary:
                    textColorValue = item.presentationData.theme.list.itemSecondaryTextColor
                case .accent:
                    textColorValue = item.presentationData.theme.list.itemAccentColor
                case .constructive:
                    textColorValue = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                }
                statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: textColorValue)
            case .none:
                break
            }

            let leftInset: CGFloat
            let verticalInset: CGFloat
            let verticalOffset: CGFloat
            let avatarSize: CGFloat
            let avatarFontSize: CGFloat
            switch item.height {
            case .generic:
                if case .none = item.text {
                    verticalInset = 11.0
                } else {
                    verticalInset = 6.0
                }
                verticalOffset = 0.0
                avatarSize = 31.0
                leftInset = 59.0 + params.leftInset
                avatarFontSize = floor(31.0 * 16.0 / 37.0)
            case .peerList:
                if case .none = item.text {
                    verticalInset = 14.0
                } else {
                    verticalInset = 8.0
                }
                verticalOffset = 0.0
                avatarSize = 40.0
                leftInset = 65.0 + params.leftInset
                avatarFontSize = floor(40.0 * 16.0 / 37.0)
            }
            
            var editableControlSizeAndApply: (CGFloat, (CGFloat) -> ItemListEditableControlNode)?
            var reorderControlSizeAndApply: (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode)?
            
            let editingOffset: CGFloat
            var reorderInset: CGFloat = 0.0
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(item.presentationData.theme, false)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0
                
                if item.editing.canBeReordered {
                    let reorderSizeAndApply = reorderControlLayout(item.presentationData.theme)
                    reorderControlSizeAndApply = reorderSizeAndApply
                    reorderInset = reorderSizeAndApply.0
                }
            } else {
                editingOffset = 0.0
            }
            
            var labelInset: CGFloat = 0.0
            var updatedLabelArrowNode: ASImageNode?
            switch item.label {
                case .none:
                    break
                case let .text(text, font):
                    let selectedFont: UIFont
                    switch font {
                    case .standard:
                        selectedFont = labelFont
                    case let .custom(value):
                        selectedFont = value
                    }
                    labelAttributedString = NSAttributedString(string: text, font: selectedFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    labelInset += 15.0
                case let .disclosure(text):
                    if let currentLabelArrowNode = currentLabelArrowNode {
                        updatedLabelArrowNode = currentLabelArrowNode
                    } else {
                        let arrowNode = ASImageNode()
                        arrowNode.isLayerBacked = true
                        arrowNode.displayWithoutProcessing = true
                        arrowNode.displaysAsynchronously = false
                        arrowNode.image = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
                        updatedLabelArrowNode = arrowNode
                    }
                    labelInset += 40.0
                    labelAttributedString = NSAttributedString(string: text, font: labelDisclosureFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                case let .badge(text):
                    labelAttributedString = NSAttributedString(string: text, font: badgeFont, textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor)
                    labelInset += 15.0
            }
            
            labelInset += reorderInset
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: labelAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 16.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - editingOffset - rightInset - labelLayout.size.width - labelInset - titleIconsWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - editingOffset - rightInset - labelLayout.size.width - labelInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            if !item.hasTopGroupInset {
                switch neighbors.top {
                case .none:
                    insets.top = 0.0
                default:
                    break
                }
            }
            if item.noInsets {
                insets.top = 0.0
                insets.bottom = 0.0
            }
            if headerAtTop, let header = item.header {
                insets.top += header.height + 18.0
            }
            
            let titleSpacing: CGFloat = statusLayout.size.height == 0.0 ? 0.0 : 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + statusLayout.size.height
            
            let contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                    currentDisabledOverlayNode?.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.5)
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, neighbors, headerAtTop)
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                    
                    strongSelf.avatarNode.font = avatarPlaceholderFont(size: avatarFontSize)
                    
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    var combinedValueString = ""
                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
                        combinedValueString.append(statusString)
                    }
                    if let labelString = labelAttributedString?.string, !labelString.isEmpty {
                        combinedValueString.append(", \(labelString)")
                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                    
                    if let updateArrowImage = updateArrowImage {
                        strongSelf.labelArrowNode?.image = updateArrowImage
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
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
                            strongSelf.addSubnode(editableControlNode)
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
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.addSubnode(strongSelf.maskNode)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params) && !item.noCorners
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                    case .sameSection(false):
                        strongSelf.topStripeNode.isHidden = true
                    default:
                        hasTopCorners = true
                        strongSelf.topStripeNode.isHidden = !item.displayDecorations || hasCorners || !item.hasTopStripe
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                    case .sameSection(false):
                        bottomStripeInset = leftInset + editingOffset
                        bottomStripeOffset = -separatorHeight
                        strongSelf.bottomStripeNode.isHidden = !item.displayDecorations
                    default:
                        bottomStripeInset = 0.0
                        bottomStripeOffset = 0.0
                        hasBottomCorners = true
                        strongSelf.bottomStripeNode.isHidden = hasCorners || !item.displayDecorations
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    let titleFrame = CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: verticalInset + verticalOffset), size: titleLayout.size)
                    transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                    
                    if let credibilityIcon = credibilityIcon {
                        let animationCache = item.context.animationCache
                        let animationRenderer = item.context.animationRenderer
                        
                        let credibilityIconView: ComponentHostView<Empty>
                        if let current = strongSelf.credibilityIconView {
                            credibilityIconView = current
                        } else {
                            credibilityIconView = ComponentHostView<Empty>()
                            strongSelf.containerNode.view.addSubview(credibilityIconView)
                            strongSelf.credibilityIconView = credibilityIconView
                        }
                        
                        let credibilityIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: animationCache,
                            animationRenderer: animationRenderer,
                            content: credibilityIcon,
                            isVisibleForAnimations: strongSelf.visibilityStatus,
                            action: nil,
                            emojiFileUpdated: nil
                        )
                        strongSelf.credibilityIconComponent = credibilityIconComponent
                        let iconSize = credibilityIconView.update(
                            transition: .immediate,
                            component: AnyComponent(credibilityIconComponent),
                            environment: {},
                            containerSize: CGSize(width: 20.0, height: 20.0)
                        )
                        
                        transition.updateFrame(view: credibilityIconView, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - iconSize.height / 2.0)), size: iconSize))
                    } else if let credibilityIconView = strongSelf.credibilityIconView {
                        strongSelf.credibilityIconView = nil
                        credibilityIconView.removeFromSuperview()
                    }
                    
                    if let currentSwitchNode = currentSwitchNode {
                        if currentSwitchNode !== strongSelf.switchNode {
                            strongSelf.switchNode = currentSwitchNode
                            strongSelf.containerNode.addSubnode(currentSwitchNode)
                            currentSwitchNode.valueUpdated = { value in
                                if let strongSelf = self {
                                    strongSelf.toggleUpdated(value)
                                }
                            }
                        }
                        currentSwitchNode.frame = CGRect(origin: CGPoint(x: revealOffset + params.width - switchSize.width - 15.0, y: floor((contentSize.height - switchSize.height) / 2.0)), size: switchSize)
                        if let switchValue = item.switchValue {
                            currentSwitchNode.setOn(switchValue.value, animated: animated)
                        }
                    } else if let switchNode = strongSelf.switchNode {
                        switchNode.removeFromSupernode()
                        strongSelf.switchNode = nil
                    }
                    
                    if let currentCheckNode = currentCheckNode {
                        if currentCheckNode !== strongSelf.checkNode {
                            strongSelf.checkNode = currentCheckNode
                            strongSelf.containerNode.addSubnode(currentCheckNode)
                        }
                        if let checkImage = checkImage {
                            currentCheckNode.image = checkImage
                            currentCheckNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - checkImage.size.width - floor((44.0 - checkImage.size.width) / 2.0), y: floor((layout.contentSize.height - checkImage.size.height) / 2.0)), size: checkImage.size)
                        }
                        if let switchValue = item.switchValue {
                            currentCheckNode.isHidden = !switchValue.value
                        }
                    } else if let checkNode = strongSelf.checkNode {
                        checkNode.removeFromSupernode()
                        strongSelf.checkNode = nil
                    }
                    
                    var rightLabelInset: CGFloat = 15.0 + params.rightInset
                    
                    if let updatedLabelArrowNode = updatedLabelArrowNode {
                        strongSelf.labelArrowNode = updatedLabelArrowNode
                        strongSelf.containerNode.addSubnode(updatedLabelArrowNode)
                        if let image = updatedLabelArrowNode.image {
                            let labelArrowNodeFrame = CGRect(origin: CGPoint(x: params.width - rightLabelInset - image.size.width + 8.0, y: floor((contentSize.height - image.size.height) / 2.0)), size: image.size)
                            transition.updateFrame(node: updatedLabelArrowNode, frame: labelArrowNodeFrame)
                            rightLabelInset += 19.0
                        }
                    } else if let labelArrowNode = strongSelf.labelArrowNode {
                        labelArrowNode.removeFromSupernode()
                        strongSelf.labelArrowNode = nil
                    }
                    
                    let badgeWidth = max(badgeDiameter, labelLayout.size.width + 10.0)
                    let labelFrame: CGRect
                    if case .badge = item.label {
                        labelFrame = CGRect(origin: CGPoint(x: revealOffset + params.width - rightLabelInset - badgeWidth + (badgeWidth - labelLayout.size.width) / 2.0, y: floor((contentSize.height - labelLayout.size.height) / 2.0) + 1.0), size: labelLayout.size)
                        strongSelf.labelNode.frame = labelFrame
                    } else {
                        labelFrame = CGRect(origin: CGPoint(x: revealOffset + params.width - labelLayout.size.width - rightLabelInset, y: floor((contentSize.height - labelLayout.size.height) / 2.0) + 1.0), size: labelLayout.size)
                        transition.updateFrame(node: strongSelf.labelNode, frame: labelFrame)
                    }
                    
                    if let updateBadgeImage = updatedLabelBadgeImage {
                        if strongSelf.labelBadgeNode.supernode == nil {
                            strongSelf.containerNode.insertSubnode(strongSelf.labelBadgeNode, belowSubnode: strongSelf.labelNode)
                        }
                        strongSelf.labelBadgeNode.image = updateBadgeImage
                    }
                    if badgeColor == nil && strongSelf.labelBadgeNode.supernode != nil {
                        strongSelf.labelBadgeNode.image = nil
                        strongSelf.labelBadgeNode.removeFromSupernode()
                    }
                    
                    strongSelf.labelBadgeNode.frame = CGRect(origin: CGPoint(x: revealOffset + params.width - rightLabelInset - badgeWidth, y: labelFrame.minY - 1.0), size: CGSize(width: badgeWidth, height: badgeDiameter))
                    
                    let avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset + editingOffset + 15.0, y: floorToScreenPixels((layout.contentSize.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
                    transition.updateFrame(node: strongSelf.avatarNode, frame: avatarFrame)
                    
                    if let threadInfo = item.threadInfo {
                        let threadIconSize = floor(avatarSize * 0.9)
                        let threadIconFrame = CGRect(origin: CGPoint(x: avatarFrame.minX + floor((avatarFrame.width - threadIconSize) / 2.0), y: avatarFrame.minY + floor((avatarFrame.height - threadIconSize) / 2.0)), size: CGSize(width: threadIconSize, height: threadIconSize))
                        
                        strongSelf.avatarNode.isHidden = true
                        
                        let avatarIconView: ComponentView<Empty>
                        if let current = strongSelf.avatarIconView {
                            avatarIconView = current
                        } else {
                            avatarIconView = ComponentView<Empty>()
                            strongSelf.avatarIconView = avatarIconView
                        }
                        
                        let avatarIconContent: EmojiStatusComponent.Content
                        if let fileId = threadInfo.icon, fileId != 0 {
                            avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .forever)
                        } else {
                            avatarIconContent = .topic(title: String(threadInfo.title.prefix(1)), color: threadInfo.iconColor, size: threadIconFrame.size)
                        }
                        
                        let avatarIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: item.context.animationCache,
                            animationRenderer: item.context.animationRenderer,
                            content: avatarIconContent,
                            isVisibleForAnimations: strongSelf.visibilityStatus,
                            action: nil,
                            emojiFileUpdated: nil
                        )
                        strongSelf.avatarIconComponent = avatarIconComponent
                        let _ = avatarIconView.update(
                            transition: .immediate,
                            component: AnyComponent(avatarIconComponent),
                            environment: {},
                            containerSize: threadIconFrame.size
                        )
                        
                        if let avatarIconComponentView = avatarIconView.view {
                            if avatarIconComponentView.superview == nil {
                                strongSelf.containerNode.view.addSubview(avatarIconComponentView)
                            }
                            transition.updateFrame(view: avatarIconComponentView, frame: threadIconFrame)
                        }
                    } else {
                        if item.peer.id == item.context.account.peerId, case .threatSelfAsSaved = item.aliasHandling {
                            strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: item.peer, overrideImage: .savedMessagesIcon, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
                        } else if item.peer.id.isReplies {
                            strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: item.peer, overrideImage: .repliesIcon, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
                        } else {
                            var overrideImage: AvatarNodeImageOverride?
                            if item.peer.isDeleted {
                                overrideImage = .deletedIcon
                            }
                            strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: item.peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
                        }
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    if let presence = item.presence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                    
                    if let shimmering = item.shimmering {
                        strongSelf.avatarNode.isHidden = true
                        strongSelf.titleNode.isHidden = true
                        
                        let shimmerNode: LoadingShimmerNode
                        if let current = strongSelf.shimmerNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = LoadingShimmerNode()
                            strongSelf.shimmerNode = shimmerNode
                            strongSelf.insertSubnode(shimmerNode, aboveSubnode: strongSelf.backgroundNode)
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }
                        var shapes: [LoadingShimmerNode.Shape] = []
                        shapes.append(.circle(strongSelf.avatarNode.frame))
                        let possibleLines: [[CGFloat]] = [
                            [50.0, 40.0],
                            [70.0, 45.0]
                        ]
                        let titleFrame = strongSelf.titleNode.frame
                        let lineDiameter: CGFloat = 10.0
                        var lineStart = titleFrame.minX
                        for lineWidth in possibleLines[shimmering.alternationIndex % possibleLines.count] {
                            shapes.append(.roundedRectLine(startPoint: CGPoint(x: lineStart, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: lineWidth, diameter: lineDiameter))
                            lineStart += lineWidth + lineDiameter
                        }
                        shimmerNode.update(backgroundColor: item.presentationData.theme.list.itemBlocksBackgroundColor, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: layout.contentSize)
                    } else if let shimmerNode = strongSelf.shimmerNode {
                        strongSelf.avatarNode.isHidden = false
                        strongSelf.titleNode.isHidden = false
                        
                        strongSelf.shimmerNode = nil
                        shimmerNode.removeFromSupernode()
                    }
                    
                    strongSelf.backgroundNode.isHidden = !item.displayDecorations
                    strongSelf.highlightedBackgroundNode.isHidden = !item.displayDecorations
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    if let revealed = item.editing.revealed {
                        strongSelf.setRevealOptionsOpened(revealed, animated: animated)
                    }
                    
                    strongSelf.updateIsHighlighted(transition: transition)
                }
            })
        }
    }
    
    var isHighlighted = false
    
    var reallyHighlighted: Bool {
        var reallyHighlighted = self.isHighlighted
        if let (item, _, _, _) = self.layoutParams, item.highlighted {
            reallyHighlighted = true
        }
        return reallyHighlighted
    }
    
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        if self.reallyHighlighted {
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
                if transition.isAnimated {
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
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
             
        self.isHighlighted = highlighted
            
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let item = self.layoutParams?.0, let params = self.layoutParams?.1 else {
            return
        }
        
        let leftInset: CGFloat
        switch item.height {
        case .generic:
            leftInset = 59.0 + params.leftInset
        case .peerList:
            leftInset = 65.0 + params.leftInset
        }
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = params.leftInset + offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.statusNode.frame.minY), size: self.statusNode.bounds.size))
        
        if let credibilityIconView = self.credibilityIconView {
            transition.updateFrame(view: credibilityIconView, frame: CGRect(origin: CGPoint(x: self.titleNode.frame.maxX + 4.0, y: credibilityIconView.frame.minY), size: credibilityIconView.bounds.size))
        }
        
        var rightLabelInset: CGFloat = 15.0 + params.rightInset
        
        if let labelArrowNode = self.labelArrowNode {
            if let image = labelArrowNode.image {
                let labelArrowNodeFrame = CGRect(origin: CGPoint(x: revealOffset + params.width - rightLabelInset - image.size.width + 8.0, y: labelArrowNode.frame.minY), size: image.size)
                transition.updateFrame(node: labelArrowNode, frame: labelArrowNodeFrame)
                rightLabelInset += 19.0
            }
        }
        
        let badgeDiameter: CGFloat = 20.0
        let labelSize = self.labelNode.frame.size
        
        let badgeWidth = max(badgeDiameter, labelSize.width + 10.0)
        let labelFrame: CGRect
        if case .badge = item.label {
            labelFrame = CGRect(origin: CGPoint(x: offset + params.width - rightLabelInset - badgeWidth + (badgeWidth - labelSize.width) / 2.0, y: self.labelNode.frame.minY), size: labelSize)
        } else {
            labelFrame = CGRect(origin: CGPoint(x: offset + params.width - self.labelNode.bounds.size.width - rightLabelInset, y: self.labelNode.frame.minY), size: self.labelNode.bounds.size)
        }
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        transition.updateFrame(node: self.labelBadgeNode, frame: CGRect(origin: CGPoint(x: offset + params.width - rightLabelInset - badgeWidth, y: self.labelBadgeNode.frame.minY), size: CGSize(width: badgeWidth, height: badgeDiameter)))
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + params.leftInset + 15.0, y: self.avatarNode.frame.minY), size: self.avatarNode.bounds.size))
        
        if let avatarIconComponentView = self.avatarIconView?.view {
            let avatarFrame = self.avatarNode.frame
            let threadIconSize = floor(avatarFrame.width * 0.9)
            let threadIconFrame = CGRect(origin: CGPoint(x: avatarFrame.minX + floor((avatarFrame.width - threadIconSize) / 2.0), y: avatarFrame.minY + floor((avatarFrame.height - threadIconSize) / 2.0)), size: CGSize(width: threadIconSize, height: threadIconSize))
            
            transition.updateFrame(view: avatarIconComponentView, frame: threadIconFrame)
        }
    }
    
    override public func revealOptionsInteractivelyOpened() {
        if let (item, _, _, _) = self.layoutParams {
            item.setPeerIdWithRevealedOptions(item.peer.id, nil)
        }
    }
    
    override public func revealOptionsInteractivelyClosed() {
        if let (item, _, _, _) = self.layoutParams {
            item.setPeerIdWithRevealedOptions(nil, item.peer.id)
        }
    }
    
    override public func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let (item, _, _, _) = self.layoutParams {
            if let revealOptions = item.revealOptions {
                if option.key >= 0 && option.key < Int32(revealOptions.options.count) {
                    revealOptions.options[Int(option.key)].action()
                }
            } else {
                item.removePeer(item.peer.id)
            }
        }
    }
    
    private func toggleUpdated(_ value: Bool) {
        if let (item, _, _, _) = self.layoutParams {
            item.toggleUpdated?(value)
        }
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.layoutParams?.0 {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.shimmerNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    override public func isReorderable(at point: CGPoint) -> Bool {
        if let reorderControlNode = self.reorderControlNode, reorderControlNode.frame.contains(point), !self.isDisplayingRevealedOptions {
            return true
        }
        return false
    }
}

public final class ItemListPeerItemHeader: ListViewItemHeader {
    public let id: ListViewItemNode.HeaderId
    public let text: String
    public let additionalText: String
    public let stickDirection: ListViewItemHeaderStickDirection = .topEdge
    public let stickOverInsets: Bool = true
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let actionTitle: String?
    public let action: (() -> Void)?
    
    public let height: CGFloat = 28.0
    
    public init(theme: PresentationTheme, strings: PresentationStrings, text: String, additionalText: String, actionTitle: String? = nil, id: Int64, action: (() -> Void)? = nil) {
        self.text = text
        self.additionalText = additionalText
        self.id = ListViewItemNode.HeaderId(space: 0, id: id)
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.action = action
    }

    public func combinesWith(other: ListViewItemHeader) -> Bool {
        if let other = other as? ItemListPeerItemHeader, other.id == self.id {
            return true
        } else {
            return false
        }
    }
    
    public func node(synchronousLoad: Bool) -> ListViewItemHeaderNode {
        return ItemListPeerItemHeaderNode(theme: self.theme, strings: self.strings, text: self.text, additionalText: self.additionalText, actionTitle: self.actionTitle, action: self.action)
    }
    
    public func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        (node as? ItemListPeerItemHeaderNode)?.update(text: self.text, additionalText: self.additionalText, actionTitle: self.actionTitle, action: self.action)
    }
}

public final class ItemListPeerItemHeaderNode: ListViewItemHeaderNode, ItemListHeaderItemNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var actionTitle: String?
    private var action: (() -> Void)?
    
    private var validLayout: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat)?
    
    private let backgroundNode: ASDisplayNode
    private let snappedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let additionalTextNode: ImmediateTextNode
    private let actionTextNode: ImmediateTextNode
    private let actionButton: HighlightableButtonNode
    
    private var stickDistanceFactor: CGFloat?
    
    public init(theme: PresentationTheme, strings: PresentationStrings, text: String, additionalText: String, actionTitle: String?, action: (() -> Void)?) {
        self.theme = theme
        self.strings = strings
        self.actionTitle = actionTitle
        self.action = action
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.list.blocksBackgroundColor
        
        self.snappedBackgroundNode = ASDisplayNode()
        self.snappedBackgroundNode.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
        self.snappedBackgroundNode.alpha = 0.0
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        self.separatorNode.alpha = 0.0
        
        let titleFont = Font.regular(13.0)
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 1
        self.textNode.attributedText = NSAttributedString(string: text, font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        
        self.additionalTextNode = ImmediateTextNode()
        self.additionalTextNode.displaysAsynchronously = false
        self.additionalTextNode.maximumNumberOfLines = 1
        self.additionalTextNode.attributedText = NSAttributedString(string: additionalText, font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        
        self.actionTextNode = ImmediateTextNode()
        self.actionTextNode.displaysAsynchronously = false
        self.actionTextNode.maximumNumberOfLines = 1
        self.actionTextNode.attributedText = NSAttributedString(string: actionTitle ?? "", font: titleFont, textColor: action == nil ? theme.list.sectionHeaderTextColor : theme.list.itemAccentColor)
        
        self.actionButton = HighlightableButtonNode()
        self.actionButton.isUserInteractionEnabled = self.action != nil
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.snappedBackgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.additionalTextNode)
        self.addSubnode(self.actionTextNode)
        self.addSubnode(self.actionButton)
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        self.actionButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.actionTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.actionTextNode.alpha = 0.4
                } else {
                    strongSelf.actionTextNode.alpha = 1.0
                    strongSelf.actionTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func actionButtonPressed() {
        self.action?()
    }
    
    public func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.backgroundColor = theme.list.blocksBackgroundColor
        self.snappedBackgroundNode.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
        self.separatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        let titleFont = Font.regular(13.0)
        
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        self.additionalTextNode.attributedText = NSAttributedString(string: self.additionalTextNode.attributedText?.string ?? "", font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        self.actionTextNode.attributedText = NSAttributedString(string: self.actionTextNode.attributedText?.string ?? "", font: titleFont, textColor: theme.list.sectionHeaderTextColor)
    }
    
    public func update(text: String, additionalText: String, actionTitle: String?, action: (() -> Void)?) {
        self.actionTitle = actionTitle
        self.action = action
        let titleFont = Font.regular(13.0)
        self.textNode.attributedText = NSAttributedString(string: text, font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        self.additionalTextNode.attributedText = NSAttributedString(string: additionalText, font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        self.actionTextNode.attributedText = NSAttributedString(string: actionTitle ?? "", font: titleFont, textColor: action == nil ? theme.list.sectionHeaderTextColor : theme.list.itemAccentColor)
        self.actionButton.isUserInteractionEnabled = self.action != nil
        if let (size, leftInset, rightInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
        }
    }
    
    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.validLayout = (size, leftInset, rightInset)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.snappedBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel))
        
        let sideInset: CGFloat = 15.0 + leftInset
        
        let actionTextSize = self.actionTextNode.updateLayout(CGSize(width: size.width - sideInset * 2.0, height: size.height))
        let additionalTextSize = self.additionalTextNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - actionTextSize.width - 8.0, height: size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: max(1.0, size.width - sideInset * 2.0 - actionTextSize.width - 8.0 - additionalTextSize.width), height: size.height))
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: 7.0), size: textSize)
        self.textNode.frame = textFrame
        self.additionalTextNode.frame = CGRect(origin: CGPoint(x: textFrame.maxX, y: 7.0), size: additionalTextSize)
        self.actionTextNode.frame = CGRect(origin: CGPoint(x: size.width - sideInset - actionTextSize.width, y: 7.0), size: actionTextSize)
        self.actionButton.frame = CGRect(origin: CGPoint(x: size.width - sideInset - actionTextSize.width, y: 0.0), size: CGSize(width: actionTextSize.width, height: size.height))
    }
    
    override public func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: true)
    }
    
    override public func updateStickDistanceFactor(_ factor: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.stickDistanceFactor == factor {
            return
        }
        self.stickDistanceFactor = factor
        if let (size, leftInset, _) = self.validLayout {
            if leftInset.isZero {
                transition.updateAlpha(node: self.separatorNode, alpha: 1.0)
                transition.updateAlpha(node: self.snappedBackgroundNode, alpha: (1.0 - factor) * 0.0 + factor * 1.0)
            } else {
                let distance = factor * size.height
                let alpha = abs(distance) / 16.0
                transition.updateAlpha(node: self.separatorNode, alpha: max(0.0, min(1.0, alpha)))
                transition.updateAlpha(node: self.snappedBackgroundNode, alpha: 0.0)
            }
        }
    }
}
