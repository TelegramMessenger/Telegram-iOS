import Foundation
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SafariServices

struct WebSearchGalleryEntry: Equatable {
    let result: ChatContextResult
    
    static func ==(lhs: WebSearchGalleryEntry, rhs: WebSearchGalleryEntry) -> Bool {
        return lhs.result == rhs.result
    }
    
    func item(account: Account, presentationData: PresentationData) -> GalleryItem {
        switch self.result {
            case let .externalReference(queryId, id, type, _, _, url, content, thumbnail, _):
                if let content = content, type == "gif", let thumbnailResource = thumbnail?.resource, let dimensions = content.dimensions {
                    let fileReference = FileMediaReference.standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: content.resource, previewRepresentations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnailResource)], mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [])]))
                    return UniversalVideoGalleryItem(account: account, presentationData: presentationData, content: NativeVideoContent(id: .contextResult(self.result.queryId, self.result.id), fileReference: fileReference, streamVideo: false, loopVideo: true, enableSound: false, fetchAutomatically: true), originData: nil, indexData: nil, contentInfo: nil, caption: NSAttributedString(), credit: nil, performAction: { _ in }, openActionOptions: { _ in })
                }
            case let .internalReference(queryId, id, _, _, _, _, file, _):
                if let file = file {
                    return UniversalVideoGalleryItem(account: account, presentationData: presentationData, content: NativeVideoContent(id: .contextResult(self.result.queryId, self.result.id), fileReference: .standalone(media: file), streamVideo: false, loopVideo: true, enableSound: false, fetchAutomatically: true), originData: nil, indexData: nil, contentInfo: nil, caption: NSAttributedString(), credit: nil, performAction: { _ in }, openActionOptions: { _ in })
                }
        }
        preconditionFailure()
    }
}

final class WebSearchGalleryControllerPresentationArguments {
    let transitionArguments: (WebSearchGalleryEntry) -> GalleryTransitionArguments?
    
    init(transitionArguments: @escaping (WebSearchGalleryEntry) -> GalleryTransitionArguments?) {
        self.transitionArguments = transitionArguments
    }
}

class WebSearchGalleryController: ViewController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let account: Account
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [WebSearchGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<GalleryFooterContentNode?>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<WebSearchGalleryEntry?>(nil)
    var hiddenMedia: Signal<WebSearchGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, ValuePromise<Bool>?) -> Void
    private let baseNavigationController: NavigationController?
    
    init(account: Account, entries: [WebSearchGalleryEntry], centralIndex: Int, replaceRootController: @escaping (ViewController, ValuePromise<Bool>?) -> Void, baseNavigationController: NavigationController?) {
        self.account = account
        self.replaceRootController = replaceRootController
        self.baseNavigationController = baseNavigationController
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        let entriesSignal: Signal<[WebSearchGalleryEntry], NoError> = .single(entries)
        
        self.disposable.set((entriesSignal |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                strongSelf.entries = entries
                strongSelf.centralEntryIndex = centralIndex
                if strongSelf.isViewLoaded {
                    strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({
                        $0.item(account: account, presentationData: strongSelf.presentationData)
                    }), centralItemIndex: centralIndex, keepFirst: false)
                    
                    let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
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
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode in
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
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? WebSearchGalleryControllerPresentationArguments {
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
                strongSelf.present(controller, in: .window(.root), with: arguments)
            }
            }, dismissController: { [weak self] in
                self?.dismiss(forceAway: true)
            }, replaceRootController: { [weak self] controller, ready in
                if let strongSelf = self {
                    strongSelf.replaceRootController(controller, ready)
                }
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? WebSearchGalleryControllerPresentationArguments {
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
        
        self.galleryNode.pager.replaceItems(self.entries.map({
            $0.item(account: account, presentationData: self.presentationData)
        }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: WebSearchGalleryEntry?
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
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? WebSearchGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface)
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        self.galleryNode.animateIn(animateContent: !nodeAnimatesItself)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
