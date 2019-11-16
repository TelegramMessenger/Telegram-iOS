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

private let colors: [Int32] = [0x007aff, 0x00c2ed, 0x29b327, 0xeb6ca4, 0xf08200, 0x9472ee, 0xd33213, 0xedb400, 0x6d839e]

final class ThemeAccentColorController: ViewController {
    private let context: AccountContext
    private let currentTheme: PresentationThemeReference
    private let section: ThemeColorSection
    
    let segmentedTitleView: ThemeColorSegmentedTitleView
    
    private var controllerNode: ThemeAccentColorControllerNode {
        return self.displayNode as! ThemeAccentColorControllerNode
    }
    
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    init(context: AccountContext, currentTheme: PresentationThemeReference, section: ThemeColorSection) {
        self.context = context
        self.currentTheme = currentTheme
        self.section = section
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
//        var color: UIColor
//        if let currentColor = currentColor {
//            color = currentColor
//        } else if let randomColor = colors.randomElement() {
//            color = UIColor(rgb: UInt32(bitPattern: randomColor))
//        } else {
//            color = defaultDayAccentColor
//        }
        
        self.segmentedTitleView = ThemeColorSegmentedTitleView(theme: self.presentationData.theme, strings: self.presentationData.strings, selectedSection: .accent)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings))
                
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.segmentedTitleView.sectionUpdated = { [weak self] section in
            if let strongSelf = self {
                strongSelf.controllerNode.updateSection(section)
            }
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        self.navigationItem.titleView = self.segmentedTitleView
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        super.loadDisplayNode()
        
        self.displayNode = ThemeAccentColorControllerNode(context: self.context, currentTheme: self.currentTheme, theme: self.presentationData.theme, dismiss: { [weak self] in
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
                    //let color = PresentationThemeAccentColor(baseColor: .custom, value: Int32(bitPattern: strongSelf.controllerNode.color))
                    //themeSpecificAccentColors[currentTheme.index] = color
                    
                    let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: currentTheme, accentColor: nil, serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: nil) ?? defaultPresentationTheme
                    if let wallpaper = current.themeSpecificChatWallpapers[currentTheme.index], wallpaper.hasWallpaper {
                    } else {
                        themeSpecificChatWallpapers[currentTheme.index] = theme.chat.defaultWallpaper
                    }
                    
                    return PresentationThemeSettings(theme: current.theme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificBubbleColors: current.themeSpecificBubbleColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                }) |> deliverOnMainQueue).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.dismiss()
                    }
                })
            }
        })
        self.controllerNode.themeUpdated = { [weak self] theme in
            if let strongSelf = self {
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationTheme: theme, presentationStrings: strongSelf.presentationData.strings))
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
                let theme = makePresentationTheme(mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: nil, serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: nil) ?? defaultPresentationTheme
                wallpaper = theme.chat.defaultWallpaper
            }
            
            let backgroundColors: (UIColor, UIColor?)?
            if case let .color(color) = wallpaper {
                backgroundColors = (UIColor(rgb: UInt32(bitPattern: color)), nil)
            } else if case let .gradient(topColor, bottomColor) = wallpaper {
                backgroundColors = (UIColor(rgb: UInt32(bitPattern: topColor)), UIColor(rgb: UInt32(bitPattern: bottomColor)))
            } else {
                backgroundColors = nil
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
