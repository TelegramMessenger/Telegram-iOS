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

public final class ImportStickerPackController: ViewController, StandalonePresentableController {
    private var controllerNode: ImportStickerPackControllerNode {
        return self.displayNode as! ImportStickerPackControllerNode
    }
    
    private var animatedIn = false
    private var isDismissed = false
        
    public var dismissed: (() -> Void)?
    
    private let context: AccountContext
    private weak var parentNavigationController: NavigationController?
    
    private let stickerPack: ImportStickerPack
    private var presentationDataDisposable: Disposable?
    private var verificationDisposable: Disposable?
    
    public init(context: AccountContext, stickerPack: ImportStickerPack, parentNavigationController: NavigationController?) {
        self.context = context
        self.parentNavigationController = parentNavigationController
        
        self.stickerPack = stickerPack
        
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        self.statusBar.statusBarStyle = .Ignore
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.verificationDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ImportStickerPackControllerNode(context: self.context)
        self.controllerNode.dismiss = { [weak self] in
            self?.dismissed?()
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.present = { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }
        self.controllerNode.presentInGlobalOverlay = { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }
        self.controllerNode.navigationController = self.parentNavigationController
        
        Queue.mainQueue().after(0.1) {
            self.controllerNode.updateStickerPack(self.stickerPack, verifiedStickers: Set(), declinedStickers: Set(), uploadedStickerResources: [:])
            
            if case .image = self.stickerPack.type {
            } else {
                let _ = (self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var signals: [Signal<(UUID, StickerVerificationStatus, MediaResource?), NoError>] = []
                    for sticker in strongSelf.stickerPack.stickers {
                        if let resource = strongSelf.controllerNode.stickerResources[sticker.uuid] {
                            signals.append(strongSelf.context.engine.stickers.uploadSticker(peer: peer, resource: resource, alt: sticker.emojis.first ?? "", dimensions: PixelDimensions(width: 512, height: 512), mimeType: sticker.mimeType)
                            |> map { result -> (UUID, StickerVerificationStatus, MediaResource?) in
                                switch result {
                                    case .progress:
                                        return (sticker.uuid, .loading, nil)
                                    case let .complete(resource, mimeType):
                                        if ["application/x-tgsticker", "video/webm"].contains(mimeType) {
                                            return (sticker.uuid, .verified, resource)
                                        } else {
                                            return (sticker.uuid, .declined, nil)
                                        }
                                }
                            }
                            |> `catch` { _ -> Signal<(UUID, StickerVerificationStatus, MediaResource?), NoError> in
                                return .single((sticker.uuid, .declined, nil))
                            })
                        }
                    }
                    strongSelf.verificationDisposable = (combineLatest(signals)
                    |> deliverOnMainQueue).start(next: { [weak self] results in
                        guard let strongSelf = self else {
                            return
                        }
                        var verifiedStickers = Set<UUID>()
                        var declinedStickers = Set<UUID>()
                        var uploadedStickerResources: [UUID: MediaResource] = [:]
                        for (uuid, result, resource) in results {
                            switch result {
                                case .verified:
                                    if let resource = resource {
                                        verifiedStickers.insert(uuid)
                                        uploadedStickerResources[uuid] = resource
                                    } else {
                                        declinedStickers.insert(uuid)
                                    }
                                case .declined:
                                    declinedStickers.insert(uuid)
                                case .loading:
                                    break
                            }
                        }
                        strongSelf.controllerNode.updateStickerPack(strongSelf.stickerPack, verifiedStickers: verifiedStickers, declinedStickers: declinedStickers, uploadedStickerResources: uploadedStickerResources)
                    })
                })
            }
        }
        
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

