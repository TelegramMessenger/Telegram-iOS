import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos

final class WallpaperListPreviewController: ViewController {
    private var controllerNode: WallpaperListPreviewControllerNode {
        return self.displayNode as! WallpaperListPreviewControllerNode
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    private let source: WallpaperListSource
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var wallpaper: WallpaperEntry?
    private var wallpaperDisposable: Disposable?
    
    private var didPlayPresentationAnimation = false
    
    var apply: ((WallpaperEntry, WallpaperPresentationOptions, CGRect?) -> Void)?
    
    init(context: AccountContext, source: WallpaperListSource) {
        self.context = context
        self.source = source
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
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
        
        self.title = self.presentationData.strings.WallpaperPreview_Title
        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: self.presentationData.theme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.sharePressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.wallpaperDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.title = self.presentationData.strings.WallpaperPreview_Title
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
        self.displayNode = WallpaperListPreviewControllerNode(context: self.context, presentationData: self.presentationData, source: self.source, dismiss: { [weak self] in
            self?.dismiss()
        }, apply: { [weak self] wallpaper, mode, cropRect in
            guard let strongSelf = self else {
                return
            }
            
            switch wallpaper {
                case let .wallpaper(wallpaper):
                    let completion: () -> Void = {
                        let _ = (updatePresentationThemeSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager, { current in
                            return PresentationThemeSettings(chatWallpaper: wallpaper, chatWallpaperOptions: mode, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                        })
                            |> deliverOnMainQueue).start(completed: {
                                self?.dismiss()
                            })
                        
                        if case .wallpaper = strongSelf.source {
                            let _ = saveWallpaper(account: strongSelf.context.account, wallpaper: wallpaper).start()
                        }
                        let _ = installWallpaper(account: strongSelf.context.account, wallpaper: wallpaper).start()
                    }
                    
                    if mode.contains(.blur) {
                        var resource: MediaResource?
                        switch wallpaper {
                            case let .file(file):
                                resource = file.file.resource
                            case let .image(representations):
                                if let largestSize = largestImageRepresentation(representations) {
                                    resource = largestSize.resource
                                }
                            default:
                                break
                        }
                        
                        if let resource = resource {
                            let _ = strongSelf.context.account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start(completed: {
                                completion()
                            })
                        }
                    } else {
                        completion()
                    }
                default:
                    break
            }
            
            strongSelf.apply?(wallpaper, mode, cropRect)
        })
        self._ready.set(self.controllerNode.ready.get())
        self.displayNodeDidLoad()
        
        self.wallpaperDisposable = (self.controllerNode.currentWallpaper
        |> deliverOnMainQueue).start(next: { [weak self] entry in
            guard let strongSelf = self else {
                return
            }
            var barButtonItem: UIBarButtonItem?
            if case let .wallpaper(wallpaper) = entry {
                switch wallpaper {
                    case .file, .color:
                        strongSelf.wallpaper = entry
                        barButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: strongSelf.presentationData.theme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(strongSelf.sharePressed))
                    default:
                        strongSelf.wallpaper = nil
                }
            } else {
                strongSelf.wallpaper = nil
            }
            //strongSelf.navigationItem.rightBarButtonItem = barButtonItem
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func sharePressed() {
        if let entry = self.wallpaper, case let .wallpaper(wallpaper) = entry {
            var controller: ShareController?
            switch wallpaper {
                case let .file(_, _, _, _, slug, _):
                    controller = ShareController(context: context, subject: .url("https://t.me/bg/\(slug)"))
                case let .color(color):
                    controller = ShareController(context: context, subject: .url("https://t.me/bg/\(String(UInt32(bitPattern: color), radix: 16, uppercase: false).rightJustified(width: 6, pad: "0"))"))
                default:
                    break
            }
            if let controller = controller {
                self.present(controller, in: .window(.root), blockInteraction: true)
            }
        }
    }
}
