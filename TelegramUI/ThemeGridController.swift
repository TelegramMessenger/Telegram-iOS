import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import LegacyComponents

final class ThemeGridController: ViewController {
    private var controllerNode: ThemeGridControllerNode {
        return self.displayNode as! ThemeGridControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    private let account: Account
    
    private var presentationData: PresentationData
    private let presentationDataPromise = Promise<PresentationData>()
    private var presentationDataDisposable: Disposable?
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    private var isEmpty: Bool?
    private var editingMode: Bool = false
    
    private var validLayout: ContainerViewLayout?
    
    init(account: Account) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.presentationDataPromise.set(.single(self.presentationData))
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.title = self.presentationData.strings.Wallpaper_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.controllerNode.scrollToTop()
            }
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
            self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.title = self.presentationData.strings.Wallpaper_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
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
        self.displayNode = ThemeGridControllerNode(account: self.account, presentationData: self.presentationData, presentPreviewController: { [weak self] source in
            if let strongSelf = self {
                let controller = WallpaperGalleryController(account: strongSelf.account, source: source)
                controller.apply = { [weak self, weak controller] wallpaper, mode, cropRect in
                    if let strongSelf = self {
                        strongSelf.uploadCustomWallpaper(wallpaper, mode: mode, cropRect: cropRect, completion: { [weak self, weak controller] in
                            if let strongSelf = self {
                                strongSelf.deactivateSearch(animated: false)
                                strongSelf.controllerNode.scrollToTop(animated: false)
                            }
                            if let controller = controller {
                                switch wallpaper {
                                    case .asset, .contextResult:
                                        controller.dismiss(forceAway: true)
                                    default:
                                        break
                                }
                            }
                        })
                    }
                }
                self?.present(controller, in: .window(.root), with: nil, blockInteraction: true)
            }
        }, presentGallery: { [weak self] in
            if let strongSelf = self {
                let _ = legacyWallpaperPicker(applicationContext: strongSelf.account.telegramApplicationContext, presentationData: strongSelf.presentationData).start(next: { generator in
                    if let strongSelf = self {
                        let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
                        legacyController.statusBar.statusBarStyle = strongSelf.presentationData.theme.rootController.statusBar.style.style
                        
                        let controller = generator(legacyController.context)
                        legacyController.bind(controller: controller)
                        legacyController.deferScreenEdgeGestures = [.top]
                        controller.selectionBlock = { [weak self, weak legacyController] asset, _ in
                            if let strongSelf = self, let asset = asset {
                                let controller = WallpaperGalleryController(account: strongSelf.account, source: .asset(asset.backingAsset))
                                controller.apply = { [weak self, weak legacyController, weak controller] wallpaper, mode, cropRect in
                                    if let strongSelf = self, let legacyController = legacyController, let controller = controller {
                                        strongSelf.uploadCustomWallpaper(wallpaper, mode: mode, cropRect: cropRect, completion: { [weak legacyController, weak controller] in
                                            if let legacyController = legacyController, let controller = controller {
                                                legacyController.dismiss()
                                                controller.dismiss(forceAway: true)
                                            }
                                        })
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
        }, presentColors: { [weak self] in
            if let strongSelf = self {
                let controller = ThemeColorsGridController(account: strongSelf.account)
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
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
        }, deleteWallpapers: { [weak self] wallpapers, completed in
            if let strongSelf = self {
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                var items: [ActionSheetItem] = []
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Wallpaper_DeleteConfirmation(Int32(wallpapers.count)), color: .destructive, action: { [weak self, weak actionSheet] in
   
                    actionSheet?.dismissAnimated()
                    completed()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    for wallpaper in wallpapers {
                        if wallpaper == strongSelf.presentationData.chatWallpaper {
                            let _ = (updatePresentationThemeSettingsInteractively(postbox: strongSelf.account.postbox, { current in
                                var fallbackWallpaper: TelegramWallpaper = .builtin
                                if case let .builtin(theme) = current.theme {
                                    switch theme {
                                        case .day:
                                            fallbackWallpaper = .color(0xffffff)
                                        case .nightGrayscale:
                                            fallbackWallpaper = .color(0x000000)
                                        case .nightAccent:
                                            fallbackWallpaper = .color(0x18222d)
                                        default:
                                            fallbackWallpaper = .builtin
                                    }
                                }
                                
                                var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                themeSpecificChatWallpapers[current.theme.index] = fallbackWallpaper
                                return PresentationThemeSettings(chatWallpaper: fallbackWallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, themeSpecificChatWallpapers: themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                            })).start()
                            break
                        }
                    }
                    
                    var deleteWallpapers: [Signal<Void, NoError>] = []
                    for wallpaper in wallpapers {
                        deleteWallpapers.append(deleteWallpaper(account: strongSelf.account, wallpaper: wallpaper))
                    }
                    
                    let _ = (combineLatest(deleteWallpapers)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.controllerNode.updateWallpapers()
                        }
                    })
                    
                    strongSelf.donePressed()
                }))
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(actionSheet, in: .window(.root))
            }
        }, shareWallpapers: { [weak self] wallpapers in
            if let strongSelf = self {
                strongSelf.shareWallpapers(wallpapers)
            }
        }, resetWallpapers: { [weak self] in
            if let strongSelf = self {
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                let items: [ActionSheetItem] = [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Wallpaper_ResetWallpapersConfirmation, color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        if let strongSelf = self {
                            strongSelf.scrollToTop?()
                            
                            let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, type: .loading(cancelled: nil))
                            strongSelf.present(controller, in: .window(.root))
                            
                            let _ = resetWallpapers(account: strongSelf.account).start(completed: { [weak self, weak controller] in
                                let _ = (strongSelf.account.postbox.transaction { transaction -> Void in
                                    transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.presentationThemeSettings, { entry in
                                        let current: PresentationThemeSettings
                                        if let entry = entry as? PresentationThemeSettings {
                                            current = entry
                                        } else {
                                            current = PresentationThemeSettings.defaultSettings
                                        }
                                        let wallpaper: TelegramWallpaper
                                        if case let .builtin(theme) = current.theme {
                                            switch theme {
                                                case .day:
                                                    wallpaper = .color(0xffffff)
                                                case .nightGrayscale:
                                                    wallpaper = .color(0x000000)
                                                case .nightAccent:
                                                    wallpaper = .color(0x18222d)
                                                default:
                                                    wallpaper = .builtin
                                            }
                                        } else {
                                            wallpaper = .builtin
                                        }
                                        return PresentationThemeSettings(chatWallpaper: wallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, themeSpecificChatWallpapers: [:], fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                                    })
                                }).start()
                                
                                let _ = (telegramWallpapers(postbox: strongSelf.account.postbox, network: strongSelf.account.network)
                                |> deliverOnMainQueue).start(completed: { [weak self, weak controller] in
                                    controller?.dismiss()
                                    if let strongSelf = self {
                                        strongSelf.controllerNode.updateWallpapers()
                                    }
                                })
                            })
                        }
                    })
                ]
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(actionSheet, in: .window(.root))
            }
        }, popViewController: { [weak self] in
            if let strongSelf = self {
                let _ = (strongSelf.navigationController as? NavigationController)?.popViewController(animated: true)
            }
        })
        self.controllerNode.navigationBar = self.navigationBar
        self.controllerNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        
        self.controllerNode.gridNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateGridVisibleContentOffset(offset)
            }
        }

        self.controllerNode.gridNode.scrollingCompleted = { [weak self] in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                let _ = strongSelf.controllerNode.fixNavigationSearchableGridNodeScrolling(searchNode: searchContentNode)
            }
        }
        
