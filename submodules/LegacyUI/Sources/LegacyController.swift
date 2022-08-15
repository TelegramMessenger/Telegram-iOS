import Foundation
import UIKit
import Display
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import AttachmentUI

public enum LegacyControllerPresentation {
    case custom
    case modal(animateIn: Bool)
    case navigation
}

private func passControllerAppearanceAnimated(in: Bool, presentation: LegacyControllerPresentation) -> Bool {
    switch presentation {
        case let .modal(animateIn):
            if `in` {
                return animateIn
            } else {
                return true
            }
        default:
            return false
    }
}

private final class LegacyComponentsOverlayWindowManagerImpl: NSObject, LegacyComponentsOverlayWindowManager {
    private weak var contentController: UIViewController?
    private weak var parentController: ViewController?
    private var controller: LegacyController?
    private var boundController = false
    
    init(parentController: ViewController?, theme: PresentationTheme?) {
        self.parentController = parentController
        self.controller = LegacyController(presentation: .custom, theme: theme)
        
        super.init()
        
        if let parentController = parentController {
            if parentController.statusBar.statusBarStyle == .Hide {
                self.controller?.statusBar.statusBarStyle = parentController.statusBar.statusBarStyle
            }
            if parentController.view.disablesInteractiveTransitionGestureRecognizer {
                self.controller?.view.disablesInteractiveTransitionGestureRecognizer = true
            }
            self.controller?.view.frame = parentController.view.bounds
        }
    }
    
    func managesWindow() -> Bool {
        return true
    }
    
    func bindController(_ controller: UIViewController!) {
        self.contentController = controller
        if controller.prefersStatusBarHidden {
            self.controller?.statusBar.statusBarStyle = .Hide
        }
        
        controller.state_setNeedsStatusBarAppearanceUpdate({ [weak self, weak controller] in
            if let parentController = self?.parentController, let controller = controller {
                if parentController.statusBar.statusBarStyle != .Hide && !controller.prefersStatusBarHidden {
                    self?.controller?.statusBar.statusBarStyle = StatusBarStyle(systemStyle: controller.preferredStatusBarStyle)
                }
            }
        })
        if let parentController = self.parentController {
            if parentController.statusBar.statusBarStyle != .Hide && !controller.prefersStatusBarHidden {
                self.controller?.statusBar.statusBarStyle = StatusBarStyle(systemStyle: controller.preferredStatusBarStyle)
            }
        }
    }
    
    func context() -> LegacyComponentsContext! {
        return self.controller?.context
    }
    
    func setHidden(_ hidden: Bool, window: UIWindow!) {
        if hidden {
            self.controller?.dismiss()
            self.controller = nil
        } else if let contentController = self.contentController, let parentController = self.parentController, let controller = self.controller {
            if !self.boundController {
                controller.bind(controller: contentController)
                self.boundController = true
            }
            parentController.present(controller, in: .window(.root))
        }
    }
}

public final class LegacyControllerContext: NSObject, LegacyComponentsContext {
    public private(set) weak var controller: ViewController?
    private let theme: PresentationTheme?
    
    public init(controller: ViewController?, theme: PresentationTheme?) {
        self.controller = controller
        self.theme = theme
        
        super.init()
    }
    
    public func fullscreenBounds() -> CGRect {
        if let controller = self.controller {
            return controller.view.bounds
        } else {
            return CGRect()
        }
    }
    
    public func keyCommandController() -> TGKeyCommandController! {
        return nil
    }
    
    public func rootCallStatusBarHidden() -> Bool {
        return true
    }
    
    public func statusBarFrame() -> CGRect {
        return legacyComponentsApplication!.statusBarFrame
    }
    
    public func isStatusBarHidden() -> Bool {
        if let controller = self.controller {
            return controller.statusBar.isHidden || controller.navigationPresentation == .modal
        } else {
            return true
        }
    }
    
    public func setStatusBarHidden(_ hidden: Bool, with animation: UIStatusBarAnimation) {
        if let controller = self.controller {
            controller.statusBar.isHidden = hidden
            self.updateDeferScreenEdgeGestures()
        }
    }
    
    public func forceSetStatusBarHidden(_ hidden: Bool, with animation: UIStatusBarAnimation) {
        if let controller = self.controller {
            controller.statusBar.isHidden = hidden
        }
    }
    
