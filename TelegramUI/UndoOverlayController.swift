import Foundation
import Display
import TelegramCore

enum UndoOverlayContent {
    case removedChat(text: String)
    case archivedChat(title: String, text: String, undo: Bool)
    case hidArchive(title: String, text: String, undo: Bool)
}

final class UndoOverlayController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData
    let content: UndoOverlayContent
    private let elevatedLayout: Bool
    private var action: (Bool) -> Void
    
    private var didPlayPresentationAnimation = false
    
    init(context: AccountContext, content: UndoOverlayContent, elevatedLayout: Bool, action: @escaping (Bool) -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.content = content
        self.elevatedLayout = elevatedLayout
        self.action = action
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = UndoOverlayControllerNode(presentationData: self.presentationData, content: self.content, elevatedLayout: self.elevatedLayout, action: { [weak self] value in
            self?.action(value)
        }, dismiss: { [weak self] in
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    func dismissWithCommitAction() {
        self.action(true)
        self.dismiss()
    }
    
    func renewWithCurrentContent(action: @escaping (Bool) -> Void) {
        self.action = action
        (self.displayNode as! UndoOverlayControllerNode).renewWithCurrentContent()
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
