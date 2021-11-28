import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

private func availableGradients(theme: PresentationTheme) -> [[UInt32]] {
    if theme.overallDarkAppearance {
        return [
            [0x1e3557, 0x151a36, 0x1c4352, 0x2a4541] as [UInt32],
            [0x1d223f, 0x1d1832, 0x1b2943, 0x141631] as [UInt32],
            [0x203439, 0x102028, 0x1d3c3a, 0x172635] as [UInt32],
            [0x1c2731, 0x1a1c25, 0x27303b, 0x1b1b21] as [UInt32],
            [0x3a1c3a, 0x24193c, 0x392e3e, 0x1a1632] as [UInt32],
            [0x2c211b, 0x44332a, 0x22191f, 0x3b2d36] as [UInt32],
            [0x1e3557, 0x182036, 0x1c4352, 0x16263a] as [UInt32],
            [0x111236, 0x14424f, 0x0b2334, 0x3b315d] as [UInt32],
            [0x2d4836, 0x172b19, 0x364331, 0x103231] as [UInt32]
        ]
    } else {
        return [
            [0xdbddbb, 0x6ba587, 0xd5d88d, 0x88b884] as [UInt32],
            [0x8dc0eb, 0xb9d1ea, 0xc6b1ef, 0xebd7ef] as [UInt32],
            [0x97beeb, 0xb1e9ea, 0xc6b1ef, 0xefb7dc] as [UInt32],
            [0x8adbf2, 0x888dec, 0xe39fea, 0x679ced] as [UInt32],
            [0xb0cdeb, 0x9fb0ea, 0xbbead5, 0xb2e3dd] as [UInt32],
            [0xdaeac8, 0xa2b4ff, 0xeccbff, 0xb9e2ff] as [UInt32],
            [0xdceb92, 0x8fe1d6, 0x67a3f2, 0x85d685] as [UInt32],
            [0xeaa36e, 0xf0e486, 0xf29ebf, 0xe8c06e] as [UInt32],
            [0xffc3b2, 0xe2c0ff, 0xffe7b2, 0xf8cece] as [UInt32]
        ]
    }
}

private func availableColors(theme: PresentationTheme) -> [UInt32] {
    if theme.overallDarkAppearance {
        return [
            0x1D2D3C,
            0x111B26,
            0x0B141E,
            0x1F361F,
            0x131F15,
            0x0E1710,
            0x2F2E27,
            0x2A261F,
            0x191817,
            0x432E30,
            0x2E1C1E,
            0x1F1314,
            0x432E3C,
            0x2E1C28,
            0x1F131B,
            0x3C2E43,
            0x291C2E,
            0x1D1221,
            0x312E43,
            0x1E1C2E,
            0x141221,
            0x2F3F3F,
            0x212D30,
            0x141E20,
            0x272524,
            0x191716,
            0x000000
        ]
    } else {
        return [
            0xD3DFEA,
            0xA5C5DB,
            0x6F99C8,
            0xD2E3A9,
            0xA4D48E,
            0x7DBB6E,
            0xE6DDAE,
            0xD5BE91,
            0xCBA479,
            0xEBC0B9,
            0xE0A79D,
            0xC97870,
            0xEBB9C8,
            0xE09DB7,
            0xD27593,
            0xDAC2ED,
            0xD3A5E7,
            0xB587D2,
            0xC2C2ED,
            0xA5A5E7,
            0x7F7FD0,
            0xC2E2ED,
            0xA5D6E7,
            0x7FBAD0,
            0xD6C2B9,
            0x9C8882,
            0x000000
        ]
    }
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
    
    private var previousContentOffset: GridNodeVisibleContentOffset?
    
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
        self.displayNode = ThemeColorsGridControllerNode(context: self.context, presentationData: self.presentationData, gradients: availableGradients(theme: self.presentationData.theme), colors: availableColors(theme: self.presentationData.theme), present: { [weak self] controller, arguments in
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
                    let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
                    
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
        
        self.controllerNode.gridNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                var previousContentOffsetValue: CGFloat?
                if let previousContentOffset = strongSelf.previousContentOffset, case let .known(value) = previousContentOffset {
                    previousContentOffsetValue = value
                }
                switch offset {
                    case let .known(value):
                        let transition: ContainedViewLayoutTransition
                        if let previousContentOffsetValue = previousContentOffsetValue, value <= 0.0, previousContentOffsetValue > 30.0 {
                            transition = .animated(duration: 0.2, curve: .easeInOut)
                        } else {
                            transition = .immediate
                        }
                        strongSelf.navigationBar?.updateBackgroundAlpha(min(30.0, value) / 30.0, transition: transition)
                    case .unknown, .none:
                        strongSelf.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
                }
                
                strongSelf.previousContentOffset = offset
            }
        }
    
        self._ready.set(self.controllerNode.ready.get())
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
