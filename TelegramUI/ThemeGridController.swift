import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import LegacyComponents

enum ThemeGridControllerMode {
    case wallpapers
    case solidColors
}

final class ThemeGridController: ViewController {
    private var controllerNode: ThemeGridControllerNode {
        return self.displayNode as! ThemeGridControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    private let account: Account
    private let mode: ThemeGridControllerMode
    
    private var presentationData: PresentationData
    private let presentationDataPromise = Promise<PresentationData>()
    private var presentationDataDisposable: Disposable?
    
    private let stateDisposable = MetaDisposable()
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    private var isEmpty: Bool?
    private var editingMode: Bool = false
    
    private var validLayout: ContainerViewLayout?
    
    init(account: Account, mode: ThemeGridControllerMode) {
        self.account = account
        self.mode = mode
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.presentationDataPromise.set(.single(self.presentationData))
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.title = self.presentationData.strings.Wallpaper_Title
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(presentationData))
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Wallpaper_Search, activate: { [weak self] in
            //self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.stateDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.title = self.presentationData.strings.Wallpaper_Title
        
        if let isEmpty = self.isEmpty, isEmpty {
        } else {
            if self.editingMode {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            }
        }
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Wallpaper_Search)
        
        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(self.presentationData)
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ThemeGridControllerNode(account: self.account, presentationData: self.presentationData, mode: self.mode, present: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
        }, selectCustomWallpaper: { [weak self] in
            if let strongSelf = self {
                let _ = legacyWallpaperPicker(applicationContext: strongSelf.account.telegramApplicationContext, presentationData: strongSelf.presentationData).start(next: { generator in
                    if let strongSelf = self {
                        let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
                        legacyController.statusBar.statusBarStyle = strongSelf.presentationData.theme.rootController.statusBar.style.style
                        let controller = generator(legacyController.context)
                        legacyController.bind(controller: controller)
                        legacyController.deferScreenEdgeGestures = [.top]
                        
                        controller.selectionBlock = { [weak self] asset, thumbnailImage in
                            if let strongSelf = self, let asset = asset {
                                let controller = WallpaperListPreviewController(account: strongSelf.account, source: .asset(asset.backingAsset, thumbnailImage))
                                controller.apply = { [weak self, weak legacyController, weak controller] wallpaper, mode in
                                    if let strongSelf = self, let legacyController = legacyController, let controller = controller {
                                        strongSelf.applyCustomWallpaper(wallpaper, mode: mode)
                                        
                                        legacyController.dismiss()
                                        controller.dismiss()
                                    }
                                }
                                strongSelf.present(controller, in: .window(.root), with: nil, blockInteraction: true)
                            }
                        }
                        controller.dismissalBlock = { [weak legacyController] in
                            if let legacyController = legacyController {
                                legacyController.dismiss()
                            }
                        }
                        strongSelf.present(legacyController, in: .window(.root), blockInteraction: true)
                    }
                })
            }
        }, emptyStateUpdated: { [weak self] empty in
            if let strongSelf = self {
                if empty != strongSelf.isEmpty {
                    strongSelf.isEmpty = empty
                    
                    if empty {
                        strongSelf.navigationItem.setRightBarButton(nil, animated: true)
                    } else {
                        if strongSelf.editingMode {
                            strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.donePressed))
                        } else {
                            strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Edit, style: .plain, target: strongSelf, action: #selector(strongSelf.editPressed))
                        }
                    }
                }
            }
        }, deleteWallpapers: { [weak self] wallpapers in
            if let strongSelf = self {
                for wallpaper in wallpapers {
                    let _ = deleteWallpaper(account: strongSelf.account, wallpaper: wallpaper).start()
                }
                
                let _ = telegramWallpapers(postbox: strongSelf.account.postbox, network: strongSelf.account.network).start()
                strongSelf.donePressed()
            }
        }, shareWallpapers: { [weak self] wallpapers in
            if let strongSelf = self {
                strongSelf.shareWallpapers(wallpapers)
            }
        })
        self.controllerNode.navigationBar = self.navigationBar
        self.controllerNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        
        self.stateDisposable.set(combineLatest(queue: .mainQueue(), self.presentationDataPromise.get(), self.controllerNode.state).start(next: { [weak self] presentationData, state in
            var toolbar: Toolbar?
            if state.editing {
                let leftAction = ToolbarAction(title: presentationData.strings.Common_Delete, isEnabled: !state.selectedIndices.isEmpty)
                toolbar = Toolbar(leftAction: leftAction, rightAction: nil)
            }
            self?.setToolbar(toolbar, transition: .animated(duration: 0.3, curve: .easeInOut))
        }))
        
        self._ready.set(self.controllerNode.ready.get())
