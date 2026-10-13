import UIKit

public struct ContainerViewLayoutInsetOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let statusBar = ContainerViewLayoutInsetOptions(rawValue: 1 << 0)
    public static let input = ContainerViewLayoutInsetOptions(rawValue: 1 << 1)
}

public enum ContainerViewLayoutSizeClass {
    case compact
    case regular
}

public struct LayoutMetrics: Equatable {
    public let widthClass: ContainerViewLayoutSizeClass
    public let heightClass: ContainerViewLayoutSizeClass
    public let orientation: UIInterfaceOrientation?
    /// The size of the window the layout is hosted in, as the system currently sizes it. Nil for a
    /// layout that is not derived from a window (previews, offscreen rendering, embedded content).
    public let windowSize: CGSize?
    
    public init(widthClass: ContainerViewLayoutSizeClass, heightClass: ContainerViewLayoutSizeClass, orientation: UIInterfaceOrientation?, windowSize: CGSize? = nil) {
        self.widthClass = widthClass
        self.heightClass = heightClass
        self.orientation = orientation
        self.windowSize = windowSize
    }
    
    public init() {
        self.widthClass = .compact
        self.heightClass = .compact
        self.orientation = nil
        self.windowSize = nil
    }
}

public extension LayoutMetrics {
    var isTablet: Bool {
        if case .regular = self.widthClass {
            return true
        } else {
            return false
        }
    }
}

public enum LayoutOrientation {
    case portrait
    case landscape
}

public struct ContainerViewLayout: Equatable {
    public var size: CGSize
    public var metrics: LayoutMetrics
    public var deviceMetrics: DeviceMetrics
    public var intrinsicInsets: UIEdgeInsets
    public var safeInsets: UIEdgeInsets
    public var additionalInsets: UIEdgeInsets
    public var statusBarHeight: CGFloat?
    public var inputHeight: CGFloat?
    public var inputHeightIsInteractivellyChanging: Bool
    public var inVoiceOver: Bool
    /// The layout is the content of a form sheet: a modal card that `NavigationModalContainer` centers
    /// over a regular-width window. Set by the container that makes that presentation decision, never
    /// inferred from geometry, and carried into every layout derived from it.
    public var presentedInFormSheet: Bool
    
    public init(size: CGSize, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, intrinsicInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, additionalInsets: UIEdgeInsets, statusBarHeight: CGFloat?, inputHeight: CGFloat?, inputHeightIsInteractivellyChanging: Bool, inVoiceOver: Bool, presentedInFormSheet: Bool) {
        self.size = size
        self.metrics = metrics
        self.deviceMetrics = deviceMetrics
        self.intrinsicInsets = intrinsicInsets
        self.safeInsets = safeInsets
        self.additionalInsets = additionalInsets
        self.statusBarHeight = statusBarHeight
        self.inputHeight = inputHeight
        self.inputHeightIsInteractivellyChanging = inputHeightIsInteractivellyChanging
        self.inVoiceOver = inVoiceOver
        self.presentedInFormSheet = presentedInFormSheet
    }
    
    public func addedInsets(insets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: self.intrinsicInsets.top + insets.top, left: self.intrinsicInsets.left + insets.left, bottom: self.intrinsicInsets.bottom + insets.bottom, right: self.intrinsicInsets.right + insets.right), safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver, presentedInFormSheet: self.presentedInFormSheet)
    }
    
    public func withUpdatedSize(_ size: CGSize) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver, presentedInFormSheet: self.presentedInFormSheet)
    }
    
    public func withUpdatedIntrinsicInsets(_ intrinsicInsets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver, presentedInFormSheet: self.presentedInFormSheet)
    }
    
    public func withUpdatedSafeInsets(_ safeInsets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver, presentedInFormSheet: self.presentedInFormSheet)
    }
    
    public func withUpdatedAdditionalInsets(_ additionalInsets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver, presentedInFormSheet: self.presentedInFormSheet)
    }
    
    public func withUpdatedInputHeight(_ inputHeight: CGFloat?) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver, presentedInFormSheet: self.presentedInFormSheet)
    }
    
    public func withUpdatedMetrics(_ metrics: LayoutMetrics) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver, presentedInFormSheet: self.presentedInFormSheet)
    }
}

public extension ContainerViewLayout {
    func insets(options: ContainerViewLayoutInsetOptions) -> UIEdgeInsets {
        var insets = self.intrinsicInsets
        if let statusBarHeight = self.statusBarHeight, options.contains(.statusBar) {
            insets.top = max(statusBarHeight, insets.top)
        }
        if let inputHeight = self.inputHeight, options.contains(.input) {
            insets.bottom = max(inputHeight, insets.bottom)
        }
        return insets
    }
    
    var isNonExclusive: Bool {
        if case .tablet = self.deviceMetrics.type {
            if case .compact = self.metrics.widthClass {
                return true
            }
            if case .compact = self.metrics.heightClass {
                return true
            }
        }
        return false
    }
    
    var orientation: LayoutOrientation {
        return self.size.width > self.size.height ? .landscape : .portrait
    }
    
    var standardKeyboardHeight: CGFloat {
        return self.deviceMetrics.keyboardHeight(inLandscape: self.orientation == .landscape)
    }
    
    var standardInputHeight: CGFloat {
        return self.deviceMetrics.standardInputHeight(inLandscape: self.orientation == .landscape)
    }
    
    static func concentricInsets(bottomInset: CGFloat, innerDiameter: CGFloat, sideInset: CGFloat) -> UIEdgeInsets {
        let mappedBottomInset: CGFloat = max(bottomInset, sideInset)
        return UIEdgeInsets(top: 0.0, left: sideInset, bottom: mappedBottomInset, right: sideInset)
    }
}
