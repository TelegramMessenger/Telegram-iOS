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
import PresentationDataUtils
import MediaResources

private let randomBackgroundColors: [Int32] = [0x007aff, 0x00c2ed, 0x29b327, 0xeb6ca4, 0xf08200, 0x9472ee, 0xd33213, 0xedb400, 0x6d839e]

extension TelegramThemeSettings {
    convenience init(baseTheme: TelegramBaseTheme, accentColor: UIColor, outgoingAccentColor: UIColor?, messageColors: [UInt32], animateMessageColors: Bool, wallpaper: TelegramWallpaper?) {
        self.init(baseTheme: baseTheme, accentColor: accentColor.argb, outgoingAccentColor: outgoingAccentColor?.argb, messageColors: messageColors, animateMessageColors: animateMessageColors, wallpaper: wallpaper)
    }
}

enum ThemeAccentColorControllerMode {
    case colors(themeReference: PresentationThemeReference, create: Bool)
    case background(themeReference: PresentationThemeReference)
    case edit(settings: TelegramThemeSettings?, theme: PresentationTheme, wallpaper: TelegramWallpaper?, generalThemeReference: PresentationThemeReference?, defaultThemeReference: PresentationThemeReference?, create: Bool, completion: (PresentationTheme, TelegramThemeSettings?) -> Void)
    
    var themeReference: PresentationThemeReference? {
        switch self {
            case let .colors(themeReference, _), let .background(themeReference):
                return themeReference
            case let .edit(_, _, _, _, defaultThemeReference, _, _):
                return defaultThemeReference
        }
    }
}

final class ThemeAccentColorController: ViewController {
    private let context: AccountContext
    private let mode: ThemeAccentColorControllerMode
    private let section: ThemeColorSection
    private let initialBackgroundColor: UIColor?
    private var presentationData: PresentationData
    private var initialAccentColor: PresentationThemeAccentColor?
    
