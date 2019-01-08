import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

enum WallpaperListPreviewSource {
    case list(wallpapers: [TelegramWallpaper], central: TelegramWallpaper)
    case wallpaper(TelegramWallpaper)
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
    
    private var didPlayPresentationAnimation = false
    
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
    }
    
    private func updateThemeAndStrings() {
        self.title = self.presentationData.strings.BackgroundPreview_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: self.presentationData.theme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.sharePressed))
        
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
        }, apply: { [weak self] wallpaper in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (updatePresentationThemeSettingsInteractively(postbox: strongSelf.account.postbox, { current in
                return PresentationThemeSettings(chatWallpaper: wallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
            })
            |> deliverOnMainQueue).start(completed: {
                self?.dismiss()
            })
        })
        self._ready.set(self.controllerNode.ready.get())
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func sharePressed() {
        let shareController = ShareController(account: account, subject: .url("link"))
        self.present(shareController, in: .window(.root), blockInteraction: true)
    }
}
