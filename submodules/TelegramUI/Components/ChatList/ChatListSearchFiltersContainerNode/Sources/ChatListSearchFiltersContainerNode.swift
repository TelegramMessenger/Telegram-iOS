import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters

public enum ChatListSearchFilterEntryId: Hashable {
    case filter(Int64)
}

public enum ChatListSearchFilterEntry: Equatable {
    case filter(ChatListSearchFilter)
    
    public var id: ChatListSearchFilterEntryId {
        switch self {
        case let .filter(filter):
            return .filter(filter.id)
        }
    }
}

public final class ChatListSearchFiltersContainerNode: ASDisplayNode {
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    
    private let scrollNode: ASScrollNode
    private let selectionView: UIImageView
    private var itemNodes: [ChatListSearchFilterEntryId: ItemNode] = [:]
    
    public var filterPressed: ((ChatListSearchFilter) -> Void)?

    private var currentParams: (size: CGSize, sideInset: CGFloat, filters: [ChatListSearchFilterEntry], selectedFilter: ChatListSearchFilterEntryId?, transitionFraction: CGFloat, presentationData: PresentationData)?
        
    private var previousSelectedAbsFrame: CGRect?
    private var previousSelectedFrame: CGRect?
    
    override public init() {
        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        
        self.scrollNode = ASScrollNode()
    
        self.selectionView = UIImageView()
        
        super.init()
                
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        
        self.view.addSubview(self.backgroundContainer)
        
        self.backgroundView.contentView.addSubview(self.scrollNode.view)
        self.scrollNode.view.addSubview(self.selectionView)
    }
        
    public func cancelAnimations() {
        self.scrollNode.layer.removeAllAnimations()
    }
    
    public func update(size: CGSize, sideInset: CGFloat, filters: [ChatListSearchFilterEntry], displayGlobalPostsNewBadge: Bool, selectedFilter: ChatListSearchFilterEntryId?, transitionFraction: CGFloat, presentationData: PresentationData, transition proposedTransition: ContainedViewLayoutTransition) {
        let isFirstTime = self.currentParams == nil
        let transition: ContainedViewLayoutTransition = isFirstTime ? .immediate : proposedTransition
        
        let componentTransition = ComponentTransition(transition)
        
        componentTransition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundContainer.update(size: size, isDark: presentationData.theme.overallDarkAppearance, transition: componentTransition)
        componentTransition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: componentTransition)
        self.scrollNode.view.layer.cornerRadius = size.height * 0.5
        
        var focusOnSelectedFilter = self.currentParams?.selectedFilter != selectedFilter
        let previousScrollBounds = self.scrollNode.bounds
        let previousContentWidth = self.scrollNode.view.contentSize.width
        
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
                
                var displayNewBadge = false
                if case .globalPosts = type {
                    displayNewBadge = displayGlobalPostsNewBadge
                }
                
                itemNode.update(type: type, displayNewBadge: displayNewBadge, presentationData: presentationData, selectionFraction: selectionFraction, transition: itemNodeTransition)
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
            if !effectiveWasAdded && !self.bounds.intersects(self.scrollNode.view.convert(paneNode.frame, to: self.view)) && self.bounds.intersects(self.scrollNode.view.convert(paneFrame, to: self.view)) {
                effectiveWasAdded = true
            }
            
            if effectiveWasAdded {
                paneNode.frame = paneFrame
                paneNode.alpha = 0.0
                paneNode.subnodeTransform = CATransform3DMakeScale(0.1, 0.1, 1.0)
                itemNodeTransition.updateSublayerTransformScale(node: paneNode, scale: 1.0)
                itemNodeTransition.updateAlpha(node: paneNode, alpha: 1.0)
            } else {
                if self.bounds.intersects(self.scrollNode.view.convert(paneFrame, to: self.view)) {
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
        
        if let selectedFrame {
            let wasAdded = self.selectionView.isHidden
            let selectionFrame = CGRect(origin: CGPoint(x: selectedFrame.minX - 13.0, y: 3.0), size: CGSize(width: selectedFrame.width + 26.0, height: size.height - 3.0 * 2.0))
            if wasAdded {
                self.selectionView.frame = selectionFrame
                ComponentTransition(transition).animateAlpha(view: self.selectionView, from: 0.0, to: 1.0)
            } else {
                transition.updateFrame(view: self.selectionView, frame: selectionFrame)
            }
            self.selectionView.isHidden = false
            
            if self.selectionView.image?.size.height != selectionFrame.height {
                self.selectionView.image = generateStretchableFilledCircleImage(diameter: selectionFrame.height, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.selectionView.tintColor = presentationData.theme.chat.inputPanel.panelControlColor.withAlphaComponent(0.1)
            
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
            self.selectionView.isHidden = true
            self.previousSelectedAbsFrame = nil
            self.previousSelectedFrame = nil
        }
        
        if updated && self.scrollNode.view.contentOffset.x > 0.0 {
            self.scrollNode.view.contentOffset = CGPoint()
        }
    }
}
