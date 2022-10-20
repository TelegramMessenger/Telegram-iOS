import Foundation
import UIKit
import Display
import QuickLook
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import AccountContext
import GalleryUI
import TelegramUniversalVideoContent

final class WebSearchGalleryControllerInteraction {
    let dismiss: (Bool) -> Void
    let send: (ChatContextResult) -> Void
    let selectionState: TGMediaSelectionContext?
    let editingState: TGMediaEditingContext
    
    init(dismiss: @escaping (Bool) -> Void, send: @escaping (ChatContextResult) -> Void, selectionState: TGMediaSelectionContext?, editingState: TGMediaEditingContext) {
        self.dismiss = dismiss
        self.send = send
        self.selectionState = selectionState
        self.editingState = editingState
    }
}

struct WebSearchGalleryEntry: Equatable {
    let index: Int
    let result: ChatContextResult
    
    static func ==(lhs: WebSearchGalleryEntry, rhs: WebSearchGalleryEntry) -> Bool {
        return lhs.result == rhs.result
    }
    
    func item(context: AccountContext, presentationData: PresentationData, controllerInteraction: WebSearchGalleryControllerInteraction?) -> GalleryItem {
        switch self.result {
            case let .externalReference(externalReference):
                if let content = externalReference.content, externalReference.type == "gif", let thumbnailResource = externalReference.thumbnail?.resource, let dimensions = content.dimensions {
                    let fileReference = FileMediaReference.standalone(media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: content.resource, previewRepresentations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil)], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [])]))
                    return WebSearchVideoGalleryItem(context: context, presentationData: presentationData, index: self.index, result: self.result, content: NativeVideoContent(id: .contextResult(self.result.queryId, self.result.id), fileReference: fileReference, loopVideo: true, enableSound: false, fetchAutomatically: true), controllerInteraction: controllerInteraction)
                }
            case let .internalReference(internalReference):
                if let file = internalReference.file {
                    return WebSearchVideoGalleryItem(context: context, presentationData: presentationData, index: self.index, result: self.result, content: NativeVideoContent(id: .contextResult(self.result.queryId, self.result.id), fileReference: .standalone(media: file), loopVideo: true, enableSound: false, fetchAutomatically: true), controllerInteraction: controllerInteraction)
                }
        }
        preconditionFailure()
    }
}

final class WebSearchGalleryControllerPresentationArguments {
    let animated: Bool
    let transitionArguments: (WebSearchGalleryEntry) -> GalleryTransitionArguments?
    
    init(animated: Bool = true, transitionArguments: @escaping (WebSearchGalleryEntry) -> GalleryTransitionArguments?) {
        self.animated = animated
        self.transitionArguments = transitionArguments
    }
}

class WebSearchGalleryController: ViewController {
    private static let navigationTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: UIColor(rgb: 0x525252), primaryTextColor: .white, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
    
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private var controllerInteraction: WebSearchGalleryControllerInteraction?
    
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
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();

    private let checkedDisposable = MetaDisposable()
    private var checkNode: GalleryNavigationCheckNode?
    
    private let _hiddenMedia = Promise<WebSearchGalleryEntry?>(nil)
    var hiddenMedia: Signal<WebSearchGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    private let baseNavigationController: NavigationController?
    
    init(context: AccountContext, peer: EnginePeer?, selectionState: TGMediaSelectionContext?, editingState: TGMediaEditingContext, entries: [WebSearchGalleryEntry], centralIndex: Int, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, baseNavigationController: NavigationController?, sendCurrent: @escaping (ChatContextResult) -> Void) {
        self.context = context
        self.replaceRootController = replaceRootController
        self.baseNavigationController = baseNavigationController
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: WebSearchGalleryController.navigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.controllerInteraction = WebSearchGalleryControllerInteraction(dismiss: { [weak self] animated in
            self?.dismiss(forceAway: false)
        }, send: { [weak self] current in
            sendCurrent(current)
            self?.dismiss(forceAway: true)
        }, selectionState: selectionState, editingState: editingState)
        
        if let title = peer?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) {
            let recipientNode = GalleryNavigationRecipientNode(color: .white, title: title)
            let leftItem = UIBarButtonItem(customDisplayNode: recipientNode)
            self.navigationItem.leftBarButtonItem = leftItem
        }
        
