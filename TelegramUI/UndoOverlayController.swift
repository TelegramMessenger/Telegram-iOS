import Foundation
import Display
import TelegramCore

final class UndoOverlayController: ViewController {
    private let account: Account
    private let presentationData: PresentationData
    private let text: String
    private let action: (Bool) -> Void
    
    private var didPlayPresentationAnimation = false
    
    init(account: Account, text: String, action: @escaping (Bool) -> Void) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.text = text
        self.action = action
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = UndoOverlayControllerNode(presentationData: self.presentationData, text: self.text, action: self.action, dismiss: { [weak self] in
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            (self.displayNode as! UndoOverlayControllerNode).animateIn()
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! UndoOverlayControllerNode).containerLayoutUpdated(layout: layout, transition: transition)
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        (self.displayNode as! UndoOverlayControllerNode).animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}
