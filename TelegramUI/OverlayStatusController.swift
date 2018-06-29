import Foundation
import Display

import LegacyComponents

enum OverlayStatusControllerType {
    case success
}

private final class OverlayStatusControllerNode: ViewControllerTracingNode {
    private let dismissed: () -> Void
    private let progressController: TGProgressWindowController
    
    init(theme: PresentationTheme, dismissed: @escaping () -> Void) {
        self.dismissed = dismissed
        self.progressController = TGProgressWindowController(light: theme.actionSheet.backgroundType == .light)
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.view.addSubview(self.progressController.view)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.progressController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.progressController.updateLayout()
    }
    
    func begin() {
        self.progressController.dismiss(success: { [weak self] in
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
        self.displayNode = OverlayStatusControllerNode(theme: self.theme, dismissed: { [weak self] in
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
