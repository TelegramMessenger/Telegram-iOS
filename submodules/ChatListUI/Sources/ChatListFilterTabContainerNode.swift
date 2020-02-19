import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SyncCore
import Postbox
import TelegramCore
import TelegramPresentationData

private final class ItemNode: ASDisplayNode {
    private let pressed: () -> Void
    
    private let titleNode: ImmediateTextNode
    private let badgeTextNode: ImmediateTextNode
    private let badgeBackgroundNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var isSelected: Bool = false
    private var unreadCount: Int = 0
    
    private var theme: PresentationTheme?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.badgeTextNode = ImmediateTextNode()
        self.badgeTextNode.displaysAsynchronously = false
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.displayWithoutProcessing = true
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTextNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func updateText(title: String, unreadCount: Int, isSelected: Bool, presentationData: PresentationData) {
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.badgeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: presentationData.theme.rootController.navigationBar.badgeBackgroundColor)
        }
        
        self.isSelected = isSelected
        self.unreadCount = unreadCount
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: isSelected ? presentationData.theme.list.itemAccentColor : presentationData.theme.list.itemSecondaryTextColor)
        if unreadCount != 0 {
            self.badgeTextNode.attributedText = NSAttributedString(string: "\(unreadCount)", font: Font.regular(14.0), textColor: presentationData.theme.rootController.navigationBar.badgeTextColor)
        }
    }
    
    func updateLayout(height: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let titleSize = self.titleNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        
        let badgeSize = self.badgeTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        let badgeInset: CGFloat = 5.0
        let badgeBackgroundFrame = CGRect(origin: CGPoint(x: titleSize.width + 5.0, y: floor((height - 18.0) / 2.0)), size: CGSize(width: max(18.0, badgeSize.width + badgeInset * 2.0), height: 18.0))
        self.badgeBackgroundNode.frame = badgeBackgroundFrame
        self.badgeTextNode.frame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.minX + floor((badgeBackgroundFrame.width - badgeSize.width) / 2.0), y: badgeBackgroundFrame.minY + floor((badgeBackgroundFrame.height - badgeSize.height) / 2.0)), size: badgeSize)
        
        if self.unreadCount == 0 {
            self.badgeBackgroundNode.alpha = 0.0
            self.badgeTextNode.alpha = 0.0
            return titleSize.width
        } else {
            self.badgeBackgroundNode.alpha = 1.0
            self.badgeTextNode.alpha = 1.0
            return badgeBackgroundFrame.maxX
        }
    }
    
    func updateArea(size: CGSize, sideInset: CGFloat) {
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))
    }
}

enum ChatListFilterTabEntryId: Hashable {
    case all
    case filter(Int32)
}

enum ChatListFilterTabEntry: Equatable {
    case all
    case filter(id: Int32, text: String, unreadCount: Int)
    
    var id: ChatListFilterTabEntryId {
        switch self {
        case .all:
            return .all
        case let .filter(filter):
            return .filter(filter.id)
        }
    }
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .all:
            return "All Chats"
        case let .filter(filter):
            return filter.text
        }
    }
}

private final class AddItemNode: HighlightableButtonNode {
    private let iconNode: ASImageNode
    
    var pressed: (() -> Void)?
    
    private var theme: PresentationTheme?
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
        
        self.addTarget(self, action: #selector(self.onPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func onPressed() {
        self.pressed?()
    }
    
    func update(size: CGSize, theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            self.iconNode.image = PresentationResourcesItemList.plusIconImage(theme)
        }
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
    }
}

final class ChatListFilterTabContainerNode: ASDisplayNode {
    private let scrollNode: ASScrollNode
    private let selectedLineNode: ASImageNode
    private var itemNodes: [ChatListFilterTabEntryId: ItemNode] = [:]
    private let addNode: AddItemNode
    