        self._ready.set(self.controllerNode.ready.get())
        
        self.displayNodeDidLoad()
    }
    
    private func uploadCustomWallpaper(_ wallpaper: WallpaperGalleryEntry, mode: WallpaperPresentationOptions, cropRect: CGRect?, completion: @escaping () -> Void) {
        let imageSignal: Signal<UIImage, NoError>
        switch wallpaper {
            case .wallpaper:
                imageSignal = .complete()
                completion()
            case let .asset(asset):
                imageSignal = fetchPhotoLibraryImage(localIdentifier: asset.localIdentifier, thumbnail: false)
                |> filter { value in
                    return !(value?.1 ?? true)
                }
                |> mapToSignal { result -> Signal<UIImage, NoError> in
                    if let result = result {
                        return .single(result.0)
                    } else {
                        return .complete()
                    }
                }
            case let .contextResult(result):
                var imageResource: TelegramMediaResource?
                switch result {
                    case let .externalReference(_, _, _, _, _, _, content, _, _):
                        if let content = content {
                            imageResource = content.resource
                        }
                    case let .internalReference(_, _, _, _, _, image, _, _):
                        if let image = image {
                            if let imageRepresentation = imageRepresentationLargerThan(image.representations, size: CGSize(width: 1000.0, height: 800.0)) {
                                imageResource = imageRepresentation.resource
                            }
                        }
                }
                
                if let imageResource = imageResource {
                    imageSignal = .single(self.account.postbox.mediaBox.completedResourcePath(imageResource))
                    |> mapToSignal { path -> Signal<UIImage, NoError> in
                        if let path = path, let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe]), let image = UIImage(data: data) {
                            return .single(image)
                        } else {
                            return .complete()
                        }
                    }
                } else {
                    imageSignal = .complete()
                }
        }
        
        let _ = (imageSignal
        |> map { image -> UIImage in
            var croppedImage = UIImage()
            
            let finalCropRect: CGRect
            if let cropRect = cropRect {
                finalCropRect = cropRect
            } else {
                let screenSize = TGScreenSize()
                let fittedSize = TGScaleToFit(screenSize, image.size)
                finalCropRect = CGRect(x: (image.size.width - fittedSize.width) / 2.0, y: (image.size.height - fittedSize.height) / 2.0, width: fittedSize.width, height: fittedSize.height)
            }
            croppedImage = TGPhotoEditorCrop(image, nil, .up, 0.0, finalCropRect, false, CGSize(width: 1440.0, height: 2960.0), image.size, true)
            
            let thumbnailDimensions = finalCropRect.size.fitted(CGSize(width: 320.0, height: 320.0))
            let thumbnailImage = generateScaledImage(image: croppedImage, size: thumbnailDimensions, scale: 1.0)
            
            if let data = UIImageJPEGRepresentation(croppedImage, 0.8), let thumbnailImage = thumbnailImage, let thumbnailData = UIImageJPEGRepresentation(thumbnailImage, 0.4) {
                let thumbnailResource = LocalFileMediaResource(fileId: arc4random64())
                self.account.postbox.mediaBox.storeResourceData(thumbnailResource.id, data: thumbnailData)
                
                let resource = LocalFileMediaResource(fileId: arc4random64())
                self.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                
                let account = self.account
                let updateWallpaper: (TelegramWallpaper) -> Void = { [weak self] wallpaper in
                    var resource: MediaResource?
                    if case let .image(representations, _) = wallpaper, let representation = largestImageRepresentation(representations) {
                        resource = representation.resource
                    } else if case let .file(file) = wallpaper {
                        resource = file.file.resource
                    }
                    
                    if let resource = resource {
                        let _ = account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start(completed: {})
                    }
                    
                    let _ = (updatePresentationThemeSettingsInteractively(postbox: account.postbox, { current in
                        var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                        themeSpecificChatWallpapers[current.theme.index] = wallpaper
                        return PresentationThemeSettings(chatWallpaper: wallpaper, theme: current.theme, themeAccentColor: current.themeAccentColor, themeSpecificChatWallpapers: themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                    })).start()
                    
                    if let strongSelf = self, case .file = wallpaper {
                        strongSelf.controllerNode.updateWallpapers()
                    }
                }
                
                let apply: () -> Void = {
                    let settings = WallpaperSettings(blur: mode.contains(.blur), motion: mode.contains(.motion), color: nil, intensity: nil)
                    let wallpaper: TelegramWallpaper = .image([TelegramMediaImageRepresentation(dimensions: thumbnailDimensions, resource: thumbnailResource), TelegramMediaImageRepresentation(dimensions: croppedImage.size, resource: resource)], settings)
                    updateWallpaper(wallpaper)
                    DispatchQueue.main.async {
                        completion()
                    }
                }
                
                if mode.contains(.blur) {
                    let _ = account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start(completed: {
                        apply()
                    })
                } else {
                    apply()
                }
            }
            
            return croppedImage
        }).start()
    }
    
    private func shareWallpapers(_ wallpapers: [TelegramWallpaper]) {
        var string: String = ""
        for wallpaper in wallpapers {
            var item: String?
            switch wallpaper {
                case let .file(_, _, _, _, isPattern, _, slug, _, settings):
                    var options: [String] = []
                    if isPattern {
                        if let color = settings.color {
                            options.append("bg_color=\(UIColor(rgb: UInt32(bitPattern: color)).hexString)")
                        }
                        if let intensity = settings.intensity {
                            options.append("intensity=\(intensity)")
                        }
                    }
                    
                    var optionsString = ""
                    if !options.isEmpty {
                        optionsString = "?\(options.joined(separator: "&"))"
                    }
                    item = slug + optionsString
                case let .color(color):
                    item = "\(UIColor(rgb: UInt32(bitPattern: color)).hexString)"
                default:
                    break
            }
            if let item = item {
                if !string.isEmpty {
                    string.append("\n")
                }
                string.append("https://t.me/bg/\(item)")
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