    public func statusBarStyle() -> UIStatusBarStyle {
        if let controller = self.controller {
            switch controller.statusBar.statusBarStyle {
                case .Black:
                    return .default
                case .White:
                    return .lightContent
                default:
                    return .default
            }
        } else {
            return .default
        }
    }
    
    public func setStatusBarStyle(_ statusBarStyle: UIStatusBarStyle, animated: Bool) {
        if let controller = self.controller {
            switch statusBarStyle {
                case .default:
                    controller.statusBar.statusBarStyle = .Black
                case .lightContent:
                    controller.statusBar.statusBarStyle = .White
                default:
                    controller.statusBar.statusBarStyle = .Black
            }
        }
    }
    
    public func forceStatusBarAppearanceUpdate() {
    }
    
    public func currentlyInSplitView() -> Bool {
        if let controller = self.controller as? LegacyController, let validLayout = controller.validLayout {
            return validLayout.isNonExclusive
        }
        return false
    }
    
    public func currentSizeClass() -> UIUserInterfaceSizeClass {
        if let controller = self.controller as? LegacyController, let validLayout = controller.validLayout {
            if case .regular = validLayout.metrics.widthClass, case .regular = validLayout.metrics.heightClass {
                return .regular
            }
        }
        return .compact
    }
    
    public func currentHorizontalSizeClass() -> UIUserInterfaceSizeClass {
        if let controller = self.controller as? LegacyController, let validLayout = controller.validLayout {
            if case .regular = validLayout.metrics.widthClass {
                return .regular
            }
        }
        return .compact
    }
    
    public func currentVerticalSizeClass() -> UIUserInterfaceSizeClass {
        if let controller = self.controller as? LegacyController, let validLayout = controller.validLayout {
            if case .regular = validLayout.metrics.heightClass {
                return .regular
            }
        }
        return .compact
    }
    
    public func sizeClassSignal() -> SSignal! {
        if let controller = self.controller as? LegacyController, let validLayout = controller.validLayout {
            if case .regular = validLayout.metrics.heightClass {
                return SSignal.single(UIUserInterfaceSizeClass.regular.rawValue as NSNumber)
            }
        }
        if let controller = self.controller as? LegacyController, controller.enableSizeClassSignal {
            //return controller.sizeClassSignal
        }
        return SSignal.single(UIUserInterfaceSizeClass.compact.rawValue as NSNumber)
    }
    
    public func canOpen(_ url: URL!) -> Bool {
        return false
    }
    
    public func open(_ url: URL!) {
    }
    
    public func serverMediaData(forAssetUrl url: String!) -> [AnyHashable : Any]! {
        return nil
    }
    
    public func presentActionSheet(_ actions: [LegacyComponentsActionSheetAction]!, view: UIView!, completion: ((LegacyComponentsActionSheetAction?) -> Void)!) {
        
    }
    
    public func presentActionSheet(_ actions: [LegacyComponentsActionSheetAction]!, view: UIView!, sourceRect: (() -> CGRect)!, completion: ((LegacyComponentsActionSheetAction?) -> Void)!) {
        
    }
    
    public func makeOverlayWindowManager() -> LegacyComponentsOverlayWindowManager! {
        return LegacyComponentsOverlayWindowManagerImpl(parentController: self.controller, theme: self.theme)
    }
    
    public func applicationStatusBarAlpha() -> CGFloat {
        if let controller = self.controller {
            return controller.statusBar.alpha
        }
        return 0.0
    }
    
    public func setApplicationStatusBarAlpha(_ alpha: CGFloat) {
        if let controller = self.controller {
            controller.statusBar.updateAlpha(alpha, transition: .immediate)
            self.updateDeferScreenEdgeGestures()
        }
    }
    
    private func updateDeferScreenEdgeGestures() {
        if let controller = self.controller {
            if controller.statusBar.isHidden || controller.statusBar.alpha.isZero {
                controller.deferScreenEdgeGestures = [.top]
            } else {
                controller.deferScreenEdgeGestures = []
            }
        }
    }

    public func animateApplicationStatusBarAppearance(_ statusBarAnimation: Int32, delay: TimeInterval, duration: TimeInterval, completion: (() -> Void)!) {
        completion?()
    }
    
    public func animateApplicationStatusBarAppearance(_ statusBarAnimation: Int32, duration: TimeInterval, completion: (() -> Void)!) {
        self.animateApplicationStatusBarAppearance(statusBarAnimation, delay: 0.0, duration: duration, completion: completion)
    }
    
