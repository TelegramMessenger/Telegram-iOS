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
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.donePressed))
        
        self.statusBar.statusBarStyle = .Hide
        
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
        
        /*self.centralItemAttributesDisposable.add(self.centralItemNavigationStyle.get().start(next: { [weak self] style in
            if let strongSelf = self {
                switch style {
                case .dark:
                    strongSelf.statusBar.statusBarStyle = .White
                    strongSelf.navigationBar.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                    strongSelf.navigationBar.stripeColor = UIColor.clear
                    strongSelf.navigationBar.foregroundColor = UIColor.white
                    strongSelf.navigationBar.accentColor = UIColor.white
                    strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor.black
                    strongSelf.galleryNode.isBackgroundExtendedOverNavigationBar = true
                case .light:
                    strongSelf.statusBar.statusBarStyle = .Black
                    strongSelf.navigationBar.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
                    strongSelf.navigationBar.foregroundColor = UIColor.black
                    strongSelf.navigationBar.accentColor = UIColor(rgb: 0x007ee5)
                    strongSelf.navigationBar.stripeColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
                    strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor(rgb: 0xbdbdc2)
                    strongSelf.galleryNode.isBackgroundExtendedOverNavigationBar = false
                }
            }
        }))*/
        
        self.statusBar.statusBarStyle = .Hide
        /*strongSelf.navigationBar.stripeColor = UIColor.clear
        strongSelf.navigationBar.foregroundColor = UIColor.white
        strongSelf.navigationBar.accentColor = UIColor.white*/
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
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? ThemePreviewControllerPresentationArguments {
            if !self.entries.isEmpty {
                if centralItemNode.index == 0, let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
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
                //strongSelf.replaceRootController(controller, ready)
            }
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction, pageGap: 0.0)
        self.displayNodeDidLoad()
        
        //self.galleryNode.statusBar = self.statusBar
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
        let toolbarNode = ThemeGalleryToolbarNode(strings: presentationData.strings)
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
                            if case .color(0x000000) = wallpaper {
                                return PresentationThemeSettings(chatWallpaper: wallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: .regular, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                            }
                            
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
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? ThemePreviewControllerPresentationArguments {
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
        
        transition.updateFrame(node: self.toolbarNode!, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode!.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        let replace = self.validLayout == nil
        self.validLayout = (layout, 0.0)
        
        if replace {
            self.galleryNode.pager.replaceItems(self.entries.map({ ThemeGalleryItem(account: self.account, entry: $0) }), centralItemIndex: self.centralEntryIndex)
        }
    }
}
