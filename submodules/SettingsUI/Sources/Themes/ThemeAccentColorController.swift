import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import PresentationDataUtils
import MediaResources

private let randomBackgroundColors: [Int32] = [0x007aff, 0x00c2ed, 0x29b327, 0xeb6ca4, 0xf08200, 0x9472ee, 0xd33213, 0xedb400, 0x6d839e]

extension TelegramThemeSettings {
    convenience init(baseTheme: TelegramBaseTheme, accentColor: UIColor, messageColors: (top: UIColor, bottom: UIColor?)?, wallpaper: TelegramWallpaper?) {
        var messageColorsValues: (UInt32, UInt32)?
        if let colors = messageColors {
            messageColorsValues = (colors.0.argb, colors.1?.argb ?? colors.0.argb)
        }
        self.init(baseTheme: baseTheme, accentColor: accentColor.argb, messageColors: messageColorsValues, wallpaper: wallpaper)
    }
}

enum ThemeAccentColorControllerMode {
    case colors(themeReference: PresentationThemeReference, create: Bool)
    case background(themeReference: PresentationThemeReference)
    case edit(theme: PresentationTheme, wallpaper: TelegramWallpaper?, generalThemeReference: PresentationThemeReference?, defaultThemeReference: PresentationThemeReference?, create: Bool, completion: (PresentationTheme, TelegramThemeSettings?) -> Void)
    
