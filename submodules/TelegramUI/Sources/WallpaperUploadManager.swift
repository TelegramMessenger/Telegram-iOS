import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MediaResources
import AccountContext

private extension TelegramWallpaper {
    var mainResource: MediaResource? {
        switch self {
            case let .image(representations, _):
                return largestImageRepresentation(representations)?.resource
            case let .file(file):
                return file.file.resource
            default:
                return nil
        }
    }
}

private final class WallpaperUploadContext {
    let wallpaper: TelegramWallpaper
    private let disposable: Disposable
    
    init(wallpaper: TelegramWallpaper, disposable: Disposable) {
        self.wallpaper = wallpaper
        self.disposable = disposable
    }
    
    deinit {
        self.disposable.dispose()
    }
}

private func areMediaResourcesEqual(_ lhs: MediaResource?, _ rhs: MediaResource?) -> Bool {
    if let lhs = lhs, let rhs = rhs {
        return lhs.isEqual(to: rhs)
    } else {
        return false
    }
}

final class WallpaperUploadManagerImpl: WallpaperUploadManager {
    private let sharedContext: SharedAccountContext
    private let account: Account
    private var context: WallpaperUploadContext?
    
    private let presentationDataDisposable = MetaDisposable()
    private var currentPresentationData: PresentationData?
    
    private let statePromise = Promise<WallpaperUploadManagerStatus>(.none)
    
    init(sharedContext: SharedAccountContext, account: Account, presentationData: Signal<PresentationData, NoError>) {
        self.sharedContext = sharedContext
        self.account = account
        self.presentationDataDisposable.set(presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationDataUpdated(presentationData)
            }
        }))
    }
    
    deinit {
        self.presentationDataDisposable.dispose()
    }
    
    func stateSignal() -> Signal<WallpaperUploadManagerStatus, NoError> {
        return self.statePromise.get()
    }
    
    func presentationDataUpdated(_ presentationData: PresentationData) {
        let previousPresentationData = self.currentPresentationData
        self.currentPresentationData = presentationData
        
        let currentWallpaper = presentationData.chatWallpaper
        
        if previousPresentationData?.chatWallpaper != currentWallpaper {
            if case .image = presentationData.chatWallpaper, let currentResource = currentWallpaper.mainResource {
                if areMediaResourcesEqual(self.context?.wallpaper.mainResource, currentResource) {
                } else {
                    let disposable = MetaDisposable()
                    self.context = WallpaperUploadContext(wallpaper: currentWallpaper, disposable: disposable)
                    
                    let statePromise = Promise<WallpaperUploadManagerStatus>(.uploading(currentWallpaper, 0.0))
                    self.statePromise.set(statePromise.get())
                    
                    let sharedContext = self.sharedContext
                    let account = self.account
                    
                    let uploadSignal = uploadWallpaper(account: account, resource: currentResource, settings: currentWallpaper.settings ?? WallpaperSettings())
                    |> map { result -> UploadWallpaperStatus in
                        switch result {
                            case let .complete(wallpaper):
                                if case let .file(file) = wallpaper {
                                    sharedContext.accountManager.mediaBox.moveResourceData(from: currentResource.id, to: file.file.resource.id)
                                    account.postbox.mediaBox.moveResourceData(from: currentResource.id, to: file.file.resource.id)
                                }
                            default:
                                break
                        }
                        return result
                    }
                    
                    let autoNightModeTriggered = presentationData.autoNightModeTriggered
                    disposable.set(uploadSignal.start(next: { status in
                        if case let .complete(wallpaper) = status {
                            let updateWallpaper: (TelegramWallpaper) -> Void = { wallpaper in
                                if let resource = wallpaper.mainResource {
                                    let _ = account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start(completed: {})
                                    let _ = sharedContext.accountManager.mediaBox.cachedResourceRepresentation(resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start(completed: {})
                                }
                                
                                let _ = (updatePresentationThemeSettingsInteractively(accountManager: sharedContext.accountManager, { current in
                                    let updatedWallpaper: TelegramWallpaper
                                    if let currentSettings = currentWallpaper.settings {
                                        updatedWallpaper = wallpaper.withUpdatedSettings(currentSettings)
                                    } else {
                                        updatedWallpaper = wallpaper
                                    }
                                    let themeReference: PresentationThemeReference
                                    if autoNightModeTriggered {
                                        themeReference = current.automaticThemeSwitchSetting.theme
                                    } else {
                                        themeReference = current.theme
                                    }
                                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                    themeSpecificChatWallpapers[themeReference.index] = updatedWallpaper
                                    themeSpecificChatWallpapers[coloredThemeIndex(reference: themeReference, accentColor: current.themeSpecificAccentColors[themeReference.index])] = updatedWallpaper
                                    return PresentationThemeSettings(theme: current.theme, themePreferredBaseTheme: current.themePreferredBaseTheme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, chatBubbleSettings: current.chatBubbleSettings, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, reduceMotion: current.reduceMotion)
                                })).start()
                            }
                            
                            if case let .file(file) = wallpaper, file.settings.blur {
                                let _ = account.postbox.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start(completed: {
                                })
                                let _ = sharedContext.accountManager.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start(completed: {
                                    updateWallpaper(wallpaper)
                                })
                            } else {
                                updateWallpaper(wallpaper)
                            }
                            
                            statePromise.set(.single(.uploaded(currentWallpaper, wallpaper)))
                        } else if case let .progress(progress) = status {
                            statePromise.set(.single(.uploading(currentWallpaper, progress)))
                        }
                    }))
                }
            } else if previousPresentationData?.theme.name == presentationData.theme.name {
                self.context = nil
            }
        }
    }
}
