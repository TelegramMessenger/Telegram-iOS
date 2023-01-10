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
    
    public init(widthClass: ContainerViewLayoutSizeClass, heightClass: ContainerViewLayoutSizeClass) {
        self.widthClass = widthClass
        self.heightClass = heightClass
    }
    
    public init() {
        self.widthClass = .compact
        self.heightClass = .compact
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
    
    public init(size: CGSize, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, intrinsicInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, additionalInsets: UIEdgeInsets, statusBarHeight: CGFloat?, inputHeight: CGFloat?, inputHeightIsInteractivellyChanging: Bool, inVoiceOver: Bool) {
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
    }
    
    public func addedInsets(insets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: self.intrinsicInsets.top + insets.top, left: self.intrinsicInsets.left + insets.left, bottom: self.intrinsicInsets.bottom + insets.bottom, right: self.intrinsicInsets.right + insets.right), safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
    }
    
    public func withUpdatedSize(_ size: CGSize) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
    }
    
    public func withUpdatedIntrinsicInsets(_ intrinsicInsets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
    }
    
    public func withUpdatedInputHeight(_ inputHeight: CGFloat?) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
    }
    
    public func withUpdatedMetrics(_ metrics: LayoutMetrics) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: metrics, deviceMetrics: self.deviceMetrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, additionalInsets: self.additionalInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
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
    
    var isModalOverlay: Bool {
        if case .tablet = self.deviceMetrics.type {
            if case .regular = self.metrics.widthClass {
                return abs(max(self.size.width, self.size.height) - self.deviceMetrics.screenSize.height) > 1.0
            }
        }
        return false
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
    
    var inSplitView: Bool {
        var maybeSplitView = false
        if case .tablet = self.deviceMetrics.type {
            if case .compact = self.metrics.widthClass {
                maybeSplitView = true
            }
            if case .compact = self.metrics.heightClass {
                maybeSplitView = true
            }
        }
        if maybeSplitView && abs(max(self.size.width, self.size.height) - self.deviceMetrics.screenSize.height) < 1.0 {
            return true
        }
        return false
    }
    
    var inSlideOver: Bool {
        var maybeSlideOver = false
        if case .tablet = self.deviceMetrics.type {
            if case .compact = self.metrics.widthClass {
                maybeSlideOver = true
            }
            if case .compact = self.metrics.heightClass {
                maybeSlideOver = true
            }
        }
        if maybeSlideOver && abs(max(self.size.width, self.size.height) - self.deviceMetrics.screenSize.height) > 10.0 {
            return true
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
        return self.deviceMetrics.keyboardHeight(inLandscape: self.orientation == .landscape) + self.deviceMetrics.predictiveInputHeight(inLandscape: self.orientation == .landscape)
    }
}
