import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit
import ReactionSelectionNode
import UndoUI

private extension ContextControllerTakeViewInfo.ContainingItem {
    var contentRect: CGRect {
        switch self {
        case let .node(containingNode):
            return containingNode.contentRect
        case let .view(containingView):
            return containingView.contentRect
        }
    }
    
    var customHitTest: ((CGPoint) -> UIView?)? {
        switch self {
        case let .node(containingNode):
            return containingNode.contentNode.customHitTest
        case let .view(containingView):
            return containingView.contentView.customHitTest
        }
    }
    
    var view: UIView {
        switch self {
        case let .node(containingNode):
            return containingNode.view
        case let .view(containingView):
            return containingView
        }
    }
    
    var contentView: UIView {
        switch self {
        case let .node(containingNode):
            return containingNode.contentNode.view
        case let .view(containingView):
            return containingView.contentView
        }
    }
    
    func contentHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        switch self {
        case let .node(containingNode):
            return containingNode.contentNode.hitTest(point, with: event)
        case let .view(containingView):
            return containingView.contentView.hitTest(point, with: event)
        }
    }
    
    var isExtractedToContextPreview: Bool {
        get {
            switch self {
            case let .node(containingNode):
                return containingNode.isExtractedToContextPreview
            case let .view(containingView):
                return containingView.isExtractedToContextPreview
            }
        } set(value) {
            switch self {
            case let .node(containingNode):
                containingNode.isExtractedToContextPreview = value
            case let .view(containingView):
                containingView.isExtractedToContextPreview = value
            }
        }
    }
    
    var willUpdateIsExtractedToContextPreview: ((Bool, ContainedViewLayoutTransition) -> Void)? {
        switch self {
        case let .node(containingNode):
            return containingNode.willUpdateIsExtractedToContextPreview
        case let .view(containingView):
            return containingView.willUpdateIsExtractedToContextPreview
        }
    }
    
    var isExtractedToContextPreviewUpdated: ((Bool) -> Void)? {
        switch self {
        case let .node(containingNode):
            return containingNode.isExtractedToContextPreviewUpdated
        case let .view(containingView):
            return containingView.isExtractedToContextPreviewUpdated
        }
    }
    
    var layoutUpdated: ((CGSize, ListViewItemUpdateAnimation) -> Void)? {
        get {
            switch self {
            case let .node(containingNode):
                return containingNode.layoutUpdated
            case let .view(containingView):
                return containingView.layoutUpdated
            }
        } set(value) {
            switch self {
            case let .node(containingNode):
                containingNode.layoutUpdated = value
            case let .view(containingView):
                containingView.layoutUpdated = value
            }
        }
    }
}

final class ContextControllerExtractedPresentationNode: ASDisplayNode, ContextControllerPresentationNode, UIScrollViewDelegate {
    enum ContentSource {
        case location(ContextLocationContentSource)
        case reference(ContextReferenceContentSource)
        case extracted(ContextExtractedContentSource)
    }
    
    private final class ContentNode: ASDisplayNode {
        let offsetContainerNode: ASDisplayNode
        var containingItem: ContextControllerTakeViewInfo.ContainingItem
        
        var animateClippingFromContentAreaInScreenSpace: CGRect?
        var storedGlobalFrame: CGRect?
        
        init(containingItem: ContextControllerTakeViewInfo.ContainingItem) {
            self.offsetContainerNode = ASDisplayNode()
            self.containingItem = containingItem
            
            super.init()
            
            self.addSubnode(self.offsetContainerNode)
        }
        
        func update(presentationData: PresentationData, size: CGSize, transition: ContainedViewLayoutTransition) {
        }
        
        func takeContainingNode() {
            switch self.containingItem {
            case let .node(containingNode):
                if containingNode.contentNode.supernode !== self.offsetContainerNode {
                    self.offsetContainerNode.addSubnode(containingNode.contentNode)
                }
            case let .view(containingView):
                if containingView.contentView.superview !== self.offsetContainerNode.view {
                    self.offsetContainerNode.view.addSubview(containingView.contentView)
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.containingItem.contentRect.contains(point) {
                return nil
            }
            return self.view
        }
    }
    
    private final class AnimatingOutState {
        var currentContentScreenFrame: CGRect
        
        init(
            currentContentScreenFrame: CGRect
        ) {
            self.currentContentScreenFrame = currentContentScreenFrame
        }
    }
    
    private let getController: () -> ContextControllerProtocol?
    private let requestUpdate: (ContainedViewLayoutTransition) -> Void
    private let requestUpdateOverlayWantsToBeBelowKeyboard: (ContainedViewLayoutTransition) -> Void
    private let requestDismiss: (ContextMenuActionResult) -> Void
    private let requestAnimateOut: (ContextMenuActionResult, @escaping () -> Void) -> Void
    private let source: ContentSource
    
    private let backgroundNode: NavigationBackgroundNode
    private let dismissTapNode: ASDisplayNode
    private let dismissAccessibilityArea: AccessibilityAreaNode
    private let clippingNode: ASDisplayNode
    private let scroller: UIScrollView
    private let scrollNode: ASDisplayNode
    
    private var reactionContextNode: ReactionContextNode?
    private var reactionContextNodeIsAnimatingOut: Bool = false
    
    private var contentNode: ContentNode?
    private let contentRectDebugNode: ASDisplayNode
    private let actionsStackNode: ContextControllerActionsStackNode
    
    private var validLayout: ContainerViewLayout?
    private var animatingOutState: AnimatingOutState?
    
    private var strings: PresentationStrings?
    
    private enum OverscrollMode {
        case unrestricted
        case topOnly
        case disabled
    }
    
    private var overscrollMode: OverscrollMode = .unrestricted
    
    private weak var currentUndoController: ViewController?
    
    init(
        getController: @escaping () -> ContextControllerProtocol?,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateOverlayWantsToBeBelowKeyboard: @escaping (ContainedViewLayoutTransition) -> Void,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestAnimateOut: @escaping (ContextMenuActionResult, @escaping () -> Void) -> Void,
        source: ContentSource
    ) {
        self.getController = getController
        self.requestUpdate = requestUpdate
        self.requestUpdateOverlayWantsToBeBelowKeyboard = requestUpdateOverlayWantsToBeBelowKeyboard
        self.requestDismiss = requestDismiss
        self.requestAnimateOut = requestAnimateOut
        self.source = source
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear, enableBlur: false)
        
        self.dismissTapNode = ASDisplayNode()
        
        self.dismissAccessibilityArea = AccessibilityAreaNode()
        self.dismissAccessibilityArea.accessibilityTraits = .button
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.scroller = UIScrollView()
        self.scroller.canCancelContentTouches = true
        self.scroller.delaysContentTouches = false
        self.scroller.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scroller.contentInsetAdjustmentBehavior = .never
        }
        self.scroller.alwaysBounceVertical = true
        
