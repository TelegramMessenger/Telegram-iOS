import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences
import AccountContext
import ShareController
import StickerResources
import AlertUI
import PresentationDataUtils
import UndoUI
import TelegramPresentationData

public enum StickerPackPreviewControllerMode {
    case `default`
    case settings
}

public final class StickerPackPreviewController: ViewController, StandalonePresentableController {
    private var controllerNode: StickerPackPreviewControllerNode {
        return self.displayNode as! StickerPackPreviewControllerNode
    }
    
    private var animatedIn = false
    private var isDismissed = false
        
    public var dismissed: (() -> Void)?
    
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
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
        
    public var sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)? {
        didSet {
            if self.isNodeLoaded {
                if let sendSticker = self.sendSticker {
                    self.controllerNode.sendSticker = { [weak self] file, sourceNode, sourceRect in
                        if sendSticker(file, sourceNode, sourceRect) {
                            self?.dismiss()
                            return true
                        } else {
                            return false
                        }
                    }
                } else {
                    self.controllerNode.sendSticker = nil
                }
            }
        }
    }
    
    private let actionPerformed: ((StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction) -> Void)?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, stickerPack: StickerPackReference, mode: StickerPackPreviewControllerMode = .default, parentNavigationController: NavigationController?, actionPerformed: ((StickerPackCollectionInfo, [StickerPackItem], StickerPackScreenPerformedAction) -> Void)? = nil) {
        self.context = context
        self.mode = mode
        self.parentNavigationController = parentNavigationController
        self.actionPerformed = actionPerformed
        
        self.stickerPack = stickerPack
        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        self.statusBar.statusBarStyle = .Ignore
        
        self.stickerPackContents.set(context.engine.stickers.loadedStickerPack(reference: stickerPack, forceActualized: true))
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stickerPackDisposable.dispose()
        self.stickerPackInstalledDisposable.dispose()
        self.openMentionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        var openShareImpl: (() -> Void)?
        if self.mode == .settings {
            openShareImpl = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                if let stickerPackContentsValue = strongSelf.stickerPackContentsValue, case let .result(info, _, _) = stickerPackContentsValue, !info.shortName.isEmpty {
                    let shareController = ShareController(context: strongSelf.context, subject: .url("https://t.me/addstickers/\(info.shortName)"), externalShare: true)
                    
                    let parentNavigationController = strongSelf.parentNavigationController
                    shareController.actionCompleted = { [weak parentNavigationController] in
                        if let parentNavigationController = parentNavigationController, let controller = parentNavigationController.topViewController as? ViewController {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        }
                    }
                    strongSelf.present(shareController, in: .window(.root))
                    strongSelf.dismiss()
                }
            }
        }
        self.displayNode = StickerPackPreviewControllerNode(context: self.context, presentationData: self.presentationData, openShare: openShareImpl, openMention: { [weak self] mention in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.openMentionDisposable.set((strongSelf.context.engine.peers.resolvePeerByName(name: mention)
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                if let peer = peer {
                    return .single(peer._asPeer())
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue).start(next: { peer in
                guard let strongSelf = self else {
                    return
                }
                if let peer = peer, let parentNavigationController = strongSelf.parentNavigationController {
                    strongSelf.dismiss()
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: parentNavigationController, context: strongSelf.context, chatLocation: .peer(id: peer.id), animated: true))
                }
            }))
        }, actionPerformed: self.actionPerformed)
        self.controllerNode.dismiss = { [weak self] in
            self?.dismissed?()
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.presentInGlobalOverlay = { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }
        if let sendSticker = self.sendSticker {
            self.controllerNode.sendSticker = { [weak self] file, sourceNode, sourceRect in
                if sendSticker(file, sourceNode, sourceRect) {
                    self?.dismiss()
                    return true
                } else {
                    return false
                }
            }
        }
        let account = self.context.account
        self.displayNodeDidLoad()
        self.stickerPackDisposable.set((combineLatest(self.stickerPackContents.get(), self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]) |> take(1))
        |> mapToSignal { next, sharedData -> Signal<(LoadedStickerPack, StickerSettings), NoError> in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
                stickerSettings = value
            }
            
            switch next {
                case let .result(info, items, _):
                    var preloadSignals: [Signal<Bool, NoError>] = []
                    
                    if let thumbnail = info.thumbnail {
                        let signal = Signal<Bool, NoError> { subscriber in
                            let fetched = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource)).start()
                            let data = account.postbox.mediaBox.resourceData(thumbnail.resource, option: .incremental(waitUntilFetchStatus: false)).start(next: { data in
                                if data.complete {
                                    subscriber.putNext(true)
                                    subscriber.putCompletion()
                                } else {
                                    subscriber.putNext(false)
                                }
                            })
                            return ActionDisposable {
                                fetched.dispose()
                                data.dispose()
                            }
                        }
                        preloadSignals.append(signal)
                    }
                    
                    let topItems = items.prefix(16)
                    for item in topItems {
                        if item.file.isAnimatedSticker {
                            let signal = Signal<Bool, NoError> { subscriber in
                                let fetched = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: FileMediaReference.standalone(media: item.file).resourceReference(item.file.resource)).start()
                                let data = account.postbox.mediaBox.resourceData(item.file.resource).start()
                                let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                                let fetchedRepresentation = chatMessageAnimatedStickerDatas(postbox: account.postbox, file: item.file, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0)), fetched: true, onlyFullSize: false, synchronousLoad: false).start(next: { next in
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
                    |> mapToSignal { loaded -> Signal<(LoadedStickerPack, StickerSettings), NoError> in
                        if !loaded {
                            return .single((.fetching, stickerSettings))
                        } else {
                            return .single((next, stickerSettings))
                        }
                    }
                default:
                    return .single((next, stickerSettings))
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                if case .none = next.0 {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: presentationData.strings.StickerPack_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    strongSelf.dismiss()
                } else {
                    strongSelf.controllerNode.updateStickerPack(next.0, stickerSettings: next.1)
                    strongSelf.stickerPackContentsValue = next.0
                }
            }
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
        } else {
            return
        }
        self.acceptsFocusWhenInOverlay = false
        self.requestUpdateParameters()
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

