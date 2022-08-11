import Foundation
import UIKit
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import GalleryUI

struct SecureIdDocumentGalleryEntryLocation: Equatable {
    let position: Int32
    let totalCount: Int32
    
    static func ==(lhs: SecureIdDocumentGalleryEntryLocation, rhs: SecureIdDocumentGalleryEntryLocation) -> Bool {
        return lhs.position == rhs.position && lhs.totalCount == rhs.totalCount
    }
}

struct SecureIdDocumentGalleryEntry: Equatable {
    let index: Int32
    let resource: TelegramMediaResource
    let location: SecureIdDocumentGalleryEntryLocation
    let error: String
    
    static func ==(lhs: SecureIdDocumentGalleryEntry, rhs: SecureIdDocumentGalleryEntry) -> Bool {
        return lhs.index == rhs.index && lhs.resource.isEqual(to: rhs.resource) && lhs.location == rhs.location && lhs.error == rhs.error
    }
    
    func item(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, secureIdContext: SecureIdAccessContext, delete: @escaping (TelegramMediaResource) -> Void) -> GalleryItem {
        return SecureIdDocumentGalleryItem(context: context, theme: theme, strings: strings, secureIdContext: secureIdContext, itemId: self.index, resource: self.resource, caption: self.error, location: self.location, delete: {
            delete(self.resource)
        })
    }
}

final class SecureIdDocumentGalleryControllerPresentationArguments {
    let transitionArguments: (SecureIdDocumentGalleryEntry) -> GalleryTransitionArguments?
    
    init(transitionArguments: @escaping (SecureIdDocumentGalleryEntry) -> GalleryTransitionArguments?) {
        self.transitionArguments = transitionArguments
    }
}

class SecureIdDocumentGalleryController: ViewController, StandalonePresentableController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private let secureIdContext: SecureIdAccessContext
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [SecureIdDocumentGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<SecureIdDocumentGalleryEntry?>(nil)
    var hiddenMedia: Signal<SecureIdDocumentGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    
    var deleteResource: ((TelegramMediaResource) -> Void)?
    
    init(context: AccountContext, secureIdContext: SecureIdAccessContext, entries: [SecureIdDocumentGalleryEntry], centralIndex: Int, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void) {
        self.context = context
        self.secureIdContext = secureIdContext
        self.replaceRootController = replaceRootController
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        let entriesSignal: Signal<[SecureIdDocumentGalleryEntry], NoError> = .single(entries)
        
        self.disposable.set((entriesSignal |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                strongSelf.entries = entries
                strongSelf.centralEntryIndex = centralIndex
                if strongSelf.isViewLoaded {
                    strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({
                        $0.item(context: context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, secureIdContext: strongSelf.secureIdContext, delete: { resource in
                            self?.deleteItem(resource)
                        })
                    }), centralItemIndex: centralIndex)
                    
                    let ready = (strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void()))) |> afterNext { [weak strongSelf] _ in
                        strongSelf?.didSetReady = true
                    }
                    strongSelf._ready.set(ready |> map { true })
                }
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            self?.navigationItem.title = title
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode, _ in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
        }))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.centralItemAttributesDisposable.dispose()
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismiss(forceAway: Bool) {
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? SecureIdDocumentGalleryControllerPresentationArguments {
            if !self.entries.isEmpty {
                if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
                    animatedOutNode = false
                    centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        animatedOutNode = true
                        completion()
                    })
                }
            }
        }
        
        self.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    override func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, pushController: { _ in
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.replaceRootController(controller, ready)
            }
        }, editMedia: { _ in
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? SecureIdDocumentGalleryControllerPresentationArguments {
                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: SecureIdDocumentGalleryEntry?
                if let index = index {
                    hiddenItem = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? SecureIdDocumentGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {})
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        self.galleryNode.animateIn(animateContent: !nodeAnimatesItself, useSimpleAnimation: false)
    }
    
    private var firstLayout = true
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        if firstLayout {
            firstLayout = false
        
            self.galleryNode.pager.replaceItems(self.entries.map({
                $0.item(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, secureIdContext: self.secureIdContext, delete: { [weak self] resource in
                    self?.deleteItem(resource)
                })
            }), centralItemIndex: self.centralEntryIndex)
            
            let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
                self?.didSetReady = true
            }
            self._ready.set(ready |> map { true })
        }
    }
    
    private func deleteItem(_ resource: TelegramMediaResource) {
        self.deleteResource?(resource)
        self.dismiss(forceAway: true)
    }
}

