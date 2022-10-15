import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext

private final class ItemNode: ASDisplayNode {
    private let pressed: () -> Void
    
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let titleActiveNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var selectionFraction: CGFloat = 0.0
    
    private var theme: PresentationTheme?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
    
        let titleInset: CGFloat = 4.0
                
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        
        self.titleActiveNode = ImmediateTextNode()
        self.titleActiveNode.displaysAsynchronously = false
        self.titleActiveNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        self.titleActiveNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.titleActiveNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.4
                    
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                } else {
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func update(type: ChatListSearchFilter, presentationData: PresentationData, selectionFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.selectionFraction = selectionFraction
        
        let title: String
        let icon: UIImage?
        
        let color = presentationData.theme.list.itemSecondaryTextColor
        switch type {
            case .chats:
                title = presentationData.strings.ChatList_Search_FilterChats
                icon = nil
            case .topics:
                title = presentationData.strings.ChatList_Search_FilterTopics
                icon = nil
            case .media:
                title = presentationData.strings.ChatList_Search_FilterMedia
                icon = nil
            case .downloads:
                title = presentationData.strings.ChatList_Search_FilterDownloads
                icon = nil
            case .links:
                title = presentationData.strings.ChatList_Search_FilterLinks
                icon = nil
            case .files:
                title = presentationData.strings.ChatList_Search_FilterFiles
                icon = nil
            case .music:
                title = presentationData.strings.ChatList_Search_FilterMusic
                icon = nil
            case .voice:
                title = presentationData.strings.ChatList_Search_FilterVoice
                icon = nil
            case let .peer(peerId, isGroup, displayTitle, _):
                title = displayTitle
                let image: UIImage?
                if isGroup {
                    image = UIImage(bundleImageName: "Chat List/Search/Group")
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    image = UIImage(bundleImageName: "Chat List/Search/Channel")
                } else {
                    image = UIImage(bundleImageName: "Chat List/Search/User")
                }
                icon = generateTintedImage(image: image, color: color)
            case let .date(_, _, displayTitle):
                title = displayTitle
                icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Calendar"), color: color)
        }
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: color)
        self.titleActiveNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: presentationData.theme.list.itemAccentColor)
        
        let selectionAlpha: CGFloat = selectionFraction * selectionFraction
        let deselectionAlpha: CGFloat = 1.0// - selectionFraction
        transition.updateAlpha(node: self.titleNode, alpha: deselectionAlpha)
        transition.updateAlpha(node: self.titleActiveNode, alpha: selectionAlpha)
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            self.iconNode.image = icon
        }
    }
    
    func updateLayout(height: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var iconInset: CGFloat = 0.0
        if let image = self.iconNode.image {
            iconInset = 22.0
            self.iconNode.frame = CGRect(x: 0.0, y: floorToScreenPixels((height - image.size.height) / 2.0), width: image.size.width, height: image.size.height)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let _ = self.titleActiveNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: -self.titleNode.insets.left + iconInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        self.titleActiveNode.frame = titleFrame
                
        return titleSize.width - self.titleNode.insets.left - self.titleNode.insets.right + iconInset
    }
    
    func updateArea(size: CGSize, sideInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))

        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -sideInset, bottom: 0.0, right: -sideInset)
    }
}

enum ChatListSearchFilterEntryId: Hashable {
    case filter(Int64)
}

enum ChatListSearchFilterEntry: Equatable {
    case filter(ChatListSearchFilter)
    
    var id: ChatListSearchFilterEntryId {
        switch self {
        case let .filter(filter):
            return .filter(filter.id)
        }
    }
}

final class ChatListSearchFiltersContainerNode: ASDisplayNode {
    private let scrollNode: ASScrollNode
    private let selectedLineNode: ASImageNode
    private var itemNodes: [ChatListSearchFilterEntryId: ItemNode] = [:]
    
    var filterPressed: ((ChatListSearchFilter) -> Void)?

    private var currentParams: (size: CGSize, sideInset: CGFloat, filters: [ChatListSearchFilterEntry], selectedFilter: ChatListSearchFilterEntryId?, transitionFraction: CGFloat, presentationData: PresentationData)?
        
    private var previousSelectedAbsFrame: CGRect?
    private var previousSelectedFrame: CGRect?
    