    public func animateApplicationStatusBarStyleTransition(withDuration duration: TimeInterval) {
    }
    
    public func safeAreaInset() -> UIEdgeInsets {
        if let controller = self.controller as? LegacyController, let validLayout = controller.validLayout {
            var safeInsets = validLayout.safeInsets
            if safeInsets.top.isEqual(to: 44.0) {
                safeInsets.bottom = 34.0
            }
            if validLayout.intrinsicInsets.bottom.isEqual(to: 21.0) {
                safeInsets.bottom = 21.0
            } else if validLayout.intrinsicInsets.bottom.isEqual(to: 34.0) {
                safeInsets.bottom = 34.0
            } else {
                if let knownSafeInset = validLayout.deviceMetrics.onScreenNavigationHeight(inLandscape: validLayout.size.width > validLayout.size.height, systemOnScreenNavigationHeight: nil) {
                    if knownSafeInset > 0.0 {
                        safeInsets.bottom = knownSafeInset
                    }
                }
            }
            if controller.navigationPresentation == .modal {
                safeInsets.top = 0.0
            }
            return safeInsets
        }
        return UIEdgeInsets()
    }
    
    public func prefersLightStatusBar() -> Bool {
        if let controller = self.controller {
            switch controller.statusBar.statusBarStyle {
                case .Black:
                    return false
                case .White:
                    return true
                default:
                    return false
            }
        } else {
            return false
        }
    }
    
    public func navigationBarPallete() -> TGNavigationBarPallete! {
        let presentationTheme: PresentationTheme
        if let theme = self.theme {
            presentationTheme = theme
        } else {
            presentationTheme = defaultPresentationTheme
        }
        let theme = presentationTheme
        let barTheme = theme.rootController.navigationBar
        return TGNavigationBarPallete(backgroundColor: barTheme.opaqueBackgroundColor, separatorColor: barTheme.separatorColor, titleColor: barTheme.primaryTextColor, tintColor: barTheme.accentTextColor)
    }
    
    public func menuSheetPallete() -> TGMenuSheetPallete! {
        let presentationTheme: PresentationTheme
        if let theme = self.theme {
            presentationTheme = theme
        } else {
            presentationTheme = defaultPresentationTheme
        }
        let theme = presentationTheme
        let sheetTheme = theme.actionSheet
        
        return TGMenuSheetPallete(dark: theme.overallDarkAppearance, backgroundColor: sheetTheme.opaqueItemBackgroundColor, selectionColor: sheetTheme.opaqueItemHighlightedBackgroundColor, separatorColor: sheetTheme.opaqueItemSeparatorColor, accentColor: sheetTheme.controlAccentColor, destructiveColor: sheetTheme.destructiveActionTextColor, textColor: sheetTheme.primaryTextColor, secondaryTextColor: sheetTheme.secondaryTextColor, spinnerColor: sheetTheme.secondaryTextColor, badgeTextColor: sheetTheme.controlAccentColor, badgeImage: nil, cornersImage: generateStretchableFilledCircleImage(diameter: 11.0, color: nil, strokeColor: nil, strokeWidth: nil, backgroundColor: sheetTheme.opaqueItemBackgroundColor))
    }
    
    public func darkMenuSheetPallete() -> TGMenuSheetPallete! {
        let presentationTheme: PresentationTheme
        if let theme = self.theme {
            presentationTheme = theme
        } else {
            presentationTheme = defaultPresentationTheme
        }
        let theme = presentationTheme
        let sheetTheme = theme.actionSheet
        return TGMenuSheetPallete(dark: theme.overallDarkAppearance, backgroundColor: sheetTheme.opaqueItemBackgroundColor, selectionColor: sheetTheme.opaqueItemHighlightedBackgroundColor, separatorColor: sheetTheme.opaqueItemSeparatorColor, accentColor: sheetTheme.controlAccentColor, destructiveColor: sheetTheme.destructiveActionTextColor, textColor: sheetTheme.primaryTextColor, secondaryTextColor: sheetTheme.secondaryTextColor, spinnerColor: sheetTheme.secondaryTextColor, badgeTextColor: sheetTheme.controlAccentColor, badgeImage: nil, cornersImage: generateStretchableFilledCircleImage(diameter: 11.0, color: nil, strokeColor: nil, strokeWidth: nil, backgroundColor: sheetTheme.opaqueItemBackgroundColor))
    }
    