public func preloadedStickerPackThumbnail(account: Account, info: StickerPackCollectionInfo, items: [ItemCollectionItem]) -> Signal<Bool, NoError> {
    if let thumbnail = info.thumbnail {
        let signal = Signal<Bool, NoError> { subscriber in
            let fetched = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource)).start()
            let dataDisposable: Disposable
            if info.flags.contains(.isAnimated) || info.flags.contains(.isVideo) {
                dataDisposable = chatMessageAnimationData(mediaBox: account.postbox.mediaBox, resource: thumbnail.resource, isVideo: info.flags.contains(.isVideo), width: 80, height: 80, synchronousLoad: false).start(next: { data in
                    if data.complete {
                        subscriber.putNext(true)
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(false)
                    }
                })
            } else {
                dataDisposable = account.postbox.mediaBox.resourceData(thumbnail.resource, option: .incremental(waitUntilFetchStatus: false)).start(next: { data in
                    if data.complete {
                        subscriber.putNext(true)
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(false)
                    }
                })
            }
            return ActionDisposable {
                fetched.dispose()
                dataDisposable.dispose()
            }
        }
        return signal
    }
    
    if let item = items.first as? StickerPackItem {
        if item.file.isAnimatedSticker {
            let signal = Signal<Bool, NoError> { subscriber in
                let fetched = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: FileMediaReference.standalone(media: item.file).resourceReference(item.file.resource)).start()
                let data = account.postbox.mediaBox.resourceData(item.file.resource).start()
                let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                let fetchedRepresentation = chatMessageAnimatedStickerDatas(postbox: account.postbox, file: item.file, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0)), fetched: true, onlyFullSize: false, synchronousLoad: false).start(next: { next in
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
            return signal
        } else {
            let signal = Signal<Bool, NoError> { subscriber in
                let data = account.postbox.mediaBox.resourceData(item.file.resource).start()
                let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                let fetchedRepresentation = chatMessageAnimatedStickerDatas(postbox: account.postbox, file: item.file, small: true, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0)), fetched: true, onlyFullSize: false, synchronousLoad: false).start(next: { next in
                    let hasContent = next._0 != nil || next._1 != nil
                    subscriber.putNext(hasContent)
                    if hasContent {
                        subscriber.putCompletion()
                    }
                })
                return ActionDisposable {
                    data.dispose()
                    fetchedRepresentation.dispose()
                }
            }
            return signal
        }
    }
    
    return .single(true)
}
