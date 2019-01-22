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
    
    private let context: AccountContext
    
    private var presentationData: PresentationData
    private let presentationDataPromise = Promise<PresentationData>()
    private var presentationDataDisposable: Disposable?
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    private var isEmpty: Bool?
    private var editingMode: Bool = false
    
    private var validLayout: ContainerViewLayout?
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.currentPresentationData.with { $0 }
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
        
        self.presentationDataDisposable = (context.presentationData
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
        
//        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Wallpaper_Search, activate: { [weak self] in
//            self?.activateSearch()
//        })
//        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
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
//            if self.editingMode {
//                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
//            } else {
//                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
//            }
        }
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Wallpaper_Search)
        
        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(self.presentationData)
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ThemeGridControllerNode(context: self.context, presentationData: self.presentationData, presentPreviewController: { [weak self] source in
            if let strongSelf = self {
                let controller = WallpaperGalleryController(context: strongSelf.context, source: source)
                self?.present(controller, in: .window(.root), with: nil, blockInteraction: true)
//                let controller = WallpaperListPreviewController(account: strongSelf.account, source: source)
//                controller.apply = { [weak self, weak controller] wallpaper, mode, cropRect in
//                    if let strongSelf = self {
//                        strongSelf.uploadCustomWallpaper(wallpaper, mode: mode, cropRect: cropRect)
//                        if case .wallpaper = wallpaper {
//                        } else if let controller = controller {
//                            controller.dismiss()
//                        }
//                    }
//                }
//                self?.present(controller, in: .window(.root), with: nil, blockInteraction: true)
            }
        }, presentGallery: { [weak self] in
            if let strongSelf = self {
                let _ = legacyWallpaperPicker(context: strongSelf.context, presentationData: strongSelf.presentationData).start(next: { generator in
                    if let strongSelf = self {
                        let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
                        legacyController.statusBar.statusBarStyle = strongSelf.presentationData.theme.rootController.statusBar.style.style
                        
                        let controller = generator(legacyController.context)
                        legacyController.bind(controller: controller)
                        legacyController.deferScreenEdgeGestures = [.top]
                        controller.selectionBlock = { [weak self, weak legacyController] asset, thumbnailImage in
                            if let strongSelf = self, let asset = asset {
                                let controller = WallpaperListPreviewController(context: strongSelf.context, source: .asset(asset.backingAsset, thumbnailImage))
                                controller.apply = { [weak self, weak legacyController, weak controller] wallpaper, mode, cropRect in
                                    if let strongSelf = self, let legacyController = legacyController, let controller = controller {
                                        strongSelf.uploadCustomWallpaper(wallpaper, mode: mode, cropRect: cropRect, completion: { [weak legacyController, weak controller] in
                                            if let legacyController = legacyController, let controller = controller {
                                                legacyController.dismiss()
                                                controller.dismiss()
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
                let controller = ThemeColorsGridController(context: strongSelf.context)
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
            }
        }, emptyStateUpdated: { [weak self] empty in
            if let strongSelf = self {
                if empty != strongSelf.isEmpty {
                    strongSelf.isEmpty = empty
                    
                    if empty {
                        strongSelf.navigationItem.setRightBarButton(nil, animated: true)
                    } else {
//                        if strongSelf.editingMode {
//                            strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.donePressed))
//                        } else {
//                            strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Edit, style: .plain, target: strongSelf, action: #selector(strongSelf.editPressed))
//                        }
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
                        let _ = deleteWallpaper(account: strongSelf.context.account, wallpaper: wallpaper).start()
                    }
                    
                    let _ = telegramWallpapers(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network).start()
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
        }, popViewController: { [weak self] in
            if let strongSelf = self {
                let _ = (strongSelf.navigationController as? NavigationController)?.popViewController(animated: true)
            }
        })
        self.controllerNode.navigationBar = self.navigationBar
        self.controllerNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        
        self.controllerNode.gridNode.scrollingCompleted = {
            
        }
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
        
        self._ready.set(self.controllerNode.ready.get())
        
        self.displayNodeDidLoad()
    }
    
    private func uploadCustomWallpaper(_ wallpaper: WallpaperEntry, mode: WallpaperPresentationOptions, cropRect: CGRect?, completion: @escaping () -> Void) {
        let imageSignal: Signal<UIImage, NoError>
        switch wallpaper {
            case .wallpaper:
                imageSignal = .complete()
            case let .asset(asset, _):
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
                    imageSignal = .single(self.context.account.postbox.mediaBox.completedResourcePath(imageResource))
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
                finalCropRect = cropRect.insetBy(dx: -16.0, dy: 0.0)
            } else {
                var screenSize = TGScreenSize()
                screenSize.width += 32.0
                let fittedSize = TGScaleToFit(screenSize, image.size)
                finalCropRect = CGRect(x: (image.size.width - fittedSize.width) / 2.0, y: (image.size.height - fittedSize.height) / 2.0, width: fittedSize.width, height: fittedSize.height)
            }
        
            croppedImage = TGPhotoEditorCrop(image, nil, .up, 0.0, finalCropRect, false, CGSize(width: 2048.0, height: 2048.0), image.size, false)
            
            if let data = UIImageJPEGRepresentation(croppedImage, 0.85) {
                let resource = LocalFileMediaResource(fileId: arc4random64())
                self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                
                let account = self.context.account
                let updateWallpaper: (TelegramWallpaper) -> Void = { wallpaper in
                    let _ = (updatePresentationThemeSettingsInteractively(postbox: account.postbox, { current in
                        return PresentationThemeSettings(chatWallpaper: wallpaper, chatWallpaperOptions: mode, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                    })).start()
                }
                
                let apply: () -> Void = {
                    let wallpaper: TelegramWallpaper = .image([TelegramMediaImageRepresentation(dimensions: croppedImage.size, resource: resource)])
                    updateWallpaper(wallpaper)
                    DispatchQueue.main.async {
                        completion()
                    }
//                    let _ = uploadWallpaper(account: account, resource: resource).start(next: { status in
//                        if case let .complete(wallpaper) = status {
//                            if mode.contains(.blur), case let .file(_, _, _, _, _, file) = wallpaper {
//                                let _ = account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start(completed: {
//                                    updateWallpaper(wallpaper)
//                                })
//                            } else {
//                                updateWallpaper(wallpaper)
//                            }
//                        }
//                    }).start()
                }
                
                if mode.contains(.blur) {
                    let _ = self.context.account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start(completed: {
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
                case let .file(_, _, _, _, slug, _):
                    item = slug
                case let .color(color):
                    item = "\(String(UInt32(bitPattern: color), radix: 16, uppercase: false))"
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
        let shareController = ShareController(context: context, subject: subject)
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
