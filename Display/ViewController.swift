import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

@objc public class ViewController: UIViewController, ContainableController {
    private var containerLayout = ContainerViewLayout()
    private let presentationContext: PresentationContext
    
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
    
    private let _ready = Promise<Bool>(true)
    public var ready: Promise<Bool> {
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
            if let displayNode = self._displayNode where self.scrollToTopView == nil {
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
    
    public init() {
        self.statusBar = StatusBar()
        self.navigationBar = NavigationBar()
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
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
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
        if statusBarHeight.isLessThanOrEqualTo(0.0) {
            navigationBarFrame.origin.y -= 20.0
            navigationBarFrame.size.height = 20.0 + 32.0
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
    
    public override func loadView() {
        self.view = self.displayNode.view
        self.displayNode.addSubnode(self.navigationBar)
        self.view.addSubview(self.statusBar.view)
        self.presentationContext.view = self.view
    }
    
    public func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()
    }
    
    public func displayNodeDidLoad() {
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
    
    override public func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        preconditionFailure("use present(_:in)")
    }
    
    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.dismiss(animated: flag, completion: completion)
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
    }
    
    public func present(_ controller: ViewController, in context: PresentationContextType, with arguments: Any? = nil) {
        controller.presentationArguments = arguments
        switch context {
            case .current:
                self.presentationContext.present(controller)
            case .window:
                (self.view.window as? Window)?.present(controller)
        }
    }
}
