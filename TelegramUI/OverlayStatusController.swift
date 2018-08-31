import Foundation
import Display

import LegacyComponents

enum OverlayStatusControllerType {
    case success
    case proxySettingSuccess
}

private enum OverlayStatusContentController {
    case progress(TGProgressWindowController)
    case proxy(TGProxyWindowController)
    
    var view: UIView {
        switch self {
            case let .progress(controller):
                return controller.view
            case let .proxy(controller):
                return controller.view
        }
    }
    
    func updateLayout() {
        switch self {
            case let .progress(controller):
                controller.updateLayout()
            case let .proxy(controller):
                controller.updateLayout()
        }
    }
    
    func dismiss(success: @escaping () -> Void) {
        switch self {
            case let .progress(controller):
                controller.dismiss(success: success)
            case let .proxy(controller):
                controller.dismiss(success: success)
        }
    }
}

private final class OverlayStatusControllerNode: ViewControllerTracingNode {
    private let dismissed: () -> Void
    private let contentController: OverlayStatusContentController
    
    init(theme: PresentationTheme, type: OverlayStatusControllerType, dismissed: @escaping () -> Void) {
        self.dismissed = dismissed
        switch type {
            case .success:
                self.contentController = .progress(TGProgressWindowController(light: theme.actionSheet.backgroundType == .light))
            case .proxySettingSuccess:
                self.contentController = .proxy(TGProxyWindowController(light: theme.actionSheet.backgroundType == .light))
        }
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.view.addSubview(self.contentController.view)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.contentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.contentController.updateLayout()
    }
    
    func begin() {
        self.contentController.dismiss(success: { [weak self] in
            self?.dismissed()
        })
    }
}

final class OverlayStatusController: ViewController {
    private let theme: PresentationTheme
    private let type: OverlayStatusControllerType
    
    private var animatedDidAppear = false
    
    private var controllerNode: OverlayStatusControllerNode {
        return self.displayNode as! OverlayStatusControllerNode
    }
    
    init(theme: PresentationTheme, type: OverlayStatusControllerType) {
        self.theme = theme
        self.type = type
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = OverlayStatusControllerNode(theme: self.theme, type: self.type, dismissed: { [weak self] in
            self?.dismiss()
        })
        
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedDidAppear {
            self.animatedDidAppear = true
            self.controllerNode.begin()
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
}
