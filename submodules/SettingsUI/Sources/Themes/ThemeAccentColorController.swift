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

enum ThemeAccentColorControllerMode {
    case colors(themeReference: PresentationThemeReference, create: Bool)
    case background(themeReference: PresentationThemeReference)
    case edit(theme: PresentationTheme, wallpaper: TelegramWallpaper?, defaultThemeReference: PresentationThemeReference?, create: Bool, completion: (PresentationTheme, TelegramThemeSettings?) -> Void)
    
    var themeReference: PresentationThemeReference? {
        switch self {
            case let .colors(themeReference, _), let .background(themeReference):
                return themeReference
            case let .edit(_, _, defaultThemeReference, _, _):
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

    private let segmentedTitleView: ThemeColorSegmentedTitleView
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
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
        
        self.navigationItem.titleView = self.segmentedTitleView
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        super.loadDisplayNode()
        
        let theme: PresentationTheme
        let wallpaper: TelegramWallpaper
        if case let .edit(editedTheme, walpaper, _, _, _) = self.mode {
            theme = editedTheme
            wallpaper = walpaper ?? editedTheme.chat.defaultWallpaper
        } else {
            theme = self.presentationData.theme
            wallpaper = self.presentationData.chatWallpaper
        }
        
        self.displayNode = ThemeAccentColorControllerNode(context: self.context, mode: self.mode, theme: theme, wallpaper: wallpaper, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] state, serviceBackgroundColor in
            if let strongSelf = self {
                let context = strongSelf.context
                let initialAccentColor = strongSelf.initialAccentColor
                
                var coloredWallpaper: TelegramWallpaper?
                if let backgroundColors = state.backgroundColors {
                    let color = Int32(bitPattern: backgroundColors.0.rgb)
                    let bottomColor = backgroundColors.1.flatMap { Int32(bitPattern: $0.rgb) }
                    
                    if let patternWallpaper = state.patternWallpaper {
                        coloredWallpaper = patternWallpaper.withUpdatedSettings(WallpaperSettings(motion: state.motion, color: color, bottomColor: bottomColor, intensity: state.patternIntensity, rotation: state.rotation))
                    } else if let bottomColor = bottomColor {
                        coloredWallpaper = .gradient(color, bottomColor, WallpaperSettings(motion: state.motion, rotation: state.rotation))
                    } else {
                        coloredWallpaper = .color(color)
                    }
                }
                
                let prepare: Signal<CreateThemeResult, CreateThemeError>
                if let patternWallpaper = state.patternWallpaper, case let .file(file) = patternWallpaper, let backgroundColors = state.backgroundColors {
                    let resource = file.file.resource
                    let representation = CachedPatternWallpaperRepresentation(color: Int32(bitPattern: backgroundColors.0.rgb), bottomColor: backgroundColors.1.flatMap { Int32(bitPattern: $0.rgb) }, intensity: state.patternIntensity, rotation: state.rotation)
                    
                    var data: Data?
                    if let path = strongSelf.context.account.postbox.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    } else if let path = strongSelf.context.sharedContext.accountManager.mediaBox.completedResourcePath(resource), let maybeData = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                        data = maybeData
                    }
                    
                    if let data = data {
                        strongSelf.context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                        prepare = (strongSelf.context.sharedContext.accountManager.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: true, fetch: true)
                        |> filter({ $0.complete })
                        |> take(1)
                        |> castError(CreateThemeError.self)
                        |> mapToSignal { _ -> Signal<CreateThemeResult, CreateThemeError> in
                            return .complete()
                        })
                    } else {
                        prepare = .complete()
                    }
                } else {
                    prepare = .complete()
                }
                
