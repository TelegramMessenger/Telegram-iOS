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

private let colors: [Int32] = [0x007aff, 0x00c2ed, 0x29b327, 0xeb6ca4, 0xf08200, 0x9472ee, 0xd33213, 0xedb400, 0x6d839e]

final class ThemeAccentColorController: ViewController {
    private let context: AccountContext
    private let currentTheme: PresentationThemeReference
    private let initialColor: UIColor
    private let initialTheme: PresentationTheme
    
    private var controllerNode: ThemeAccentColorControllerNode {
        return self.displayNode as! ThemeAccentColorControllerNode
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    
    init(context: AccountContext, currentTheme: PresentationThemeReference, currentColor: UIColor?) {
        self.context = context
        self.currentTheme = currentTheme
        
        var color: UIColor
        if let currentColor = currentColor {
            color = currentColor
        }
        else if let randomColor = colors.randomElement() {
            color = UIColor(rgb: UInt32(bitPattern: randomColor))
        } else {
            color = defaultDayAccentColor
        }
        self.initialColor = color
        self.initialTheme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: currentTheme, accentColor: color, serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: nil, preview: true)
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.initialTheme, presentationStrings: self.presentationData.strings))
        
        self.title = self.presentationData.strings.AccentColor_Title
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override func loadDisplayNode() {
        super.loadDisplayNode()
        
        self.displayNode = ThemeAccentColorControllerNode(context: self.context, currentTheme: self.currentTheme, color: self.initialColor, theme: self.initialTheme, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] in
            if let strongSelf = self {
                let context = strongSelf.context
                let _ = (updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    var themeSpecificAccentColors = current.themeSpecificAccentColors
                    let color = PresentationThemeAccentColor(baseColor: .custom, value: Int32(bitPattern: strongSelf.controllerNode.color))
                    themeSpecificAccentColors[current.theme.index] = color
                    
                    var themeSpecificChatWallpapers = current.themeSpecificChatWallpapers
                    
                    let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: strongSelf.currentTheme, accentColor: UIColor(rgb: strongSelf.controllerNode.color), serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: color.baseColor)
                    var chatWallpaper = current.chatWallpaper
                    if let wallpaper = current.themeSpecificChatWallpapers[current.theme.index], wallpaper.hasWallpaper {
                    } else {
                        chatWallpaper = theme.chat.defaultWallpaper
                        themeSpecificChatWallpapers[current.theme.index] = chatWallpaper
                    }
                    
                    return PresentationThemeSettings(chatWallpaper: chatWallpaper, theme: strongSelf.currentTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
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
        self.displayNodeDidLoad()
    }
    
    private func updateStrings() {
        
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
