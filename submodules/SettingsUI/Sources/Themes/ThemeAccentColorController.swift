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

final class ThemeAccentColorController: ViewController {
    private let context: AccountContext
    private let themeReference: PresentationThemeReference
    private let section: ThemeColorSection
    private let initialBackgroundColor: UIColor?
    private var presentationData: PresentationData
    
    private var controllerNode: ThemeAccentColorControllerNode {
        return self.displayNode as! ThemeAccentColorControllerNode
    }

    let segmentedTitleView: ThemeColorSegmentedTitleView
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    var completion: (() -> Void)?
    
    init(context: AccountContext, themeReference: PresentationThemeReference, section: ThemeColorSection) {
        self.context = context
        self.themeReference = themeReference
        self.section = section
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.segmentedTitleView = ThemeColorSegmentedTitleView(theme: self.presentationData.theme, strings: self.presentationData.strings, selectedSection: section)
        
        if section == .background {
            self.initialBackgroundColor = colors.randomElement().flatMap { UIColor(rgb: UInt32(bitPattern: $0)) }
        } else {
            self.initialBackgroundColor = nil
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings))
                
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
        
        self.displayNode = ThemeAccentColorControllerNode(context: self.context, themeReference: self.themeReference, theme: self.presentationData.theme, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] state in
            if let strongSelf = self {
                let context = strongSelf.context
                let _ = (updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
                    var currentTheme = current.theme
                    if autoNightModeTriggered {
                        currentTheme = current.automaticThemeSwitchSetting.theme
                    }
                    
                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                    var themeSpecificBubbleColors = current.themeSpecificBubbleColors
                    let color = PresentationThemeAccentColor(baseColor: .custom, value: Int32(bitPattern: state.accentColor.rgb))
                    themeSpecificAccentColors[currentTheme.index] = color
                    
                    var wallpaper = themeSpecificChatWallpapers[currentTheme.index]
                    if let backgroundColors = state.backgroundColors {
                        if let bottomColor = backgroundColors.1 {
                            wallpaper = .gradient(Int32(bitPattern: backgroundColors.0.rgb), Int32(bitPattern: bottomColor.rgb))
                        } else {
                            wallpaper = .color(Int32(bitPattern: backgroundColors.0.rgb))
                        }
                    }
                    themeSpecificChatWallpapers[currentTheme.index] = wallpaper
                    
                    var bubbleColors: PresentationThemeColorPair?
                    if let messagesColors = state.messagesColors {
                        if let secondColor = messagesColors.1 {
                            bubbleColors = PresentationThemeColorPair(color: Int32(bitPattern: messagesColors.0.rgb), optionalColor: Int32(bitPattern: secondColor.rgb))
                        } else {
                            bubbleColors = PresentationThemeColorPair(color: Int32(bitPattern: messagesColors.0.rgb), optionalColor: nil)
                        }
                    }
                    themeSpecificBubbleColors[currentTheme.index] = bubbleColors
                    
                    return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificBubbleColors: themeSpecificBubbleColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: current.useSystemFont, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                }) |> deliverOnMainQueue).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.completion?()
                        strongSelf.dismiss()
                    }
                })
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
            
            let autoNightModeTriggered = strongSelf.presentationData.autoNightModeTriggered
            let themeReference: PresentationThemeReference
            if autoNightModeTriggered {
                themeReference = settings.automaticThemeSwitchSetting.theme
            } else {
                themeReference = settings.theme
            }
    
            let accentColor = settings.themeSpecificAccentColors[themeReference.index]?.color ?? defaultDayAccentColor
            let wallpaper: TelegramWallpaper
            if let customWallpaper = settings.themeSpecificChatWallpapers[themeReference.index] {
                wallpaper = customWallpaper
            } else {
                let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: nil, bubbleColors: nil, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
                wallpaper = theme.chat.defaultWallpaper
            }
            
            let backgroundColors: (UIColor, UIColor?)?
            if let initialBackgroundColor = strongSelf.initialBackgroundColor {
                backgroundColors = (initialBackgroundColor, nil)
            } else {
                if case let .color(color) = wallpaper {
                    backgroundColors = (UIColor(rgb: UInt32(bitPattern: color)), nil)
                } else if case let .gradient(topColor, bottomColor) = wallpaper {
                    backgroundColors = (UIColor(rgb: UInt32(bitPattern: topColor)), UIColor(rgb: UInt32(bitPattern: bottomColor)))
                } else {
                    backgroundColors = nil
                }
            }
            
            let messageColors: (UIColor, UIColor?)?
            if let bubbleColors = settings.themeSpecificBubbleColors[themeReference.index] {
                if let bottomColor = bubbleColors.optionalColor {
                    messageColors = (UIColor(rgb: UInt32(bitPattern: bubbleColors.color)), UIColor(rgb: UInt32(bitPattern: bottomColor)))
                } else {
                    messageColors = (UIColor(rgb: UInt32(bitPattern: bubbleColors.color)), nil)
                }
            } else {
                messageColors = nil
            }
            
            let initialState = ThemeColorState(section: strongSelf.section, accentColor: accentColor, backgroundColors: backgroundColors, messagesColors: messageColors)
            
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
