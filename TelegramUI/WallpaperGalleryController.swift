import Foundation
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import Photos

enum WallpaperListType {
    case wallpapers(WallpaperPresentationOptions?)
    case colors
}

enum WallpaperListSource {
    case list(wallpapers: [TelegramWallpaper], central: TelegramWallpaper, type: WallpaperListType)
    case wallpaper(TelegramWallpaper)
    case slug(String, TelegramMediaFile?)
    case asset(PHAsset, UIImage?)
    case contextResult(ChatContextResult)
    case customColor(Int32?)
}

enum WallpaperGalleryEntry: Equatable {
    case wallpaper(TelegramWallpaper)
    case asset(PHAsset, UIImage?)
    case contextResult(ChatContextResult)
    
    public static func ==(lhs: WallpaperGalleryEntry, rhs: WallpaperGalleryEntry) -> Bool {
        switch lhs {
            case let .wallpaper(wallpaper):
                if case .wallpaper(wallpaper) = rhs {
                    return true
                } else {
                    return false
                }
            case let .asset(lhsAsset, _):
                if case let .asset(rhsAsset, _) = rhs, lhsAsset.localIdentifier == rhsAsset.localIdentifier {
                    return true
                } else {
                    return false
                }
            case let .contextResult(lhsResult):
                if case let .contextResult(rhsResult) = rhs, lhsResult.id == rhsResult.id {
                    return true
                } else {
                    return false
                }
        }
    }
}

class WallpaperGalleryController: ViewController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let account: Account
    private let source: WallpaperListSource
    var apply: ((WallpaperEntry, WallpaperPresentationOptions, CGRect?) -> Void)?
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var entries: [WallpaperGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemControlsColor = Promise<UIColor>()
    private let centralItemStatus = Promise<MediaResourceStatus>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var toolbarNode: ThemeGalleryToolbarNode?
    
    init(account: Account, source: WallpaperListSource) {
        self.account = account
        self.source = source
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.title = self.presentationData.strings.Wallpaper_Title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        switch source {
            case let .list(wallpapers, central, type):
                self.entries = wallpapers.map { .wallpaper($0) }
                self.centralEntryIndex = wallpapers.index(of: central)!
                
                //if case let .wallpapers(wallpaperMode) = type, let mode = wallpaperMode {
                //   self.segmentedControl.selectedSegmentIndex = Int(clamping: mode.rawValue)
                //}
            case let .slug(slug, file):
                if let file = file {
                    self.entries = [.wallpaper(.file(id: 0, accessHash: 0, isCreator: false, isDefault: false, slug: slug, file: file))]
                    self.centralEntryIndex = 0
                }
            case let .wallpaper(wallpaper):
                self.entries = [.wallpaper(wallpaper)]
                self.centralEntryIndex = 0
            case let .asset(asset, thumbnailImage):
                self.entries = [.asset(asset, thumbnailImage)]
                self.centralEntryIndex = 0
            case let .contextResult(result):
                self.entries = [.contextResult(result)]
                self.centralEntryIndex = 0
            case let .customColor(color):
                let initialColor = color ?? 0x000000
                self.entries = [.wallpaper(.color(initialColor))]
                self.centralEntryIndex = 0
        }
        
//        let initialEntries: [ThemeGalleryEntry] = wallpapers.map { ThemeGalleryEntry.wallpaper($0) }
//        let entriesSignal: Signal<[ThemeGalleryEntry], NoError> = .single(initialEntries)
//
//        self.disposable.set((entriesSignal |> deliverOnMainQueue).start(next: { [weak self] entries in
//            if let strongSelf = self {
//                strongSelf.entries = entries
//                strongSelf.centralEntryIndex = wallpapers.index(of: centralWallpaper)!
//                if strongSelf.isViewLoaded {
//                    strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ ThemeGalleryItem(account: account, entry: $0) }), centralItemIndex: strongSelf.centralEntryIndex, keepFirst: true)
//
//                    let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
//                        strongSelf?.didSetReady = true
//                    }
//                    strongSelf._ready.set(ready |> map { true })
//                }
//            }
//        }))
        
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
        
        //self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
        //    self?.navigationItem.titleView = titleView
        //}))
        
//        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode in
//            self?.galleryNode.updatePresentationState({
//                $0.withUpdatedFooterContentNode(footerContentNode)
//            }, transition: .immediate)
//        }))
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
        self.title = self.presentationData.strings.Wallpaper_Title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.toolbarNode?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismiss(forceAway: Bool) {
        let completion = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        //self.galleryNode.modalAnimateOut(completion: completion)
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
//            if let strongSelf = self {
//                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? ThemePreviewControllerPresentationArguments {
//                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
//                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
//                    }
//                }
//            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                if let index = index {
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        //strongSelf.centralItemTitle.set(node.title())
                    }
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
            //self?.dismiss(forceAway: true)
        }
        toolbarNode.done = { [weak self] in
//            if let strongSelf = self {
//                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode() {
//                    if !strongSelf.entries.isEmpty {
//                        let wallpaper: TelegramWallpaper
//                        switch strongSelf.entries[centralItemNode.index] {
//                        case let .wallpaper(value):
//                            wallpaper = value
//                        }
//                        let _ = (updatePresentationThemeSettingsInteractively(postbox: strongSelf.account.postbox, { current in
//                            return PresentationThemeSettings(chatWallpaper: wallpaper, chatWallpaperOptions: [], theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
//                        }) |> deliverOnMainQueue).start(completed: {
//                            self?.dismiss(forceAway: true)
//                        })
//                    }
//                }
//            }
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
            self.galleryNode.pager.replaceItems(self.entries.map({ WallpaperGalleryItem(account: self.account, entry: $0) }), centralItemIndex: self.centralEntryIndex)
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
