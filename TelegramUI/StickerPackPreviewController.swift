import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class StickerPackPreviewController: ViewController {
    private var controllerNode: StickerPackPreviewControllerNode {
        return self.displayNode as! StickerPackPreviewControllerNode
    }
    
    private var animatedIn = false
    private var dismissed = false
    
    private let account: Account
    private weak var parentNavigationController: NavigationController?
    
    private let stickerPack: StickerPackReference
    
    private var stickerPackContentsValue: LoadedStickerPack?
    
    private let stickerPackDisposable = MetaDisposable()
    private let stickerPackContents = Promise<LoadedStickerPack>()
    
    private let stickerPackInstalledDisposable = MetaDisposable()
    private let stickerPackInstalled = Promise<Bool>()
    
    private let openMentionDisposable = MetaDisposable()
    
    private var presentationDataDisposable: Disposable?
    
    var sendSticker: ((FileMediaReference) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                if let sendSticker = self.sendSticker {
                    self.controllerNode.sendSticker = { [weak self] file in
                        sendSticker(file)
                        self?.dismiss()
                    }
                } else {
                    self.controllerNode.sendSticker = nil
                }
            }
        }
    }
    
    init(account: Account, stickerPack: StickerPackReference, parentNavigationController: NavigationController?) {
        self.account = account
        self.parentNavigationController = parentNavigationController
        
        self.stickerPack = stickerPack
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.stickerPackContents.set(loadedStickerPack(postbox: account.postbox, network: account.network, reference: stickerPack, forceActualized: true))
        
        self.presentationDataDisposable = (self.account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stickerPackDisposable.dispose()
        self.stickerPackInstalledDisposable.dispose()
        self.openMentionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = StickerPackPreviewControllerNode(account: self.account, openShare: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let stickerPackContentsValue = strongSelf.stickerPackContentsValue, case let .result(info, _, _) = stickerPackContentsValue, !info.shortName.isEmpty {
                strongSelf.present(ShareController(account: strongSelf.account, subject: .url("https://t.me/addstickers/\(info.shortName)"), externalShare: true), in: .window(.root))
                strongSelf.dismiss()
            }
        }, openMention: { [weak self] mention in
            guard let strongSelf = self else {
                return
            }
            
            let account = strongSelf.account
            strongSelf.openMentionDisposable.set((resolvePeerByName(account: strongSelf.account, name: mention)
            |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                if let peerId = peerId {
                    return account.postbox.loadedPeerWithId(peerId)
                    |> map(Optional.init)
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue).start(next: { peer in
                guard let strongSelf = self else {
                    return
                }
                if let peer = peer {
                    strongSelf.dismiss()
                    strongSelf.parentNavigationController?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(peer.id), messageId: nil))
                }
            }))
        })
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.presentInGlobalOverlay = { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }
        if let sendSticker = self.sendSticker {
            self.controllerNode.sendSticker = { [weak self] file in
                sendSticker(file)
                self?.dismiss()
            }
        }
        self.displayNodeDidLoad()
        self.stickerPackDisposable.set((self.stickerPackContents.get() |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                if case .none = next {
                    let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.StickerPack_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    strongSelf.dismiss()
                } else {
                    strongSelf.controllerNode.updateStickerPack(next)
                    strongSelf.stickerPackContentsValue = next
                }
            }
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        if !self.dismissed {
            self.dismissed = true
        } else {
            return
        }
        self.controllerNode.animateOut(completion: completion)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
