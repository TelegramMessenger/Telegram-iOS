import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private struct WindowLayout: Equatable {
    let size: CGSize
    let metrics: LayoutMetrics
    let statusBarHeight: CGFloat?
    let forceInCallStatusBarText: String?
    let inputHeight: CGFloat?
    let safeInsets: UIEdgeInsets
    let onScreenNavigationHeight: CGFloat?
    let upperKeyboardInputPositionBound: CGFloat?
    let inVoiceOver: Bool
}

private struct UpdatingLayout {
    var layout: WindowLayout
    var transition: ContainedViewLayoutTransition
    
    mutating func update(transition: ContainedViewLayoutTransition, override: Bool) {
        var update = false
        if case .immediate = self.transition {
            update = true
        } else if override {
            update = true
        }
        if update {
            self.transition = transition
        }
    }
    
    mutating func update(size: CGSize, metrics: LayoutMetrics, safeInsets: UIEdgeInsets, forceInCallStatusBarText: String?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: size, metrics: metrics, statusBarHeight: self.layout.statusBarHeight, forceInCallStatusBarText: forceInCallStatusBarText, inputHeight: self.layout.inputHeight, safeInsets: safeInsets, onScreenNavigationHeight: self.layout.onScreenNavigationHeight, upperKeyboardInputPositionBound: self.layout.upperKeyboardInputPositionBound, inVoiceOver: self.layout.inVoiceOver)
    }
    
    
    mutating func update(forceInCallStatusBarText: String?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, metrics: self.layout.metrics, statusBarHeight: self.layout.statusBarHeight, forceInCallStatusBarText: forceInCallStatusBarText, inputHeight: self.layout.inputHeight, safeInsets: self.layout.safeInsets, onScreenNavigationHeight: self.layout.onScreenNavigationHeight, upperKeyboardInputPositionBound: self.layout.upperKeyboardInputPositionBound, inVoiceOver: self.layout.inVoiceOver)
    }
    
    mutating func update(statusBarHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, metrics: self.layout.metrics, statusBarHeight: statusBarHeight, forceInCallStatusBarText: self.layout.forceInCallStatusBarText, inputHeight: self.layout.inputHeight, safeInsets: self.layout.safeInsets, onScreenNavigationHeight: self.layout.onScreenNavigationHeight, upperKeyboardInputPositionBound: self.layout.upperKeyboardInputPositionBound, inVoiceOver: self.layout.inVoiceOver)
    }
    
    mutating func update(inputHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, metrics: self.layout.metrics, statusBarHeight: self.layout.statusBarHeight, forceInCallStatusBarText: self.layout.forceInCallStatusBarText, inputHeight: inputHeight, safeInsets: self.layout.safeInsets, onScreenNavigationHeight: self.layout.onScreenNavigationHeight, upperKeyboardInputPositionBound: self.layout.upperKeyboardInputPositionBound, inVoiceOver: self.layout.inVoiceOver)
    }
    
    mutating func update(safeInsets: UIEdgeInsets, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, metrics: self.layout.metrics, statusBarHeight: self.layout.statusBarHeight, forceInCallStatusBarText: self.layout.forceInCallStatusBarText, inputHeight: self.layout.inputHeight, safeInsets: safeInsets, onScreenNavigationHeight: self.layout.onScreenNavigationHeight, upperKeyboardInputPositionBound: self.layout.upperKeyboardInputPositionBound, inVoiceOver: self.layout.inVoiceOver)
    }
    
    mutating func update(onScreenNavigationHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, metrics: self.layout.metrics, statusBarHeight: self.layout.statusBarHeight, forceInCallStatusBarText: self.layout.forceInCallStatusBarText, inputHeight: self.layout.inputHeight, safeInsets: self.layout.safeInsets, onScreenNavigationHeight: onScreenNavigationHeight, upperKeyboardInputPositionBound: self.layout.upperKeyboardInputPositionBound, inVoiceOver: self.layout.inVoiceOver)
    }
    
    mutating func update(upperKeyboardInputPositionBound: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, metrics: self.layout.metrics, statusBarHeight: self.layout.statusBarHeight, forceInCallStatusBarText: self.layout.forceInCallStatusBarText, inputHeight: self.layout.inputHeight, safeInsets: self.layout.safeInsets, onScreenNavigationHeight: self.layout.onScreenNavigationHeight, upperKeyboardInputPositionBound: upperKeyboardInputPositionBound, inVoiceOver: self.layout.inVoiceOver)
    }
    
    mutating func update(inVoiceOver: Bool) {
        self.update(transition: transition, override: false)
        
        self.layout = WindowLayout(size: self.layout.size, metrics: self.layout.metrics, statusBarHeight: self.layout.statusBarHeight, forceInCallStatusBarText: self.layout.forceInCallStatusBarText, inputHeight: self.layout.inputHeight, safeInsets: self.layout.safeInsets, onScreenNavigationHeight: self.layout.onScreenNavigationHeight, upperKeyboardInputPositionBound: self.layout.upperKeyboardInputPositionBound, inVoiceOver: inVoiceOver)
    }
}

private let defaultStatusBarHeight: CGFloat = 20.0
private let statusBarHiddenInLandscape: Bool = UIDevice.current.userInterfaceIdiom == .phone

private func inputHeightOffsetForLayout(_ layout: WindowLayout) -> CGFloat {
    if let inputHeight = layout.inputHeight, let upperBound = layout.upperKeyboardInputPositionBound {
        return max(0.0, upperBound - (layout.size.height - inputHeight))
    }
    return 0.0
}

private func containedLayoutForWindowLayout(_ layout: WindowLayout, deviceMetrics: DeviceMetrics) -> ContainerViewLayout {
    let resolvedStatusBarHeight: CGFloat?
    if let statusBarHeight = layout.statusBarHeight {
        if layout.forceInCallStatusBarText != nil {
            resolvedStatusBarHeight = max(40.0, layout.safeInsets.top)
        } else {
            resolvedStatusBarHeight = statusBarHeight
        }
    } else {
        resolvedStatusBarHeight = nil
    }
    
    var updatedInputHeight = layout.inputHeight
    if let inputHeight = updatedInputHeight, let _ = layout.upperKeyboardInputPositionBound {
        updatedInputHeight = inputHeight - inputHeightOffsetForLayout(layout)
    }
    
    let isLandscape = layout.size.width > layout.size.height
    var resolvedSafeInsets = layout.safeInsets
    if layout.safeInsets.left.isZero {
        resolvedSafeInsets = deviceMetrics.safeInsets(inLandscape: isLandscape)
    }
    
    return ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.onScreenNavigationHeight ?? 0.0, right: 0.0), safeInsets: resolvedSafeInsets, additionalInsets: UIEdgeInsets(), statusBarHeight: resolvedStatusBarHeight, inputHeight: updatedInputHeight, inputHeightIsInteractivellyChanging: layout.upperKeyboardInputPositionBound != nil && layout.upperKeyboardInputPositionBound != layout.size.height && layout.inputHeight != nil, inVoiceOver: layout.inVoiceOver)
}

