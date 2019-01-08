import Foundation
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore

enum ThemeGalleryEntry: Equatable {
    case wallpaper(TelegramWallpaper)
    
    static func ==(lhs: ThemeGalleryEntry, rhs: ThemeGalleryEntry) -> Bool {
        switch lhs {
            case let .wallpaper(wallpaper):
                if case .wallpaper(wallpaper) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class ThemePreviewControllerPresentationArguments {
    let transitionArguments: (ThemeGalleryEntry) -> GalleryTransitionArguments?
    
    init(transitionArguments: @escaping (ThemeGalleryEntry) -> GalleryTransitionArguments?) {
        self.transitionArguments = transitionArguments
    }
}

class ThemeGalleryController: ViewController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let account: Account
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var entries: [ThemeGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<GalleryFooterContentNode?>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var toolbarNode: ThemeGalleryToolbarNode?
    
    private let _hiddenMedia = Promise<ThemeGalleryEntry?>(nil)
    var hiddenMedia: Signal<ThemeGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    init(account: Account, wallpapers: [TelegramWallpaper], at centralWallpaper: TelegramWallpaper) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.title = self.presentationData.strings.Wallpaper_Title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        let initialEntries: [ThemeGalleryEntry] = wallpapers.map { ThemeGalleryEntry.wallpaper($0) }
        
        let entriesSignal: Signal<[ThemeGalleryEntry], NoError> = .single(initialEntries)
        
        self.disposable.set((entriesSignal |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                strongSelf.entries = entries
                strongSelf.centralEntryIndex = wallpapers.index(of: centralWallpaper)!
                if strongSelf.isViewLoaded {
                    strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ ThemeGalleryItem(account: account, entry: $0) }), centralItemIndex: strongSelf.centralEntryIndex, keepFirst: true)
                    
                    let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                        strongSelf?.didSetReady = true
                    }
                    strongSelf._ready.set(ready |> map { true })
                }
            }
        }))
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
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
        self.presentationDataDisposable?.dispose()
        self.centralItemAttributesDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.toolbarNode?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismiss(forceAway: Bool) {
        let completion = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.modalAnimateOut(completion: completion)
    }
    
    override func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { controller, ready in
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction, pageGap: 0.0)
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? ThemePreviewControllerPresentationArguments {
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
                var hiddenItem: ThemeGalleryEntry?
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
        
        self.galleryNode.backgroundNode.backgroundColor = nil
        self.galleryNode.backgroundNode.isOpaque = false
        self.galleryNode.isBackgroundExtendedOverNavigationBar = true
        
        let presentationData = self.account.telegramApplicationContext.currentPresentationData.with { $0 }
        let toolbarNode = ThemeGalleryToolbarNode(theme: presentationData.theme, strings: presentationData.strings)
        self.toolbarNode = toolbarNode
        self.galleryNode.addSubnode(toolbarNode)
        self.galleryNode.toolbarNode = toolbarNode
        toolbarNode.cancel = { [weak self] in
            self?.dismiss(forceAway: true)
        }
        toolbarNode.done = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode() {
                    if !strongSelf.entries.isEmpty {
                        let wallpaper: TelegramWallpaper
                        switch strongSelf.entries[centralItemNode.index] {
                            case let .wallpaper(value):
                                wallpaper = value
                        }
                        let _ = (updatePresentationThemeSettingsInteractively(postbox: strongSelf.account.postbox, { current in                            
                            return PresentationThemeSettings(chatWallpaper: wallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                        }) |> deliverOnMainQueue).start(completed: {
                            self?.dismiss(forceAway: true)
                        })
                    }
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
        
        self.galleryNode.modalAnimateIn()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
        
        transition.updateFrame(node: self.toolbarNode!, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode!.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        let replace = self.validLayout == nil
        self.validLayout = (layout, 0.0)
        
        if replace {
            self.galleryNode.pager.replaceItems(self.entries.map({ ThemeGalleryItem(account: self.account, entry: $0) }), centralItemIndex: self.centralEntryIndex)
        }
    }
}

private extension GalleryControllerNode {
    func modalAnimateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func modalAnimateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
}
