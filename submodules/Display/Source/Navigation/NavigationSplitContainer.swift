import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

enum NavigationSplitContainerScrollToTop {
    case master
    case detail
}

/// The width of the master pane. While the fold is active and runs vertically through the whole
/// container (iPhone Duo half-open in landscape), the split sits on the hinge's midline, so the
/// chat list and the chat each get one side of the fold. Otherwise a third of the width, at least
/// 320pt and at most half.
public func splitMasterWidth(containerSize: CGSize, division: CGRect?) -> CGFloat {
    if let division, division.width < containerSize.width, division.minY <= 0.5, division.maxY >= containerSize.height - 0.5 {
        return floorToScreenPixels(division.midX)
    }
    return min(max(320.0, floor(containerSize.width / 3.0)), floor(containerSize.width / 2.0))
}

func narrowMasterSwipeCloses(offset: CGFloat, velocity: CGFloat, width: CGFloat) -> Bool {
    if velocity > 600.0 {
        return true
    }
    return offset > width / 3.0 && velocity > -600.0
}

final class NavigationSplitContainer: ASDisplayNode {
    private var theme: NavigationControllerTheme
    
    private let masterContainer: NavigationContainer
    private let detailContainer: NavigationContainer
    private let separator: ASDisplayNode
    
    private(set) var masterControllers: [ViewController] = []
    private(set) var detailControllers: [ViewController] = []
    private var masterWidthOverride: CGFloat?
    private(set) var detailSwipeOffset: CGFloat = 0.0
    private(set) var masterContentWidth: CGFloat = 0.0
    private(set) var layoutMetrics: LayoutMetrics = LayoutMetrics()
    
    var detailSwipeIsAvailable: Bool {
        return self.detailContainer.swipeClosesFirstController
    }
    // The detail pane's last size and `isBesideBottomTabBar`.
    private var detailLayoutState: (size: CGSize, isBesideBottomTabBar: Bool)?
    
    var canHaveKeyboardFocus: Bool = false {
        didSet {
            self.masterContainer.canHaveKeyboardFocus = self.canHaveKeyboardFocus
            self.detailContainer.canHaveKeyboardFocus = self.canHaveKeyboardFocus
        }
    }
    
    var isInFocus: Bool = false {
        didSet {
            if self.isInFocus != oldValue {
                self.inFocusUpdated(isInFocus: self.isInFocus)
            }
        }
    }
    func inFocusUpdated(isInFocus: Bool) {
        self.masterContainer.isInFocus = isInFocus
        self.detailContainer.isInFocus = isInFocus
    }
    
    init(theme: NavigationControllerTheme, controllerRemoved: @escaping (ViewController) -> Void) {
        self.theme = theme
        
        self.masterContainer = NavigationContainer(isFlat: false, controllerRemoved: controllerRemoved)
        self.masterContainer.clipsToBounds = true
        
        self.detailContainer = NavigationContainer(isFlat: false, controllerRemoved: controllerRemoved)
        self.detailContainer.clipsToBounds = true
        
        self.separator = ASDisplayNode()
        self.separator.backgroundColor = theme.separatorColor
        
        super.init()
        
        self.addSubnode(self.masterContainer)
        self.addSubnode(self.detailContainer)
        self.addSubnode(self.separator)
        
        self.detailContainer.firstControllerSwipe = { [weak self] translation, velocity, state in
            self?.detailSwipeUpdated(translation: translation, velocity: velocity, state: state)
        }
    }
    
    func hasNonReadyControllers() -> Bool {
        if self.masterContainer.hasNonReadyControllers() {
            return true
        }
        if self.detailContainer.hasNonReadyControllers() {
            return true
        }
        return false
    }
    
    func updateTheme(theme: NavigationControllerTheme) {
        self.separator.backgroundColor = theme.separatorColor
    }
    
    /// The master controllers highlight the chat the detail pane shows (`updateNavigationCustomData`);
    /// when the split goes away (the layout became compact, e.g. folding iPhone Duo) nothing else clears
    /// that highlight, so the container clears it before it is removed.
    func clearDetailSelection() {
        for controller in self.masterControllers {
            controller.updateNavigationCustomData(nil, progress: 0.0, transition: .immediate)
        }
    }