        let checkNode = GalleryNavigationCheckNode(theme: self.presentationData.theme)
        checkNode.addTarget(target: self, action: #selector(self.checkPressed))
        let rightItem = UIBarButtonItem(customDisplayNode: checkNode)
        self.navigationItem.rightBarButtonItem = rightItem
        self.checkNode = checkNode
        
        self.statusBar.statusBarStyle = .White
        
        let entriesSignal: Signal<[WebSearchGalleryEntry], NoError> = .single(entries)
        
        self.disposable.set((entriesSignal |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                strongSelf.entries = entries
                strongSelf.centralEntryIndex = centralIndex
                if strongSelf.isViewLoaded {
                    strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({
                        $0.item(context: context, presentationData: strongSelf.presentationData, controllerInteraction: strongSelf.controllerInteraction)
                    }), centralItemIndex: centralIndex)
                    
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
        self.checkedDisposable.dispose()
        self.centralItemAttributesDisposable.dispose()
    }
    
    @objc func checkPressed() {
        if let checkNode = self.checkNode, let controllerInteraction = self.controllerInteraction, let centralItemNode = self.galleryNode.pager.centralItemNode() as? WebSearchVideoGalleryItemNode, let item = centralItemNode.item {
            let legacyItem = LegacyWebSearchItem(result: item.result)
            
            controllerInteraction.selectionState?.setItem(legacyItem, selected: checkNode.isChecked)
        }
    }
    
    private func dismiss(forceAway: Bool, animated: Bool = true) {
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if animated {
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
        } else {
            animatedOutInterface = true
            completion()
        }
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
            $0.item(context: self.context, presentationData: self.presentationData, controllerInteraction: self.controllerInteraction)
        }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var item: WebSearchGalleryEntry?
                if let index = index {
                    item = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                    
                    if let checkNode = strongSelf.checkNode, let controllerInteraction = strongSelf.controllerInteraction, let selectionState = controllerInteraction.selectionState, let item = item {
                        checkNode.setIsChecked(selectionState.isIdentifierSelected(item.result.id), animated: false)
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(item))
                }
            }
        }
        
        let selectionState = self.controllerInteraction?.selectionState
        let selectionUpdated = Signal<Void, NoError> { subscriber in
            if let selectionState = selectionState {
                let disposable = selectionState.selectionChangedSignal()!.start(next: { _ in
                    subscriber.putNext(Void())
                }, error: { _ in }, completed: {})!
                return ActionDisposable {
                    disposable.dispose()
                }
            } else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
        self.checkedDisposable.set((selectionUpdated
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            if let strongSelf = self, let centralItemNode = strongSelf.galleryNode.pager.centralItemNode() {
                let item = strongSelf.entries[centralItemNode.index]
                if let checkNode = strongSelf.checkNode, let controllerInteraction = strongSelf.controllerInteraction, let selectionState = controllerInteraction.selectionState {
                    checkNode.setIsChecked(selectionState.isIdentifierSelected(item.result.id), animated: true)
                }
            }
        }))
        
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
            
            let item = self.entries[centralItemNode.index]
            if let transitionArguments = presentationArguments.transitionArguments(item) {
                nodeAnimatesItself = true
                centralItemNode.activateAsInitial()
                
                if presentationArguments.animated {
                    centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {})
                }
                
                if let checkNode = self.checkNode, let controllerInteraction = self.controllerInteraction, let selectionState = controllerInteraction.selectionState {
                    checkNode.setIsChecked(selectionState.isIdentifierSelected(item.result.id), animated: false)
                }
        
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        self.galleryNode.animateIn(animateContent: !nodeAnimatesItself, useSimpleAnimation: false)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
