import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import AccountContext

public enum UndoOverlayContent {
    case removedChat(text: String)
    case archivedChat(peerId: PeerId, title: String, text: String, undo: Bool)
    case hidArchive(title: String, text: String, undo: Bool)
    case revealedArchive(title: String, text: String, undo: Bool)
    case succeed(text: String)
}

public final class UndoOverlayController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData
    public let content: UndoOverlayContent
    private let elevatedLayout: Bool
    private let animateInAsReplacement: Bool
    private var action: (Bool) -> Void
    
    private var didPlayPresentationAnimation = false
    
    public init(context: AccountContext, content: UndoOverlayContent, elevatedLayout: Bool, animateInAsReplacement: Bool = false, action: @escaping (Bool) -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.content = content
        self.elevatedLayout = elevatedLayout
        self.animateInAsReplacement = animateInAsReplacement
        self.action = action
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = UndoOverlayControllerNode(presentationData: self.presentationData, content: self.content, elevatedLayout: self.elevatedLayout, action: { [weak self] value in
            self?.action(value)
        }, dismiss: { [weak self] in
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    public func dismissWithCommitAction() {
        self.action(true)
        self.dismiss()
    }
    
    public func dismissWithCommitActionAndReplacementAnimation() {
        self.action(true)
        (self.displayNode as! UndoOverlayControllerNode).animateOutWithReplacement(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            (self.displayNode as! UndoOverlayControllerNode).animateIn(asReplacement: self.animateInAsReplacement)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! UndoOverlayControllerNode).containerLayoutUpdated(layout: layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        (self.displayNode as! UndoOverlayControllerNode).animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}