                if case let .edit(theme, _, themeReference, _, completion) = strongSelf.mode {
                    let _ = (prepare
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        let updatedTheme: PresentationTheme
                        
                        var settings: TelegramThemeSettings?
                        
                        if let themeReference = themeReference {
                            updatedTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: state.accentColor, backgroundColors: state.backgroundColors, bubbleColors: state.messagesColors, wallpaper: state.initialWallpaper ?? coloredWallpaper, serviceBackgroundColor: serviceBackgroundColor) ?? defaultPresentationTheme
                            
                            if case let .builtin(theme) = themeReference {
                                var messageColors: (Int32, Int32)?
                                if let colors = state.messagesColors {
                                    messageColors = (Int32(bitPattern: colors.0.rgb), Int32(bitPattern: colors.1?.rgb ?? colors.0.rgb))
                                }
                                
                                settings = TelegramThemeSettings(baseTheme: theme.baseTheme, accentColor: Int32(bitPattern: state.accentColor.rgb), messageColors: messageColors, wallpaper: coloredWallpaper)
                            }
                        } else {
                            updatedTheme = customizePresentationTheme(theme, editing: false, accentColor: state.accentColor, backgroundColors: state.backgroundColors, bubbleColors: state.messagesColors, wallpaper: state.initialWallpaper ?? coloredWallpaper)
                        }
                                                
                        completion(updatedTheme, settings)
                    })
                } else if case let .colors(theme, create) = strongSelf.mode {
                    var baseTheme: TelegramBaseTheme
                    var telegramTheme: TelegramTheme?
                    if case let .cloud(theme) = theme, let settings = theme.theme.settings {
                        telegramTheme = theme.theme
                        baseTheme = settings.baseTheme
                    } else {
                        baseTheme = .classic
                    }
                    
                    let accentColor =  Int32(bitPattern: state.accentColor.rgb)
                    var bubbleColors: (Int32, Int32)?
                    if let messagesColors = state.messagesColors {
                        if let secondColor = messagesColors.1 {
                            bubbleColors = (Int32(bitPattern: messagesColors.0.rgb), Int32(bitPattern: secondColor.rgb))
                        } else {
                            bubbleColors = (Int32(bitPattern: messagesColors.0.rgb), Int32(bitPattern: messagesColors.0.rgb))
                        }
                    }
                    
                    var wallpaper: TelegramWallpaper? = nil // themeSpecificChatWallpapers[currentTheme.index]
                    if let coloredWallpaper = coloredWallpaper {
                        wallpaper = coloredWallpaper
                    }
                    
                    let settings = TelegramThemeSettings(baseTheme: baseTheme, accentColor: accentColor, messageColors: bubbleColors, wallpaper: wallpaper)
                    let baseThemeReference = PresentationThemeReference.builtin(PresentationBuiltinThemeReference(baseTheme: baseTheme))
                    
                    let save: Signal<Void, NoError>
                    
                    if !create, let theme = telegramTheme {
                        let _ = (prepare |> then(updateTheme(account: context.account, accountManager: context.sharedContext.accountManager, theme: theme, title: theme.title, slug: theme.slug, resource: nil, settings: settings))
                        |> deliverOnMainQueue).start(next: { next in
                            if case let .result(resultTheme) = next {
                                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                let _ = (updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
//                                    if let resource = resultTheme.file?.resource, let data = themeData {
//                                        context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
//                                    }
                                    
                                    let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: wallpaper))
                                    
                                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                    themeSpecificChatWallpapers[themeReference.index] = nil
                                    
                                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                                    themeSpecificAccentColors[baseThemeReference.index] = PresentationThemeAccentColor(themeIndex: themeReference.index)
                                    
                                    return PresentationThemeSettings(theme: themeReference, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                                }) |> deliverOnMainQueue).start(completed: {
                                    if let strongSelf = self {
                                        strongSelf.completion?()
                                        strongSelf.dismiss()
                                    }
                                })
                            }
                        }, error: { error in
                        })
                    } else {
                        let title = generateThemeName(accentColor: state.accentColor)
                        let _ = (prepare |> then(createTheme(account: context.account, title: title, resource: nil, thumbnailData: nil, settings: settings))
                        |> deliverOnMainQueue).start(next: { next in
                            if case let .result(resultTheme) = next {
                                let _ = applyTheme(accountManager: context.sharedContext.accountManager, account: context.account, theme: resultTheme).start()
                                let _ = (updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                                //                                    if let resource = resultTheme.file?.resource, let data = themeData {
                                //                                        context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                //                                    }
                                
                                    let themeReference: PresentationThemeReference = .cloud(PresentationCloudTheme(theme: resultTheme, resolvedWallpaper: wallpaper))
                                    
                                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                                    themeSpecificChatWallpapers[themeReference.index] = nil
                                    
                                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                                    themeSpecificAccentColors[baseThemeReference.index] = PresentationThemeAccentColor(themeIndex: themeReference.index)
                                    
                                    return PresentationThemeSettings(theme: themeReference, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                                }) |> deliverOnMainQueue).start(completed: {
                                    if let strongSelf = self {
                                        strongSelf.completion?()
                                        strongSelf.dismiss()
                                    }
                                })
                            }
                        }, error: { error in
                        })
                    }
                }
            }
        })
        self.controllerNode.themeUpdated = { [weak self] theme in
            if let strongSelf = self {
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationTheme: theme, presentationStrings: strongSelf.presentationData.strings))
                strongSelf.segmentedTitleView.theme = theme
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
            
            var ignoreDefaultWallpaper = false
            
            func extractWallpaperParameters(_ wallpaper: TelegramWallpaper?) {
                guard let wallpaper = wallpaper else {
                    return
                }
                if case let .file(file) = wallpaper, file.isPattern {
                    var patternColor = UIColor(rgb: 0xd6e2ee, alpha: 0.4)
                    var bottomColor: UIColor?
                    if let color = file.settings.color {
                        if let intensity = file.settings.intensity {
                            patternIntensity = intensity
                        }
                        patternColor = UIColor(rgb: UInt32(bitPattern: color))
                        if let bottomColorValue = file.settings.bottomColor {
                            bottomColor = UIColor(rgb: UInt32(bitPattern: bottomColorValue))
                        }
                    }
                    patternWallpaper = wallpaper
                    backgroundColors = (patternColor, bottomColor)
                    motion = file.settings.motion
                    rotation = file.settings.rotation ?? 0
                } else if case let .color(color) = wallpaper {
                    backgroundColors = (UIColor(rgb: UInt32(bitPattern: color)), nil)
                } else if case let .gradient(topColor, bottomColor, settings) = wallpaper {
                    backgroundColors = (UIColor(rgb: UInt32(bitPattern: topColor)), UIColor(rgb: UInt32(bitPattern: bottomColor)))
                    motion = settings.motion
                    rotation = settings.rotation ?? 0
                } else {
                    backgroundColors = nil
                }
            }
            
            if let themeReference = strongSelf.mode.themeReference {
                var wallpaper: TelegramWallpaper
                
                if case .colors(_, true) = strongSelf.mode {
                    let themeSpecificAccentColor = settings.themeSpecificAccentColors[themeReference.index]
                    accentColor = themeSpecificAccentColor?.color ?? defaultDayAccentColor
                   
                    if let accentColor = themeSpecificAccentColor, let customWallpaper = settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: themeReference, accentColor: accentColor)] {
                        wallpaper = customWallpaper
                    } else if let customWallpaper = settings.themeSpecificChatWallpapers[themeReference.index] {
                        wallpaper = customWallpaper
                    } else {
                        let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: nil) ?? defaultPresentationTheme
                        if case let .builtin(themeName) = themeReference {
                            if case .dayClassic = themeName, settings.themeSpecificAccentColors[themeReference.index] != nil {
                                ignoreDefaultWallpaper = true
                            } else if case .nightAccent = themeName {
                                ignoreDefaultWallpaper = true
                            }
                        }
                        
                        wallpaper = theme.chat.defaultWallpaper
                    }
                    
                    if case let .builtin(settings) = wallpaper {
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
                    
                    if !wallpaper.isColorOrGradient && !ignoreDefaultWallpaper {
                        initialWallpaper = wallpaper
                    }
                    
                    if let initialBackgroundColor = strongSelf.initialBackgroundColor {
                        backgroundColors = (initialBackgroundColor, nil)
                    } else if !ignoreDefaultWallpaper {
                        extractWallpaperParameters(wallpaper)
                    } else {
                        backgroundColors = nil
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
                        accentColor = UIColor(rgb: UInt32(bitPattern: themeSettings.accentColor))
                        
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
                            let topMessageColor = UIColor(rgb: UInt32(bitPattern: colors.top))
                            let bottomMessageColor = UIColor(rgb: UInt32(bitPattern: colors.bottom))
                            if topMessageColor.rgb == bottomMessageColor.rgb {
                                messageColors = (topMessageColor, nil)
                            } else {
                                messageColors = (topMessageColor, bottomMessageColor)
                            }
                        } else {
                           messageColors = nil
                        }
                    } else {
                        let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference)!
                        
                        accentColor = theme.rootController.navigationBar.accentTextColor
                        
                        let wallpaper = theme.chat.defaultWallpaper
                        extractWallpaperParameters(wallpaper)
                        
                        if !wallpaper.isColorOrGradient {
                            initialWallpaper = wallpaper
                        }
                        
                        let topMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.fill
                        let bottomMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.gradientFill
                        
                        if topMessageColor.rgb == bottomMessageColor.rgb {
                            messageColors = (topMessageColor, nil)
                        } else {
                            messageColors = (topMessageColor, bottomMessageColor)
                        }
                    }
                }
            } else if case let .edit(theme, wallpaper, _, _, _) = strongSelf.mode {
                accentColor = theme.rootController.navigationBar.accentTextColor
                
                let wallpaper = wallpaper ?? theme.chat.defaultWallpaper
                extractWallpaperParameters(wallpaper)
                
                if !wallpaper.isColorOrGradient {
                    initialWallpaper = wallpaper
                }
                
                let topMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.fill
                let bottomMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.gradientFill
                
                if topMessageColor.rgb == bottomMessageColor.rgb {
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
            strongSelf._ready.set(.single(true))
        })
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