    var tabSelected: ((ChatListFilterTabEntryId) -> Void)?
    var addFilter: (() -> Void)?
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, filters: [ChatListFilterTabEntry], selectedFilter: ChatListFilterTabEntryId?, presentationData: PresentationData)?
    
    override init() {
        self.scrollNode = ASScrollNode()
        
        self.selectedLineNode = ASImageNode()
        self.selectedLineNode.displaysAsynchronously = false
        self.selectedLineNode.displayWithoutProcessing = true
        
        self.addNode = AddItemNode()
        
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
        self.scrollNode.addSubnode(self.addNode)
        
        self.addNode.pressed = { [weak self] in
            self?.addFilter?()
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, filters: [ChatListFilterTabEntry], selectedFilter: ChatListFilterTabEntryId?, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        let focusOnSelectedFilter = self.currentParams?.selectedFilter != selectedFilter
        
        if self.currentParams?.presentationData.theme !== presentationData.theme {
            self.selectedLineNode.image = generateImage(CGSize(width: 7.0, height: 4.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(presentationData.theme.list.itemAccentColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
            })?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 1)
        }
        
        self.currentParams = (size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, presentationData: presentationData)
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        
        for filter in filters {
            let itemNode: ItemNode
            var wasAdded = false
            if let current = self.itemNodes[filter.id] {
                itemNode = current
            } else {
                wasAdded = true
                itemNode = ItemNode(pressed: { [weak self] in
                    self?.tabSelected?(filter.id)
                })
                self.itemNodes[filter.id] = itemNode
            }
            let unreadCount: Int
            switch filter {
            case .all:
                unreadCount = 0
            case let .filter(filter):
                unreadCount = filter.unreadCount
            }
            itemNode.updateText(title: filter.title(strings: presentationData.strings), unreadCount: unreadCount, isSelected: selectedFilter == filter.id, presentationData: presentationData)
        }
        var removeKeys: [ChatListFilterTabEntryId] = []
        for (id, _) in self.itemNodes {
            if !filters.contains(where: { $0.id == id }) {
                removeKeys.append(id)
            }
        }
        for id in removeKeys {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                itemNode.removeFromSupernode()
            }
        }
        
        var tabSizes: [(CGSize, ItemNode, Bool)] = []
        var totalRawTabSize: CGFloat = 0.0
        var selectionFrames: [CGRect] = []
        
        for filter in filters {
            guard let itemNode = self.itemNodes[filter.id] else {
                continue
            }
            let wasAdded = itemNode.supernode == nil
            if wasAdded {
                self.scrollNode.addSubnode(itemNode)
            }
            let paneNodeWidth = itemNode.updateLayout(height: size.height, transition: transition)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            tabSizes.append((paneNodeSize, itemNode, wasAdded))
            totalRawTabSize += paneNodeSize.width
        }
        
        let minSpacing: CGFloat = 30.0
        
        let sideInset: CGFloat = 16.0
        var leftOffset: CGFloat = sideInset
        for i in 0 ..< tabSizes.count {
            let (paneNodeSize, paneNode, wasAdded) = tabSizes[i]
            let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
            if wasAdded {
                paneNode.frame = paneFrame
                paneNode.alpha = 0.0
                transition.updateAlpha(node: paneNode, alpha: 1.0)
            } else {
                transition.updateFrameAdditiveToCenter(node: paneNode, frame: paneFrame)
            }
            paneNode.updateArea(size: paneFrame.size, sideInset: minSpacing / 2.0)
            paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -minSpacing / 2.0, bottom: 0.0, right: -minSpacing / 2.0)
            
            selectionFrames.append(paneFrame)
            
            leftOffset += paneNodeSize.width + minSpacing
        }
        
        let addSize = CGSize(width: 32.0, height: size.height)
        transition.updateFrame(node: self.addNode, frame: CGRect(origin: CGPoint(x: max(leftOffset, size.width - sideInset - addSize.width + 6.0), y: 0.0), size: addSize))
        self.addNode.update(size: addSize, theme: presentationData.theme)
        leftOffset += addSize.width + minSpacing
        
        self.scrollNode.view.contentSize = CGSize(width: leftOffset - minSpacing + sideInset, height: size.height)
        
        let transitionFraction: CGFloat = 0.0
        var selectedFrame: CGRect?
        if let selectedFilter = selectedFilter, let currentIndex = filters.index(where: { $0.id == selectedFilter }) {
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
            let wasAdded = self.selectedLineNode.isHidden
            self.selectedLineNode.isHidden = false
            let lineFrame = CGRect(origin: CGPoint(x: selectedFrame.minX, y: size.height - 4.0), size: CGSize(width: selectedFrame.width, height: 4.0))
            if wasAdded {
                self.selectedLineNode.frame = lineFrame
                self.selectedLineNode.alpha = 0.0
                transition.updateAlpha(node: self.selectedLineNode, alpha: 1.0)
            } else {
                transition.updateFrame(node: self.selectedLineNode, frame: lineFrame)
            }
            if focusOnSelectedFilter {
                if selectedFilter == filters.first?.id {
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size))
                } else if selectedFilter == filters.last?.id {
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: max(0.0, self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width), y: 0.0), size: self.scrollNode.bounds.size))
                } else {
                    let contentOffsetX = max(0.0, min(self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width, floor(selectedFrame.midX - self.scrollNode.bounds.width / 2.0)))
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: contentOffsetX, y: 0.0), size: self.scrollNode.bounds.size))
                }
            }
        } else {
            self.selectedLineNode.isHidden = true
        }
    }
}