        self.scrollNode = ASDisplayNode()
        self.scrollNode.view.addGestureRecognizer(self.scroller.panGestureRecognizer)
        
        self.contentRectDebugNode = ASDisplayNode()
        self.contentRectDebugNode.isUserInteractionEnabled = false
        self.contentRectDebugNode.backgroundColor = UIColor.red.withAlphaComponent(0.2)
        
        self.actionsStackNode = ContextControllerActionsStackNode(
            getController: getController,
            requestDismiss: { result in
                requestDismiss(result)
            },
            requestUpdate: requestUpdate
        )
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.dismissTapNode)
        self.scrollNode.addSubnode(self.dismissAccessibilityArea)
        self.scrollNode.addSubnode(self.actionsStackNode)
        
        self.scroller.delegate = self
        
        self.dismissTapNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dismissTapGesture(_:))))
        
        self.dismissAccessibilityArea.activate = { [weak self] in
            self?.requestDismiss(.default)
            
            return true
        }
    }
    
    @objc func dismissTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.requestDismiss(.default)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if let reactionContextNode = self.reactionContextNode {
                if let result = reactionContextNode.hitTest(self.view.convert(point, to: reactionContextNode.view), with: event) {
                    return result
                }
            }
            
            if case let .extracted(source) = self.source, !source.ignoreContentTouches, let contentNode = self.contentNode {
                let contentPoint = self.view.convert(point, to: contentNode.containingItem.contentView)
                if let result = contentNode.containingItem.customHitTest?(contentPoint) {
                    return result
                } else if let result = contentNode.containingItem.contentHitTest(contentPoint, with: event) {
                    if result is TextSelectionNodeView {
                        return result
                    } else if contentNode.containingItem.contentRect.contains(contentPoint) {
                        return contentNode.containingItem.contentView
                    }
                }
            }
            
            return self.scrollNode.hitTest(self.view.convert(point, to: self.scrollNode.view), with: event)
        } else {
            return nil
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let reactionContextNode = self.reactionContextNode, (reactionContextNode.isExpanded || !reactionContextNode.canBeExpanded) {
            self.overscrollMode = .disabled
            self.scroller.alwaysBounceVertical = false
        } else {
            if scrollView.contentSize.height > scrollView.bounds.height {
                self.overscrollMode = .unrestricted
                self.scroller.alwaysBounceVertical = true
            } else {
                if self.reactionContextNode != nil {
                    self.overscrollMode = .topOnly
                    self.scroller.alwaysBounceVertical = true
                } else {
                    self.overscrollMode = .disabled
                    self.scroller.alwaysBounceVertical = false
                }
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var adjustedBounds = scrollView.bounds
        var topOverscroll: CGFloat = 0.0
        
        switch self.overscrollMode {
        case .unrestricted:
            if adjustedBounds.origin.y < 0.0 {
                topOverscroll = -adjustedBounds.origin.y
            }
        case .disabled:
            break
        case .topOnly:
            if scrollView.contentSize.height <= scrollView.bounds.height {
                if adjustedBounds.origin.y > 0.0 {
                    adjustedBounds.origin.y = 0.0
                } else {
                    adjustedBounds.origin.y = floorToScreenPixels(adjustedBounds.origin.y * 0.35)
                    topOverscroll = -adjustedBounds.origin.y
                }
            } else {
                if adjustedBounds.origin.y < 0.0 {
                    adjustedBounds.origin.y = floorToScreenPixels(adjustedBounds.origin.y * 0.35)
                    topOverscroll = -adjustedBounds.origin.y
                } else if adjustedBounds.origin.y + adjustedBounds.height > scrollView.contentSize.height {
                    adjustedBounds.origin.y = scrollView.contentSize.height - adjustedBounds.height
                }
            }
        }
        self.scrollNode.bounds = adjustedBounds
        
        if let reactionContextNode = self.reactionContextNode {
            let isIntersectingContent = adjustedBounds.minY >= 10.0
            reactionContextNode.updateIsIntersectingContent(isIntersectingContent: isIntersectingContent, transition: .animated(duration: 0.25, curve: .easeInOut))
            
            if !reactionContextNode.isExpanded && reactionContextNode.canBeExpanded {
                if topOverscroll > 30.0 && self.scroller.isDragging {
                    self.scroller.panGestureRecognizer.state = .cancelled
                    reactionContextNode.expand()
                } else {
                    reactionContextNode.updateExtension(distance: topOverscroll)
                }
            }
        }
    }
    
    func highlightGestureMoved(location: CGPoint, hover: Bool) {
        self.actionsStackNode.highlightGestureMoved(location: self.view.convert(location, to: self.actionsStackNode.view))
        
        if let reactionContextNode = self.reactionContextNode {
            reactionContextNode.highlightGestureMoved(location: self.view.convert(location, to: reactionContextNode.view), hover: hover)
        }
    }
    
    func highlightGestureFinished(performAction: Bool) {
        self.actionsStackNode.highlightGestureFinished(performAction: performAction)
        
        if let reactionContextNode = self.reactionContextNode {
            reactionContextNode.highlightGestureFinished(performAction: performAction)
        }
    }
    
    func decreaseHighlightedIndex() {
        self.actionsStackNode.decreaseHighlightedIndex()
    }
    
    func increaseHighlightedIndex() {
        self.actionsStackNode.increaseHighlightedIndex()
    }
    
    func wantsDisplayBelowKeyboard() -> Bool {
        if let reactionContextNode = self.reactionContextNode {
            return reactionContextNode.wantsDisplayBelowKeyboard()
        } else {
            return false
        }
    }
    
    func replaceItems(items: ContextController.Items, animated: Bool) {
        self.actionsStackNode.replace(item: makeContextControllerActionsStackItem(items: items), animated: animated)
    }
    
    func pushItems(items: ContextController.Items) {
        let currentScrollingState = self.getCurrentScrollingState()
        var positionLock: CGFloat?
        if !items.disablePositionLock {
            positionLock = self.getActionsStackPositionLock()
        }
        self.actionsStackNode.push(item: makeContextControllerActionsStackItem(items: items), currentScrollingState: currentScrollingState, positionLock: positionLock, animated: true)
    }
    
    func popItems() {
        self.actionsStackNode.pop()
    }
    
    private func getCurrentScrollingState() -> CGFloat {
        return self.scrollNode.bounds.minY
    }
    
    private func getActionsStackPositionLock() -> CGFloat? {
        switch self.source {
        case .location, .reference:
            return nil
        case .extracted:
            return self.actionsStackNode.view.convert(CGPoint(), to: self.view).y
        }
    }
    
    private var proposedReactionsPositionLock: CGFloat?
    private var currentReactionsPositionLock: CGFloat?
    
    private func setCurrentReactionsPositionLock() {
        self.currentReactionsPositionLock = self.proposedReactionsPositionLock
    }
    
    private func getCurrentReactionsPositionLock() -> CGFloat? {
        return self.currentReactionsPositionLock
    }
    
    func update(
        presentationData: PresentationData,
        layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition,
        stateTransition: ContextControllerPresentationNodeStateTransition?
    ) {
        self.validLayout = layout
        
        let contentActionsSpacing: CGFloat = 7.0
        let actionsEdgeInset: CGFloat
        let actionsSideInset: CGFloat = 6.0
        let topInset: CGFloat = layout.insets(options: .statusBar).top + 8.0
        let bottomInset: CGFloat = 10.0
        
        let contentNode: ContentNode?
        var contentTransition = transition
        
        if self.strings !== presentationData.strings {
            self.strings = presentationData.strings
            
            self.dismissAccessibilityArea.accessibilityLabel = presentationData.strings.VoiceOver_DismissContextMenu
        }
        
        switch self.source {
        case .location, .reference:
            self.backgroundNode.updateColor(
                color: .clear,
                enableBlur: false,
                forceKeepBlur: false,
                transition: .immediate
            )
            actionsEdgeInset = 16.0
        case .extracted:
            self.backgroundNode.updateColor(
                color: presentationData.theme.contextMenu.dimColor,
                enableBlur: true,
                forceKeepBlur: true,
                transition: .immediate
            )
            actionsEdgeInset = 12.0
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
        self.backgroundNode.update(size: layout.size, transition: transition)
        
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
        if self.scrollNode.frame != CGRect(origin: CGPoint(), size: layout.size) {
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
            transition.updateFrame(view: self.scroller, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
        }
        
        if let current = self.contentNode {
            contentNode = current
        } else {
            switch self.source {
            case .location, .reference:
                contentNode = nil
            case let .extracted(source):
                guard let takeInfo = source.takeView() else {
                    return
                }
                let contentNodeValue = ContentNode(containingItem: takeInfo.containingItem)
                contentNodeValue.animateClippingFromContentAreaInScreenSpace = takeInfo.contentAreaInScreenSpace
                self.scrollNode.insertSubnode(contentNodeValue, aboveSubnode: self.actionsStackNode)
                self.contentNode = contentNodeValue
                contentNode = contentNodeValue
                contentTransition = .immediate
            }
        }
        
        var animateReactionsIn = false
        var contentTopInset: CGFloat = topInset
        var removedReactionContextNode: ReactionContextNode?
        if let reactionItems = self.actionsStackNode.topReactionItems, !reactionItems.reactionItems.isEmpty {
            let reactionContextNode: ReactionContextNode
            if let current = self.reactionContextNode {
                reactionContextNode = current
            } else {
                reactionContextNode = ReactionContextNode(
                    context: reactionItems.context,
                    animationCache: reactionItems.animationCache,
                    presentationData: presentationData,
                    items: reactionItems.reactionItems,
                    selectedItems: reactionItems.selectedReactionItems,
                    getEmojiContent: reactionItems.getEmojiContent,
                    isExpandedUpdated: { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.setCurrentReactionsPositionLock()
                        strongSelf.requestUpdate(transition)
                    },
                    requestLayout: { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.requestUpdate(transition)
                    },
                    requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.requestUpdateOverlayWantsToBeBelowKeyboard(transition)
                    }
                )
                self.reactionContextNode = reactionContextNode
                self.addSubnode(reactionContextNode)
                
                if transition.isAnimated {
                    animateReactionsIn = true
                }
                
                reactionContextNode.reactionSelected = { [weak self] reaction, isLarge in
                    guard let strongSelf = self, let controller = strongSelf.getController() as? ContextController else {
                        return
                    }
                    controller.reactionSelected?(reaction, isLarge)
                }
                let context = reactionItems.context
                reactionContextNode.premiumReactionsSelected = { [weak self] file in
                    guard let strongSelf = self, let validLayout = strongSelf.validLayout, let controller = strongSelf.getController() as? ContextController else {
                        return
                    }
                    
                    if let file = file, let reactionContextNode = strongSelf.reactionContextNode {
                        let position: UndoOverlayController.Position
                        let insets = validLayout.insets(options: .statusBar)
                        if reactionContextNode.hasSpaceInTheBottom(insets: insets, height: 100.0) {
                            position = .bottom
                        } else {
                            position = .top
                        }
                        
                        var animateInAsReplacement = false
                        if let currentUndoController = strongSelf.currentUndoController {
                            currentUndoController.dismiss()
                            animateInAsReplacement = true
                        }
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let undoController = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, title: nil, text: presentationData.strings.Chat_PremiumReactionToastTitle, undoText: presentationData.strings.Chat_PremiumReactionToastAction, customAction: { [weak controller] in
                            controller?.premiumReactionsSelected?()
                        }), elevatedLayout: false, position: position, animateInAsReplacement: animateInAsReplacement, action: { _ in true })
                        strongSelf.currentUndoController = undoController
                        controller.present(undoController, in: .current)
                    } else {
                        controller.premiumReactionsSelected?()
                    }
                }
            }
            contentTopInset += reactionContextNode.contentHeight + 18.0
        } else if let reactionContextNode = self.reactionContextNode {
            self.reactionContextNode = nil
            removedReactionContextNode = reactionContextNode
        }
        
        if let contentNode = contentNode {
            switch stateTransition {
            case .animateIn, .animateOut:
                contentNode.storedGlobalFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
            case .none:
                if contentNode.storedGlobalFrame == nil {
                    contentNode.storedGlobalFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
                }
            }
        }
        
        let contentParentGlobalFrame: CGRect
        var contentRect: CGRect
        
        switch self.source {
        case let .location(location):
            if let transitionInfo = location.transitionInfo() {
                contentRect = CGRect(origin: transitionInfo.location, size: CGSize(width: 1.0, height: 1.0))
                contentParentGlobalFrame = CGRect(origin: CGPoint(x: 0.0, y: contentRect.minX), size: CGSize(width: layout.size.width, height: contentRect.height))
            } else {
                return
            }
        case let .reference(reference):
            if let transitionInfo = reference.transitionInfo() {
                contentRect = convertFrame(transitionInfo.referenceView.bounds, from: transitionInfo.referenceView, to: self.view).insetBy(dx: -2.0, dy: 0.0)
                contentRect.size.width += 5.0
                contentParentGlobalFrame = CGRect(origin: CGPoint(x: 0.0, y: contentRect.minX), size: CGSize(width: layout.size.width, height: contentRect.height))
            } else {
                return
            }
        case .extracted:
            if let contentNode = contentNode {
                contentParentGlobalFrame = convertFrame(contentNode.containingItem.view.bounds, from: contentNode.containingItem.view, to: self.view)
                
                let contentRectGlobalFrame = CGRect(origin: CGPoint(x: contentNode.containingItem.contentRect.minX, y: (contentNode.storedGlobalFrame?.maxY ?? 0.0) - contentNode.containingItem.contentRect.height), size: contentNode.containingItem.contentRect.size)
                contentRect = CGRect(origin: CGPoint(x: contentRectGlobalFrame.minX, y: contentRectGlobalFrame.maxY - contentNode.containingItem.contentRect.size.height), size: contentNode.containingItem.contentRect.size)
                if case .animateOut = stateTransition {
                    contentRect.origin.y = self.contentRectDebugNode.frame.maxY - contentRect.size.height
                }
            } else {
                return
            }
        }
        
        let keepInPlace: Bool
        let actionsHorizontalAlignment: ContextActionsHorizontalAlignment
        switch self.source {
        case .location, .reference:
            keepInPlace = true
            actionsHorizontalAlignment = .default
        case let .extracted(source):
            keepInPlace = source.keepInPlace
            actionsHorizontalAlignment = source.actionsHorizontalAlignment
        }
        
        var defaultScrollY: CGFloat = 0.0
        if self.animatingOutState == nil {
            if let contentNode = contentNode {
                contentNode.update(
                    presentationData: presentationData,
                    size: contentNode.containingItem.view.bounds.size,
                    transition: contentTransition
                )
            }
            
            let actionsConstrainedHeight: CGFloat
            if let actionsPositionLock = self.actionsStackNode.topPositionLock {
                actionsConstrainedHeight = layout.size.height - bottomInset - layout.intrinsicInsets.bottom - actionsPositionLock
            } else {
                actionsConstrainedHeight = layout.size.height - contentTopInset - contentRect.height - contentActionsSpacing - bottomInset - layout.intrinsicInsets.bottom
            }
            
            let actionsStackPresentation: ContextControllerActionsStackNode.Presentation
            switch self.source {
            case .location, .reference:
                actionsStackPresentation = .inline
            case .extracted:
                actionsStackPresentation = .modal
            }
            
            let actionsSize = self.actionsStackNode.update(
                presentationData: presentationData,
                constrainedSize: CGSize(width: layout.size.width, height: actionsConstrainedHeight),
                presentation: actionsStackPresentation,
                transition: transition
            )
            
            var isAnimatingOut = false
            if case .animateOut = stateTransition {
                isAnimatingOut = true
            } else {
                if let currentReactionsPositionLock = self.currentReactionsPositionLock, let reactionContextNode = self.reactionContextNode {
                    contentRect.origin.y = currentReactionsPositionLock + reactionContextNode.contentHeight + 18.0 + reactionContextNode.visibleExtensionDistance
                } else if let topPositionLock = self.actionsStackNode.topPositionLock {
                    contentRect.origin.y = topPositionLock - contentActionsSpacing - contentRect.height
                } else if keepInPlace {
                } else {
                    if contentRect.minY < contentTopInset {
                        contentRect.origin.y = contentTopInset
                    }
                    var combinedBounds = CGRect(origin: CGPoint(x: 0.0, y: contentRect.minY), size: CGSize(width: layout.size.width, height: contentRect.height + contentActionsSpacing + actionsSize.height))
                    if combinedBounds.maxY > layout.size.height - bottomInset - layout.intrinsicInsets.bottom {
                        combinedBounds.origin.y = layout.size.height - bottomInset - layout.intrinsicInsets.bottom - combinedBounds.height
                    }
                    if combinedBounds.minY < contentTopInset {
                        combinedBounds.origin.y = contentTopInset
                    }
                    
                    contentRect.origin.y = combinedBounds.minY
                }
            }
            
            if let reactionContextNode = self.reactionContextNode {
                var reactionContextNodeTransition = transition
                if reactionContextNode.frame.isEmpty {
                    reactionContextNodeTransition = .immediate
                }
                reactionContextNodeTransition.updateFrame(node: reactionContextNode, frame: CGRect(origin: CGPoint(), size: layout.size), beginWithCurrentState: true)
                
                var reactionAnchorRect = contentRect.offsetBy(dx: contentParentGlobalFrame.minX, dy: 0.0)
                
                let bottomInset = layout.insets(options: [.input]).bottom
                var isCoveredByInput = false
                if reactionAnchorRect.minY > layout.size.height - bottomInset {
                    reactionAnchorRect.origin.y = layout.size.height - bottomInset
                    isCoveredByInput = true
                }
                
                reactionContextNode.updateLayout(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: 0.0, right: layout.safeInsets.right), anchorRect: reactionAnchorRect, isCoveredByInput: isCoveredByInput, isAnimatingOut: isAnimatingOut, transition: reactionContextNodeTransition)
                
                self.proposedReactionsPositionLock = contentRect.minY - 18.0 - reactionContextNode.contentHeight - 46.0
            } else {
                self.proposedReactionsPositionLock = nil
            }
            
            if let _ = self.currentReactionsPositionLock {
                transition.updateAlpha(node: self.actionsStackNode, alpha: 0.0)
            } else {
                transition.updateAlpha(node: self.actionsStackNode, alpha: 1.0)
            }
            
            if let removedReactionContextNode = removedReactionContextNode {
                removedReactionContextNode.animateOut(to: contentRect, animatingOutToReaction: false)
                transition.updateAlpha(node: removedReactionContextNode, alpha: 0.0, completion: { [weak removedReactionContextNode] _ in
                    removedReactionContextNode?.removeFromSupernode()
                })
            }
            
            transition.updateFrame(node: self.contentRectDebugNode, frame: contentRect, beginWithCurrentState: true)
            
            var actionsFrame = CGRect(origin: CGPoint(x: actionsSideInset, y: contentRect.maxY + contentActionsSpacing), size: actionsSize)

            var contentVerticalOffset: CGFloat = 0.0
            if keepInPlace, case .extracted = self.source {
                actionsFrame.origin.y = contentRect.minY - contentActionsSpacing - actionsFrame.height
                let statusBarHeight = (layout.statusBarHeight ?? 0.0)
                if actionsFrame.origin.y < statusBarHeight {
                    let updatedActionsOriginY = statusBarHeight + contentActionsSpacing
                    let delta = updatedActionsOriginY - actionsFrame.origin.y
                    actionsFrame.origin.y = updatedActionsOriginY
                    contentVerticalOffset = delta
                }
            }
            var additionalVisibleOffsetY: CGFloat = 0.0
            if let reactionContextNode = self.reactionContextNode {
                additionalVisibleOffsetY += reactionContextNode.visibleExtensionDistance
            }
            if case .center = actionsHorizontalAlignment {
                actionsFrame.origin.x = floor(contentParentGlobalFrame.minX + contentRect.midX - actionsFrame.width / 2.0)
                if actionsFrame.maxX > layout.size.width - actionsEdgeInset {
                    actionsFrame.origin.x = layout.size.width - actionsEdgeInset - actionsFrame.width
                }
                if actionsFrame.minX < actionsEdgeInset {
                    actionsFrame.origin.x = actionsEdgeInset
                }
            } else {
                if case .location = self.source {
                    actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.minX + actionsSideInset - 4.0
                } else if case .right = actionsHorizontalAlignment {
                    actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.maxX - actionsSideInset - actionsSize.width - 1.0
                } else {
                    if contentRect.midX < layout.size.width / 2.0 {
                        actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.minX + actionsSideInset - 4.0
                    } else {
                        switch self.source {
                        case .location, .reference:
                            actionsFrame.origin.x = floor(contentParentGlobalFrame.minX + contentRect.midX - actionsFrame.width / 2.0)
                            if actionsFrame.maxX > layout.size.width - actionsEdgeInset {
                                actionsFrame.origin.x = layout.size.width - actionsEdgeInset - actionsFrame.width
                            }
                            if actionsFrame.minX < actionsEdgeInset {
                                actionsFrame.origin.x = actionsEdgeInset
                            }
                        case .extracted:
                            actionsFrame.origin.x = contentParentGlobalFrame.minX + contentRect.maxX - actionsSideInset - actionsSize.width - 1.0
                        }
                    }
                }
                if actionsFrame.maxX > layout.size.width - actionsEdgeInset {
                    actionsFrame.origin.x = layout.size.width - actionsEdgeInset - actionsFrame.width
                }
                if actionsFrame.minX < actionsEdgeInset {
                    actionsFrame.origin.x = actionsEdgeInset
                }
            }
            transition.updateFrame(node: self.actionsStackNode, frame: actionsFrame.offsetBy(dx: 0.0, dy: additionalVisibleOffsetY), beginWithCurrentState: true)
            
            if let contentNode = contentNode {
                contentTransition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: contentParentGlobalFrame.minX + contentRect.minX - contentNode.containingItem.contentRect.minX, y: contentRect.minY - contentNode.containingItem.contentRect.minY + contentVerticalOffset + additionalVisibleOffsetY), size: contentNode.containingItem.view.bounds.size), beginWithCurrentState: true)
            }
            
            let contentHeight: CGFloat
            if self.actionsStackNode.topPositionLock != nil || self.currentReactionsPositionLock != nil {
                contentHeight = layout.size.height
            } else {
                if keepInPlace, case .extracted = self.source {
                    contentHeight = (layout.statusBarHeight ?? 0.0) + actionsFrame.height + abs(actionsFrame.minY) + bottomInset + layout.intrinsicInsets.bottom
                } else {
                    contentHeight = actionsFrame.maxY + bottomInset + layout.intrinsicInsets.bottom
                }
            }
            let contentSize = CGSize(width: layout.size.width, height: contentHeight)
            
            if self.scroller.contentSize != contentSize {
                let previousContentOffset = self.scroller.contentOffset
                self.scroller.contentSize = contentSize
                if let storedScrollingState = self.actionsStackNode.storedScrollingState {
                    self.actionsStackNode.clearStoredScrollingState()
                    
                    self.scroller.contentOffset = CGPoint(x: 0.0, y: storedScrollingState)
                }
                if case .none = stateTransition, transition.isAnimated {
                    let contentOffset = self.scroller.contentOffset
                    transition.animateOffsetAdditive(layer: self.scrollNode.layer, offset: previousContentOffset.y - contentOffset.y)
                }
            }
            
            self.actionsStackNode.updatePanSelection(isEnabled: contentSize.height <= layout.size.height)
            
            defaultScrollY = contentSize.height - layout.size.height
            if defaultScrollY < 0.0 {
                defaultScrollY = 0.0
            }
            
            self.dismissTapNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: max(contentSize.height, layout.size.height)))
            self.dismissAccessibilityArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: max(contentSize.height, layout.size.height)))
        }
        
        switch stateTransition {
        case .animateIn:
            if let contentNode = contentNode {
                contentNode.takeContainingNode()
            }
            
            let duration: Double = 0.42
            let springDamping: CGFloat = 104.0
            
            self.scroller.contentOffset = CGPoint(x: 0.0, y: defaultScrollY)
            
            self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            
            let animationInContentDistance: CGFloat
            let currentContentScreenFrame: CGRect
            if let contentNode = contentNode {
                if let animateClippingFromContentAreaInScreenSpace = contentNode.animateClippingFromContentAreaInScreenSpace {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(x: 0.0, y: animateClippingFromContentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: animateClippingFromContentAreaInScreenSpace.height)), to: CGRect(origin: CGPoint(), size: layout.size), duration: 0.2)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: animateClippingFromContentAreaInScreenSpace.minY, to: 0.0, duration: 0.2)
                }
                
                currentContentScreenFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
                let currentContentLocalFrame = convertFrame(contentRect, from: self.scrollNode.view, to: self.view)
                animationInContentDistance = currentContentLocalFrame.maxY - currentContentScreenFrame.maxY
                
                contentNode.layer.animateSpring(
                    from: -animationInContentDistance as NSNumber, to: 0.0 as NSNumber,
                    keyPath: "position.y",
                    duration: duration,
                    delay: 0.0,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: true
                )
            } else {
                animationInContentDistance = 0.0
                currentContentScreenFrame = contentRect
            }
            
            self.actionsStackNode.layer.animateAlpha(from: 0.0, to: self.actionsStackNode.alpha, duration: 0.05)
            self.actionsStackNode.layer.animateSpring(
                from: 0.01 as NSNumber,
                to: 1.0 as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: 0.0,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: false
            )
            
            let actionsSize = self.actionsStackNode.bounds.size
            
            var actionsPositionDeltaXDistance: CGFloat = 0.0
            if case .center = actionsHorizontalAlignment {
                actionsPositionDeltaXDistance = currentContentScreenFrame.midX - self.actionsStackNode.frame.midX
            }
            
            let actionsVerticalTransitionDirection: CGFloat
            if let contentNode = contentNode {
                if contentNode.frame.minY < self.actionsStackNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            } else {
                if contentRect.minY < self.actionsStackNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            }
            let actionsPositionDeltaYDistance = -animationInContentDistance + actionsVerticalTransitionDirection * actionsSize.height / 2.0 - contentActionsSpacing
            self.actionsStackNode.layer.animateSpring(
                from: NSValue(cgPoint: CGPoint(x: actionsPositionDeltaXDistance, y: actionsPositionDeltaYDistance)),
                to: NSValue(cgPoint: CGPoint()),
                keyPath: "position",
                duration: duration,
                delay: 0.0,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            if let reactionContextNode = self.reactionContextNode {
                let reactionsPositionDeltaYDistance = -animationInContentDistance
                reactionContextNode.layer.animateSpring(
                    from: NSValue(cgPoint: CGPoint(x: 0.0, y: reactionsPositionDeltaYDistance)),
                    to: NSValue(cgPoint: CGPoint()),
                    keyPath: "position",
                    duration: duration,
                    delay: 0.0,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: true
                )
                reactionContextNode.animateIn(from: currentContentScreenFrame)
            }
            
            self.actionsStackNode.animateIn()
            
            if let contentNode = contentNode {
                contentNode.containingItem.isExtractedToContextPreview = true
                contentNode.containingItem.isExtractedToContextPreviewUpdated?(true)
                contentNode.containingItem.willUpdateIsExtractedToContextPreview?(true, transition)
                
                contentNode.containingItem.layoutUpdated = { [weak self] _, animation in
                    guard let strongSelf = self, let _ = strongSelf.contentNode else {
                        return
                    }
                    
                    if let _ = strongSelf.animatingOutState {
                    } else {
                        strongSelf.requestUpdate(animation.transition)
                    }
                }
            }
            
            if let overlayViews = self.getController()?.getOverlayViews?(), !overlayViews.isEmpty {
                for view in overlayViews {
                    if let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = view.convert(view.bounds, to: nil)
                        self.view.addSubview(snapshotView)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
            }
        case let .animateOut(result, completion):
            let duration: Double
            let timingFunction: String
            switch result {
            case .default, .dismissWithoutContent:
                duration = self.reactionContextNodeIsAnimatingOut ? 0.25 : 0.2
                timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
            case let .custom(customTransition):
                switch customTransition {
                case let .animated(customDuration, curve):
                    duration = customDuration
                    timingFunction = curve.timingFunction
                case .immediate:
                    duration = self.reactionContextNodeIsAnimatingOut ? 0.25 : 0.2
                    timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
                }
            }
            
            let currentContentScreenFrame: CGRect
            
            switch self.source {
            case let .location(location):
                if let putBackInfo = location.transitionInfo() {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(), size: layout.size), to: CGRect(origin: CGPoint(x: 0.0, y: putBackInfo.contentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: putBackInfo.contentAreaInScreenSpace.height)), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    
                    currentContentScreenFrame = CGRect(origin: putBackInfo.location, size: CGSize(width: 1.0, height: 1.0))
                } else {
                    return
                }
            case let .reference(source):
                if let putBackInfo = source.transitionInfo() {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(), size: layout.size), to: CGRect(origin: CGPoint(x: 0.0, y: putBackInfo.contentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: putBackInfo.contentAreaInScreenSpace.height)), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    
                    currentContentScreenFrame = convertFrame(putBackInfo.referenceView.bounds, from: putBackInfo.referenceView, to: self.view)
                } else {
                    return
                }
            case let .extracted(source):
                let putBackInfo = source.putBack()
                
                if let putBackInfo = putBackInfo {
                    self.clippingNode.layer.animateFrame(from: CGRect(origin: CGPoint(), size: layout.size), to: CGRect(origin: CGPoint(x: 0.0, y: putBackInfo.contentAreaInScreenSpace.minY), size: CGSize(width: layout.size.width, height: putBackInfo.contentAreaInScreenSpace.height)), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                    self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: putBackInfo.contentAreaInScreenSpace.minY, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
                }
                
                if let contentNode = contentNode {
                    currentContentScreenFrame = convertFrame(contentNode.containingItem.contentRect, from: contentNode.containingItem.view, to: self.view)
                } else {
                    return
                }
            }
            
            self.animatingOutState = AnimatingOutState(
                currentContentScreenFrame: currentContentScreenFrame
            )
            
            let currentContentLocalFrame = convertFrame(contentRect, from: self.scrollNode.view, to: self.view)
            
            let animationInContentDistance: CGFloat
            
            switch result {
            case .default, .custom:
                animationInContentDistance = currentContentLocalFrame.minY - currentContentScreenFrame.minY
            case .dismissWithoutContent:
                animationInContentDistance = 0.0
                if let contentNode = contentNode {
                    contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
                }
            }
            
            let actionsVerticalTransitionDirection: CGFloat
            if let contentNode = contentNode {
                if contentNode.frame.minY < self.actionsStackNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            } else {
                if contentRect.minY < self.actionsStackNode.frame.minY {
                    actionsVerticalTransitionDirection = -1.0
                } else {
                    actionsVerticalTransitionDirection = 1.0
                }
            }
            
            let completeWithActionStack = contentNode == nil
            
            if let contentNode = contentNode {
                contentNode.containingItem.willUpdateIsExtractedToContextPreview?(false, transition)
                
                contentNode.offsetContainerNode.position = contentNode.offsetContainerNode.position.offsetBy(dx: 0.0, dy: -animationInContentDistance)
                let reactionContextNodeIsAnimatingOut = self.reactionContextNodeIsAnimatingOut
                contentNode.offsetContainerNode.layer.animate(
                    from: animationInContentDistance as NSNumber,
                    to: 0.0 as NSNumber,
                    keyPath: "position.y",
                    timingFunction: timingFunction,
                    duration: duration,
                    delay: 0.0,
                    additive: true,
                    completion: { [weak self] _ in
                        Queue.mainQueue().after(reactionContextNodeIsAnimatingOut ? 0.2 * UIView.animationDurationFactor() : 0.0, {
                            contentNode.containingItem.isExtractedToContextPreview = false
                            contentNode.containingItem.isExtractedToContextPreviewUpdated?(false)
                            
                            if let strongSelf = self, let contentNode = strongSelf.contentNode {
                                switch contentNode.containingItem {
                                case let .node(containingNode):
                                    containingNode.addSubnode(containingNode.contentNode)
                                case let .view(containingView):
                                    containingView.addSubview(containingView.contentView)
                                }
                            }
                            
                            completion()
                        })
                    }
                )
            }
            
            self.actionsStackNode.layer.animateAlpha(from: self.actionsStackNode.alpha, to: 0.0, duration: duration, removeOnCompletion: false)
            self.actionsStackNode.layer.animate(
                from: 1.0 as NSNumber,
                to: 0.01 as NSNumber,
                keyPath: "transform.scale",
                timingFunction: timingFunction,
                duration: duration,
                delay: 0.0,
                removeOnCompletion: false,
                completion: { _ in
                    if completeWithActionStack {
                        completion()
                    }
                }
            )
            
            let actionsSize = self.actionsStackNode.bounds.size
            
            var actionsPositionDeltaXDistance: CGFloat = 0.0
            if case .center = actionsHorizontalAlignment {
                actionsPositionDeltaXDistance = currentContentScreenFrame.midX - self.actionsStackNode.frame.midX
            }
            let actionsPositionDeltaYDistance = -animationInContentDistance + actionsVerticalTransitionDirection * actionsSize.height / 2.0 - contentActionsSpacing
            self.actionsStackNode.layer.animate(
                from: NSValue(cgPoint: CGPoint()),
                to: NSValue(cgPoint: CGPoint(x: actionsPositionDeltaXDistance, y: actionsPositionDeltaYDistance)),
                keyPath: "position",
                timingFunction: timingFunction,
                duration: duration,
                delay: 0.0,
                removeOnCompletion: false,
                additive: true
            )
            
            self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
            
            if let reactionContextNode = self.reactionContextNode {
                reactionContextNode.animateOut(to: currentContentScreenFrame, animatingOutToReaction: self.reactionContextNodeIsAnimatingOut)
            }
            
            if let overlayViews = self.getController()?.getOverlayViews?(), !overlayViews.isEmpty {
                for view in overlayViews {
                    if let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = view.convert(view.bounds, to: nil)
                        self.view.addSubview(snapshotView)
                        snapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
            }
        case .none:
            if animateReactionsIn, let reactionContextNode = self.reactionContextNode {
                reactionContextNode.animateIn(from: contentRect)
            }
        }
    }
    
    func animateOutToReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, reducedCurve: Bool, completion: @escaping () -> Void) {
        guard let reactionContextNode = self.reactionContextNode else {
            self.requestAnimateOut(.default, completion)
            return
        }

        var contentCompleted = false
        var reactionCompleted = false
        let intermediateCompletion: () -> Void = {
            if contentCompleted && reactionCompleted {
                completion()
            }
        }
        
        self.reactionContextNodeIsAnimatingOut = true
        reactionContextNode.willAnimateOutToReaction(value: value)
        
        let result: ContextMenuActionResult
        if reducedCurve {
            result = .custom(.animated(duration: 0.5, curve: .spring))
        } else {
            result = .default
        }
        
        self.requestAnimateOut(result, {
            contentCompleted = true
            intermediateCompletion()
        })
        
        reactionContextNode.animateOutToReaction(value: value, targetView: targetView, hideNode: hideNode, animateTargetContainer: animateTargetContainer, addStandaloneReactionAnimation: addStandaloneReactionAnimation, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reactionContextNode?.removeFromSupernode()
            strongSelf.reactionContextNode = nil
            reactionCompleted = true
            intermediateCompletion()
        })
    }
    
    func cancelReactionAnimation() {
        self.reactionContextNode?.cancelReactionAnimation()
    }
    
    func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        if self.reactionContextNodeIsAnimatingOut, let reactionContextNode = self.reactionContextNode {
            reactionContextNode.bounds = reactionContextNode.bounds.offsetBy(dx: 0.0, dy: offset.y)
            transition.animateOffsetAdditive(node: reactionContextNode, offset: -offset.y)
        }
    }
}
