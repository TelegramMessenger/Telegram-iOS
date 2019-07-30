import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

final class ThemePreviewController: ViewController {
    private let context: AccountContext
    private let previewTheme: PresentationTheme
    private let media: AnyMediaReference
    
    private var controllerNode: ThemePreviewControllerNode {
        return self.displayNode as! ThemePreviewControllerNode
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    init(context: AccountContext, previewTheme: PresentationTheme, media: AnyMediaReference) {
        self.context = context
        self.previewTheme = previewTheme
        self.media = media
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.previewTheme, presentationStrings: self.presentationData.strings))
        
        if let author = previewTheme.author {
            let titleView = CounterContollerTitleView(theme: self.previewTheme)
            titleView.title = CounterContollerTitle(title: self.previewTheme.name.string, counter: author)
            self.navigationItem.titleView = titleView
        } else {
            self.title = previewTheme.name.string
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
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
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
        
        self.displayNode = ThemePreviewControllerNode(context: self.context, previewTheme: self.previewTheme, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] in
            if let strongSelf = self {
                let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> Void in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
                        let current: PresentationThemeSettings
                        if let entry = entry as? PresentationThemeSettings {
                            current = entry
                        } else {
                            current = PresentationThemeSettings.defaultSettings
                        }
                        
                        return PresentationThemeSettings(chatWallpaper: .color(0xffffff), theme: .builtin(.day), themeSpecificAccentColors: current.themeSpecificAccentColors, themeSpecificChatWallpapers: current.themeSpecificChatWallpapers, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, largeEmoji: current.largeEmoji, disableAnimations: current.disableAnimations)
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
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }

    @objc private func actionPressed() {
        let controller = ShareController(context: self.context, subject: .media(self.media))
        self.present(controller, in: .window(.root), blockInteraction: true)
    }
}
