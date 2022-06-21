import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ShareController
import CounterContollerTitleView
import WallpaperResources
import OverlayStatusController
import AppBundle
import PresentationDataUtils
import UndoUI
import TelegramNotices

public enum ThemePreviewSource {
    case settings(PresentationThemeReference, TelegramWallpaper?, Bool)
    case theme(TelegramTheme)
    case slug(String, TelegramMediaFile)
    case themeSettings(String, TelegramThemeSettings)
    case media(AnyMediaReference)
}

public final class ThemePreviewController: ViewController {
    private let context: AccountContext
    private let previewTheme: PresentationTheme
    private let source: ThemePreviewSource
    private let theme = Promise<TelegramTheme?>()
    private let presentationTheme = Promise<PresentationTheme>()
    
    private var controllerNode: ThemePreviewControllerNode {
        return self.displayNode as! ThemePreviewControllerNode
    }
        
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var validLayout: ContainerViewLayout?
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var disposable: Disposable?
    private var applyDisposable = MetaDisposable()
    
    var customApply: (() -> Void)?

    public init(context: AccountContext, previewTheme: PresentationTheme, source: ThemePreviewSource) {
        self.context = context
        self.previewTheme = previewTheme
        self.source = source
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationTheme.set(.single(previewTheme))
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.previewTheme, presentationStrings: self.presentationData.strings))
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        self.navigationPresentation = .modal
        
        var hasInstallsCount = false
        let themeName: String
        switch source {
            case let .theme(theme):
                themeName = theme.title
                self.theme.set(.single(theme)
                |> then(
                    getTheme(account: context.account, slug: theme.slug)
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<TelegramTheme?, NoError> in
                        return .single(nil)
                    }
                    |> filter { $0 != nil }
                ))
                hasInstallsCount = true
            case let .slug(slug, _), let .themeSettings(slug, _):
                self.theme.set(getTheme(account: context.account, slug: slug)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<TelegramTheme?, NoError> in
                    return .single(nil)
                })
                themeName = previewTheme.name.string
                
                self.presentationTheme.set(.single(self.previewTheme)
                |> then(
                    self.theme.get()
                    |> mapToSignal { theme in
                        if let file = theme?.file {
                            return telegramThemeData(account: context.account, accountManager: context.sharedContext.accountManager, reference: .standalone(resource: file.resource))
                                |> mapToSignal { data -> Signal<PresentationTheme, NoError> in
                                    guard let data = data, let presentationTheme = makePresentationTheme(data: data) else {
                                        return .complete()
                                    }
                                    return .single(presentationTheme)
                            }
                        } else {
                            return .complete()
                        }
                    }
                ))
                hasInstallsCount = true
            case let .settings(themeReference, _, _):
                if case let .cloud(theme) = themeReference {
                    self.theme.set(getTheme(account: context.account, slug: theme.theme.slug)
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<TelegramTheme?, NoError> in
                        return .single(nil)
                    })
                    if let emoticon = theme.theme.emoticon{
                        themeName = emoticon
                    } else {
                        themeName = theme.theme.title
                        hasInstallsCount = true
                    }
                } else {
                    self.theme.set(.single(nil))
                    if [.builtin(.dayClassic), .builtin(.night)].contains(themeReference) {
                        themeName = "🏠"
                    } else {
                        themeName = previewTheme.name.string
                    }
                }
            default:
                self.theme.set(.single(nil))
                themeName = previewTheme.name.string
        }
        
        var isPreview = false
        if case .settings = source {
            isPreview = true
        }
        
        let titleView = CounterContollerTitleView(theme: self.previewTheme)
        titleView.title = CounterContollerTitle(title: themeName, counter: hasInstallsCount ? " " : "")
        self.navigationItem.titleView = titleView
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        self.statusBar.statusBarStyle = self.previewTheme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        if !isPreview {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: self.previewTheme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.actionPressed))
        }
        
        self.disposable = (combineLatest(self.theme.get(), self.presentationTheme.get())
        |> deliverOnMainQueue).start(next: { [weak self] theme, presentationTheme in
            if let strongSelf = self, let theme = theme {
                let titleView = CounterContollerTitleView(theme: strongSelf.previewTheme)
                titleView.title = CounterContollerTitle(title: themeName, counter: hasInstallsCount ? strongSelf.presentationData.strings.Theme_UsersCount(max(1, theme.installCount ?? 0)) : "")
                strongSelf.navigationItem.titleView = titleView
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationTheme: presentationTheme, presentationStrings: strongSelf.presentationData.strings))
            }
        })
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.disposable?.dispose()
        self.applyDisposable.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override public func loadDisplayNode() {
        super.loadDisplayNode()
        
        var isPreview = false
        var forceReady = false
        var initialWallpaper: TelegramWallpaper?
        if case let .settings(_, currentWallpaper, preview) = self.source {
            isPreview = preview
            forceReady = true
            if let wallpaper = currentWallpaper {
                initialWallpaper = wallpaper
            }
        }
        
        self.displayNode = ThemePreviewControllerNode(context: self.context, previewTheme: self.previewTheme, initialWallpaper: initialWallpaper, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] in
            if let strongSelf = self {
                strongSelf.apply()
            }
        }, isPreview: isPreview, forceReady: forceReady, ready: self._ready)
        self.displayNodeDidLoad()
        
        let previewTheme = self.previewTheme
        if let initialWallpaper = initialWallpaper {
            self.controllerNode.wallpaperPromise.set(.single(initialWallpaper))
        } else if case let .file(file) = previewTheme.chat.defaultWallpaper, file.id == 0 {
            self.controllerNode.wallpaperPromise.set(cachedWallpaper(account: self.context.account, slug: file.slug, settings: file.settings)
            |> mapToSignal { wallpaper in                
                return .single(wallpaper?.wallpaper ?? .color(previewTheme.chatList.backgroundColor.argb))
            })
        } else {
            self.controllerNode.wallpaperPromise.set(.single(previewTheme.chat.defaultWallpaper))
        }
    }
    
    private func apply() {
        if let customApply = self.customApply {
            customApply()
            Queue.mainQueue().after(0.2) {
                self.dismiss()
            }
            return
        }
        
        let previewTheme = self.previewTheme
        let theme: Signal<PresentationThemeReference?, NoError>
        let context = self.context
        let wallpaperPromise = self.controllerNode.wallpaperPromise
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let disposable = self.applyDisposable
        
        switch self.source {
            case let .settings(reference, _, _):
                theme = .single(reference)
            case .theme, .slug, .themeSettings:
                theme = combineLatest(self.theme.get() |> take(1), wallpaperPromise.get() |> take(1))
                |> mapToSignal { theme, wallpaper -> Signal<PresentationThemeReference?, NoError> in
                    if let theme = theme {
                        if case let .file(file) = wallpaper, file.id != 0 {
                            return .single(.cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: wallpaper, creatorAccountId: theme.isCreator ? context.account.id : nil)))
                        } else {
                            return .single(.cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: nil, creatorAccountId: theme.isCreator ? context.account.id : nil)))
                        }
                    } else {
                        return .complete()
                    }
                }
            case .media:
                if let strings = encodePresentationTheme(previewTheme), let data = strings.data(using: .utf8) {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data)
                    theme = .single(.local(PresentationLocalTheme(title: previewTheme.name.string, resource: resource, resolvedWallpaper: nil)))
                } else {
                    theme = .single(.builtin(.dayClassic))
                }
        }
        
        var resolvedWallpaper: TelegramWallpaper?
        
        let setup = theme
        |> mapToSignal { theme -> Signal<(PresentationThemeReference, Bool), NoError> in
            guard let theme = theme else {
                return .complete()
            }
            switch theme {
                case let .cloud(info):
                    resolvedWallpaper = info.resolvedWallpaper
                    return telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
                    |> take(1)
                    |> map { themes -> Bool in
                        if let _ = themes.first(where: { $0.id == info.theme.id }) {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> map { exists in
                        return (theme, exists)
                    }
                case let .local(info):
                    return wallpaperPromise.get()
                    |> take(1)
                    |> mapToSignal { currentWallpaper -> Signal<(PresentationThemeReference, Bool), NoError> in
                        if case let .file(file) = currentWallpaper, file.id != 0 {
                            resolvedWallpaper = currentWallpaper
                        }
                        
                        var wallpaperImage: UIImage?
                        if case .file = currentWallpaper {
                            wallpaperImage = chatControllerBackgroundImage(theme: previewTheme, wallpaper: currentWallpaper, mediaBox: context.sharedContext.accountManager.mediaBox, knockoutMode: false)
                        }
                        let themeThumbnail = generateImage(CGSize(width: 213, height: 320.0), contextGenerator: { size, context in
                            if let image = generateImage(CGSize(width: 194.0, height: 291.0), contextGenerator: { size, c in
                                drawThemeImage(context: c, theme: previewTheme, wallpaperImage: wallpaperImage, size: size)
                            })?.cgImage {
                                context.draw(image, in: CGRect(origin: CGPoint(), size: size))
                            }
                        }, scale: 1.0)
                        let themeThumbnailData = themeThumbnail?.jpegData(compressionQuality: 0.6)
                        
                        return telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
                        |> take(1)
                        |> mapToSignal { themes -> Signal<(PresentationThemeReference, Bool), NoError> in
                            let similarTheme = themes.first(where: { $0.isCreator && $0.title == info.title })
                            if let similarTheme = similarTheme {
                                return updateTheme(account: context.account, accountManager: context.sharedContext.accountManager, theme: similarTheme, title: nil, slug: nil, resource: info.resource, thumbnailData: themeThumbnailData, settings: nil)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<CreateThemeResult?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { result -> Signal<(PresentationThemeReference, Bool), NoError> in
                                    guard let result = result else {
                                        let updatedTheme = PresentationLocalTheme(title: info.title, resource: info.resource, resolvedWallpaper: resolvedWallpaper)
                                        return .single((.local(updatedTheme), true))
                                    }
                                    if case let .result(theme) = result, let file = theme.file {
                                        context.sharedContext.accountManager.mediaBox.moveResourceData(from: info.resource.id, to: file.resource.id)
                                        return .single((.cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: resolvedWallpaper, creatorAccountId: theme.isCreator ? context.account.id : nil)), true))
                                    } else {
                                        return .complete()
                                    }
                                }
                                
                            } else {
                                return createTheme(account: context.account, title: info.title, resource: info.resource, thumbnailData: themeThumbnailData, settings: nil)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<CreateThemeResult?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { result -> Signal<(PresentationThemeReference, Bool), NoError> in
                                    guard let result = result else {
                                        let updatedTheme = PresentationLocalTheme(title: info.title, resource: info.resource, resolvedWallpaper: resolvedWallpaper)
                                        return .single((.local(updatedTheme), true))
                                    }
                                    if case let .result(updatedTheme) = result, let file = updatedTheme.file {
                                        context.sharedContext.accountManager.mediaBox.moveResourceData(from: info.resource.id, to: file.resource.id)
                                        return .single((.cloud(PresentationCloudTheme(theme: updatedTheme, resolvedWallpaper: resolvedWallpaper, creatorAccountId: updatedTheme.isCreator ? context.account.id : nil)), true))
                                    } else {
                                        return .complete()
                                    }
                                }
                            }
                        }
                    }
                case .builtin:
                    return .single((theme, true))
            }
        }
        |> mapToSignal { updatedTheme, existing -> Signal<(PresentationThemeReference, PresentationThemeAccentColor?, Bool, PresentationThemeReference, Bool)?, NoError> in
            if case let .cloud(info) = updatedTheme {
                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: info.theme).start()
                if info.theme.emoticon == nil {
                    let _ = saveThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: info.theme).start()
                }
            }

            let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
            
            return context.sharedContext.accountManager.transaction { transaction -> (PresentationThemeReference, PresentationThemeAccentColor?, Bool, PresentationThemeReference, Bool)? in
                var previousDefaultTheme: (PresentationThemeReference, PresentationThemeAccentColor?, Bool, PresentationThemeReference, Bool)?
                transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
                    let currentSettings: PresentationThemeSettings
                    if let entry = entry?.get(PresentationThemeSettings.self) {
                        currentSettings = entry
                    } else {
                        currentSettings = PresentationThemeSettings.defaultSettings
                    }
                    
                    var updatedSettings: PresentationThemeSettings
                    if autoNightModeTriggered {
                        if case .builtin = currentSettings.automaticThemeSwitchSetting.theme {
                            previousDefaultTheme = (currentSettings.automaticThemeSwitchSetting.theme, currentSettings.themeSpecificAccentColors[currentSettings.automaticThemeSwitchSetting.theme.index], true, updatedTheme, existing)
                        }
                        
                        var automaticThemeSwitchSetting = currentSettings.automaticThemeSwitchSetting
                        automaticThemeSwitchSetting.theme = updatedTheme
                        updatedSettings = currentSettings.withUpdatedAutomaticThemeSwitchSetting(automaticThemeSwitchSetting)
                    } else {
                        if case .builtin = currentSettings.theme {
                            previousDefaultTheme = (currentSettings.theme, currentSettings.themeSpecificAccentColors[currentSettings.theme.index], false, updatedTheme, existing)
                        }
                         
                        updatedSettings = currentSettings.withUpdatedTheme(updatedTheme)
                    }
                    
                    var themeSpecificAccentColors = updatedSettings.themeSpecificAccentColors
                    if case let .cloud(info) = updatedTheme, let settings = info.theme.settings?.first {
                        let baseThemeReference = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme))
                        themeSpecificAccentColors[baseThemeReference.index] = PresentationThemeAccentColor(themeIndex: updatedTheme.index)
                    }
                    
                    var themeSpecificChatWallpapers = updatedSettings.themeSpecificChatWallpapers
                    themeSpecificChatWallpapers[updatedTheme.index] = nil
                    return PreferencesEntry(updatedSettings.withUpdatedThemeSpecificChatWallpapers(themeSpecificChatWallpapers).withUpdatedThemeSpecificAccentColors(themeSpecificAccentColors))
                })
                return previousDefaultTheme
            }
        }
        
        var cancelImpl: (() -> Void)?
        let progress = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))
            self?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.35, queue: Queue.mainQueue())
        
        let progressDisposable = progress.start()
        cancelImpl = {
            disposable.set(nil)
        }
        disposable.set((setup
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] previousDefaultTheme in
            if let strongSelf = self, let layout = strongSelf.validLayout {
                Queue.mainQueue().after(0.3) {
                    if case .settings = strongSelf.source {
                        
                    } else if layout.size.width >= 375.0 {
                        let navigationController = strongSelf.navigationController as? NavigationController
                        if let (previousDefaultTheme, previousAccentColor, autoNightMode, theme, _) = previousDefaultTheme {
                            let _ = (ApplicationSpecificNotice.getThemeChangeTip(accountManager: strongSelf.context.sharedContext.accountManager)
                            |> deliverOnMainQueue).start(next: { [weak self] displayed in
                                guard let strongSelf = self, !displayed else {
                                    return
                                }
                                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .actionSucceeded(title: strongSelf.presentationData.strings.Theme_ThemeChanged, text: strongSelf.presentationData.strings.Theme_ThemeChangedText, cancel: strongSelf.presentationData.strings.Undo_Undo), elevatedLayout: true, animateInAsReplacement: false, action: { value in
                                    if value == .undo {
                                        Queue.mainQueue().after(0.2) {
                                            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current -> PresentationThemeSettings in
                                                var updated: PresentationThemeSettings
                                                if autoNightMode {
                                                    var automaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                                                    automaticThemeSwitchSetting.theme = previousDefaultTheme
                                                    updated = current.withUpdatedAutomaticThemeSwitchSetting(automaticThemeSwitchSetting)
                                                } else {
                                                    updated = current.withUpdatedTheme(previousDefaultTheme)
                                                }
                                                
                                                var themeSpecificAccentColors = current.themeSpecificAccentColors
                                                themeSpecificAccentColors[previousDefaultTheme.index] = previousAccentColor
                                                updated = updated.withUpdatedThemeSpecificAccentColors(themeSpecificAccentColors)
                                                
                                                return updated
                                            }).start()
                                        }
                                        
                                        if case let .cloud(info) = theme {
                                            let _ = deleteThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: info.theme).start()
                                        }
                                        return true
                                    } else if value == .info {
                                        let controller = themeSettingsController(context: context)
                                        controller.navigationPresentation = .modal
                                        navigationController?.pushViewController(controller, animated: true)
                                        return true
                                    }
                                    return false
                                }), in: .window(.root))
                                
                                ApplicationSpecificNotice.markThemeChangeTipAsSeen(accountManager: strongSelf.context.sharedContext.accountManager)
                            })
                        }
                    }
                    strongSelf.dismiss()
                }
            }
        }))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    @objc private func actionPressed() {
        let subject: ShareControllerSubject
        let preferredAction: ShareControllerPreferredAction
        switch self.source {
            case .settings:
                return
            case let .theme(theme):
                subject = .url("https://t.me/addtheme/\(theme.slug)")
                preferredAction = .default
            case let .slug(slug, _), let .themeSettings(slug, _):
                subject = .url("https://t.me/addtheme/\(slug)")
                preferredAction = .default
            case let .media(media):
                subject = .media(media)
                preferredAction = .default
        }
        let controller = ShareController(context: self.context, subject: subject, preferredAction: preferredAction)
        self.present(controller, in: .window(.root), blockInteraction: true)
    }
}
