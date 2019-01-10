import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos

enum WallpaperListPreviewSource {
    case list(wallpapers: [TelegramWallpaper], central: TelegramWallpaper, mode: PresentationWallpaperMode?)
    case wallpaper(TelegramWallpaper)
    case asset(PHAsset, UIImage?)
}

final class WallpaperListPreviewController: ViewController {
    private var controllerNode: WallpaperListPreviewControllerNode {
        return self.displayNode as! WallpaperListPreviewControllerNode
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let account: Account
    private let source: WallpaperListPreviewSource
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var wallpaper: WallpaperEntry?
    private var wallpaperDisposable: Disposable?
    
    private var didPlayPresentationAnimation = false
    
    var apply: ((WallpaperEntry, PresentationWallpaperMode) -> Void)?
    
    init(account: Account, source: WallpaperListPreviewSource) {
        self.account = account
        self.source = source
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
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
        
        self.title = self.presentationData.strings.BackgroundPreview_Title
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: self.presentationData.theme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.sharePressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.wallpaperDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.title = self.presentationData.strings.BackgroundPreview_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(self.presentationData)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.controllerNode.animateIn()
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WallpaperListPreviewControllerNode(account: self.account, presentationData: self.presentationData, source: self.source, dismiss: { [weak self] in
            self?.dismiss()
        }, apply: { [weak self] wallpaper, mode in
            guard let strongSelf = self else {
                return
            }
            
            switch wallpaper {
                case let .wallpaper(wallpaper):
                    let _ = (updatePresentationThemeSettingsInteractively(postbox: strongSelf.account.postbox, { current in
                        return PresentationThemeSettings(chatWallpaper: wallpaper, chatWallpaperMode: mode, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                    })
                    |> deliverOnMainQueue).start(completed: {
                        self?.dismiss()
                    })
                    
                    if case .wallpaper = strongSelf.source, case .file(_, _, _, _, _, _, _) = wallpaper {
                        let _ = saveWallpaper(account: strongSelf.account, wallpaper: wallpaper).start()
                    }
                case let .asset(asset):
                    break
            }
            
            strongSelf.apply?(wallpaper, mode)
        })
        self._ready.set(self.controllerNode.ready.get())
        self.displayNodeDidLoad()
        
        self.wallpaperDisposable = (self.controllerNode.currentWallpaper
        |> deliverOnMainQueue).start(next: { [weak self] entry in
            guard let strongSelf = self else {
                return
            }
            
            if case let .wallpaper(wallpaper) = entry, case let .file(_, _, _, _, slug, _, _) = wallpaper, let wallpaperSlug = slug, !wallpaperSlug.isEmpty {
                strongSelf.wallpaper = entry
                strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: strongSelf.presentationData.theme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(strongSelf.sharePressed))
            } else {
                strongSelf.navigationItem.rightBarButtonItem = nil
            }
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func sharePressed() {
        if let entry = self.wallpaper, case let .wallpaper(wallpaper) = entry, case let .file(_, _, _, _, wallpaperSlug, _, _) = wallpaper, let slug = wallpaperSlug, !slug.isEmpty {
            let shareController = ShareController(account: account, subject: .url("https://t.me/bg/\(slug)"))
            self.present(shareController, in: .window(.root), blockInteraction: true)
        }
    }
}
