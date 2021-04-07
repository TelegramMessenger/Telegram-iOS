import Foundation
import UIKit
import Display
import AppBundle
import OverlayStatusControllerImpl

public enum OverlayStatusControllerType {
    case loading(cancelled: (() -> Void)?)
    case success
    case shieldSuccess(String, Bool)
    case genericSuccess(String, Bool)
    case starSuccess(String)
}

private enum OverlayStatusContentController {
    case loading(ProgressWindowController)
    case progress(ProgressWindowController)
    case shieldSuccess(ProxyWindowController, Bool)
    case genericSuccess(ProxyWindowController, Bool)
    case starSuccess(ProxyWindowController)
    
    var view: UIView {
        switch self {
            case let .loading(controller):
                return controller.view
            case let .progress(controller):
                return controller.view
            case let .shieldSuccess(controller, _):
                return controller.view
            case let .genericSuccess(controller, _):
                return controller.view
            case let .starSuccess(controller):
                return controller.view
        }
    }
    
    func updateLayout() {
        switch self {
            case let .loading(controller):
                controller.updateLayout()
            case let .progress(controller):
                controller.updateLayout()
            case let .shieldSuccess(controller, _):
                controller.updateLayout()
            case let .genericSuccess(controller, _):
                controller.updateLayout()
            case let .starSuccess(controller):
                controller.updateLayout()
        }
    }
    
    func show(success: @escaping () -> Void) {
        switch self {
            case let .loading(controller):
                controller.show(true)
            case let .progress(controller):
                controller.dismiss(success: success)
            case let .shieldSuccess(controller, increasedDelay):
                controller.dismiss(success: success, increasedDelay: increasedDelay)
            case let .genericSuccess(controller, increasedDelay):
                controller.dismiss(success: success, increasedDelay: increasedDelay)
            case let .starSuccess(controller):
                controller.dismiss(success: success, increasedDelay: false)
        }
    }
    
    func dismiss(completion: @escaping () -> Void) {
        switch self {
            case let .loading(controller):
                controller.dismiss(true, completion: {
                    completion()
                })
            default:
                completion()
        }
    }
}

private final class OverlayStatusControllerNode: ViewControllerTracingNode {
    private let dismissed: () -> Void
    private let contentController: OverlayStatusContentController
    
    init(style: OverlayStatusControllerStyle, type: OverlayStatusControllerType, dismissed: @escaping () -> Void) {
        self.dismissed = dismissed
        var isUserInteractionEnabled = true
        switch type {
            case let .loading(cancelled):
                let controller = ProgressWindowController(light: style == .light)!
                controller.cancelled = {
                    cancelled?()
                }
                self.contentController = .loading(controller)
            case .success:
                self.contentController = .progress(ProgressWindowController(light: style == .light))
            case let .shieldSuccess(text, increasedDelay):
                self.contentController = .shieldSuccess(ProxyWindowController(light: style == .light, text: text, icon: ProxyWindowController.generateShieldImage(style == .light), isShield: true, showCheck: true), increasedDelay)
            case let .genericSuccess(text, increasedDelay):
                let controller = ProxyWindowController(light: style == .light, text: text, icon: nil, isShield: false, showCheck: true)!
                self.contentController = .genericSuccess(controller, increasedDelay)
                isUserInteractionEnabled = false
            case let .starSuccess(text):
                self.contentController = .genericSuccess(ProxyWindowController(light: style == .light, text: text, icon: UIImage(bundleImageName: "Star"), isShield: false, showCheck: false), false)
        }
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        self.isUserInteractionEnabled = isUserInteractionEnabled
        
        self.view.addSubview(self.contentController.view)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.contentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.contentController.updateLayout()
    }
    
    func begin() {
        self.contentController.show(success: { [weak self] in
            self?.dismissed()
        })
    }
    
    func dismiss(increasedDelay: Bool = false) {
        self.contentController.dismiss(completion: { [weak self] in
            self?.dismissed()
        })
    }
}

public enum OverlayStatusControllerStyle {
    case light
    case dark
}

private final class OverlayStatusControllerImpl: ViewController, StandalonePresentableController {
    private let style: OverlayStatusControllerStyle
    private let type: OverlayStatusControllerType
    
    private var animatedDidAppear = false
    private var isDismissed = false
    
    private var controllerNode: OverlayStatusControllerNode {
        return self.displayNode as! OverlayStatusControllerNode
    }
    
    public init(style: OverlayStatusControllerStyle, type: OverlayStatusControllerType) {
        self.style = style
        self.type = type
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = OverlayStatusControllerNode(style: self.style, type: self.type, dismissed: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedDidAppear {
            self.animatedDidAppear = true
            self.controllerNode.begin()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if self.isDismissed {
            completion?()
            return
        }
        self.isDismissed = true
        self.controllerNode.dismiss()
    }
}

public func OverlayStatusController(style: OverlayStatusControllerStyle, type: OverlayStatusControllerType) -> ViewController {
    return OverlayStatusControllerImpl(style: style, type: type)
}
