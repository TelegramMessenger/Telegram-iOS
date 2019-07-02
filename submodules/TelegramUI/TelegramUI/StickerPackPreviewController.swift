import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

enum StickerPackPreviewControllerMode {
    case `default`
    case settings
}

final class StickerPackPreviewController: ViewController {
    private var controllerNode: StickerPackPreviewControllerNode {
        return self.displayNode as! StickerPackPreviewControllerNode
    }
    
    private var animatedIn = false
    private var dismissed = false
    
    private let context: AccountContext
    private let mode: StickerPackPreviewControllerMode
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
    
    init(context: AccountContext, stickerPack: StickerPackReference, mode: StickerPackPreviewControllerMode = .default, parentNavigationController: NavigationController?) {
        self.context = context
        self.mode = mode
        self.parentNavigationController = parentNavigationController
        
        self.stickerPack = stickerPack
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.stickerPackContents.set(loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: stickerPack, forceActualized: true))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
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
        var openShareImpl: (() -> Void)?
        if self.mode == .settings {
            openShareImpl = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                if let stickerPackContentsValue = strongSelf.stickerPackContentsValue, case let .result(info, _, _) = stickerPackContentsValue, !info.shortName.isEmpty {
                    strongSelf.present(ShareController(context: strongSelf.context, subject: .url("https://t.me/addstickers/\(info.shortName)"), externalShare: true), in: .window(.root))
                    strongSelf.dismiss()
                }
            }
        }
        self.displayNode = StickerPackPreviewControllerNode(context: self.context, openShare: openShareImpl, openMention: { [weak self] mention in
            guard let strongSelf = self else {
                return
            }
            
            let account = strongSelf.context.account
            strongSelf.openMentionDisposable.set((resolvePeerByName(account: strongSelf.context.account, name: mention)
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
                    strongSelf.parentNavigationController?.pushViewController(ChatController(context: strongSelf.context, chatLocation: .peer(peer.id), messageId: nil))
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
        let account = self.context.account
        self.displayNodeDidLoad()
        self.stickerPackDisposable.set((self.stickerPackContents.get()
        |> mapToSignal { next -> Signal<LoadedStickerPack, NoError> in
            switch next {
                case let .result(_, items, _):
                    var preloadSignals: [Signal<Bool, NoError>] = []
                    let topItems = items.prefix(16)
                    for item in topItems {
                        if let item = item as? StickerPackItem, item.file.isAnimatedSticker {
                            let signal = Signal<Bool, NoError> { subscriber in
                                let fetched = fetchedMediaResource(postbox: account.postbox, reference: FileMediaReference.standalone(media: item.file).resourceReference(item.file.resource)).start()
                                let data = account.postbox.mediaBox.resourceData(item.file.resource).start()
                                let fetchedRepresentation = chatMessageAnimatedStickerDatas(postbox: account.postbox, file: item.file, small: false, size: CGSize(width: 160.0, height: 160.0), fetched: true, onlyFullSize: false, synchronousLoad: false).start(next: { next in
                                    let hasContent = next._0 != nil || next._1 != nil
                                    subscriber.putNext(hasContent)
                                    if hasContent {
                                        subscriber.putCompletion()
                                    }
                                })
                                return ActionDisposable {
                                    fetched.dispose()
                                    data.dispose()
                                    fetchedRepresentation.dispose()
                                }
                            }
                            preloadSignals.append(signal)
                        }
                    }
                    return combineLatest(preloadSignals)
                    |> map { values -> Bool in
                        return !values.contains(false)
                    }
                    |> distinctUntilChanged
                    |> mapToSignal { loaded -> Signal<LoadedStickerPack, NoError> in
                        if !loaded {
                            return .single(.fetching)
                        } else {
                            return .single(next)
                        }
                    }
                default:
                    return .single(next)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                if case .none = next {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: presentationData.strings.StickerPack_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
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
