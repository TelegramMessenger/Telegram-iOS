
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

public struct ContainerViewLayout: Equatable {
    public let size: CGSize
    public let metrics: LayoutMetrics
    public let intrinsicInsets: UIEdgeInsets
    public let safeInsets: UIEdgeInsets
    public let statusBarHeight: CGFloat?
    public var inputHeight: CGFloat?
    public let standardInputHeight: CGFloat
    public let inputHeightIsInteractivellyChanging: Bool
    public let inVoiceOver: Bool
    
    public init(size: CGSize, metrics: LayoutMetrics, intrinsicInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, statusBarHeight: CGFloat?, inputHeight: CGFloat?, standardInputHeight: CGFloat, inputHeightIsInteractivellyChanging: Bool, inVoiceOver: Bool) {
        self.size = size
        self.metrics = metrics
        self.intrinsicInsets = intrinsicInsets
        self.safeInsets = safeInsets
        self.statusBarHeight = statusBarHeight
        self.inputHeight = inputHeight
        self.standardInputHeight = standardInputHeight
        self.inputHeightIsInteractivellyChanging = inputHeightIsInteractivellyChanging
        self.inVoiceOver = inVoiceOver
    }
    
    public func insets(options: ContainerViewLayoutInsetOptions) -> UIEdgeInsets {
        var insets = self.intrinsicInsets
        if let statusBarHeight = self.statusBarHeight , options.contains(.statusBar) {
            insets.top += statusBarHeight
        }
        if let inputHeight = self.inputHeight , options.contains(.input) {
            insets.bottom = max(inputHeight, insets.bottom)
        }
        return insets
    }
    
    public func addedInsets(insets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, intrinsicInsets: UIEdgeInsets(top: self.intrinsicInsets.top + insets.top, left: self.intrinsicInsets.left + insets.left, bottom: self.intrinsicInsets.bottom + insets.bottom, right: self.intrinsicInsets.right + insets.right), safeInsets: self.safeInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, standardInputHeight: self.standardInputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
    }
    
    public func withUpdatedInputHeight(_ inputHeight: CGFloat?) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, statusBarHeight: self.statusBarHeight, inputHeight: inputHeight, standardInputHeight: self.standardInputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
    }
    
    public func withUpdatedMetrics(_ metrics: LayoutMetrics) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: metrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, standardInputHeight: self.standardInputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging, inVoiceOver: self.inVoiceOver)
    }
}