    func scrollToTopProxyFrames(layout: ContainerViewLayout) -> (master: CGRect, detail: CGRect) {
        let masterWidth = self.masterWidthOverride ?? splitMasterWidth(containerSize: layout.size, division: layout.division)
        let detailWidth = layout.size.width - masterWidth
        let scrollToTopHeight = max(layout.statusBarHeight ?? layout.safeInsets.top, 1.0)
        
        return (
            master: CGRect(origin: CGPoint(), size: CGSize(width: masterWidth, height: scrollToTopHeight)),
            detail: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: scrollToTopHeight))
        )
    }

    func animateDetailIn() {
        let duration: Double = 0.3
        self.detailContainer.layer.animatePosition(from: CGPoint(x: self.detailContainer.bounds.width, y: 0.0), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        self.separator.layer.animatePosition(from: CGPoint(x: self.detailContainer.bounds.width, y: 0.0), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
    }
    
    func animateDetailOut(over nextContent: UIView) {
        guard let snapshot = self.detailContainer.view.snapshotView(afterScreenUpdates: false) else {
            return
        }
        snapshot.frame = self.detailContainer.frame
        nextContent.addSubview(snapshot)
        snapshot.layer.animatePosition(from: CGPoint(), to: CGPoint(x: snapshot.bounds.width, y: 0.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak snapshot] _ in
            snapshot?.removeFromSuperview()
        })
    }
    
    func detailSwipeUpdated(translation: CGFloat, velocity: CGFloat, state: UIGestureRecognizer.State) {
        guard let masterWidth = self.masterWidthOverride else {
            return
        }
        let size = self.bounds.size
        let width = size.width - masterWidth
        let offset = max(0.0, min(width, translation))
        switch state {
        case .began, .changed:
            if state == .began {
                for controller in self.masterControllers {
                    controller.narrowMasterRevealUpdated(true)
                }
            }
            self.detailSwipeOffset = offset
            self.updatePaneFrames(masterWidth: masterWidth, size: size, transition: .immediate)
        case .ended, .cancelled:
            self.detailSwipeOffset = offset
            if state == .ended, narrowMasterSwipeCloses(offset: offset, velocity: velocity, width: width) {
                self.detailControllers.last?.navigationBar?.backPressed()
            }
            for controller in self.masterControllers {
                controller.narrowMasterRevealUpdated(false)
            }
            self.detailSwipeOffset = 0.0
            if self.supernode != nil {
                self.updatePaneFrames(masterWidth: masterWidth, size: size, transition: .animated(duration: 0.3, curve: .spring))
            }
        default:
            break
        }
    }
    
    private func updatePaneFrames(masterWidth: CGFloat, size: CGSize, transition: ContainedViewLayoutTransition) {
        let detailMinX = masterWidth + self.detailSwipeOffset
        transition.updateFrame(node: self.masterContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: detailMinX, height: size.height)))
        transition.updateFrame(node: self.detailContainer, frame: CGRect(origin: CGPoint(x: detailMinX, y: 0.0), size: CGSize(width: size.width - masterWidth, height: size.height)))
        transition.updateFrame(node: self.separator, frame: CGRect(origin: CGPoint(x: detailMinX, y: 0.0), size: CGSize(width: UIScreenPixel, height: size.height)))
    }
    
    func prepareMasterFull(layout: ContainerViewLayout, masterWidth: CGFloat, masterControllers: [ViewController]) {
        self.masterContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.masterContainer.update(layout: layout, canBeClosed: false, controllers: masterControllers, transition: .immediate)
        self.detailContainer.frame = CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: layout.size.width - masterWidth, height: layout.size.height))
        self.separator.frame = CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: UIScreenPixel, height: layout.size.height))
    }
    
    func update(layout: ContainerViewLayout, masterWidthOverride: CGFloat? = nil, masterControllers: [ViewController], detailControllers: [ViewController], detailsPlaceholderNode: NavigationDetailsPlaceholderNode?, transition: ContainedViewLayoutTransition) {
        self.masterWidthOverride = masterWidthOverride
        if masterWidthOverride == nil {
            self.detailSwipeOffset = 0.0
        }
        let masterWidth = masterWidthOverride ?? splitMasterWidth(containerSize: layout.size, division: layout.division)
        let masterContentWidth = masterWidthOverride != nil ? max(masterWidth, layout.size.width) : masterWidth
        let detailWidth = layout.size.width - masterWidth
        self.masterContentWidth = masterContentWidth
        self.layoutMetrics = layout.metrics
        
        self.updatePaneFrames(masterWidth: masterWidth, size: layout.size, transition: transition)
        
        if let detailsPlaceholderNode {
            let needsTiling = layout.size.width > layout.size.height
            detailsPlaceholderNode.updateLayout(size: CGSize(width: detailWidth, height: layout.size.height), needsTiling: needsTiling, transition: transition)
            transition.updateFrame(node: detailsPlaceholderNode, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: layout.size.height)))
        }
        
        // Each pane touches the screen edge on one side only; the split line
        // is not a screen edge, so it must not inherit that side's safe inset.
        var masterSafeInsets = layout.safeInsets
        masterSafeInsets.right = 0.0
        var detailSafeInsets = layout.safeInsets
        detailSafeInsets.left = 0.0
        let masterReserved = reservedAreaForPane(corners: layout.reservedCorners, division: layout.division, paneFrame: CGRect(x: 0.0, y: 0.0, width: masterWidth, height: layout.size.height), containerSize: layout.size)
        let detailReserved = reservedAreaForPane(corners: layout.reservedCorners, division: layout.division, paneFrame: CGRect(x: masterWidth, y: 0.0, width: detailWidth, height: layout.size.height), containerSize: layout.size)
        
        // The master pane is laid out first, so that its top controller reports its tab bar for the layout it now has.
        self.detailContainer.firstControllerPreviousItem = masterWidthOverride != nil ? masterControllers.last.flatMap { .item($0.navigationItem) } : nil
        self.masterContainer.update(layout: ContainerViewLayout(size: CGSize(width: masterContentWidth, height: layout.size.height), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: masterSafeInsets, reservedCorners: masterReserved.corners, division: masterReserved.division, additionalInsets: UIEdgeInsets(), statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver, presentedInFormSheet: layout.presentedInFormSheet), canBeClosed: false, controllers: masterControllers, transition: transition)
        let detailSize = CGSize(width: detailWidth, height: layout.size.height)
        let isBesideBottomTabBar = masterControllers.last?.showsBottomTabBar ?? false
        var detailTransition = transition
        // A master stack change applied without animation (a swipe back in the master pane, as it commits) would move
        // what in the detail lines up with the master's tab bar in one frame; with nothing else changed (the detail's
        // size and its stack, which an animated transition would animate a push or pop of), animate it.
        if case .immediate = transition, let detailLayoutState = self.detailLayoutState, detailLayoutState.size == detailSize, detailLayoutState.isBesideBottomTabBar != isBesideBottomTabBar, self.detailControllers.elementsEqual(detailControllers, by: ===) {
            detailTransition = .animated(duration: 0.3, curve: .easeInOut)
        }
        self.detailLayoutState = (detailSize, isBesideBottomTabBar)
        self.detailContainer.update(layout: ContainerViewLayout(size: detailSize, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: detailSafeInsets, reservedCorners: detailReserved.corners, division: detailReserved.division, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver, presentedInFormSheet: layout.presentedInFormSheet, isBesideBottomTabBar: isBesideBottomTabBar), canBeClosed: true, controllers: detailControllers, transition: detailTransition)
        
        var controllersUpdated = false
        if self.detailControllers.last !== detailControllers.last {
            controllersUpdated = true
        } else if self.masterControllers.count != masterControllers.count {
            controllersUpdated = true
        } else {
            for i in 0 ..< masterControllers.count {
                if masterControllers[i] !== self.masterControllers[i] {
                    controllersUpdated = true
                    break
                }
            }
        }
        
        self.masterControllers = masterControllers
        self.detailControllers = detailControllers
        
        if controllersUpdated {
            let data = self.detailControllers.last?.customData
            for controller in self.masterControllers {
                controller.updateNavigationCustomData(data, progress: 1.0, transition: transition)
            }
        }
    }
}
