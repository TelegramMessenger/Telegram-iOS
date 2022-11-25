import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramUIPreferences
import MediaResources
import AccountContext
import LegacyUI
import LegacyMediaPickerUI
import LocalMediaResources

func presentCustomWallpaperPicker(context: AccountContext, present: @escaping (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let _ = legacyWallpaperPicker(context: context, presentationData: presentationData).start(next: { generator in
        let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: presentationData.theme)
        legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
        
        let controller = generator(legacyController.context)
        legacyController.bind(controller: controller)
        legacyController.deferScreenEdgeGestures = [.top]
        controller.selectionBlock = { [weak legacyController] asset, _ in
            if let asset = asset {
                let controller = WallpaperGalleryController(context: context, source: .asset(asset.backingAsset))
                controller.apply = { [weak legacyController, weak controller] wallpaper, mode, cropRect in
                    if let legacyController = legacyController, let controller = controller {
                        uploadCustomWallpaper(context: context, wallpaper: wallpaper, mode: mode, cropRect: cropRect, completion: { [weak legacyController, weak controller] in
                            if let legacyController = legacyController, let controller = controller {
                                legacyController.dismiss()
                                controller.dismiss(forceAway: true)
                            }
                        })
                    }
                }
                present(controller)
            }
        }
        controller.dismissalBlock = { [weak legacyController] in
            if let legacyController = legacyController {
                legacyController.dismiss()
            }
        }
        present(legacyController)
    })
}

func uploadCustomWallpaper(context: AccountContext, wallpaper: WallpaperGalleryEntry, mode: WallpaperPresentationOptions, cropRect: CGRect?, completion: @escaping () -> Void) {
    let imageSignal: Signal<UIImage, NoError>
    switch wallpaper {
        case let .wallpaper(wallpaper, _):
            switch wallpaper {
                case let .file(file):
                    if let path = context.account.postbox.mediaBox.completedResourcePath(file.file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        context.sharedContext.accountManager.mediaBox.storeResourceData(file.file.resource.id, data: data)
                        let _ = context.sharedContext.accountManager.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start()
                        let _ = context.sharedContext.accountManager.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start()
                    }
                case let .image(representations, _):
                    for representation in representations {
                        let resource = representation.resource
                        if let path = context.account.postbox.mediaBox.completedResourcePath(resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                            context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data)
                            let _ = context.sharedContext.accountManager.mediaBox.cachedResourceRepresentation(resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start()
                        }
                    }
                default:
                    break
            }
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
                case let .externalReference(externalReference):
                    if let content = externalReference.content {
                        imageResource = content.resource
                    }
                case let .internalReference(internalReference):
                    if let image = internalReference.image {
                        if let imageRepresentation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 1000, height: 800)) {
                            imageResource = imageRepresentation.resource
                        }
                    }
            }
            
            if let imageResource = imageResource {
                imageSignal = .single(context.account.postbox.mediaBox.completedResourcePath(imageResource))
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
        
        if let data = croppedImage.jpegData(compressionQuality: 0.8), let thumbnailImage = thumbnailImage, let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.4) {
            let thumbnailResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
            context.sharedContext.accountManager.mediaBox.storeResourceData(thumbnailResource.id, data: thumbnailData)
            context.account.postbox.mediaBox.storeResourceData(thumbnailResource.id, data: thumbnailData)
            
            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
            context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data)
            context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
            
            let autoNightModeTriggered = context.sharedContext.currentPresentationData.with {$0 }.autoNightModeTriggered
            let accountManager = context.sharedContext.accountManager
            let account = context.account
            let updateWallpaper: (TelegramWallpaper) -> Void = { wallpaper in
                var resource: MediaResource?
                if case let .image(representations, _) = wallpaper, let representation = largestImageRepresentation(representations) {
                    resource = representation.resource
                } else if case let .file(file) = wallpaper {
                    resource = file.file.resource
                }
                
                if let resource = resource {
                    let _ = accountManager.mediaBox.cachedResourceRepresentation(resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start(completed: {})
                    let _ = account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start(completed: {})
                }
                
                let _ = (updatePresentationThemeSettingsInteractively(accountManager: accountManager, { current in
                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                    let themeReference: PresentationThemeReference
                    if autoNightModeTriggered {
                        themeReference = current.automaticThemeSwitchSetting.theme
                    } else {
                        themeReference = current.theme
                    }
                    let accentColor = current.themeSpecificAccentColors[themeReference.index]
                    if let accentColor = accentColor, accentColor.baseColor == .custom {
                        themeSpecificChatWallpapers[coloredThemeIndex(reference: themeReference, accentColor: accentColor)] = wallpaper
                    } else {
                        themeSpecificChatWallpapers[coloredThemeIndex(reference: themeReference, accentColor: accentColor)] = nil
                        themeSpecificChatWallpapers[themeReference.index] = wallpaper
                    }
                    return current.withUpdatedThemeSpecificChatWallpapers(themeSpecificChatWallpapers)
                })).start()
            }
            
            let apply: () -> Void = {
                let settings = WallpaperSettings(blur: mode.contains(.blur), motion: mode.contains(.motion), colors: [], intensity: nil)
                let wallpaper: TelegramWallpaper = .image([TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailDimensions), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false), TelegramMediaImageRepresentation(dimensions: PixelDimensions(croppedImage.size), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false)], settings)
                updateWallpaper(wallpaper)
                DispatchQueue.main.async {
                    completion()
                }
            }
            
            if mode.contains(.blur) {
                let representation = CachedBlurredWallpaperRepresentation()
                let _ = context.account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: true, fetch: true).start()
                let _ = context.sharedContext.accountManager.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: true, fetch: true).start(completed: {
                    apply()
                })
            } else {
                apply()
            }
        }
        return croppedImage
    }).start()
}
