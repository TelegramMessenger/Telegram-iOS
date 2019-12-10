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

private let colors: [Int32] = [0x007aff, 0x00c2ed, 0x29b327, 0xeb6ca4, 0xf08200, 0x9472ee, 0xd33213, 0xedb400, 0x6d839e]

enum ThemeAccentColorControllerMode {
    case colors(themeReference: PresentationThemeReference)
    case background(themeReference: PresentationThemeReference)
    case edit(theme: PresentationTheme, wallpaper: TelegramWallpaper?, defaultThemeReference: PresentationThemeReference?, create: Bool, completion: (PresentationTheme) -> Void)
    
    var themeReference: PresentationThemeReference? {
        switch self {
            case let .colors(themeReference), let .background(themeReference):
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
            self.initialBackgroundColor = colors.randomElement().flatMap { UIColor(rgb: UInt32(bitPattern: $0)) }
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
                if case let .edit(theme, _, themeReference, _, completion) = strongSelf.mode {
                    let updatedTheme: PresentationTheme
                    if let themeReference = themeReference {
                        updatedTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: state.accentColor, bubbleColors: state.messagesColors, backgroundColors: state.backgroundColors, serviceBackgroundColor: serviceBackgroundColor) ?? defaultPresentationTheme
                    } else {
                        updatedTheme = customizePresentationTheme(theme, editing: false, accentColor: state.accentColor, backgroundColors: state.backgroundColors, bubbleColors: state.messagesColors)
                    }
                    
                    completion(updatedTheme)
                } else {
                    let _ = (updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                        let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
                        var currentTheme = current.theme
                        if autoNightModeTriggered {
                            currentTheme = current.automaticThemeSwitchSetting.theme
                        }
                        
                        var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                        var themeSpecificAccentColors = current.themeSpecificAccentColors
                        
                        var bubbleColors: (Int32, Int32?)?
                        if let messagesColors = state.messagesColors {
                            if let secondColor = messagesColors.1 {
                                bubbleColors = (Int32(bitPattern: messagesColors.0.rgb), Int32(bitPattern: secondColor.rgb))
                            } else {
                                bubbleColors = (Int32(bitPattern: messagesColors.0.rgb), nil)
                            }
                        }
                        
                        let color = PresentationThemeAccentColor(baseColor: .custom, accentColor: Int32(bitPattern: state.accentColor.rgb), bubbleColors: bubbleColors)
                        themeSpecificAccentColors[currentTheme.index] = color
                        
                        var wallpaper = themeSpecificChatWallpapers[currentTheme.index]
                        if let backgroundColors = state.backgroundColors {
                            if let bottomColor = backgroundColors.1 {
                                wallpaper = .gradient(Int32(bitPattern: backgroundColors.0.rgb), Int32(bitPattern: bottomColor.rgb), WallpaperSettings())
                            } else {
                                wallpaper = .color(Int32(bitPattern: backgroundColors.0.rgb))
                            }
                        }
                        themeSpecificChatWallpapers[currentTheme.index] = wallpaper
                        
                        return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                    }) |> deliverOnMainQueue).start(completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.completion?()
                            strongSelf.dismiss()
                        }
                    })
                }
            }
        })
        self.controllerNode.themeUpdated = { [weak self] theme in
            if let strongSelf = self {
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationTheme: theme, presentationStrings: strongSelf.presentationData.strings))
                strongSelf.segmentedTitleView.theme = theme
            }
        }
        
        let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            guard let strongSelf = self else {
                return
            }
            let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
                
            let accentColor: UIColor
            var initialWallpaper: TelegramWallpaper?
            let backgroundColors: (UIColor, UIColor?)?
            let messageColors: (UIColor, UIColor?)?
            var defaultMessagesColor: UIColor?
            
            var ignoreDefaultWallpaper = false
            
            if let themeReference = strongSelf.mode.themeReference {
                accentColor = settings.themeSpecificAccentColors[themeReference.index]?.color ?? defaultDayAccentColor
                let wallpaper: TelegramWallpaper
                if let customWallpaper = settings.themeSpecificChatWallpapers[themeReference.index] {
                    wallpaper = customWallpaper
                } else {
                    let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: nil, bubbleColors: nil) ?? defaultPresentationTheme
                    if case let .builtin(themeName) = themeReference {
                        if case .dayClassic = themeName, settings.themeSpecificAccentColors[themeReference.index] != nil {
                            ignoreDefaultWallpaper = true
                        } else if case .nightAccent = themeName {
                            ignoreDefaultWallpaper = true
                        }
                    }
                    
                    wallpaper = theme.chat.defaultWallpaper
                }
                
                if !wallpaper.isColorOrGradient && !ignoreDefaultWallpaper {
                    initialWallpaper = wallpaper
                }
                
                if let initialBackgroundColor = strongSelf.initialBackgroundColor {
                    backgroundColors = (initialBackgroundColor, nil)
                } else if !ignoreDefaultWallpaper {
                    if case let .color(color) = wallpaper {
                        backgroundColors = (UIColor(rgb: UInt32(bitPattern: color)), nil)
                    } else if case let .gradient(topColor, bottomColor, _) = wallpaper {
                        backgroundColors = (UIColor(rgb: UInt32(bitPattern: topColor)), UIColor(rgb: UInt32(bitPattern: bottomColor)))
                    } else {
                        backgroundColors = nil
                    }
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
            } else if case let .edit(theme, wallpaper, _, _, _) = strongSelf.mode {
                accentColor = theme.rootController.navigationBar.accentTextColor
                if case let .color(color) = theme.chat.defaultWallpaper {
                    backgroundColors = (UIColor(rgb: UInt32(bitPattern: color)), nil)
                } else if case let .gradient(topColor, bottomColor, _) = theme.chat.defaultWallpaper {
                    backgroundColors = (UIColor(rgb: UInt32(bitPattern: topColor)), UIColor(rgb: UInt32(bitPattern: bottomColor)))
                } else {
                    backgroundColors = nil
                }
                let topMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.fill
                let bottomMessageColor = theme.chat.message.outgoing.bubble.withWallpaper.gradientFill
                
                if topMessageColor.rgb == bottomMessageColor.rgb {
                    messageColors = (topMessageColor, nil)
                } else {
                    messageColors = (topMessageColor, bottomMessageColor)
                }
            } else {
                accentColor = UIColor(rgb: 0x007ee5)
                backgroundColors = nil
                messageColors = nil
            }
            
            let initialState = ThemeColorState(section: strongSelf.section, accentColor: accentColor, initialWallpaper: initialWallpaper, backgroundColors: backgroundColors, defaultMessagesColor: defaultMessagesColor, messagesColors: messageColors)
            
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