    var themeReference: PresentationThemeReference? {
        switch self {
            case let .colors(themeReference, _), let .background(themeReference):
                return themeReference
            case let .edit(_, _, _, defaultThemeReference, _, _):
                return defaultThemeReference
            default:
                return nil
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
        
        var section: ThemeColorSection = .accent
        if case .background = mode {
            section = .background
        }
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
    
    override func loadDisplayNode() {
        super.loadDisplayNode()
        
        let theme: PresentationTheme
        let initialWallpaper: TelegramWallpaper
        if case let .edit(editedTheme, walpaper, _, _, _, _) = self.mode {
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
                let initialAccentColor = strongSelf.initialAccentColor
                let autoNightModeTriggered = strongSelf.presentationData.autoNightModeTriggered
                
                var coloredWallpaper: TelegramWallpaper?
                if let backgroundColors = state.backgroundColors {
                    let color = backgroundColors.0.argb
                    let bottomColor = backgroundColors.1.flatMap { $0.argb }
                    
                    if let patternWallpaper = state.patternWallpaper {
                        coloredWallpaper = patternWallpaper.withUpdatedSettings(WallpaperSettings(motion: state.motion, color: color, bottomColor: bottomColor, intensity: state.patternIntensity, rotation: state.rotation))
                    } else if let bottomColor = bottomColor {
                        coloredWallpaper = .gradient(color, bottomColor, WallpaperSettings(motion: state.motion, rotation: state.rotation))
                    } else {
                        coloredWallpaper = .color(color)
                    }
                }
                
                
                let apply: Signal<Void, NoError>
                
                let prepareWallpaper: Signal<CreateThemeResult, CreateThemeError>
                if let patternWallpaper = state.patternWallpaper, case let .file(file) = patternWallpaper, let backgroundColors = state.backgroundColors {
                    let resource = file.file.resource
                    let representation = CachedPatternWallpaperRepresentation(color: backgroundColors.0.argb, bottomColor: backgroundColors.1.flatMap { $0.argb }, intensity: state.patternIntensity, rotation: state.rotation)
                    
                    var data: Data?
                    if let path = strongSelf.context.account.postbox.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    } else if let path = strongSelf.context.sharedContext.accountManager.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    }
                    
                    if let data = data {
                        strongSelf.context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                        prepareWallpaper = (strongSelf.context.sharedContext.accountManager.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: true, fetch: true)
                        |> filter({ $0.complete })
                        |> take(1)
                        |> castError(CreateThemeError.self)
                        |> mapToSignal { _ -> Signal<CreateThemeResult, CreateThemeError> in
                            return .complete()
                        })
                    } else {
                        prepareWallpaper = .complete()
                    }
                } else {
                    prepareWallpaper = .complete()
                }
                
                if case let .edit(theme, initialWallpaper, generalThemeReference, themeReference, _, completion) = strongSelf.mode {
                    let _ = (prepareWallpaper
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        let updatedTheme: PresentationTheme
                        
                        var settings: TelegramThemeSettings?
                        var hasSettings = false
                        var baseTheme: TelegramBaseTheme?
                        
                        if case let .cloud(theme) = generalThemeReference, let settings = theme.theme.settings {
                            hasSettings = true
                            baseTheme = settings.baseTheme
                        } else if case let .builtin(theme) = generalThemeReference {
                            hasSettings = true
                            baseTheme = theme.baseTheme
                        }
                        
                        if let themeReference = generalThemeReference {
                            updatedTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: state.accentColor, backgroundColors: state.backgroundColors, bubbleColors: state.messagesColors, wallpaper: state.initialWallpaper ?? coloredWallpaper, serviceBackgroundColor: serviceBackgroundColor) ?? defaultPresentationTheme
                        } else {
                            updatedTheme = customizePresentationTheme(theme, editing: false, accentColor: state.accentColor, backgroundColors: state.backgroundColors, bubbleColors: state.messagesColors, wallpaper: state.initialWallpaper ?? coloredWallpaper)
                        }
                        
                        if hasSettings, let baseTheme = baseTheme {
                            var messageColors: (Int32, Int32)?
                            if let colors = state.messagesColors {
                                messageColors = (Int32(bitPattern: colors.0.argb), Int32(bitPattern: colors.1?.argb ?? colors.0.argb))
                            }
                            
                            settings = TelegramThemeSettings(baseTheme: baseTheme, accentColor: state.accentColor, messageColors: state.messagesColors, wallpaper: coloredWallpaper)
                        }
                        
                        completion(updatedTheme, settings)
                    })
                } else if case let .colors(theme, create) = strongSelf.mode {
                    var baseTheme: TelegramBaseTheme
                    var telegramTheme: TelegramTheme?
                    if case let .cloud(theme) = theme, let settings = theme.theme.settings {
                        telegramTheme = theme.theme
                        baseTheme = settings.baseTheme
                    } else if case let .builtin(theme) = theme {
                        baseTheme = theme.baseTheme
                    } else {
                        baseTheme = .classic
                    }
                    
                    let wallpaper = state.initialWallpaper ?? coloredWallpaper
                    
                    let settings = TelegramThemeSettings(baseTheme: baseTheme, accentColor: state.accentColor, messageColors: state.messagesColors, wallpaper: wallpaper)
                    let baseThemeReference = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: baseTheme))
                    
                    let apply: Signal<Void, CreateThemeError>
                    if create {
                        apply = (prepareWallpaper |> then(createTheme(account: context.account, title: generateThemeName(accentColor: state.accentColor), resource: nil, thumbnailData: nil, settings: settings)))
                        |> mapToSignal { next -> Signal<Void, CreateThemeError> in
                            if case let .result(resultTheme) = next {
                                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                return updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                                    let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: wallpaper))
                                    
                                    var updatedTheme = current.theme
                                    var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                                    if autoNightModeTriggered {
                                        updatedAutomaticThemeSwitchSetting.theme = themeReference
                                    } else {
                                        updatedTheme = themeReference
                                    }
                                    
                                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                    themeSpecificChatWallpapers[themeReference.index] = nil
                                    
                                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                                    themeSpecificAccentColors[baseThemeReference.index] = PresentationThemeAccentColor(themeIndex: themeReference.index)
                                    
                                    return PresentationThemeSettings(theme: updatedTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, automaticThemeSwitchSetting: updatedAutomaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                                })
                                |> castError(CreateThemeError.self)
                            } else {
                                return .complete()
                            }
                        }
                    } else if let theme = telegramTheme {
                        apply = (prepareWallpaper |> then(updateTheme(account: context.account, accountManager: context.sharedContext.accountManager, theme: theme, title: theme.title, slug: theme.slug, resource: nil, settings: settings)))
                        |> mapToSignal { next -> Signal<Void, CreateThemeError> in
                            if case let .result(resultTheme) = next {
                                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                return updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                                    let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: wallpaper))
                                    
                                    var updatedTheme = current.theme
                                    var updatedAutomaticThemeSwitchSetting = current.automaticThemeSwitchSetting
                                    if autoNightModeTriggered {
                                        updatedAutomaticThemeSwitchSetting.theme = themeReference
                                    } else {
                                        updatedTheme = themeReference
                                    }
                                    
                                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                    themeSpecificChatWallpapers[themeReference.index] = nil
                                    
                                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                                    themeSpecificAccentColors[baseThemeReference.index] = PresentationThemeAccentColor(themeIndex: themeReference.index)
                                    
                                    return PresentationThemeSettings(theme: updatedTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, listsFontSize: current.listsFontSize, automaticThemeSwitchSetting: updatedAutomaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
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
            let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
                
            let accentColor: UIColor
            var initialWallpaper: TelegramWallpaper?
            var backgroundColors: (UIColor, UIColor?)?
            var patternWallpaper: TelegramWallpaper?
            var patternIntensity: Int32 = 50
            var motion = false
            let messageColors: (UIColor, UIColor?)?
            var defaultMessagesColor: UIColor?
            var rotation: Int32 = 0
            
            func extractWallpaperParameters(_ wallpaper: TelegramWallpaper?) {
                guard let wallpaper = wallpaper else {
                    return
                }
                if case let .file(file) = wallpaper, wallpaper.isPattern {
                    var patternColor = UIColor(rgb: 0xd6e2ee, alpha: 0.4)
                    var bottomColor: UIColor?
                    if let color = file.settings.color {
                        if let intensity = file.settings.intensity {
                            patternIntensity = intensity
                        }
                        patternColor = UIColor(rgb: color)
                        if let bottomColorValue = file.settings.bottomColor {
                            bottomColor = UIColor(rgb: bottomColorValue)
                        }
                    }
                    patternWallpaper = wallpaper
                    backgroundColors = (patternColor, bottomColor)
                    motion = file.settings.motion
                    rotation = file.settings.rotation ?? 0
                } else if case let .color(color) = wallpaper {
                    backgroundColors = (UIColor(rgb: color), nil)
                } else if case let .gradient(topColor, bottomColor, settings) = wallpaper {
                    backgroundColors = (UIColor(rgb: topColor), UIColor(rgb: bottomColor))
                    motion = settings.motion
                    rotation = settings.rotation ?? 0
                } else {
                    backgroundColors = nil
                }
            }
            
            if let themeReference = strongSelf.mode.themeReference {
                var wallpaper: TelegramWallpaper
        
                func extractBuiltinWallpaper(_ currentWallpaper: TelegramWallpaper) {
                    if case let .builtin(settings) = currentWallpaper {
                        var defaultPatternWallpaper: TelegramWallpaper?
                        
                        for wallpaper in wallpapers {
                            //JqSUrO0-mFIBAAAAWwTvLzoWGQI, 25
                            if case let .file(file) = wallpaper, file.slug == "-Xc-np9y2VMCAAAARKr0yNNPYW0" {
                                defaultPatternWallpaper = wallpaper
                                break
                            }
                        }
                        
                        if let defaultPatternWallpaper = defaultPatternWallpaper {
                            wallpaper = defaultPatternWallpaper.withUpdatedSettings(WallpaperSettings(blur: settings.blur, motion: settings.motion, color: 0xd6e2ee, bottomColor: nil, intensity: 40, rotation: nil))
                        }
                    }
                }
                
                if case .colors(_, true) = strongSelf.mode {
                    let themeSpecificAccentColor = settings.themeSpecificAccentColors[themeReference.index]
                    accentColor = themeSpecificAccentColor?.color ?? defaultDayAccentColor
                   
                    if let accentColor = themeSpecificAccentColor, let customWallpaper = settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: themeReference, accentColor: accentColor)] {
                        wallpaper = customWallpaper
                    } else if let customWallpaper = settings.themeSpecificChatWallpapers[themeReference.index] {
                        wallpaper = customWallpaper
                    } else {
                        let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: themeSpecificAccentColor?.color, wallpaper: themeSpecificAccentColor?.wallpaper) ?? defaultPresentationTheme
                        wallpaper = theme.chat.defaultWallpaper
                    }
                    
                    extractBuiltinWallpaper(wallpaper)
                    
                    if !wallpaper.isColorOrGradient {
                        initialWallpaper = wallpaper
                    }
                    
                    if let initialBackgroundColor = strongSelf.initialBackgroundColor {
                        backgroundColors = (initialBackgroundColor, nil)
                    } else {
                        extractWallpaperParameters(wallpaper)
                    }
                    
                    if let bubbleColors = settings.themeSpecificAccentColors[themeReference.index]?.customBubbleColors {
                        if let bottomColor = bubbleColors.1 {
                            messageColors = (bubbleColors.0, bottomColor)
                        } else {
                            messageColors = (bubbleColors.0, nil)
                        }
                    } else {
                        if let themeReference = strongSelf.mode.themeReference, themeReference == .builtin(.dayClassic), settings.themeSpecificAccentColors[themeReference.index] == nil {
                            messageColors = (UIColor(rgb: 0xe1ffc7), nil)
                        } else {
                            messageColors = nil
                        }
                    }
                } else {
                    let presentationTheme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference)!
                    if case let .cloud(theme) = themeReference, let themeSettings = theme.theme.settings {
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
                        
                        if let colors = themeSettings.messageColors {
                            let topMessageColor = UIColor(argb: colors.top)
                            let bottomMessageColor = UIColor(argb: colors.bottom)
                            if topMessageColor.argb == bottomMessageColor.argb {
                                messageColors = (topMessageColor, nil)
                            } else {
                                messageColors = (topMessageColor, bottomMessageColor)
                            }
                        } else {
                           messageColors = nil
                        }
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
                             backgroundColors = (initialBackgroundColor, nil)
                         } else {
                             extractWallpaperParameters(wallpaper)
                         }
                         
                         if let bubbleColors = settings.themeSpecificAccentColors[themeReference.index]?.customBubbleColors {
                             if let bottomColor = bubbleColors.1 {
                                 messageColors = (bubbleColors.0, bottomColor)
                             } else {
                                 messageColors = (bubbleColors.0, nil)
                             }
                         } else {
                             if let themeReference = strongSelf.mode.themeReference, themeReference == .builtin(.dayClassic), settings.themeSpecificAccentColors[themeReference.index] == nil {
                                 messageColors = (UIColor(rgb: 0xe1ffc7), nil)
                             } else {
                                 messageColors = nil
                             }
                         }
                    } else {
                        let themeSpecificAccentColor = settings.themeSpecificAccentColors[themeReference.index]
                        
                        let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference)!
                        
                        accentColor = theme.rootController.navigationBar.accentTextColor
                        
                        let wallpaper = theme.chat.defaultWallpaper
                        extractWallpaperParameters(wallpaper)
                        
                        if !wallpaper.isColorOrGradient {
                            initialWallpaper = wallpaper
                        }
                        
                        let topMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.fill
                        let bottomMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.gradientFill
                        
                        if topMessageColor.argb == bottomMessageColor.argb {
                            messageColors = (topMessageColor, nil)
                        } else {
                            messageColors = (topMessageColor, bottomMessageColor)
                        }
                    }
                }
            } else if case let .edit(theme, wallpaper, _, themeReference, _, _) = strongSelf.mode {
                accentColor = theme.rootController.navigationBar.accentTextColor
                
                let wallpaper = wallpaper ?? theme.chat.defaultWallpaper
                extractWallpaperParameters(wallpaper)
                
                if !wallpaper.isColorOrGradient {
                    initialWallpaper = wallpaper
                }
                
                let topMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.fill
                let bottomMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.gradientFill
                
                if topMessageColor.argb == bottomMessageColor.argb {
                    messageColors = (topMessageColor, nil)
                } else {
                    messageColors = (topMessageColor, bottomMessageColor)
                }
            } else {
                accentColor = defaultDayAccentColor
                backgroundColors = nil
                messageColors = nil
            }
            
            let initialState = ThemeColorState(section: strongSelf.section, accentColor: accentColor, initialWallpaper: initialWallpaper, backgroundColors: backgroundColors, patternWallpaper: patternWallpaper, patternIntensity: patternIntensity, motion: motion, defaultMessagesColor: defaultMessagesColor, messagesColors: messageColors, rotation: rotation)
            
            strongSelf.controllerNode.updateState({ _ in
                return initialState
            }, animated: false)
        })
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
