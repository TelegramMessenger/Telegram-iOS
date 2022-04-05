import Foundation
import UIKit
import Display
import TelegramPresentationData
import TelegramCore
import AccountContext
import ComponentFlow

public enum UndoOverlayContent {
    case removedChat(text: String)
    case archivedChat(peerId: Int64, title: String, text: String, undo: Bool)
    case hidArchive(title: String, text: String, undo: Bool)
    case revealedArchive(title: String, text: String, undo: Bool)
    case succeed(text: String)
    case info(title: String?, text: String)
    case emoji(name: String, text: String)
    case swipeToReply(title: String, text: String)
    case actionSucceeded(title: String, text: String, cancel: String)
    case stickersModified(title: String, text: String, undo: Bool, info: StickerPackCollectionInfo, topItem: StickerPackItem?, context: AccountContext)
    case dice(dice: TelegramMediaDice, context: AccountContext, text: String, action: String?)
    case chatAddedToFolder(chatTitle: String, folderTitle: String)
    case chatRemovedFromFolder(chatTitle: String, folderTitle: String)
    case messagesUnpinned(title: String, text: String, undo: Bool, isHidden: Bool)
    case setProximityAlert(title: String, text: String, cancelled: Bool)
    case invitedToVoiceChat(context: AccountContext, peer: EnginePeer, text: String)
    case linkCopied(text: String)
    case banned(text: String)
    case importedMessage(text: String)
    case audioRate(slowdown: Bool, text: String)
    case forward(savedMessages: Bool, text: String)
    case autoDelete(isOn: Bool, title: String?, text: String)
    case gigagroupConversion(text: String)
    case linkRevoked(text: String)
    case voiceChatRecording(text: String)
    case voiceChatFlag(text: String)
    case voiceChatCanSpeak(text: String)
    case sticker(context: AccountContext, file: TelegramMediaFile, text: String)
    case copy(text: String)
    case mediaSaved(text: String)
    case paymentSent(currencyValue: String, itemTitle: String)
    case inviteRequestSent(title: String, text: String)
    case image(image: UIImage, text: String)
    case notificationSoundAdded(title: String, text: String, action: (() -> Void)?)
    case universal(animation: String, scale: CGFloat, colors: [String: UIColor], title: String?, text: String)
}

public enum UndoOverlayAction {
    case info
    case undo
    case commit
}

public final class UndoOverlayController: ViewController {
    private let presentationData: PresentationData
    public var content: UndoOverlayContent {
        didSet {
            (self.displayNode as! UndoOverlayControllerNode).updateContent(self.content)
        }
    }
    private let elevatedLayout: Bool
    private let animateInAsReplacement: Bool
    private var action: (UndoOverlayAction) -> Bool
    
    private var didPlayPresentationAnimation = false
    private var dismissed = false
    
    public var keepOnParentDismissal = false
    
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
