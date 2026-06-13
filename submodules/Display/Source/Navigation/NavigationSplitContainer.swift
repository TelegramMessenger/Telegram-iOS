import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

enum NavigationSplitContainerScrollToTop {
    case master
    case detail
}

final class NavigationSplitContainer: ASDisplayNode {
    private enum Metrics {
        static let regularMasterMinWidth: CGFloat = 320.0
        static let compactMasterWidth: CGFloat = 96.0
        static let avatarRailMaximumContainerWidth: CGFloat = 1133.0
    }

    private var theme: NavigationControllerTheme
    
    private let masterContainer: NavigationContainer
    private let detailContainer: NavigationContainer
    private let separator: ASDisplayNode
    private let resizeHandle: ASDisplayNode
    private var forceRegularMasterWidth: Bool = UserDefaults.standard.bool(forKey: "NavigationSplitContainer.forceRegularMasterWidth")
    private var currentLayout: ContainerViewLayout?
    private var currentDetailsPlaceholderNode: NavigationDetailsPlaceholderNode?
    
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

        self.resizeHandle = ASDisplayNode()
        self.resizeHandle.backgroundColor = .clear
        self.resizeHandle.isUserInteractionEnabled = true
        
        super.init()
        
        self.addSubnode(self.masterContainer)
        self.addSubnode(self.detailContainer)
        self.addSubnode(self.separator)
        self.addSubnode(self.resizeHandle)
    }

    override func didLoad() {
        super.didLoad()

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handleResizePan(_:)))
        self.resizeHandle.view.addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleResizeTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.resizeHandle.view.addGestureRecognizer(tapGesture)
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
        let masterWidth = self.masterWidth(for: layout)
        let detailWidth = layout.size.width - masterWidth
        let scrollToTopHeight = max(layout.statusBarHeight ?? layout.safeInsets.top, 1.0)
        
        return (
            master: CGRect(origin: CGPoint(), size: CGSize(width: masterWidth, height: scrollToTopHeight)),
            detail: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: scrollToTopHeight))
        )
    }

    private func masterWidth(for layout: ContainerViewLayout) -> CGFloat {
        if case .tablet = layout.deviceMetrics.type, layout.size.width <= Metrics.avatarRailMaximumContainerWidth, !self.forceRegularMasterWidth {
            return Metrics.compactMasterWidth
        }
        return min(max(Metrics.regularMasterMinWidth, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
    }

    @objc private func handleResizeTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.setForceRegularMasterWidth(!self.forceRegularMasterWidth)
        }
    }

    @objc private func handleResizePan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended || recognizer.state == .cancelled else {
            return
        }
        let translation = recognizer.translation(in: self.view)
        if translation.x > 24.0 {
            self.setForceRegularMasterWidth(true)
        } else if translation.x < -24.0 {
            self.setForceRegularMasterWidth(false)
        }
    }

    private func setForceRegularMasterWidth(_ value: Bool) {
        if self.forceRegularMasterWidth == value {
            return
        }
        self.forceRegularMasterWidth = value
        UserDefaults.standard.set(value, forKey: "NavigationSplitContainer.forceRegularMasterWidth")

        if let layout = self.currentLayout {
            self.update(
                layout: layout,
                masterControllers: self.masterControllers,
                detailControllers: self.detailControllers,
                detailsPlaceholderNode: self.currentDetailsPlaceholderNode,
                transition: .animated(duration: 0.28, curve: .easeInOut)
            )
        }
    }

    func update(layout: ContainerViewLayout, masterControllers: [ViewController], detailControllers: [ViewController], detailsPlaceholderNode: NavigationDetailsPlaceholderNode?, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        self.currentDetailsPlaceholderNode = detailsPlaceholderNode

        let masterWidth = self.masterWidth(for: layout)
        let detailWidth = layout.size.width - masterWidth
        
        transition.updateFrame(node: self.masterContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: masterWidth, height: layout.size.height)))
        transition.updateFrame(node: self.detailContainer, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: layout.size.height)))
        transition.updateFrame(node: self.separator, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: UIScreenPixel, height: layout.size.height)))
        transition.updateFrame(node: self.resizeHandle, frame: CGRect(origin: CGPoint(x: masterWidth - 12.0, y: 0.0), size: CGSize(width: 24.0, height: layout.size.height)))
        
        if let detailsPlaceholderNode {
            let needsTiling = layout.size.width > layout.size.height
            detailsPlaceholderNode.updateLayout(size: CGSize(width: detailWidth, height: layout.size.height), needsTiling: needsTiling, transition: transition)
            transition.updateFrame(node: detailsPlaceholderNode, frame: CGRect(origin: CGPoint(x: masterWidth, y: 0.0), size: CGSize(width: detailWidth, height: layout.size.height)))
        }
        
        self.masterContainer.update(layout: ContainerViewLayout(size: CGSize(width: masterWidth, height: layout.size.height), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: layout.safeInsets, additionalInsets: UIEdgeInsets(), statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), canBeClosed: false, controllers: masterControllers, transition: transition)
        self.detailContainer.update(layout: ContainerViewLayout(size: CGSize(width: detailWidth, height: layout.size.height), metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), canBeClosed: true, controllers: detailControllers, transition: transition)
        
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