    public func mediaAssetsPallete() -> TGMediaAssetsPallete! {
        let presentationTheme: PresentationTheme
        if let theme = self.theme {
            presentationTheme = theme
        } else {
            presentationTheme = defaultPresentationTheme
        }
        
        let theme = presentationTheme.list
        let navigationBar = presentationTheme.rootController.navigationBar
        let tabBar = presentationTheme.rootController.tabBar
        
        return TGMediaAssetsPallete(dark: presentationTheme.overallDarkAppearance, backgroundColor: theme.plainBackgroundColor, selectionColor: theme.itemHighlightedBackgroundColor, separatorColor: theme.itemPlainSeparatorColor, textColor: theme.itemPrimaryTextColor, secondaryTextColor: theme.controlSecondaryColor, accentColor: theme.itemAccentColor, destructiveColor: theme.itemDestructiveColor, barBackgroundColor: navigationBar.opaqueBackgroundColor, barSeparatorColor: tabBar.separatorColor, navigationTitleColor: navigationBar.primaryTextColor, badge: generateStretchableFilledCircleImage(diameter: 22.0, color: navigationBar.accentTextColor), badgeTextColor: navigationBar.opaqueBackgroundColor, sendIconImage: PresentationResourcesChat.chatInputPanelSendButtonImage(presentationTheme), doneIconImage: PresentationResourcesChat.chatInputPanelApplyButtonImage(presentationTheme), maybeAccentColor: navigationBar.accentTextColor)
    }
    
    public func checkButtonPallete() -> TGCheckButtonPallete! {
        let presentationTheme: PresentationTheme
        if let theme = self.theme {
            presentationTheme = theme
        } else {
            presentationTheme = defaultPresentationTheme
        }
        
        let theme = presentationTheme
        return TGCheckButtonPallete(defaultBackgroundColor: theme.chat.message.selectionControlColors.fillColor, accentBackgroundColor: theme.chat.message.selectionControlColors.fillColor, defaultBorderColor: theme.chat.message.selectionControlColors.strokeColor, mediaBorderColor: theme.chat.message.selectionControlColors.strokeColor, chatBorderColor: theme.chat.message.selectionControlColors.strokeColor, check: theme.chat.message.selectionControlColors.foregroundColor, blueColor: theme.chat.message.selectionControlColors.fillColor, barBackgroundColor: theme.chat.message.selectionControlColors.fillColor)
    }
}

open class LegacyController: ViewController, PresentableController, AttachmentContainable {
    public private(set) var legacyController: UIViewController!
    private let presentation: LegacyControllerPresentation
    
    private var controllerNode: LegacyControllerNode {
        return self.displayNode as! LegacyControllerNode
    }
    
    private var contextImpl: LegacyControllerContext!
    public var context: LegacyComponentsContext {
        return self.contextImpl!
    }
    
    fileprivate var validLayout: ContainerViewLayout?
    
    public var parentInsets: UIEdgeInsets = UIEdgeInsets()
    
    public var controllerLoaded: (() -> Void)?
    public var presentationCompleted: (() -> Void)?
    
    private let sizeClass: SVariable = SVariable()
    public var enableSizeClassSignal: Bool = false
    public var sizeClassSignal: SSignal {
        return self.sizeClass.signal()
    }
    private var enableContainerLayoutUpdates = false
    
    public var disposables = DisposableSet()
    
    open var requestAttachmentMenuExpansion: () -> Void = {}
    open var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    open var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    open var cancelPanGesture: () -> Void = { }
    open var isContainerPanning: () -> Bool = { return false }
    open var isContainerExpanded: () -> Bool = { return false }
    