    override init() {
        self.scrollNode = ASScrollNode()
    
        self.selectedLineNode = ASImageNode()
        self.selectedLineNode.displaysAsynchronously = false
        self.selectedLineNode.displayWithoutProcessing = true
        
        super.init()
                
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.selectedLineNode)
    }
        
    func cancelAnimations() {
        self.scrollNode.layer.removeAllAnimations()
    }
    
    func update(size: CGSize, sideInset: CGFloat, filters: [ChatListSearchFilterEntry], selectedFilter: ChatListSearchFilterEntryId?, transitionFraction: CGFloat, presentationData: PresentationData, transition proposedTransition: ContainedViewLayoutTransition) {
        let isFirstTime = self.currentParams == nil
        let transition: ContainedViewLayoutTransition = isFirstTime ? .immediate : proposedTransition
        
        var focusOnSelectedFilter = self.currentParams?.selectedFilter != selectedFilter
        let previousScrollBounds = self.scrollNode.bounds
        let previousContentWidth = self.scrollNode.view.contentSize.width
        
        if self.currentParams?.presentationData.theme !== presentationData.theme {
            //self.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
            self.selectedLineNode.image = generateImage(CGSize(width: 5.0, height: 3.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(presentationData.theme.list.itemAccentColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + 1.0)))
                context.fill(CGRect(x: 0.0, y: 2.0, width: size.width, height: 2.0))
            })?.stretchableImage(withLeftCapWidth: 2, topCapHeight: 2)
        }
        
        self.currentParams = (size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, transitionFraction: transitionFraction, presentationData: presentationData)
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
             
        var hasSelection = false
        for i in 0 ..< filters.count {
            let filter = filters[i]
            if case let .filter(type) = filter {
                let itemNode: ItemNode
                var itemNodeTransition = transition
                if let current = self.itemNodes[filter.id] {
                    itemNode = current
                } else {
                    itemNodeTransition = .immediate
                    itemNode = ItemNode(pressed: { [weak self] in
                        self?.filterPressed?(type)
                    })
                    self.itemNodes[filter.id] = itemNode
                }
                
                let selectionFraction: CGFloat
                if selectedFilter == filter.id {
                    selectionFraction = 1.0 - abs(transitionFraction)
                    hasSelection = true
                } else if i != 0 && selectedFilter == filters[i - 1].id {
                    selectionFraction = max(0.0, -transitionFraction)
                } else if i != filters.count - 1 && selectedFilter == filters[i + 1].id {
                    selectionFraction = max(0.0, transitionFraction)
                } else {
                    selectionFraction = 0.0
                }
                
                itemNode.update(type: type, presentationData: presentationData, selectionFraction: selectionFraction, transition: itemNodeTransition)
            }
        }
        
        var updated = false
        
        var removeKeys: [ChatListSearchFilterEntryId] = []
        for (id, _) in self.itemNodes {
            if !filters.contains(where: { $0.id == id }) {
                removeKeys.append(id)
                updated = true
            }
        }
        for id in removeKeys {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
                transition.updateTransformScale(node: itemNode, scale: 0.1)
            }
        }
        
        var tabSizes: [(ChatListSearchFilterEntryId, CGSize, ItemNode, Bool)] = []
        var totalRawTabSize: CGFloat = 0.0
        var selectionFrames: [CGRect] = []
        
        for filter in filters {
            guard let itemNode = self.itemNodes[filter.id] else {
                continue
            }
            let wasAdded = itemNode.supernode == nil
            var itemNodeTransition = transition
            if wasAdded {
                itemNodeTransition = .immediate
                self.scrollNode.addSubnode(itemNode)
            }
            let paneNodeWidth = itemNode.updateLayout(height: size.height, transition: itemNodeTransition)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            tabSizes.append((filter.id, paneNodeSize, itemNode, wasAdded))
            totalRawTabSize += paneNodeSize.width
        }
        
        let minSpacing: CGFloat = 24.0
        var spacing = minSpacing
        
        let resolvedSideInset: CGFloat = 16.0 + sideInset
        var leftOffset: CGFloat = resolvedSideInset
        
        var longTitlesWidth: CGFloat = resolvedSideInset
        var titlesWidth: CGFloat = 0.0
        for i in 0 ..< tabSizes.count {
            let (_, paneNodeSize, _, _) = tabSizes[i]
            longTitlesWidth += paneNodeSize.width
            titlesWidth += paneNodeSize.width
            if i != tabSizes.count - 1 {
                longTitlesWidth += minSpacing
            }
        }
        longTitlesWidth += resolvedSideInset
        
        if longTitlesWidth < size.width && hasSelection {
            spacing = (size.width - titlesWidth - resolvedSideInset * 2.0) / CGFloat(tabSizes.count - 1)
        }
        
        let verticalOffset: CGFloat = -4.0
        for i in 0 ..< tabSizes.count {
            let (_, paneNodeSize, paneNode, wasAdded) = tabSizes[i]
            let itemNodeTransition = transition
            
            let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0) + verticalOffset), size: paneNodeSize)
            
            var effectiveWasAdded = wasAdded
            if !effectiveWasAdded && !self.bounds.intersects(self.scrollNode.convert(paneNode.frame, to: self)) && self.bounds.intersects(self.scrollNode.convert(paneFrame, to: self)) {
                effectiveWasAdded = true
            }
            
            if effectiveWasAdded {
                paneNode.frame = paneFrame
                paneNode.alpha = 0.0
                paneNode.subnodeTransform = CATransform3DMakeScale(0.1, 0.1, 1.0)
                itemNodeTransition.updateSublayerTransformScale(node: paneNode, scale: 1.0)
                itemNodeTransition.updateAlpha(node: paneNode, alpha: 1.0)
            } else {
                if self.bounds.intersects(self.scrollNode.convert(paneFrame, to: self)) {
                    itemNodeTransition.updateFrameAdditive(node: paneNode, frame: paneFrame)
                } else if paneNode.frame != paneFrame {
                    paneNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.4) { [weak paneNode] _ in
                        paneNode?.frame = paneFrame
                    }
                }
            }
            
            paneNode.updateArea(size: paneFrame.size, sideInset: spacing / 2.0, transition: itemNodeTransition)
            paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -spacing / 2.0, bottom: 0.0, right: -spacing / 2.0)
                        
            selectionFrames.append(paneFrame)
            
            leftOffset += paneNodeSize.width + spacing
        }
        leftOffset -= spacing
        leftOffset += resolvedSideInset
        
        self.scrollNode.view.contentSize = CGSize(width: leftOffset, height: size.height)
        
        var selectedFrame: CGRect?
        if let selectedFilter = selectedFilter, let currentIndex = filters.firstIndex(where: { $0.id == selectedFilter }) {
            func interpolateFrame(from fromValue: CGRect, to toValue: CGRect, t: CGFloat) -> CGRect {
                return CGRect(x: floorToScreenPixels(toValue.origin.x * t + fromValue.origin.x * (1.0 - t)), y: floorToScreenPixels(toValue.origin.y * t + fromValue.origin.y * (1.0 - t)), width: floorToScreenPixels(toValue.size.width * t + fromValue.size.width * (1.0 - t)), height: floorToScreenPixels(toValue.size.height * t + fromValue.size.height * (1.0 - t)))
            }
            
            if currentIndex != 0 && transitionFraction > 0.0 {
                let currentFrame = selectionFrames[currentIndex]
                let previousFrame = selectionFrames[currentIndex - 1]
                selectedFrame = interpolateFrame(from: currentFrame, to: previousFrame, t: abs(transitionFraction))
            } else if currentIndex != filters.count - 1 && transitionFraction < 0.0 {
                let currentFrame = selectionFrames[currentIndex]
                let previousFrame = selectionFrames[currentIndex + 1]
                selectedFrame = interpolateFrame(from: currentFrame, to: previousFrame, t: abs(transitionFraction))
            } else {
                selectedFrame = selectionFrames[currentIndex]
            }
        }
        
        if let selectedFrame = selectedFrame {
            let wasAdded = self.selectedLineNode.alpha < 1.0
            let lineFrame = CGRect(origin: CGPoint(x: selectedFrame.minX, y: size.height - 3.0), size: CGSize(width: selectedFrame.width, height: 3.0))
            if wasAdded {
                self.selectedLineNode.frame = lineFrame
                self.selectedLineNode.alpha = 0.0
            } else {
                transition.updateFrame(node: self.selectedLineNode, frame: lineFrame)
            }
            transition.updateAlpha(node: self.selectedLineNode, alpha: 1.0)
            
            if let previousSelectedFrame = self.previousSelectedFrame {
                let previousContentOffsetX = max(0.0, min(previousContentWidth - previousScrollBounds.width, floor(previousSelectedFrame.midX - previousScrollBounds.width / 2.0)))
                if abs(previousContentOffsetX - previousScrollBounds.minX) < 1.0 {
                    focusOnSelectedFilter = true
                }
            }
            
            if focusOnSelectedFilter {
                let updatedBounds: CGRect
                if transitionFraction.isZero && selectedFilter == filters.first?.id {
                    updatedBounds = CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size)
                } else if transitionFraction.isZero && selectedFilter == filters.last?.id {
                    updatedBounds = CGRect(origin: CGPoint(x: max(0.0, self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width), y: 0.0), size: self.scrollNode.bounds.size)
                } else {
                    let contentOffsetX = max(0.0, min(self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width, floor(selectedFrame.midX - self.scrollNode.bounds.width / 2.0)))
                    updatedBounds = CGRect(origin: CGPoint(x: contentOffsetX, y: 0.0), size: self.scrollNode.bounds.size)
                }
                self.scrollNode.bounds = updatedBounds
            }
            transition.animateHorizontalOffsetAdditive(node: self.scrollNode, offset: previousScrollBounds.minX - self.scrollNode.bounds.minX)
            
            self.previousSelectedAbsFrame = selectedFrame.offsetBy(dx: -self.scrollNode.bounds.minX, dy: 0.0)
            self.previousSelectedFrame = selectedFrame
        } else {
            transition.updateAlpha(node: self.selectedLineNode, alpha: 0.0)
            self.previousSelectedAbsFrame = nil
            self.previousSelectedFrame = nil
        }
        
        if updated && self.scrollNode.view.contentOffset.x > 0.0 {
            self.scrollNode.view.contentOffset = CGPoint()
        }
    }
}