public func doesViewTreeDisableInteractiveTransitionGestureRecognizer(_ view: UIView, keyboardOnly: Bool = false) -> Bool {
    if view.disablesInteractiveTransitionGestureRecognizer && !keyboardOnly {
        return true
    }
    if view.disablesInteractiveKeyboardGestureRecognizer {
        return true
    }
    if let f = view.disablesInteractiveTransitionGestureRecognizerNow, f() {
        return true
    }
    if let superview = view.superview {
        return doesViewTreeDisableInteractiveTransitionGestureRecognizer(superview, keyboardOnly: keyboardOnly)
    }
    return false
}

public func getFirstResponderAndAccessoryHeight(_ view: UIView, _ accessoryHeight: CGFloat? = nil) -> (UIView?, CGFloat?) {
    if view.isFirstResponder {
        return (view, accessoryHeight)
    } else {
        var updatedAccessoryHeight = accessoryHeight
        if let view = view as? WindowInputAccessoryHeightProvider {
            updatedAccessoryHeight = view.getWindowInputAccessoryHeight()
        }
        for subview in view.subviews {
            let (result, resultHeight) = getFirstResponderAndAccessoryHeight(subview, updatedAccessoryHeight)
            if let result = result {
                return (result, resultHeight)
            }
        }
        return (nil, nil)
    }
}

public final class WindowHostView {
    public let containerView: UIView
    public let eventView: UIView
    public let isRotating: () -> Bool
    public let systemUserInterfaceStyle: Signal<WindowUserInterfaceStyle, NoError>
    
    let updateSupportedInterfaceOrientations: (UIInterfaceOrientationMask) -> Void
    let updateDeferScreenEdgeGestures: (UIRectEdge) -> Void
    let updatePrefersOnScreenNavigationHidden: (Bool) -> Void
    
    var present: ((ContainableController, PresentationSurfaceLevel, Bool, @escaping () -> Void) -> Void)?
    var presentInGlobalOverlay: ((_ controller: ContainableController) -> Void)?
    var addGlobalPortalHostViewImpl: ((PortalSourceView) -> Void)?
    var presentNative: ((UIViewController) -> Void)?
    var nativeController: (() -> UIViewController?)?
    var updateSize: ((CGSize, Double) -> Void)?
    var layoutSubviews: (() -> Void)?
    var updateToInterfaceOrientation: ((UIInterfaceOrientation) -> Void)?
    var isUpdatingOrientationLayout = false
    var hitTest: ((CGPoint, UIEvent?) -> UIView?)?
    var invalidateDeferScreenEdgeGesture: (() -> Void)?
    var invalidatePrefersOnScreenNavigationHidden: (() -> Void)?
    var invalidateSupportedOrientations: (() -> Void)?
    var cancelInteractiveKeyboardGestures: (() -> Void)?
    var forEachController: (((ContainableController) -> Void) -> Void)?
    var getAccessibilityElements: (() -> [Any]?)?
    
    init(containerView: UIView, eventView: UIView, isRotating: @escaping () -> Bool, systemUserInterfaceStyle:  Signal<WindowUserInterfaceStyle, NoError>, updateSupportedInterfaceOrientations: @escaping (UIInterfaceOrientationMask) -> Void, updateDeferScreenEdgeGestures: @escaping (UIRectEdge) -> Void, updatePrefersOnScreenNavigationHidden: @escaping (Bool) -> Void) {
        self.containerView = containerView
        self.eventView = eventView
        self.isRotating = isRotating
        self.systemUserInterfaceStyle = systemUserInterfaceStyle
        self.updateSupportedInterfaceOrientations = updateSupportedInterfaceOrientations
        self.updateDeferScreenEdgeGestures = updateDeferScreenEdgeGestures
        self.updatePrefersOnScreenNavigationHidden = updatePrefersOnScreenNavigationHidden
    }
    
    fileprivate var onScreenNavigationHeight: CGFloat? {
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            return self.eventView.safeAreaInsets.bottom.isLessThanOrEqualTo(0.0) ? nil : self.eventView.safeAreaInsets.bottom
        } else {
            return nil
        }
    }
}

public protocol WindowHost {
    func forEachController(_ f: (ContainableController) -> Void)
    func present(_ controller: ContainableController, on level: PresentationSurfaceLevel, blockInteraction: Bool, completion: @escaping () -> Void)
    func presentInGlobalOverlay(_ controller: ContainableController)
    func addGlobalPortalHostView(sourceView: PortalSourceView)
    func invalidateDeferScreenEdgeGestures()
    func invalidatePrefersOnScreenNavigationHidden()
    func invalidateSupportedOrientations()
    func cancelInteractiveKeyboardGestures()
}

public extension UIView {
    var windowHost: WindowHost? {
        if let window = self.window as? WindowHost {
            return window
        } else if let result = findWindow(self) {
            return result
        } else {
            return nil
        }
    }
}

private func layoutMetricsForScreenSize(_ size: CGSize) -> LayoutMetrics {
    if size.width > 690.0 && size.height > 690.0 {
        return LayoutMetrics(widthClass: .regular, heightClass: .regular)
    } else {
        return LayoutMetrics(widthClass: .compact, heightClass: .compact)
    }
}

public final class WindowKeyboardGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

public class Window1 {
    public let hostView: WindowHostView
    
    private var deviceMetrics: DeviceMetrics
    
    public let statusBarHost: StatusBarHost?
    private let keyboardManager: KeyboardManager?
    private let keyboardViewManager: KeyboardViewManager?
    private var statusBarChangeObserver: AnyObject?
    private var keyboardRotationChangeObserver: AnyObject?
    private var keyboardFrameChangeObserver: AnyObject?
    private var keyboardTypeChangeObserver: AnyObject?
    private var voiceOverStatusObserver: AnyObject?
    
    private var windowLayout: WindowLayout
    private var updatingLayout: UpdatingLayout?
    private var updatedContainerLayout: ContainerViewLayout?
    private var upperKeyboardInputPositionBound: CGFloat?
    private var cachedWindowSubviewCount: Int = 0
    private var cachedHasPreview: Bool = false
    
    private let presentationContext: PresentationContext
    private let overlayPresentationContext: GlobalOverlayPresentationContext
    private let topPresentationContext: PresentationContext
    
    private var tracingStatusBarsInvalidated = false
    private var shouldUpdateDeferScreenEdgeGestures = false
    private var shouldInvalidatePrefersOnScreenNavigationHidden = false
    private var shouldInvalidateSupportedOrientations = false
    
    private var statusBarHidden = false
    
    public var previewThemeAccentColor: UIColor = .blue
    public var previewThemeDarkBlur: Bool = false
    
    private var shouldNotAnimateLikelyKeyboardAutocorrectionSwitch: Bool = false
    
    public private(set) var forceInCallStatusBarText: String? = nil
    public var inCallNavigate: (() -> Void)?