    public init(presentation: LegacyControllerPresentation, theme: PresentationTheme? = nil, strings: PresentationStrings? = nil, initialLayout: ContainerViewLayout? = nil) {
        self.sizeClass.set(SSignal.single(UIUserInterfaceSizeClass.compact.rawValue as NSNumber))
        self.presentation = presentation
        self.validLayout = initialLayout
        
        let navigationBarPresentationData: NavigationBarPresentationData?
        if let theme = theme, let strings = strings, case .navigation = presentation {
            navigationBarPresentationData = NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: theme), strings: NavigationBarStrings(presentationStrings: strings))
        } else {
            navigationBarPresentationData = nil
        }
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        if let theme = theme {
            self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        }
        
        let contextImpl = LegacyControllerContext(controller: self, theme: theme)
        self.contextImpl = contextImpl
    }
    
    deinit {
        self.disposables.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func bind(controller: UIViewController) {
        self.legacyController = controller
        if let controller = controller as? TGViewController {
            controller.customRemoveFromParentViewController = { [weak self] in
                self?.dismiss()
            }
        }
    }
    
    override open func loadDisplayNode() {
        self.displayNode = LegacyControllerNode()
        self.displayNodeDidLoad()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        if self.controllerNode.controllerView == nil {
            if self.controllerNode.frame.width == 0.0, let layout = self.validLayout {
                self.controllerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width - self.parentInsets.left - self.parentInsets.right, height: layout.size.height))
            }
            
            self.controllerNode.controllerView = self.legacyController.view
            if let legacyController = self.legacyController as? TGViewController {
                legacyController.ignoreAppearEvents = true
            }
            self.controllerNode.view.insertSubview(self.legacyController.view, at: 0)
            if let legacyController = self.legacyController as? TGViewController {
                legacyController.ignoreAppearEvents = false
            }
            
            if let controllerLoaded = self.controllerLoaded {
                controllerLoaded()
            }
        }
        
        self.legacyController.viewWillAppear(animated && passControllerAppearanceAnimated(in: true, presentation: self.presentation))
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        self.legacyController.viewWillDisappear(animated && passControllerAppearanceAnimated(in: false, presentation: self.presentation))
    }
    
    private var viewDidAppearProcessed = false
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.enableContainerLayoutUpdates = true
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        self.viewDidAppear(animated: animated, completion: {})
    }
    
    public func viewDidAppear(completion: @escaping () -> Void) {
        self.viewDidAppear(animated: false, completion: completion)
    }
    
    private func viewDidAppear(animated: Bool, completion: @escaping () -> Void) {
        if self.viewDidAppearProcessed {
            completion()
            return
        }
        self.viewDidAppearProcessed = true
        switch self.presentation {
            case let .modal(animateIn):
                if animateIn {
                    self.controllerNode.animateModalIn(completion: { [weak self] in
                        self?.presentationCompleted?()
                        completion()
                    })
                } else {
                    self.presentationCompleted?()
                    completion()
                }
                self.legacyController.viewDidAppear(animated && animateIn)
            case .custom, .navigation:
                self.legacyController.viewDidAppear(animated)
                self.presentationCompleted?()
                completion()
        }
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.viewDidAppearProcessed = false
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        self.legacyController.viewDidDisappear(animated && passControllerAppearanceAnimated(in: false, presentation: self.presentation))
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let previousSizeClass: UIUserInterfaceSizeClass
        if let validLayout = self.validLayout, case .regular = validLayout.metrics.widthClass {
            previousSizeClass = .regular
        } else {
            previousSizeClass = .compact
        }
        self.validLayout = layout
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        if let legacyTelegramController = self.legacyController as? TGViewController {
            var duration: TimeInterval = 0.0
            if case let .animated(transitionDuration, _) = transition {
                duration = transitionDuration
            }
            
            var orientation = UIInterfaceOrientation.portrait
            if layout.size.width > layout.size.height {
                orientation = .landscapeRight
            }
            
            let size = CGSize(width: layout.size.width - layout.intrinsicInsets.left - layout.intrinsicInsets.right, height: layout.size.height)
            
            legacyTelegramController.intrinsicSize = size
            legacyTelegramController._updateInset(for: orientation, force: false, notify: true)
            if self.enableContainerLayoutUpdates {
                legacyTelegramController.layoutController(for: size, duration: duration)
            }
        }
        let updatedSizeClass: UIUserInterfaceSizeClass
        if case .regular = layout.metrics.widthClass {
            updatedSizeClass = .regular
        } else {
            updatedSizeClass = .compact
        }
        if previousSizeClass != updatedSizeClass {
            self.sizeClass.set(SSignal.single(updatedSizeClass.rawValue as NSNumber))
        }
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        switch self.presentation {
            case .modal:
                self.controllerNode.animateModalOut { [weak self] in
                    self?.presentingViewController?.dismiss(animated: false, completion: completion)
                }
            case .custom:
                self.presentingViewController?.dismiss(animated: false, completion: completion)
            case .navigation:
                (self.navigationController as? NavigationController)?.filterController(self, animated: true)
        }
    }
    
    public func dismissWithAnimation() {
        self.controllerNode.animateModalOut { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
    }
}
