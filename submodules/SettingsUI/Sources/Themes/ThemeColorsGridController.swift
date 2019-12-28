import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

private func availableColors() -> [UInt32] {
    return [
        0xffffff,
        0xd4dfea,
        0xb3cde1,
        0x6ab7ea,
        0x008dd0,
        0xd3e2da,
        0xc8e6c9,
        0xc5e1a5,
        0x61b06e,
        0xcdcfaf,
        0xa7a895,
        0x7c6f72,
        0xffd7ae,
        0xffb66d,
        0xde8751,
        0xefd5e0,
        0xdba1b9,
        0xffafaf,
        0xf16a60,
        0xe8bcea,
        0x9592ed,
        0xd9bc60,
        0xb17e49,
        0xd5cef7,
        0xdf506b,
        0x8bd2cc,
        0x3c847e,
        0x22612c,
        0x244d7c,
        0x3d3b85,
        0x65717d,
        0x18222d,
        0x000000
    ]
}

private func randomColor() -> UInt32 {
    let colors = availableColors()
    return colors[1 ..< colors.count - 1].randomElement() ?? 0x000000
}

final class ThemeColorsGridController: ViewController {
    private var controllerNode: ThemeColorsGridControllerNode {
        return self.displayNode as! ThemeColorsGridControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var validLayout: ContainerViewLayout?
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.title = self.presentationData.strings.WallpaperColors_Title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.title = self.presentationData.strings.WallpaperColors_Title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(self.presentationData)
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ThemeColorsGridControllerNode(context: self.context, presentationData: self.presentationData, colors: availableColors(), present: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
        }, pop: { [weak self] in
            if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                let _ = navigationController.popViewController(animated: true)
            }
        }, presentColorPicker: { [weak self] in
            if let strongSelf = self {
                let _ = (strongSelf.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings])
                |> take(1)
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
                    
                    let controller = ThemeAccentColorController(context: strongSelf.context, mode: .background(themeReference: themeReference))
                    controller.completion = { [weak self] in
                        if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                            var controllers = navigationController.viewControllers
                            controllers = controllers.filter { controller in
                                if controller is ThemeColorsGridController {
                                    return false
                                }
                                return true
                            }
                            navigationController.setViewControllers(controllers, animated: false)
                            controllers = controllers.filter { controller in
                                if controller is ThemeAccentColorController {
                                    return false
                                }
                                return true
                            }
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }
                    strongSelf.push(controller)
                })
            }
        })
    
        self._ready.set(self.controllerNode.ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
