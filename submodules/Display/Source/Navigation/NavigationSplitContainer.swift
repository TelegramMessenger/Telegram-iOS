import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

enum NavigationSplitContainerScrollToTop {
    case master
    case detail
}

final class NavigationSplitContainer: ASDisplayNode {
    private var theme: NavigationControllerTheme
    
    private let masterContainer: NavigationContainer
    private let detailContainer: NavigationContainer
    private let separator: ASDisplayNode
    
    private(set) var masterControllers: [ViewController] = []
    private(set) var detailControllers: [ViewController] = []
    
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
        self.separator.backgroundColor = theme.navigationBar.separatorColor
        
        super.init()
        
        self.addSubnode(self.masterContainer)
        self.addSubnode(self.detailContainer)
        self.addSubnode(self.separator)
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
        self.separator.backgroundColor = theme.navigationBar.separatorColor
    }
    
    func scrollToTopProxyFrames(layout: ContainerViewLayout) -> (master: CGRect, detail: CGRect) {
        let masterWidth: CGFloat = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
        let detailWidth = layout.size.width - masterWidth
        let scrollToTopHeight = max(layout.statusBarHeight ?? layout.safeInsets.top, 1.0)
        
        return (
            master: CGRect(origin: CGPoint(), size: CGSize(width: masterWidth, height: scrollToTopHeight)),
            detail: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: scrollToTopHeight))
        )
    }

    func update(layout: ContainerViewLayout, masterControllers: [ViewController], detailControllers: [ViewController], detailsPlaceholderNode: NavigationDetailsPlaceholderNode?, transition: ContainedViewLayoutTransition) {
        let masterWidth: CGFloat = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
        let detailWidth = layout.size.width - masterWidth
        
        transition.updateFrame(node: self.masterContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: masterWidth, height: layout.size.height)))
        transition.updateFrame(node: self.detailContainer, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: layout.size.height)))
        transition.updateFrame(node: self.separator, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: UIScreenPixel, height: layout.size.height)))
        
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
        
        self.masterContainer.update(layout: ContainerViewLayout(size: CGSize(width: masterWidth, height: layout.size.height), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: masterSafeInsets, additionalInsets: UIEdgeInsets(), statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver, presentedInFormSheet: layout.presentedInFormSheet), canBeClosed: false, controllers: masterControllers, transition: transition)
        self.detailContainer.update(layout: ContainerViewLayout(size: CGSize(width: detailWidth, height: layout.size.height), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: detailSafeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver, presentedInFormSheet: layout.presentedInFormSheet), canBeClosed: true, controllers: detailControllers, transition: transition)
        
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