//        
//        self.controllerNode.gridNode.scroll = { [weak self] offset in
//            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
//                searchContentNode.updateListVisibleContentOffset(offset)
//            }
//        }
//
//        self.controllerNode.gridNode.scrollingCompleted = { [weak self] in
//            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
//                return fixNavigationSearchableListNodeScrolling(listView, searchNode: searchContentNode)
//            } else {
//                return false
//            }
//        }
        
        self.displayNodeDidLoad()
    }
    
    private func applyCustomWallpaper(_ wallpaper: WallpaperEntry, mode: PresentationWallpaperMode) {
        guard case let .asset(asset, _) = wallpaper else {
            return
        }
        
        let _ = (fetchPhotoLibraryImage(localIdentifier: asset.localIdentifier)
        |> filter { value in
            return !(value?.1 ?? true)
        }
        |> map { result -> UIImage in
            let image = result?.0
            
            var croppedImage = UIImage()
            if let image = image {
                var screenSize = TGScreenSize()
                screenSize.width += 32.0
                let fittedSize = TGScaleToFit(screenSize, image.size)
                croppedImage = TGPhotoEditorCrop(image, nil, .up, 0.0, CGRect(x: (image.size.width - fittedSize.width) / 2.0, y: (image.size.height - fittedSize.height) / 2.0, width: fittedSize.width, height: fittedSize.height), false, CGSize(width: 2048.0, height: 2048.0), image.size, false)
                
                if let data = UIImageJPEGRepresentation(croppedImage, 0.85) {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    self.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    
                    let wallpaper: TelegramWallpaper = .image([TelegramMediaImageRepresentation(dimensions: image.size, resource: resource)])
                    let _ = (updatePresentationThemeSettingsInteractively(postbox: self.account.postbox, { current in
                        return PresentationThemeSettings(chatWallpaper: wallpaper, chatWallpaperMode: mode, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                    }) |> deliverOnMainQueue).start()
                    
                    let account = self.account
                    let _ = uploadWallpaper(account: account, resource: resource).start(next: { status in
                        if case let .complete(wallpaper) = status {
                            let _ = (updatePresentationThemeSettingsInteractively(postbox: account.postbox, { current in
                                return PresentationThemeSettings(chatWallpaper: wallpaper, chatWallpaperMode: mode, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                            })).start()
                        }
                    })
                }
            }
            
            return croppedImage
        }).start()
    }
    
    private func shareWallpapers(_ wallpapers: [TelegramWallpaper]) {
        var string: String = ""
        for wallpaper in wallpapers {
            if case let .file(_, _, _, slug, _, _) = wallpaper {
                if !string.isEmpty {
                    string.append("\n")
                }
                string.append("https://t.me/bg/\(slug)")
            }
        }
        let subject: ShareControllerSubject
        if wallpapers.count == 1 {
            subject = .url(string)
        } else {
            subject = .text(string)
        }
        let shareController = ShareController(account: account, subject: subject)
        self.present(shareController, in: .window(.root), blockInteraction: true)
        
        self.donePressed()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, transition: transition)
    }
    
    func activateSearch() {
        if self.displayNavigationBar {
            let _ = (self.controllerNode.ready.get()
            |> take(1)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let scrollToTop = strongSelf.scrollToTop {
                    scrollToTop()
                }
                if let searchContentNode = strongSelf.searchContentNode {
                    strongSelf.controllerNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
                }
                strongSelf.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
            })
        }
    }
    
    func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode, animated: animated)
            }
        }
    }
    
    @objc func editPressed() {
        self.editingMode = true
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        self.searchContentNode?.setIsEnabled(false, animated: true)
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(true)
        }
    }
    
    @objc func donePressed() {
        self.editingMode = false
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        self.searchContentNode?.setIsEnabled(true, animated: true)
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(false)
        }
    }
}
