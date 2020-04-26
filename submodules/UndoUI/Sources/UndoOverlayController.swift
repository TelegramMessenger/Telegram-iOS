import Foundation
import UIKit
import Display
import TelegramPresentationData
import SyncCore
import Postbox
import TelegramCore

public enum UndoOverlayContent {
    case removedChat(text: String)
    case archivedChat(peerId: Int64, title: String, text: String, undo: Bool)
    case hidArchive(title: String, text: String, undo: Bool)
    case revealedArchive(title: String, text: String, undo: Bool)
    case succeed(text: String)
    case info(text: String)
    case emoji(path: String, text: String)
    case swipeToReply(title: String, text: String)
    case actionSucceeded(title: String, text: String, cancel: String)
    case stickersModified(title: String, text: String, undo: Bool, info: StickerPackCollectionInfo, topItem: ItemCollectionItem?, account: Account)
    case dice(dice: TelegramMediaDice, account: Account, text: String, action: String?)
}

public enum UndoOverlayAction {
    case info
    case undo
    case commit
}

public final class UndoOverlayController: ViewController {
    private let presentationData: PresentationData
    public let content: UndoOverlayContent
    private let elevatedLayout: Bool
    private let animateInAsReplacement: Bool
    private var action: (UndoOverlayAction) -> Bool
    
    private var didPlayPresentationAnimation = false
    private var dismissed = false
    
    public init(presentationData: PresentationData, content: UndoOverlayContent, elevatedLayout: Bool, animateInAsReplacement: Bool = false, action: @escaping (UndoOverlayAction) -> Bool) {
        self.presentationData = presentationData
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
            return self?.action(value) ?? false
        }, dismiss: { [weak self] in
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    public func dismissWithCommitAction() {
        let _ = self.action(.commit)
        self.dismiss()
    }
    
    public func dismissWithCommitActionAndReplacementAnimation() {
        let _ = self.action(.commit)
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
        guard !self.dismissed else {
            return
        }
        self.dismissed = true
        (self.displayNode as! UndoOverlayControllerNode).animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}
