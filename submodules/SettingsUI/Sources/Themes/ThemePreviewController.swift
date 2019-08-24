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

public enum ThemePreviewSource {
    case theme(TelegramTheme)
    case media(AnyMediaReference)
}

public final class ThemePreviewController: ViewController {
    private let context: AccountContext
    private let previewTheme: PresentationTheme
    private let source: ThemePreviewSource
    
    private var controllerNode: ThemePreviewControllerNode {
        return self.displayNode as! ThemePreviewControllerNode
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    public init(context: AccountContext, previewTheme: PresentationTheme, source: ThemePreviewSource) {
        self.context = context
        self.previewTheme = previewTheme
        self.source = source
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.previewTheme, presentationStrings: self.presentationData.strings))
        
        let themeName: String
        if case let .theme(theme) = source {
            themeName = theme.title
        } else {
            themeName = previewTheme.name.string
        }
        
        if let author = previewTheme.author {
            let titleView = CounterContollerTitleView(theme: self.previewTheme)
            titleView.title = CounterContollerTitle(title: themeName, counter: author)
            self.navigationItem.titleView = titleView
        } else {
            self.title = themeName
        }
        self.statusBar.statusBarStyle = self.previewTheme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: self.previewTheme.rootController.navigationBar.accentTextColor), style: .plain, target: self, action: #selector(self.actionPressed))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.updateStrings()
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
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
                let theme: PresentationThemeReference
                if case let .theme(info) = strongSelf.source {
                    theme = .cloud(info)
                } else {
                    theme = .builtin(.day)
                }
                
                let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> Void in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
                        let current: PresentationThemeSettings
                        if let entry = entry as? PresentationThemeSettings {
                            current = entry
                        } else {
                            current = PresentationThemeSettings.defaultSettings
                        }
                        
                        return PresentationThemeSettings(chatWallpaper: .color(0xffffff), theme: theme, themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
                    })
                }).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.dismiss()
                    }
                })
            }
        })
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
            case let .media(media):
                subject = .media(media)
                preferredAction = .custom(action: ShareControllerAction(title: "Publish", action: { [weak self] in
                    if let strongSelf = self, let file = media.media as? TelegramMediaFile {
                        let controller = createThemeController(context: strongSelf.context, theme: strongSelf.previewTheme, resource: file.resource)
                        strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet), blockInteraction: true)
                    }
                }))
        }
        let controller = ShareController(context: self.context, subject: subject, preferredAction: preferredAction)
        self.present(controller, in: .window(.root), blockInteraction: true)
    }
}