    private var controllerNode: ThemeAccentColorControllerNode {
        return self.displayNode as! ThemeAccentColorControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let segmentedTitleView: ThemeColorSegmentedTitleView
    
    private var applyDisposable = MetaDisposable()
    
    var completion: (() -> Void)?
    
    init(context: AccountContext, mode: ThemeAccentColorControllerMode) {
        self.context = context
        self.mode = mode
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let section: ThemeColorSection = .background
        self.section = section
        
        self.segmentedTitleView = ThemeColorSegmentedTitleView(theme: self.presentationData.theme, strings: self.presentationData.strings, selectedSection: section)
        
        if case .background = mode {
            self.initialBackgroundColor = randomBackgroundColors.randomElement().flatMap { UIColor(rgb: UInt32(bitPattern: $0)) }
        } else {
            self.initialBackgroundColor = nil
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings))
        
        self.navigationPresentation = .modal
                
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.segmentedTitleView.sectionUpdated = { [weak self] section in
            if let strongSelf = self {
                strongSelf.controllerNode.updateSection(section)
            }
        }
        
        self.segmentedTitleView.shouldUpdateSection = { [weak self] section, f in
            guard let strongSelf = self else {
                f(false)
                return
            }
            guard section == .background else {
                f(true)
                return
            }
                        
            if strongSelf.controllerNode.requiresWallpaperChange {
                let controller = textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Theme_Colors_ColorWallpaperWarning, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                    f(false)
                }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Theme_Colors_ColorWallpaperWarningProceed, action: {
                    f(true)
                })])
                strongSelf.present(controller, in: .window(.root))
            } else {
                f(true)
            }
        }
        
        if case .background = mode {
            self.title = self.presentationData.strings.Wallpaper_Title
        } else {
            self.navigationItem.titleView = self.segmentedTitleView
        }
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.applyDisposable.dispose()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.controllerNode.animateWallpaperAppeared()
    }
    
    override func loadDisplayNode() {
        super.loadDisplayNode()
        
        let theme: PresentationTheme
        let initialWallpaper: TelegramWallpaper
        if case let .edit(_, editedTheme, walpaper, _, _, _, _) = self.mode {
            theme = editedTheme
            initialWallpaper = walpaper ?? editedTheme.chat.defaultWallpaper
        } else {
            theme = self.presentationData.theme
            initialWallpaper = self.presentationData.chatWallpaper
        }
        
        self.displayNode = ThemeAccentColorControllerNode(context: self.context, mode: self.mode, theme: theme, wallpaper: initialWallpaper, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] state, serviceBackgroundColor in
            if let strongSelf = self {
                let context = strongSelf.context
                let autoNightModeTriggered = strongSelf.presentationData.autoNightModeTriggered
                
                var coloredWallpaper: TelegramWallpaper?
                if !state.backgroundColors.isEmpty {
                    if let patternWallpaper = state.patternWallpaper {
                        coloredWallpaper = patternWallpaper.withUpdatedSettings(WallpaperSettings(colors: state.backgroundColors.map { $0.rgb }, intensity: state.patternIntensity, rotation: state.rotation))
                    } else if state.backgroundColors.count >= 2 {
                        coloredWallpaper = .gradient(TelegramWallpaper.Gradient(id: nil, colors: state.backgroundColors.map { $0.rgb }, settings: WallpaperSettings(rotation: state.rotation)))
                    } else {
                        coloredWallpaper = .color(state.backgroundColors[0].rgb)
                    }
                }
                
                let prepareWallpaper: Signal<CreateThemeResult, CreateThemeError>
                if let patternWallpaper = state.patternWallpaper, case let .file(file) = patternWallpaper, !state.backgroundColors.isEmpty {
                    let resource = file.file.resource

                    var data: Data?
                    if let path = strongSelf.context.account.postbox.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    } else if let path = strongSelf.context.sharedContext.accountManager.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    }
                    
                    if let data = data {
                        strongSelf.context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                        prepareWallpaper = .complete()
                    } else {
                        prepareWallpaper = .complete()
                    }
                } else {
                    prepareWallpaper = .complete()
                }
                
                if case let .edit(themeSettings, theme, _, generalThemeReference, _, _, completion) = strongSelf.mode {
                    let _ = (prepareWallpaper
                    |> deliverOnMainQueue).start(completed: {
                        let updatedTheme: PresentationTheme
                        var settings: TelegramThemeSettings?
                        var hasSettings = false
                        var baseTheme: TelegramBaseTheme?
                        
                        if let settings = themeSettings {
                            hasSettings = true
                            baseTheme = settings.baseTheme
                        } else if case let .cloud(theme) = generalThemeReference, let settings = theme.theme.settings?.first {
                            hasSettings = true
                            baseTheme = settings.baseTheme
                        } else if case let .builtin(theme) = generalThemeReference {
                            hasSettings = true
                            baseTheme = theme.baseTheme
                        }
                        
                        if let themeReference = generalThemeReference {
                            updatedTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: state.accentColor.color, outgoingAccentColor: state.outgoingAccentColor?.color, backgroundColors: state.backgroundColors.map { $0.rgb }, bubbleColors: state.messagesColors.map { $0.rgb }, animateBubbleColors: state.animateMessageColors, wallpaper: coloredWallpaper ?? state.initialWallpaper, serviceBackgroundColor: serviceBackgroundColor) ?? defaultPresentationTheme
                        } else {
                            updatedTheme = customizePresentationTheme(theme, editing: false, accentColor: state.accentColor.color, outgoingAccentColor: state.outgoingAccentColor?.color, backgroundColors: state.backgroundColors.map { $0.rgb }, bubbleColors: state.messagesColors.map { $0.rgb }, animateBubbleColors: state.animateMessageColors, wallpaper: state.initialWallpaper ?? coloredWallpaper)
                        }
                        
                        if hasSettings, let baseTheme = baseTheme {
                            settings = TelegramThemeSettings(baseTheme: baseTheme, accentColor: state.accentColor.color, outgoingAccentColor: state.outgoingAccentColor?.color, messageColors: state.messagesColors.map { $0.rgb }, animateMessageColors: state.animateMessageColors, wallpaper: coloredWallpaper)
                        }
                        
                        completion(updatedTheme, settings)
                    })
                } else if case let .colors(theme, create) = strongSelf.mode {
                    var baseTheme: TelegramBaseTheme
                    var telegramTheme: TelegramTheme?
                    if case let .cloud(theme) = theme, let settings = theme.theme.settings?.first {
                        telegramTheme = theme.theme
                        baseTheme = settings.baseTheme
                    } else if case let .builtin(theme) = theme {
                        baseTheme = theme.baseTheme
                    } else {
                        baseTheme = .classic
                    }
                    
                    let wallpaper = coloredWallpaper ?? state.initialWallpaper
                    
                    let settings = TelegramThemeSettings(baseTheme: baseTheme, accentColor: state.accentColor.rgb, outgoingAccentColor: state.outgoingAccentColor?.rgb, messageColors: state.messagesColors.map { $0.rgb }, animateMessageColors: state.animateMessageColors, wallpaper: wallpaper)
                    let baseThemeReference = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: baseTheme))
                    
                    let apply: Signal<Void, CreateThemeError>
                    if create {
                        apply = (prepareWallpaper |> then(createTheme(account: context.account, title: generateThemeName(accentColor: state.accentColor.color), resource: nil, thumbnailData: nil, settings: [settings])))
                        |> mapToSignal { next -> Signal<Void, CreateThemeError> in
                            if case let .result(resultTheme) = next {
                                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                return updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                                    let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: wallpaper, creatorAccountId: context.account.id))
                                    
                                    var updatedTheme = current.theme
                                    var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                                    if autoNightModeTriggered {
                                        updatedAutomaticThemeSwitchSetting.theme = themeReference
                                    } else {
                                        updatedTheme = themeReference
                                    }
                                    
                                    let themePreferredBaseTheme = current.themePreferredBaseTheme
                                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                    themeSpecificChatWallpapers[themeReference.index] = nil
                                    
                                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                                    themeSpecificAccentColors[baseThemeReference.index] = PresentationThemeAccentColor(themeIndex: themeReference.index)
                                    
                                    return PresentationThemeSettings(theme: updatedTheme, themePreferredBaseTheme: themePreferredBaseTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, chatBubbleSettings: current.chatBubbleSettings, automaticThemeSwitchSetting: updatedAutomaticThemeSwitchSetting, largeEmoji: current.largeEmoji, reduceMotion: current.reduceMotion)
                                })
                                |> castError(CreateThemeError.self)
                            } else {
                                return .complete()
                            }
                        }
                    } else if let theme = telegramTheme {
                        apply = (prepareWallpaper |> then(updateTheme(account: context.account, accountManager: context.sharedContext.accountManager, theme: theme, title: theme.title, slug: theme.slug, resource: nil, settings: [settings])))
                        |> mapToSignal { next -> Signal<Void, CreateThemeError> in
                            if case let .result(resultTheme) = next {
                                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                return updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                                    let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: wallpaper, creatorAccountId: context.account.id))
                                    
                                    var updatedTheme = current.theme
                                    var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                                    if autoNightModeTriggered {
                                        updatedAutomaticThemeSwitchSetting.theme = themeReference
                                    } else {
                                        updatedTheme = themeReference
                                    }
                                    
                                    let themePreferredBaseTheme = current.themePreferredBaseTheme
                                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                    themeSpecificChatWallpapers[themeReference.index] = nil
                                    
                                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                                    themeSpecificAccentColors[baseThemeReference.index] = PresentationThemeAccentColor(themeIndex: themeReference.index)
                                    
                                    return PresentationThemeSettings(theme: updatedTheme, themePreferredBaseTheme: themePreferredBaseTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, chatBubbleSettings: current.chatBubbleSettings, automaticThemeSwitchSetting: updatedAutomaticThemeSwitchSetting, largeEmoji: current.largeEmoji, reduceMotion: current.reduceMotion)
                                })
                                |> castError(CreateThemeError.self)
                            } else {
                                return .complete()
                            }
                        }
                    } else {
                        apply = .complete()
                    }
                    
                    let disposable = strongSelf.applyDisposable
                    var cancelImpl: (() -> Void)?
                    let progress = Signal<Never, NoError> { [weak self] subscriber in
                        let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
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
                        if let strongSelf = self {
                            strongSelf.controllerNode.dismissed = false
                        }
                        disposable.set(nil)
                    }
                    disposable.set((apply
                    |> afterDisposed {
                        Queue.mainQueue().async {
                            progressDisposable.dispose()
                        }
                    }
                    |> deliverOnMainQueue).start(completed: {
                        if let strongSelf = self {
                            strongSelf.completion?()
                            strongSelf.dismiss()
                        }
                    }))
                } else if case .background = strongSelf.mode {
                    let autoNightModeTriggered = strongSelf.presentationData.autoNightModeTriggered
                    let _ = (updatePresentationThemeSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager) { current in
                        var updated = current
                        let themeReference: PresentationThemeReference
                        if autoNightModeTriggered {
                            themeReference = current.automaticThemeSwitchSetting.theme
                        } else {
                            themeReference = current.theme
                        }
                        updated.themeSpecificChatWallpapers[themeReference.index] = coloredWallpaper
                        return updated
                    } |> deliverOnMainQueue).start(completed: {
                        if let strongSelf = self {
                            strongSelf.completion?()
                            strongSelf.dismiss()
                        }
                    })
                }
            }
        }, ready: self._ready)
        self.controllerNode.themeUpdated = { [weak self] theme in
            if let strongSelf = self {
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationTheme: theme, presentationStrings: strongSelf.presentationData.strings))
                strongSelf.segmentedTitleView.theme = theme
            }
        }
        self.controllerNode.requestSectionUpdate = { [weak self] section in
            if let strongSelf = self {
                strongSelf.segmentedTitleView.setIndex(section.rawValue, animated: true)
            }
        }
        
        let _ = (combineLatest(
            self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings]) |> take(1),
            telegramWallpapers(postbox: context.account.postbox, network: context.account.network) |> take(1)
        )
        |> deliverOnMainQueue).start(next: { [weak self] sharedData, wallpapers in
            guard let strongSelf = self else {
                return
            }
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
                
            let accentColor: UIColor
            let outgoingAccentColor: UIColor?
            var initialWallpaper: TelegramWallpaper?
            var backgroundColors: [UInt32] = []
            var patternWallpaper: TelegramWallpaper?
            var patternIntensity: Int32 = 50
            let messageColors: [UInt32]
            let defaultMessagesColor: UIColor? = nil
            var rotation: Int32 = 0
            let animateMessageColors: Bool
            
            func extractWallpaperParameters(_ wallpaper: TelegramWallpaper?) {
                guard let wallpaper = wallpaper else {
                    return
                }
                if case let .file(file) = wallpaper, wallpaper.isPattern {
                    if !file.settings.colors.isEmpty {
                        if let intensity = file.settings.intensity {
                            patternIntensity = intensity
                        }
                    }
                    patternWallpaper = wallpaper
                    backgroundColors = file.settings.colors
                    rotation = file.settings.rotation ?? 0
                } else if case let .color(color) = wallpaper {
                    backgroundColors = [color]
                } else if case let .gradient(gradient) = wallpaper {
                    backgroundColors = gradient.colors
                    rotation = gradient.settings.rotation ?? 0
                } else {
                    if let image = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, knockoutMode: false) {
                        backgroundColors = [averageColor(from: image).rgb]
                    } else if let image = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: strongSelf.context.account.postbox.mediaBox, knockoutMode: false) {
                        backgroundColors = [averageColor(from: image).rgb]
                    } else {
                        backgroundColors = [UIColor.gray.rgb]
                    }
                }
            }
            
            if let themeReference = strongSelf.mode.themeReference {
                var wallpaper: TelegramWallpaper
        
                func extractBuiltinWallpaper(_ currentWallpaper: TelegramWallpaper) {
                    if case let .builtin(settings) = currentWallpaper {
                        var defaultPatternWallpaper: TelegramWallpaper?
                        
                        for wallpaper in wallpapers {
                            if case let .file(file) = wallpaper, file.slug == "JqSUrO0-mFIBAAAAWwTvLzoWGQI" {
                                defaultPatternWallpaper = wallpaper
                                break
                            }
                        }
                        
                        if let defaultPatternWallpaper = defaultPatternWallpaper {
                            wallpaper = defaultPatternWallpaper.withUpdatedSettings(WallpaperSettings(blur: settings.blur, motion: settings.motion, colors: [0xd6e2ee], intensity: 40, rotation: nil))
                        }
                    }
                }
                
                if case let .colors(initialThemeReference, true) = strongSelf.mode {
                    let themeSpecificAccentColor = settings.themeSpecificAccentColors[themeReference.index]
                    var customAccentColor: UIColor?
                    if let color = themeSpecificAccentColor?.color, color != .clear {
                        accentColor = color
                        customAccentColor = accentColor
                    } else if case let .cloud(cloudTheme) = initialThemeReference, let settings = cloudTheme.theme.settings?.first {
                        accentColor = UIColor(rgb: settings.accentColor)
                        customAccentColor = accentColor
                    } else {
                        accentColor = defaultDayAccentColor
                    }
                    
                    var referenceTheme: PresentationTheme?
                    if let accentColor = themeSpecificAccentColor, let customWallpaper = settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: themeReference, accentColor: accentColor)] {
                        wallpaper = customWallpaper
                    } else if let customWallpaper = settings.themeSpecificChatWallpapers[themeReference.index] {
                        wallpaper = customWallpaper
                    } else {
                        let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: customAccentColor, wallpaper: themeSpecificAccentColor?.wallpaper, baseColor: themeSpecificAccentColor?.baseColor) ?? defaultPresentationTheme
                        referenceTheme = theme
                        wallpaper = theme.chat.defaultWallpaper
                    }
                    
                    if case let .cloud(cloudTheme) = initialThemeReference, let settings = cloudTheme.theme.settings?.first {
                        animateMessageColors = settings.animateMessageColors
                        outgoingAccentColor = settings.outgoingAccentColor.flatMap { UIColor(rgb: $0) }
                    } else if let referenceTheme = referenceTheme {
                        animateMessageColors = referenceTheme.chat.animateMessageColors
                        outgoingAccentColor = nil
                    } else {
                        animateMessageColors = false
                        outgoingAccentColor = nil
                    }
                    
                    extractBuiltinWallpaper(wallpaper)
                    
                    if !wallpaper.isColorOrGradient {
                        initialWallpaper = wallpaper
                    }
                    
                    if let initialBackgroundColor = strongSelf.initialBackgroundColor {
                        backgroundColors = [initialBackgroundColor.rgb]
                    } else {
                        extractWallpaperParameters(wallpaper)
                    }
                    
                    if let bubbleColors = settings.themeSpecificAccentColors[themeReference.index]?.customBubbleColors, !bubbleColors.isEmpty {
                        messageColors = bubbleColors
                    } else {
                        if let themeReference = strongSelf.mode.themeReference, themeReference == .builtin(.dayClassic), settings.themeSpecificAccentColors[themeReference.index] == nil {
                            messageColors = [UIColor(rgb: 0xe1ffc7).rgb]
                        } else if let referenceTheme = referenceTheme {
                            messageColors = referenceTheme.chat.message.outgoing.bubble.withoutWallpaper.fill.map(\.rgb)
                        } else {
                            messageColors = []
                        }
                    }
                } else {
                    let presentationTheme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference)!
                    if case let .cloud(theme) = themeReference, let themeSettings = theme.theme.settings?.first {                        
                        accentColor = UIColor(argb: themeSettings.accentColor)
                        
                        if let customWallpaper = settings.themeSpecificChatWallpapers[themeReference.index] {
                            wallpaper = customWallpaper
                        } else {
                            wallpaper = presentationTheme.chat.defaultWallpaper
                        }
                        extractWallpaperParameters(wallpaper)
                        if !wallpaper.isColorOrGradient {
                            initialWallpaper = wallpaper
                        }
                        
                        if !themeSettings.messageColors.isEmpty {
                            messageColors = themeSettings.messageColors
                        } else {
                            messageColors = []
                        }
                        
                        animateMessageColors = themeSettings.animateMessageColors
                        outgoingAccentColor = themeSettings.outgoingAccentColor.flatMap { UIColor(rgb: $0) }
                    } else if case .builtin = themeReference {
                         let themeSpecificAccentColor = settings.themeSpecificAccentColors[themeReference.index]
                         accentColor = themeSpecificAccentColor?.color ?? defaultDayAccentColor
                        
                         if let accentColor = themeSpecificAccentColor, let customWallpaper = settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: themeReference, accentColor: accentColor)] {
                             wallpaper = customWallpaper
                         } else if let customWallpaper = settings.themeSpecificChatWallpapers[themeReference.index] {
                             wallpaper = customWallpaper
                         } else {
                             let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: nil, wallpaper: themeSpecificAccentColor?.wallpaper) ?? defaultPresentationTheme
                             wallpaper = theme.chat.defaultWallpaper
                         }
                         
                         extractBuiltinWallpaper(wallpaper)
                         
                         if !wallpaper.isColorOrGradient {
                             initialWallpaper = wallpaper
                         }
                         
                         if let initialBackgroundColor = strongSelf.initialBackgroundColor {
                            backgroundColors = [initialBackgroundColor.rgb]
                         } else {
                             extractWallpaperParameters(wallpaper)
                         }
                         
                        if let bubbleColors = settings.themeSpecificAccentColors[themeReference.index]?.customBubbleColors, !bubbleColors.isEmpty {
                            messageColors = bubbleColors
                         } else {
                             if let themeReference = strongSelf.mode.themeReference, themeReference == .builtin(.dayClassic), settings.themeSpecificAccentColors[themeReference.index] == nil {
                                messageColors = [UIColor(rgb: 0xe1ffc7).rgb]
                             } else {
                                 messageColors = []
                             }
                         }
                        
                        animateMessageColors = false
                        outgoingAccentColor = nil
                    } else {
                        let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference)!
                        
                        accentColor = theme.rootController.navigationBar.accentTextColor
                        outgoingAccentColor = nil
                        
                        let wallpaper = theme.chat.defaultWallpaper
                        extractWallpaperParameters(wallpaper)
                        
                        if !wallpaper.isColorOrGradient {
                            initialWallpaper = wallpaper
                        }
                        
                        messageColors = theme.chat.message.outgoing.bubble.withWallpaper.fill.map(\.rgb)
                        animateMessageColors = theme.chat.animateMessageColors
                    }
                }
            } else if case let .edit(settings, theme, wallpaper, _, _, _, _) = strongSelf.mode {
                if let settings = settings {
                    accentColor = UIColor(rgb: settings.accentColor)
                    outgoingAccentColor = settings.outgoingAccentColor.flatMap { UIColor(rgb: $0) }
                    
                    let wallpaper = settings.wallpaper ?? theme.chat.defaultWallpaper
                    extractWallpaperParameters(wallpaper)
                    initialWallpaper = wallpaper
                    
                    messageColors = settings.messageColors
                    animateMessageColors = settings.animateMessageColors
                } else {
                    accentColor = theme.rootController.navigationBar.accentTextColor
                    outgoingAccentColor = nil
                    
                    let wallpaper = wallpaper ?? theme.chat.defaultWallpaper
                    extractWallpaperParameters(wallpaper)
                    
                    if !wallpaper.isColorOrGradient {
                        initialWallpaper = wallpaper
                    }
                    
                    messageColors = theme.chat.message.outgoing.bubble.withWallpaper.fill.map(\.rgb)
                    animateMessageColors = theme.chat.animateMessageColors
                }
            } else {
                accentColor = defaultDayAccentColor
                outgoingAccentColor = nil
                backgroundColors = []
                messageColors = []
                
                animateMessageColors = false
            }
            
            let initialState = ThemeColorState(section: strongSelf.section, accentColor: HSBColor(color: accentColor), outgoingAccentColor: outgoingAccentColor.flatMap { HSBColor(color: $0) }, initialWallpaper: initialWallpaper, backgroundColors: backgroundColors.map { HSBColor(rgb: $0) }, patternWallpaper: patternWallpaper, patternIntensity: patternIntensity, animateMessageColors: animateMessageColors, defaultMessagesColor: defaultMessagesColor.flatMap { HSBColor(color: $0) }, messagesColors: messageColors.map { HSBColor(rgb: $0) }, selectedColor: 0, rotation: rotation)
            
            strongSelf.controllerNode.updateState({ _ in
                return initialState
            }, animated: false)
        })
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
