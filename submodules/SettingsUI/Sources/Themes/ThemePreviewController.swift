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

public enum ThemePreviewSource {
    case theme(TelegramTheme)
    case slug(String, TelegramMediaFile)
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
        
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var disposable: Disposable?
    private var applyDisposable = MetaDisposable()

    public init(context: AccountContext, previewTheme: PresentationTheme, source: ThemePreviewSource) {
        self.context = context
        self.previewTheme = previewTheme
        self.source = source
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationTheme.set(.single(previewTheme))
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.previewTheme, presentationStrings: self.presentationData.strings))
        
        let themeName: String
        if case let .theme(theme) = source {
            themeName = theme.title
            self.theme.set(.single(theme))
        } else if case let .slug(slug, _) = source {
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
                        return telegramThemeData(account: context.account, accountManager: context.sharedContext.accountManager, resource: file.resource)
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
        } else {
            self.theme.set(.single(nil))
            themeName = previewTheme.name.string
        }
        
        let titleView = CounterContollerTitleView(theme: self.previewTheme)
        titleView.title = CounterContollerTitle(title: themeName, counter: " ")
        self.navigationItem.titleView = titleView
        
        self.statusBar.statusBarStyle = self.previewTheme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: self.previewTheme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.actionPressed))
        
        self.disposable = (combineLatest(self.theme.get(), self.presentationTheme.get())
        |> deliverOnMainQueue).start(next: { [weak self] theme, presentationTheme in
            if let strongSelf = self, let theme = theme {
                let titleView = CounterContollerTitleView(theme: strongSelf.previewTheme)
                titleView.title = CounterContollerTitle(title: themeName, counter: strongSelf.presentationData.strings.Theme_UsersCount(max(1, theme.installCount)))
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
        
        self.displayNode = ThemePreviewControllerNode(context: self.context, previewTheme: self.previewTheme, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] in
            if let strongSelf = self {
                strongSelf.apply()
            }
        })
        self.displayNodeDidLoad()
        
        let previewTheme = self.previewTheme
        if case let .file(file) = previewTheme.chat.defaultWallpaper, file.id == 0 {
            self.controllerNode.wallpaperPromise.set(cachedWallpaper(account: self.context.account, slug: file.slug, settings: file.settings)
            |> mapToSignal { wallpaper in
                return .single(wallpaper?.wallpaper ?? .color(Int32(bitPattern: previewTheme.chatList.backgroundColor.rgb)))
            })
        } else {
            self.controllerNode.wallpaperPromise.set(.single(previewTheme.chat.defaultWallpaper))
        }
    }
    
    private func apply() {
        let previewTheme = self.previewTheme
        let theme: Signal<PresentationThemeReference?, NoError>
        let context = self.context
        let wallpaperPromise = self.controllerNode.wallpaperPromise
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let disposable = self.applyDisposable
        
        switch self.source {
            case .theme, .slug:
                theme = combineLatest(self.theme.get() |> take(1), wallpaperPromise.get() |> take(1))
                |> mapToSignal { theme, wallpaper -> Signal<PresentationThemeReference?, NoError> in
                    if let theme = theme {
                        if case let .file(file) = wallpaper, file.id != 0 {
                            return .single(.cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: wallpaper)))
                        } else {
                            return .single(.cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: nil)))
                        }
                    } else {
                        return .complete()
                    }
                }
            case .media:
                if let strings = encodePresentationTheme(previewTheme), let data = strings.data(using: .utf8) {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data)
                    theme = .single(.local(PresentationLocalTheme(title: previewTheme.name.string, resource: resource, resolvedWallpaper: nil)))
                } else {
                    theme = .single(.builtin(.dayClassic))
                }
        }
        
        var resolvedWallpaper: TelegramWallpaper?
        
        let signal = theme
        |> mapToSignal { theme -> Signal<PresentationThemeReference, NoError> in
            guard let theme = theme else {
                return .complete()
            }
            switch theme {
                case let .cloud(info):
                    resolvedWallpaper = info.resolvedWallpaper
                    return .single(theme)
                case let .local(info):
                    return wallpaperPromise.get()
                    |> take(1)
                    |> mapToSignal { currentWallpaper -> Signal<PresentationThemeReference, NoError> in
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
                        |> mapToSignal { themes -> Signal<PresentationThemeReference, NoError> in
                            let similarTheme = themes.filter { $0.isCreator && $0.title == info.title }.first
                            if let similarTheme = similarTheme {
                                return updateTheme(account: context.account, accountManager: context.sharedContext.accountManager, theme: similarTheme, title: nil, slug: nil, resource: info.resource, thumbnailData: themeThumbnailData)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<CreateThemeResult?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { result -> Signal<PresentationThemeReference, NoError> in
                                    guard let result = result else {
                                        let updatedTheme = PresentationLocalTheme(title: info.title, resource: info.resource, resolvedWallpaper: resolvedWallpaper)
                                        return .single(.local(updatedTheme))
                                    }
                                    if case let .result(theme) = result, let file = theme.file {
                                        context.sharedContext.accountManager.mediaBox.moveResourceData(from: info.resource.id, to: file.resource.id)
                                        return .single(.cloud(PresentationCloudTheme(theme: theme, resolvedWallpaper: resolvedWallpaper)))
                                    } else {
                                        return .complete()
                                    }
                                }
                                
                            } else {
                                return createTheme(account: context.account, title: info.title, resource: info.resource, thumbnailData: themeThumbnailData)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<CreateThemeResult?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { result -> Signal<PresentationThemeReference, NoError> in
                                    guard let result = result else {
                                        let updatedTheme = PresentationLocalTheme(title: info.title, resource: info.resource, resolvedWallpaper: resolvedWallpaper)
                                        return .single(.local(updatedTheme))
                                    }
                                    if case let .result(updatedTheme) = result, let file = updatedTheme.file {
                                        context.sharedContext.accountManager.mediaBox.moveResourceData(from: info.resource.id, to: file.resource.id)
                                        return .single(.cloud(PresentationCloudTheme(theme: updatedTheme, resolvedWallpaper: resolvedWallpaper)))
                                    } else {
                                        return .complete()
                                    }
                                }
                            }
                        }
                    }
                case .builtin:
                    return .single(theme)
            }
        }
        |> mapToSignal { theme -> Signal<Void, NoError> in
            if case let .cloud(info) = theme {
                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: info.theme).start()
                let _ = saveThemeInteractively(account: context.account, accountManager: context.sharedContext.accountManager, theme: info.theme).start()
            }
            return context.sharedContext.accountManager.transaction { transaction -> Void in
                transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
                    let current = entry as? PresentationThemeSettings ?? PresentationThemeSettings.defaultSettings
                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                    themeSpecificChatWallpapers[theme.index] = nil
                    return PresentationThemeSettings(chatWallpaper: resolvedWallpaper ?? previewTheme.chat.defaultWallpaper, theme: theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                })
            }
        }
        
        var cancelImpl: (() -> Void)?
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings,  type: .loading(cancelled: {
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
        
        let progressDisposable = progressSignal.start()
        cancelImpl = {
            disposable.set(nil)
        }
        disposable.set((signal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(completed: {[weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }))
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }

    @objc private func actionPressed() {
        let subject: ShareControllerSubject
        let preferredAction: ShareControllerPreferredAction
        switch self.source {
            case let .theme(theme):
                subject = .url("https://t.me/addtheme/\(theme.slug)")
                preferredAction = .default
            case let .slug(slug, _):
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