    private var debugTapCounter: (Double, Int) = (0.0, 0)
    private var debugTapRecognizer: UITapGestureRecognizer?
    public var debugAction: (() -> Void)? {
        didSet {
            if self.debugAction != nil {
                if self.debugTapRecognizer == nil {
                    let debugTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.debugTapGesture(_:)))
                    self.debugTapRecognizer = debugTapRecognizer
                    self.hostView.containerView.addGestureRecognizer(debugTapRecognizer)
                }
            } else if let debugTapRecognizer = self.debugTapRecognizer {
                self.debugTapRecognizer = nil
                self.hostView.containerView.removeGestureRecognizer(debugTapRecognizer)
            }
        }
    }
    @objc private func debugTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let timestamp = CACurrentMediaTime()
            if self.debugTapCounter.0 < timestamp - 0.4 {
                self.debugTapCounter.0 = timestamp
                self.debugTapCounter.1 = 0
            }

            if self.debugTapCounter.0 >= timestamp - 0.4 {
                self.debugTapCounter.0 = timestamp
                self.debugTapCounter.1 += 1
            }

            if self.debugTapCounter.1 >= 10 {
                self.debugTapCounter.1 = 0

                self.debugAction?()
            }
        }
    }
    
    public let systemUserInterfaceStyle: Signal<WindowUserInterfaceStyle, NoError>
    
    private var windowPanRecognizer: WindowPanRecognizer?
    private let keyboardGestureRecognizerDelegate = WindowKeyboardGestureRecognizerDelegate()
    private var keyboardGestureBeginLocation: CGPoint?
    private var keyboardGestureAccessoryHeight: CGFloat?
    
    private var keyboardTypeChangeTimer: SwiftSignalKit.Timer?
    
    private var isInteractionBlocked = false
    
    public init(hostView: WindowHostView, statusBarHost: StatusBarHost?) {
        self.hostView = hostView
        self.systemUserInterfaceStyle = hostView.systemUserInterfaceStyle
        
        let boundsSize = self.hostView.eventView.bounds.size
        self.deviceMetrics = DeviceMetrics(screenSize: UIScreen.main.bounds.size, scale: UIScreen.main.scale, statusBarHeight: statusBarHost?.statusBarFrame.height ?? 0.0, onScreenNavigationHeight: self.hostView.onScreenNavigationHeight)
        
        self.statusBarHost = statusBarHost
        let statusBarHeight: CGFloat
        if let statusBarHost = statusBarHost {
            statusBarHeight = statusBarHost.statusBarFrame.size.height
            self.keyboardManager = KeyboardManager(host: statusBarHost)
            self.keyboardViewManager = KeyboardViewManager(host: statusBarHost)
        } else {
            statusBarHeight = 0.0
            self.keyboardManager = nil
            self.keyboardViewManager = nil
        }
        
        let isLandscape =  boundsSize.width > boundsSize.height
        let safeInsets = self.deviceMetrics.safeInsets(inLandscape: isLandscape)
        let onScreenNavigationHeight = self.deviceMetrics.onScreenNavigationHeight(inLandscape: isLandscape, systemOnScreenNavigationHeight: self.hostView.onScreenNavigationHeight)
        
        self.windowLayout = WindowLayout(size: boundsSize, metrics: layoutMetricsForScreenSize(boundsSize), statusBarHeight: statusBarHeight, forceInCallStatusBarText: self.forceInCallStatusBarText, inputHeight: 0.0, safeInsets: safeInsets, onScreenNavigationHeight: onScreenNavigationHeight, upperKeyboardInputPositionBound: nil, inVoiceOver: UIAccessibility.isVoiceOverRunning)
        self.updatingLayout = UpdatingLayout(layout: self.windowLayout, transition: .immediate)
        self.presentationContext = PresentationContext()
        self.overlayPresentationContext = GlobalOverlayPresentationContext(statusBarHost: statusBarHost, parentView: self.hostView.containerView)
        self.topPresentationContext = PresentationContext()
        
        self.presentationContext.topLevelSubview = { [weak self] in
            guard let strongSelf = self else {
                return nil
            }
            if let first = strongSelf.topPresentationContext.controllers.first {
                return first.0.displayNode.view
            }
            if let first = strongSelf._topLevelOverlayControllers.first {
                return first.view
            }
            return nil
        }
        
        self.presentationContext.updateIsInteractionBlocked = { [weak self] value in
            self?.isInteractionBlocked = value
        }
        
        let updateOpaqueOverlays: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf._rootController?.displayNode.accessibilityElementsHidden = strongSelf.presentationContext.hasOpaqueOverlay || strongSelf.topPresentationContext.hasOpaqueOverlay
        }
        self.presentationContext.updateHasOpaqueOverlay = { value in
            updateOpaqueOverlays()
        }
        self.topPresentationContext.updateHasOpaqueOverlay = { value in
            updateOpaqueOverlays()
        }
        
        self.hostView.present = { [weak self] controller, level, blockInteraction, completion in
            self?.present(controller, on: level, blockInteraction: blockInteraction, completion: completion)
        }
        
        self.hostView.presentInGlobalOverlay = { [weak self] controller in
            self?.presentInGlobalOverlay(controller)
        }
        
        self.hostView.addGlobalPortalHostViewImpl = { [weak self] sourceView in
            self?.addGlobalPortalHostView(sourceView: sourceView)
        }
        
        self.hostView.presentNative = { [weak self] controller in
            self?.presentNative(controller)
        }
        
        self.hostView.updateSize = { [weak self] size, duration in
            self?.updateSize(size, duration: duration)
        }
        
        self.hostView.layoutSubviews = { [weak self] in
            self?.layoutSubviews(force: false)
        }
        
        self.hostView.updateToInterfaceOrientation = { [weak self] orientation in
            self?.updateToInterfaceOrientation(orientation)
        }
        
        self.hostView.hitTest = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
        
        self.hostView.invalidateDeferScreenEdgeGesture = { [weak self] in
            self?.invalidateDeferScreenEdgeGestures()
        }
        
        self.hostView.invalidatePrefersOnScreenNavigationHidden = { [weak self] in
            self?.invalidatePrefersOnScreenNavigationHidden()
        }
        
        self.hostView.invalidateSupportedOrientations = { [weak self] in
            self?.invalidateSupportedOrientations()
        }
        
        self.hostView.cancelInteractiveKeyboardGestures = { [weak self] in
            self?.cancelInteractiveKeyboardGestures()
        }
        
        self.hostView.forEachController = { [weak self] f in
            self?.forEachViewController({ controller in
                f(controller)
                return true
            })
        }
        
        self.presentationContext.view = self.hostView.containerView
        self.topPresentationContext.view = self.hostView.containerView
        self.presentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout, deviceMetrics: self.deviceMetrics), transition: .immediate)
        self.topPresentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout, deviceMetrics: self.deviceMetrics), transition: .immediate)
        self.overlayPresentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout, deviceMetrics: self.deviceMetrics), transition: .immediate)
        
        self.statusBarChangeObserver = NotificationCenter.default.addObserver(forName: UIApplication.willChangeStatusBarFrameNotification, object: nil, queue: OperationQueue.main, using: { [weak self] notification in
            if let strongSelf = self, strongSelf.statusBarHost != nil {
                let statusBarHeight: CGFloat = max(defaultStatusBarHeight, (notification.userInfo?[UIApplication.statusBarFrameUserInfoKey] as? NSValue)?.cgRectValue.height ?? defaultStatusBarHeight)
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
                strongSelf.updateLayout { $0.update(statusBarHeight: statusBarHeight, transition: transition, overrideTransition: false) }
            }
        })
        self.keyboardRotationChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("UITextEffectsWindowDidRotateNotification"), object: nil, queue: nil, using: { [weak self] notification in
            if let strongSelf = self {
                if !strongSelf.hostView.isUpdatingOrientationLayout {
                    return
                }
                var keyboardHeight = max(0.0, strongSelf.keyboardManager?.getCurrentKeyboardHeight() ?? 0.0)
                if strongSelf.deviceMetrics.type == .tablet, abs(strongSelf.windowLayout.size.height - UIScreen.main.bounds.height) > 41.0 {
                    keyboardHeight = max(0.0, keyboardHeight - 24.0)
                }
                
                //print("rotation keyboardHeight: \(keyboardHeight)")
                
                var duration: Double = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
                if duration > Double.ulpOfOne {
                    duration = 0.5
                }
                let curve: UInt = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
                
                let transitionCurve: ContainedViewLayoutTransitionCurve
                if curve == 7 {
                    transitionCurve = .spring
                } else {
                    transitionCurve = .easeInOut
                }
                
                strongSelf.updateLayout { $0.update(inputHeight: keyboardHeight.isLessThanOrEqualTo(0.0) ? nil : keyboardHeight, transition: .animated(duration: duration, curve: transitionCurve), overrideTransition: false) }
            }
        })
        
        self.keyboardFrameChangeObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: nil, using: { [weak self] notification in
            if let strongSelf = self {
                var keyboardFrame: CGRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect()
                if #available(iOSApplicationExtension 14.2, iOS 14.2, *), UIAccessibility.prefersCrossFadeTransitions {
                } else if let keyboardView = strongSelf.statusBarHost?.keyboardView {
                    if keyboardFrame.width.isEqual(to: keyboardView.bounds.width) && keyboardFrame.height.isEqual(to: keyboardView.bounds.height) && keyboardFrame.minX.isEqual(to: keyboardView.frame.minX) {
                        keyboardFrame.origin.y = keyboardView.frame.minY
                    }
                }
                
                
                var popoverDelta: CGFloat = 0.0
                
                let screenHeight: CGFloat
                var inPopover = false
                if keyboardFrame.width.isEqual(to: UIScreen.main.bounds.width) {
                    let screenSize = UIScreen.main.bounds.size
                    var portraitScreenSize = UIScreen.main.bounds.size
                    if portraitScreenSize.width > portraitScreenSize.height {
                        portraitScreenSize = CGSize(width: portraitScreenSize.height, height: portraitScreenSize.width)
                    }
                    var portraitLayoutSize = strongSelf.windowLayout.size
                    if portraitLayoutSize.width > portraitLayoutSize.height {
                        portraitLayoutSize = CGSize(width: portraitLayoutSize.height, height: portraitLayoutSize.width)
                    }
                    
                    if strongSelf.windowLayout.size.height != screenSize.height {
                        let heightDelta = screenSize.height - strongSelf.windowLayout.size.height
                        
                        let heightDeltaValid = heightDelta > 0.0 && heightDelta < 100.0
                        
                        if heightDeltaValid {
                            inPopover = true
                            popoverDelta = heightDelta / 2.0
                        }
                    }
                    
                    if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
                        screenHeight = UIScreen.main.bounds.height
                    } else {
                        screenHeight = strongSelf.windowLayout.size.height
                    }
                } else {
                    if keyboardFrame.minX > 0.0 {
                        screenHeight = UIScreen.main.bounds.height
                    } else {
                        screenHeight = UIScreen.main.bounds.width
                    }
                }
                
                var keyboardHeight: CGFloat
                if keyboardFrame.isEmpty || keyboardFrame.maxY < screenHeight {
                    keyboardHeight = 0.0
                } else {
                    keyboardHeight = max(0.0, screenHeight - keyboardFrame.minY)
                    if inPopover && !keyboardHeight.isZero {
                        keyboardHeight = max(0.0, keyboardHeight - popoverDelta)
                    }
                }
                
                print("keyboardHeight: \(keyboardHeight) (raw: \(keyboardFrame))")
            
                var duration: Double = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
                if duration > Double.ulpOfOne {
                    duration = 0.5
                }
                let curve: UInt = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
                
                let transitionCurve: ContainedViewLayoutTransitionCurve
                if curve == 7 {
                    transitionCurve = .spring
                } else {
                    transitionCurve = .easeInOut
                }
                
                var transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: transitionCurve)
                
                if strongSelf.shouldNotAnimateLikelyKeyboardAutocorrectionSwitch, let inputHeight = strongSelf.windowLayout.inputHeight {
                    if abs(inputHeight - keyboardHeight) <= 44.1 {
                        transition = .immediate
                    }
                }
                
                strongSelf.updateLayout { $0.update(inputHeight: keyboardHeight.isLessThanOrEqualTo(0.0) ? nil : keyboardHeight, transition: transition, overrideTransition: false) }
            }
        })
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.keyboardTypeChangeObserver = NotificationCenter.default.addObserver(forName: UITextInputMode.currentInputModeDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [weak self] notification in
                if let strongSelf = self, let initialInputHeight = strongSelf.windowLayout.inputHeight, let firstResponder = getFirstResponderAndAccessoryHeight(strongSelf.hostView.eventView).0 {
                    if firstResponder.textInputMode?.primaryLanguage != nil {
                        return
                    }
                    
                    strongSelf.keyboardTypeChangeTimer?.invalidate()
                    let timer = SwiftSignalKit.Timer(timeout: 0.1, repeat: false, completion: {
                        if let strongSelf = self, let firstResponder = getFirstResponderAndAccessoryHeight(strongSelf.hostView.eventView).0 {
                            if firstResponder.textInputMode?.primaryLanguage != nil {
                                return
                            }
                            
                            if let keyboardManager = strongSelf.keyboardManager {
                                var updatedKeyboardHeight = keyboardManager.getCurrentKeyboardHeight()
                                if strongSelf.deviceMetrics.type == .tablet, abs(strongSelf.windowLayout.size.height - UIScreen.main.bounds.height) > 41.0 {
                                    updatedKeyboardHeight = max(0.0, updatedKeyboardHeight - 24.0)
                                }
                                if !updatedKeyboardHeight.isEqual(to: initialInputHeight) {
                                    strongSelf.updateLayout({ $0.update(inputHeight: updatedKeyboardHeight, transition: .immediate, overrideTransition: false) })
                                }
                            }
                        }
                    }, queue: Queue.mainQueue())
                    strongSelf.keyboardTypeChangeTimer = timer
                    timer.start()
                }
            })
        }
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.voiceOverStatusObserver = NotificationCenter.default.addObserver(forName: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.updateLayout { $0.update(inVoiceOver: UIAccessibility.isVoiceOverRunning) }
                }
            })
        }
        
        let recognizer = WindowPanRecognizer(target: self, action: #selector(self.panGesture(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self.keyboardGestureRecognizerDelegate
        recognizer.isEnabled = self.deviceMetrics.type == .phone
        recognizer.began = { [weak self] point in
            self?.panGestureBegan(location: point)
        }
        recognizer.moved = { [weak self] point in
            self?.panGestureMoved(location: point)
        }
        recognizer.ended = { [weak self] point, velocity in
            self?.panGestureEnded(location: point, velocity: velocity)
        }
        self.windowPanRecognizer = recognizer
        self.hostView.containerView.addGestureRecognizer(recognizer)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let statusBarChangeObserver = self.statusBarChangeObserver {
            NotificationCenter.default.removeObserver(statusBarChangeObserver)
        }
        if let keyboardRotationChangeObserver = self.keyboardRotationChangeObserver {
            NotificationCenter.default.removeObserver(keyboardRotationChangeObserver)
        }
        if let keyboardFrameChangeObserver = self.keyboardFrameChangeObserver {
            NotificationCenter.default.removeObserver(keyboardFrameChangeObserver)
        }
        if let keyboardTypeChangeObserver = self.keyboardTypeChangeObserver {
            NotificationCenter.default.removeObserver(keyboardTypeChangeObserver)
        }
        if let voiceOverStatusObserver = self.voiceOverStatusObserver {
            NotificationCenter.default.removeObserver(voiceOverStatusObserver)
        }
    }
    
    public func setForceInCallStatusBar(_ forceInCallStatusBarText: String?, transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)) {
        if self.forceInCallStatusBarText != forceInCallStatusBarText {
            self.forceInCallStatusBarText = forceInCallStatusBarText
            
            self.updateLayout { $0.update(forceInCallStatusBarText: self.forceInCallStatusBarText, transition: transition, overrideTransition: true) }
            
            self.invalidateTracingStatusBars()
        }
    }
    
    private func invalidateTracingStatusBars() {
        self.tracingStatusBarsInvalidated = true
        self.hostView.eventView.setNeedsLayout()
    }
    
    public func invalidateDeferScreenEdgeGestures() {
        self.shouldUpdateDeferScreenEdgeGestures = true
        self.hostView.eventView.setNeedsLayout()
    }
    
    public func invalidatePrefersOnScreenNavigationHidden() {
        self.shouldInvalidatePrefersOnScreenNavigationHidden = true
        self.hostView.eventView.setNeedsLayout()
    }
    
    public func invalidateSupportedOrientations() {
        self.shouldInvalidateSupportedOrientations = true
        self.hostView.eventView.setNeedsLayout()
    }
    
    public func cancelInteractiveKeyboardGestures() {
        self.windowPanRecognizer?.isEnabled = false
        self.windowPanRecognizer?.isEnabled = true
        
        if self.windowLayout.upperKeyboardInputPositionBound != nil {
            self.updateLayout {
                $0.update(upperKeyboardInputPositionBound: nil, transition: .animated(duration: 0.25, curve: .spring), overrideTransition: false)
            }
        }
        
        if self.keyboardGestureBeginLocation != nil {
            self.keyboardGestureBeginLocation = nil
        }
    }
    
    public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.isInteractionBlocked {
            return nil
        }
                
        if let result = self.topPresentationContext.hitTest(view: self.hostView.containerView, point: point, with: event) {
            return result
        }
        
        if let coveringView = self.coveringView, !coveringView.isHidden, coveringView.superview != nil, coveringView.frame.contains(point) {
            return coveringView.hitTest(point, with: event)
        }
        
        for view in self.hostView.eventView.subviews.reversed() {
            let classString = NSStringFromClass(type(of: view))
            if classString == "UITransitionView" || classString.contains("ContextMenuContainerView") {
                if let result = view.hitTest(point, with: event) {
                    return result
                }
            }
        }
        
        if let result = self.overlayPresentationContext.hitTest(point, with: event) {
            return result
        }
        
        for controller in self._topLevelOverlayControllers.reversed() {
            if let result = controller.view.hitTest(point, with: event) {
                return result
            }
        }
        
        if let result = self.presentationContext.hitTest(view: self.hostView.containerView, point: point, with: event) {
            return result
        }
        return self.viewController?.view.hitTest(point, with: event)
    }
    
    func updateSize(_ value: CGSize, duration: Double) {
        let transition: ContainedViewLayoutTransition
        if !duration.isZero {
            transition = .animated(duration: duration, curve: .easeInOut)
        } else {
            transition = .immediate
        }
        self.updateLayout { $0.update(size: value, metrics: layoutMetricsForScreenSize(value), safeInsets: self.deviceMetrics.safeInsets(inLandscape: value.width > value.height), forceInCallStatusBarText: self.forceInCallStatusBarText, transition: transition, overrideTransition: true) }
        if let statusBarHost = self.statusBarHost, !statusBarHost.isApplicationInForeground {
            self.layoutSubviews(force: true)
        }
    }
    
    private var _rootController: ContainableController?
    public var viewController: ContainableController? {
        get {
            return _rootController
        }
        set(value) {
            if let rootController = self._rootController {
                rootController.view.removeFromSuperview()
            }
            self._rootController = value
            
            if let rootController = self._rootController {
                if let rootController = rootController as? NavigationController {
                    rootController.statusBarHost = self.statusBarHost
                    rootController.updateSupportedOrientations = { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        var supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
                        let orientationToLock: UIInterfaceOrientationMask
                        if strongSelf.windowLayout.size.width < strongSelf.windowLayout.size.height {
                            orientationToLock = .portrait
                        } else {
                            orientationToLock = .landscape
                        }
                        if let _rootController = strongSelf._rootController {
                            supportedOrientations = supportedOrientations.intersection(_rootController.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
                        }
                        supportedOrientations = supportedOrientations.intersection(strongSelf.presentationContext.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
                        supportedOrientations = supportedOrientations.intersection(strongSelf.overlayPresentationContext.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
                        
                        var resolvedOrientations: UIInterfaceOrientationMask
                        switch strongSelf.windowLayout.metrics.widthClass {
                        case .regular:
                            resolvedOrientations = supportedOrientations.regularSize
                        case .compact:
                            resolvedOrientations = supportedOrientations.compactSize
                        }
                        if resolvedOrientations.isEmpty {
                            resolvedOrientations = [.portrait]
                        }
                        strongSelf.hostView.updateSupportedInterfaceOrientations(resolvedOrientations)
                    }
                    rootController.keyboardViewManager = self.keyboardViewManager
                    rootController.inCallNavigate = { [weak self] in
                        self?.inCallNavigate?()
                    }
                }
                self.hostView.containerView.insertSubview(rootController.view, at: 0)
                if !self.windowLayout.size.width.isZero && !self.windowLayout.size.height.isZero {
                    rootController.displayNode.frame = CGRect(origin: CGPoint(), size: self.windowLayout.size)
                    rootController.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout, deviceMetrics: self.deviceMetrics), transition: .immediate)
                }
            }
            
            self.hostView.eventView.setNeedsLayout()
        }
    }
    
    private var _topLevelOverlayControllers: [ContainableController] = []
    public var topLevelOverlayControllers: [ContainableController] {
        get {
            return _topLevelOverlayControllers
        }
        set(value) {
            for controller in self._topLevelOverlayControllers {
                if let controller = controller as? ViewController {
                    controller.statusBar.alphaUpdated = nil
                }
                controller.view.removeFromSuperview()
            }
            self._topLevelOverlayControllers = value
            
            let layout = containedLayoutForWindowLayout(self.windowLayout, deviceMetrics: self.deviceMetrics)
            for controller in self._topLevelOverlayControllers {
                controller.displayNode.frame = CGRect(origin: CGPoint(), size: self.windowLayout.size)
                controller.containerLayoutUpdated(layout, transition: .immediate)
                
                if let coveringView = self.coveringView {
                    self.hostView.containerView.insertSubview(controller.view, belowSubview: coveringView)
                } else {
                    self.hostView.containerView.addSubview(controller.view)
                }
                
                if let controller = controller as? ViewController {
                    controller.statusBar.alphaUpdated = { [weak self] transition in
                        guard let strongSelf = self, let navigationController = strongSelf._rootController as? NavigationController else {
                            return
                        }
                        var isStatusBarHidden: Bool = false
                        for controller in strongSelf._topLevelOverlayControllers {
                            if let controller = controller as? ViewController {
                                if case .Hide = controller.statusBar.statusBarStyle {
                                    isStatusBarHidden = true
                                }
                            }
                        }
                        
                        navigationController.updateExternalStatusBarHidden(isStatusBarHidden, transition: .animated(duration: 0.3, curve: .easeInOut))
                    }
                }
            }
        }
    }
    
    public var coveringView: WindowCoveringView? {
        didSet {
            if self.coveringView !== oldValue {
                if let oldValue = oldValue {
                    oldValue.layer.allowsGroupOpacity = true
                    oldValue.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak oldValue] _ in
                        oldValue?.removeFromSuperview()
                    })
                }
                if let coveringView = self.coveringView {
                    coveringView.layer.removeAnimation(forKey: "opacity")
                    coveringView.layer.allowsGroupOpacity = false
                    coveringView.alpha = 1.0
                    if let controller = self.topPresentationContext.controllers.first {
                        self.hostView.containerView.insertSubview(coveringView, belowSubview: controller.0.displayNode.view)
                    } else {
                        self.hostView.containerView.addSubview(coveringView)
                    }
                    if !self.windowLayout.size.width.isZero {
                        coveringView.frame = CGRect(origin: CGPoint(), size: self.windowLayout.size)
                        coveringView.updateLayout(self.windowLayout.size)
                    }
                }
            }
        }
    }
    
    private func layoutSubviews(force: Bool) {
        if self.tracingStatusBarsInvalidated, let _ = keyboardManager {
            self.tracingStatusBarsInvalidated = false
            
            var supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
            let orientationToLock: UIInterfaceOrientationMask
            if self.windowLayout.size.width < self.windowLayout.size.height {
                orientationToLock = .portrait
            } else {
                orientationToLock = .landscape
            }
            if let _rootController = self._rootController {
                supportedOrientations = supportedOrientations.intersection(_rootController.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
            }
            supportedOrientations = supportedOrientations.intersection(self.presentationContext.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
            supportedOrientations = supportedOrientations.intersection(self.overlayPresentationContext.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
            
            var resolvedOrientations: UIInterfaceOrientationMask
            switch self.windowLayout.metrics.widthClass {
                case .regular:
                    resolvedOrientations = supportedOrientations.regularSize
                case .compact:
                    resolvedOrientations = supportedOrientations.compactSize
            }
            if resolvedOrientations.isEmpty {
                resolvedOrientations = [.portrait]
            }
            self.hostView.updateSupportedInterfaceOrientations(resolvedOrientations)
            
            self.hostView.updateDeferScreenEdgeGestures(self.collectScreenEdgeGestures())
            self.hostView.updatePrefersOnScreenNavigationHidden(self.collectPrefersOnScreenNavigationHidden())
            
            self.shouldUpdateDeferScreenEdgeGestures = false
            self.shouldInvalidatePrefersOnScreenNavigationHidden = false
            self.shouldInvalidateSupportedOrientations = false
        } else if self.shouldUpdateDeferScreenEdgeGestures || self.shouldInvalidatePrefersOnScreenNavigationHidden || self.shouldInvalidateSupportedOrientations {
            self.hostView.updateDeferScreenEdgeGestures(self.collectScreenEdgeGestures())
            self.hostView.updatePrefersOnScreenNavigationHidden(self.collectPrefersOnScreenNavigationHidden())
            
            self.shouldUpdateDeferScreenEdgeGestures = false
            self.shouldInvalidatePrefersOnScreenNavigationHidden = false
            
            if self.shouldInvalidateSupportedOrientations {
                var supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
                let orientationToLock: UIInterfaceOrientationMask
                if self.windowLayout.size.width < self.windowLayout.size.height {
                    orientationToLock = .portrait
                } else {
                    orientationToLock = .landscape
                }
                if let _rootController = self._rootController {
                    supportedOrientations = supportedOrientations.intersection(_rootController.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
                }
                supportedOrientations = supportedOrientations.intersection(self.presentationContext.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
                supportedOrientations = supportedOrientations.intersection(self.overlayPresentationContext.combinedSupportedOrientations(currentOrientationToLock: orientationToLock))
                
                var resolvedOrientations: UIInterfaceOrientationMask
                switch self.windowLayout.metrics.widthClass {
                    case .regular:
                        resolvedOrientations = supportedOrientations.regularSize
                    case .compact:
                        resolvedOrientations = supportedOrientations.compactSize
                }
                if resolvedOrientations.isEmpty {
                    resolvedOrientations = [.portrait]
                }
                self.hostView.updateSupportedInterfaceOrientations(resolvedOrientations)
                
                self.shouldInvalidateSupportedOrientations = false
            }
        }
        
        if force {
            self.commitUpdatingLayout()
        } else if !UIWindow.isDeviceRotating() {
            if !self.hostView.isUpdatingOrientationLayout {
                self.commitUpdatingLayout()
            } else {
                self.addPostUpdateToInterfaceOrientationBlock(f: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.hostView.eventView.setNeedsLayout()
                    }
                })
            }
        } else {
            UIWindow.addPostDeviceOrientationDidChange({ [weak self] in
                if let strongSelf = self {
                    strongSelf.hostView.eventView.setNeedsLayout()
                }
            })
        }
    }
    
    var postUpdateToInterfaceOrientationBlocks: [() -> Void] = []
    
    private func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        let blocks = self.postUpdateToInterfaceOrientationBlocks
        self.postUpdateToInterfaceOrientationBlocks = []
        for f in blocks {
            f()
        }
        self._rootController?.updateToInterfaceOrientation(orientation)
        self.presentationContext.updateToInterfaceOrientation(orientation)
        self.overlayPresentationContext.updateToInterfaceOrientation(orientation)
        
         self.topPresentationContext.updateToInterfaceOrientation(orientation)
        
        for controller in self.topLevelOverlayControllers {
            controller.updateToInterfaceOrientation(orientation)
        }
    }
    
    public func addPostUpdateToInterfaceOrientationBlock(f: @escaping () -> Void) {
        postUpdateToInterfaceOrientationBlocks.append(f)
    }
    
    private func updateLayout(_ update: (inout UpdatingLayout) -> ()) {
        if self.updatingLayout == nil {
            var updatingLayout = UpdatingLayout(layout: self.windowLayout, transition: .immediate)
            update(&updatingLayout)
            if updatingLayout.layout != self.windowLayout {
                self.updatingLayout = updatingLayout
                self.hostView.eventView.setNeedsLayout()
            }
        } else {
            update(&self.updatingLayout!)
            self.hostView.eventView.setNeedsLayout()
        }
    }
    
    private var isFirstLayout = true
    
    private func commitUpdatingLayout() {
        if let updatingLayout = self.updatingLayout {
            self.updatingLayout = nil
            if updatingLayout.layout != self.windowLayout || self.isFirstLayout {
                self.isFirstLayout = false
                
                let boundsSize = updatingLayout.layout.size
                let isLandscape = boundsSize.width > boundsSize.height
                var statusBarHeight: CGFloat? = self.deviceMetrics.statusBarHeight(for: boundsSize)
                if let statusBarHeightValue = statusBarHeight, let statusBarHost = self.statusBarHost {
                    statusBarHeight = max(statusBarHeightValue, statusBarHost.statusBarFrame.size.height)
                } else {
                    statusBarHeight = nil
                }
                
                if self.deviceMetrics.type == .tablet, let onScreenNavigationHeight = self.hostView.onScreenNavigationHeight, onScreenNavigationHeight != self.deviceMetrics.onScreenNavigationHeight(inLandscape: false, systemOnScreenNavigationHeight: self.hostView.onScreenNavigationHeight) {
                    self.deviceMetrics = DeviceMetrics(screenSize: UIScreen.main.bounds.size, scale: UIScreen.main.scale, statusBarHeight: statusBarHeight ?? 0.0, onScreenNavigationHeight: onScreenNavigationHeight)
                }
                
                let statusBarWasHidden = self.statusBarHidden
                if statusBarHiddenInLandscape && isLandscape {
                    statusBarHeight = nil
                    self.statusBarHidden = true
                } else {
                    self.statusBarHidden = false
                }
                if self.statusBarHidden != statusBarWasHidden {
                    self.tracingStatusBarsInvalidated = true
                    self.hostView.eventView.setNeedsLayout()
                }
                let previousInputOffset = inputHeightOffsetForLayout(self.windowLayout)
                
                self.windowLayout = WindowLayout(size: updatingLayout.layout.size, metrics: layoutMetricsForScreenSize(updatingLayout.layout.size), statusBarHeight: statusBarHeight, forceInCallStatusBarText: updatingLayout.layout.forceInCallStatusBarText, inputHeight: updatingLayout.layout.inputHeight, safeInsets: updatingLayout.layout.safeInsets, onScreenNavigationHeight: self.deviceMetrics.onScreenNavigationHeight(inLandscape: isLandscape, systemOnScreenNavigationHeight: self.hostView.onScreenNavigationHeight), upperKeyboardInputPositionBound: updatingLayout.layout.upperKeyboardInputPositionBound, inVoiceOver: updatingLayout.layout.inVoiceOver)
                
                let childLayout = containedLayoutForWindowLayout(self.windowLayout, deviceMetrics: self.deviceMetrics)
                let childLayoutUpdated = self.updatedContainerLayout != childLayout
                self.updatedContainerLayout = childLayout
                
                if childLayoutUpdated {
                    var rootLayout = childLayout
                    let rootTransition = updatingLayout.transition
                    if self.presentationContext.isCurrentlyOpaque {
                        rootLayout.inputHeight = nil
                    }
                    if let rootController = self._rootController {
                        rootTransition.updateFrame(node: rootController.displayNode, frame: CGRect(origin: CGPoint(), size: self.windowLayout.size))
                        rootController.containerLayoutUpdated(rootLayout, transition: rootTransition)
                    }
                    self.presentationContext.containerLayoutUpdated(childLayout, transition: updatingLayout.transition)
                    self.overlayPresentationContext.containerLayoutUpdated(childLayout, transition: updatingLayout.transition)
                    
                    self.topPresentationContext.containerLayoutUpdated(childLayout, transition: updatingLayout.transition)
                
                    for controller in self.topLevelOverlayControllers {
                        updatingLayout.transition.updateFrame(node: controller.displayNode, frame: CGRect(origin: CGPoint(), size: self.windowLayout.size))
                        controller.containerLayoutUpdated(childLayout, transition: updatingLayout.transition)
                    }
                }
                
                let updatedInputOffset = inputHeightOffsetForLayout(self.windowLayout)
                if !previousInputOffset.isEqual(to: updatedInputOffset) {
                    let hide = updatingLayout.transition.isAnimated && updatingLayout.layout.upperKeyboardInputPositionBound == updatingLayout.layout.size.height
                    self.keyboardManager?.updateInteractiveInputOffset(updatedInputOffset, transition: updatingLayout.transition, completion: { [weak self] in
                        if let strongSelf = self, hide {
                            strongSelf.updateLayout {
                                $0.update(upperKeyboardInputPositionBound: nil, transition: .immediate, overrideTransition: false)
                            }
                            strongSelf.hostView.eventView.endEditing(true)
                        }
                    })
                }
                
                if let coveringView = self.coveringView {
                    coveringView.frame = CGRect(origin: CGPoint(), size: self.windowLayout.size)
                    coveringView.updateLayout(self.windowLayout.size)
                }
            }
        }
    }
    
    public func present(_ controller: ContainableController, on level: PresentationSurfaceLevel, blockInteraction: Bool = false, completion: @escaping () -> Void = {}) {
        if level.rawValue <= 3, let controller = controller as? ViewController {
            for presentedController in self.presentationContext.controllers.reversed() {
                if let navigationController = presentedController.0 as? NavigationController {
                    navigationController.presentOverlay(controller: controller, inGlobal: false, blockInteraction: blockInteraction)
                    return
                }
            }
            
            if let navigationController = self._rootController as? NavigationController {
                navigationController.presentOverlay(controller: controller, inGlobal: false, blockInteraction: blockInteraction)
            } else {
                self.presentationContext.present(controller, on: level, blockInteraction: blockInteraction, completion: completion)
            }
        } else {
            if let controller = controller as? ViewController, controller.presentedOverCoveringView {
                self.topPresentationContext.present(controller, on: level, completion: completion)
            } else {
                self.presentationContext.present(controller, on: level, blockInteraction: blockInteraction, completion: completion)
            }
        }
    }
    
    public func presentInGlobalOverlay(_ controller: ContainableController) {
        if let controller = controller as? ViewController {
            if let navigationController = self._rootController as? NavigationController {
                navigationController.presentOverlay(controller: controller, inGlobal: true)
                return
            }
        }
        self.overlayPresentationContext.present(controller)
    }
    
    public func addGlobalPortalHostView(sourceView: PortalSourceView) {
        self.overlayPresentationContext.addGlobalPortalHostView(sourceView: sourceView)
    }
    
    public func presentNative(_ controller: UIViewController) {
        if let nativeController = self.hostView.nativeController?() {
            nativeController.present(controller, animated: true, completion: nil)
        }
    }
    
    private func panGestureBegan(location: CGPoint) {
        if self.windowLayout.upperKeyboardInputPositionBound != nil {
            return
        }
        
        let keyboardGestureBeginLocation = location
        let view = self.hostView.containerView
        let (firstResponder, accessoryHeight) = getFirstResponderAndAccessoryHeight(view)
        if let inputHeight = self.windowLayout.inputHeight, !inputHeight.isZero, keyboardGestureBeginLocation.y < self.windowLayout.size.height - inputHeight - (accessoryHeight ?? 0.0) {
            var enableGesture = true
            if let view = self.hostView.containerView.hitTest(location, with: nil) {
                if doesViewTreeDisableInteractiveTransitionGestureRecognizer(view, keyboardOnly: true) {
                    enableGesture = false
                }
            }
            if enableGesture, let _ = firstResponder {
                self.keyboardGestureBeginLocation = keyboardGestureBeginLocation
                self.keyboardGestureAccessoryHeight = accessoryHeight
            }
        }
    }
    
    private func panGestureMoved(location: CGPoint) {
        if let keyboardGestureBeginLocation = self.keyboardGestureBeginLocation {
            let currentLocation = location
            let deltaY = keyboardGestureBeginLocation.y - location.y
            if deltaY * deltaY >= 3.0 * 3.0 || self.windowLayout.upperKeyboardInputPositionBound != nil {
                self.updateLayout {
                    $0.update(upperKeyboardInputPositionBound: currentLocation.y + (self.keyboardGestureAccessoryHeight ?? 0.0), transition: .immediate, overrideTransition: false)
                }
            }
        }
    }
    
    public func simulateKeyboardDismiss(transition: ContainedViewLayoutTransition) {
        var simulate = false
        for controller in self.overlayPresentationContext.controllers {
            if controller.isViewLoaded {
                if controller.view.window != self.hostView.containerView.window {
                    simulate = true
                    break
                }
            }
        }
        if simulate {
            self.updateLayout {
                $0.update(upperKeyboardInputPositionBound: self.windowLayout.size.height, transition: transition, overrideTransition: false)
            }
        } else {
            self.hostView.containerView.endEditing(true)
        }
    }
    
    private func panGestureEnded(location: CGPoint, velocity: CGPoint?) {
        if self.keyboardGestureBeginLocation == nil {
            return
        }
        
        self.keyboardGestureBeginLocation = nil
        let currentLocation = location
        
        let accessoryHeight = (self.keyboardGestureAccessoryHeight ?? 0.0)
        
        var canDismiss = false
        if let upperKeyboardInputPositionBound = self.windowLayout.upperKeyboardInputPositionBound, upperKeyboardInputPositionBound >= self.windowLayout.size.height - accessoryHeight {
            canDismiss = true
        } else if let velocity = velocity, velocity.y > 100.0 {
            canDismiss = true
        }
        
        if canDismiss, let inputHeight = self.windowLayout.inputHeight, currentLocation.y + (self.keyboardGestureAccessoryHeight ?? 0.0) > self.windowLayout.size.height - inputHeight {
            self.updateLayout {
                $0.update(upperKeyboardInputPositionBound: self.windowLayout.size.height, transition: .animated(duration: 0.25, curve: .spring), overrideTransition: false)
            }
        } else {
            self.updateLayout {
                $0.update(upperKeyboardInputPositionBound: nil, transition: .animated(duration: 0.25, curve: .spring), overrideTransition: false)
            }
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                self.panGestureBegan(location: recognizer.location(in: recognizer.view))
            case .changed:
                self.panGestureMoved(location: recognizer.location(in: recognizer.view))
            case .ended:
                self.panGestureEnded(location: recognizer.location(in: recognizer.view), velocity: recognizer.velocity(in: recognizer.view))
            case .cancelled:
                self.panGestureEnded(location: recognizer.location(in: recognizer.view), velocity: nil)
            default:
                break
        }
    }
    
    private func collectScreenEdgeGestures() -> UIRectEdge {
        var edges: UIRectEdge = []
        if let navigationController = self._rootController as? NavigationController, let overlayController = navigationController.topOverlayController {
            edges = edges.union(overlayController.deferScreenEdgeGestures)
        }
        edges = edges.union(self.presentationContext.combinedDeferScreenEdgeGestures())
        
        for controller in self.topLevelOverlayControllers {
            if let controller = controller as? ViewController {
                edges = edges.union(controller.deferScreenEdgeGestures)
            }
        }
        
        return edges
    }
    
    private func collectPrefersOnScreenNavigationHidden() -> Bool {
        var hidden = false
        if let navigationController = self._rootController as? NavigationController, let overlayController = navigationController.topOverlayController {
            hidden = hidden || overlayController.prefersOnScreenNavigationHidden
        }
        hidden = hidden || self.presentationContext.combinedPrefersOnScreenNavigationHidden()
        
        for controller in self.topLevelOverlayControllers {
            if let controller = controller as? ViewController {
                hidden = hidden || controller.prefersOnScreenNavigationHidden
            }
        }
        
        return hidden
    }
    
    public func forEachViewController(_ f: (ContainableController) -> Bool, excludeNavigationSubControllers: Bool = false) {
        if let navigationController = self._rootController as? NavigationController {
            if !excludeNavigationSubControllers {
                for case let controller as ContainableController in navigationController.viewControllers {
                    let _ = f(controller)
                }
            }
            if let controller = navigationController.topOverlayController {
                let _ = f(controller)
            }
        }
        for (controller, _) in self.presentationContext.controllers {
            if !f(controller) {
                break
            }
        }
        
        for controller in self.topLevelOverlayControllers {
            if !f(controller) {
                break
            }
        }
        for (controller, _) in self.topPresentationContext.controllers {
            if !f(controller) {
                break
            }
        }
    }
    
    public func doNotAnimateLikelyKeyboardAutocorrectionSwitch() {
        self.shouldNotAnimateLikelyKeyboardAutocorrectionSwitch = true
        DispatchQueue.main.async {
            self.shouldNotAnimateLikelyKeyboardAutocorrectionSwitch = false
        }
    }
}
