import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private func findCurrentResponder(_ view: UIView) -> UIResponder? {
    if view.isFirstResponder {
        return view
    } else {
        for subview in view.subviews {
            if let result = findCurrentResponder(subview) {
                return result
            }
        }
        return nil
    }
}

public enum ViewControllerPresentationAnimation {
    case none
    case modalSheet
}

open class ViewControllerPresentationArguments {
    public let presentationAnimation: ViewControllerPresentationAnimation
    
    public init(presentationAnimation: ViewControllerPresentationAnimation) {
        self.presentationAnimation = presentationAnimation
    }
}

@objc open class ViewController: UIViewController, ContainableController {
    private var containerLayout = ContainerViewLayout()
    private let presentationContext: PresentationContext
    
    public final var supportedOrientations: UIInterfaceOrientationMask = .all
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return self.supportedOrientations
    }
    
    public private(set) var presentationArguments: Any?
    
    private var _displayNode: ASDisplayNode?
    public final var displayNode: ASDisplayNode {
        get {
            if let value = self._displayNode {
                return value
            }
            else {
                self.loadDisplayNode()
                if self._displayNode == nil {
                    fatalError("displayNode should be initialized after loadDisplayNode()")
                }
                return self._displayNode!
            }
        }
        set(value) {
            self._displayNode = value
        }
    }
    
    public final var isNodeLoaded: Bool {
        return self._displayNode != nil
    }
    
    public let statusBar: StatusBar
    public let navigationBar: NavigationBar
    
    public var displayNavigationBar = true
    
    private weak var activeInputViewCandidate: UIResponder?
    private weak var activeInputView: UIResponder?
    
    open var navigationHeight: CGFloat {
        return self.navigationBar.frame.maxY
    }
    
    private let _ready = Promise<Bool>(true)
    open var ready: Promise<Bool> {
        return self._ready
    }
    
    private var scrollToTopView: ScrollToTopView?
    public var scrollToTop: (() -> Void)? {
        didSet {
            if self.isViewLoaded {
                self.updateScrollToTopView()
            }
        }
    }
    
    private func updateScrollToTopView() {
        if self.scrollToTop != nil {
            if let displayNode = self._displayNode , self.scrollToTopView == nil {
                let scrollToTopView = ScrollToTopView(frame: CGRect(x: 0.0, y: -1.0, width: displayNode.frame.size.width, height: 1.0))
                scrollToTopView.action = { [weak self] in
                    if let scrollToTop = self?.scrollToTop {
                        scrollToTop()
                    }
                }
                self.scrollToTopView = scrollToTopView
                self.view.addSubview(scrollToTopView)
            }
        } else if let scrollToTopView = self.scrollToTopView {
            scrollToTopView.removeFromSuperview()
            self.scrollToTopView = nil
        }
    }
    
    public init(navigationBar: NavigationBar = NavigationBar()) {
        self.statusBar = StatusBar()
        self.navigationBar = navigationBar
        self.presentationContext = PresentationContext()
        
        super.init(nibName: nil, bundle: nil)
        
        self.navigationBar.backPressed = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        self.navigationBar.item = self.navigationItem
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
    }
    
    open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.containerLayout = layout
        
        if !self.isViewLoaded {
            self.loadView()
        }
        self.view.frame = CGRect(origin: self.view.frame.origin, size: layout.size)
        if let _ = layout.statusBarHeight {
            self.statusBar.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: 40.0))
        }
        
        let statusBarHeight: CGFloat = layout.statusBarHeight ?? 0.0
        var navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, statusBarHeight - 20.0)), size: CGSize(width: layout.size.width, height: 64.0))
        if layout.statusBarHeight == nil {
            //navigationBarFrame.origin.y -= 20.0
            navigationBarFrame.size.height = 44.0
        }
        
        if !self.displayNavigationBar {
            navigationBarFrame.origin.y = -navigationBarFrame.size.height
        }
        
        transition.updateFrame(node: self.navigationBar, frame: navigationBarFrame)
        
        self.presentationContext.containerLayoutUpdated(layout, transition: transition)
        
        if let scrollToTopView = self.scrollToTopView {
            scrollToTopView.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: 10.0)
        }
    }
    
    open override func loadView() {
        self.view = self.displayNode.view
        self.displayNode.addSubnode(self.navigationBar)
        self.view.addSubview(self.statusBar.view)
        self.presentationContext.view = self.view
    }
    
    open func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()
    }
    
    open func displayNodeDidLoad() {
        if let layer = self.displayNode.layer as? CATracingLayer {
            layer.setTraceableInfo(CATracingLayerInfo(shouldBeAdjustedToInverseTransform: false, userData: self.displayNode.layer, tracingTag: WindowTracingTags.keyboard))
        }
        self.updateScrollToTopView()
    }
    
    public func requestLayout(transition: ContainedViewLayoutTransition) {
        if self.isViewLoaded {
            self.containerLayoutUpdated(self.containerLayout, transition: transition)
        }
    }
    
    public func setDisplayNavigationBar(_ displayNavigtionBar: Bool, transition: ContainedViewLayoutTransition = .immediate) {
        if displayNavigtionBar != self.displayNavigationBar {
            self.displayNavigationBar = displayNavigtionBar
            if let parent = self.parent as? TabBarController {
                if parent.currentController === self {
                    parent.displayNavigationBar = displayNavigationBar
                    parent.requestLayout(transition: transition)
                }
            } else {
                self.requestLayout(transition: transition)
            }
        }
    }
    
    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        super.present(viewControllerToPresent, animated: flag, completion: completion)
        return
        
        if let controller = viewControllerToPresent as? ViewController {
            self.present(controller, in: .window)
        } else {
            preconditionFailure("use present(_:in) for \(viewControllerToPresent)")
        }
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.dismiss(animated: flag, completion: completion)
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
    }
    
    public final var window: WindowHost? {
        if let window = self.view.window as? WindowHost {
            return window
        } else if let superwindow = self.view.window {
            for subview in superwindow.subviews {
                if let subview = subview as? WindowHost {
                    return subview
                }
            }
        }
        return nil
    }
    
    public func present(_ controller: ViewController, in context: PresentationContextType, with arguments: Any? = nil) {
        controller.presentationArguments = arguments
        switch context {
            case .current:
                self.presentationContext.present(controller)
            case .window:
                self.window?.present(controller)
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        self.activeInputViewCandidate = findCurrentResponder(self.view)
        
        super.viewWillDisappear(animated)
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        self.activeInputView = self.activeInputViewCandidate
        
        super.viewDidDisappear(animated)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        self.activeInputView = nil
        
        super.viewDidAppear(animated)
    }
    
    open func dismiss(completion: (() -> Void)? = nil) {
    }
}
