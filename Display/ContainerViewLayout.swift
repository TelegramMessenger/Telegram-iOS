
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
    
    public static func ==(lhs: LayoutMetrics, rhs: LayoutMetrics) -> Bool {
        return lhs.widthClass == rhs.widthClass && lhs.heightClass == rhs.heightClass
    }
}

public struct ContainerViewLayout: Equatable {
    public let size: CGSize
    public let metrics: LayoutMetrics
    public let intrinsicInsets: UIEdgeInsets
    public let safeInsets: UIEdgeInsets
    public let statusBarHeight: CGFloat?
    public let inputHeight: CGFloat?
    public let inputHeightIsInteractivellyChanging: Bool
    
    public init() {
        self.size = CGSize()
        self.metrics = LayoutMetrics()
        self.intrinsicInsets = UIEdgeInsets()
        self.safeInsets = UIEdgeInsets()
        self.statusBarHeight = nil
        self.inputHeight = nil
        self.inputHeightIsInteractivellyChanging = false
    }
    
    public init(size: CGSize, metrics: LayoutMetrics, intrinsicInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, statusBarHeight: CGFloat?, inputHeight: CGFloat?, inputHeightIsInteractivellyChanging: Bool) {
        self.size = size
        self.metrics = metrics
        self.intrinsicInsets = intrinsicInsets
        self.safeInsets = safeInsets
        self.statusBarHeight = statusBarHeight
        self.inputHeight = inputHeight
        self.inputHeightIsInteractivellyChanging = inputHeightIsInteractivellyChanging
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
        return ContainerViewLayout(size: self.size, metrics: self.metrics, intrinsicInsets: UIEdgeInsets(top: self.intrinsicInsets.top + insets.top, left: self.intrinsicInsets.left + insets.left, bottom: self.intrinsicInsets.bottom + insets.bottom, right: self.intrinsicInsets.right + insets.right), safeInsets: self.safeInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging)
    }
    
    public func withUpdatedInputHeight(_ inputHeight: CGFloat?) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: self.metrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, statusBarHeight: self.statusBarHeight, inputHeight: inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging)
    }
    
    public func withUpdatedMetrics(_ metrics: LayoutMetrics) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: metrics, intrinsicInsets: self.intrinsicInsets, safeInsets: self.safeInsets, statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight, inputHeightIsInteractivellyChanging: self.inputHeightIsInteractivellyChanging)
    }

    public static func ==(lhs: ContainerViewLayout, rhs: ContainerViewLayout) -> Bool {
        if !lhs.size.equalTo(rhs.size) {
            return false
        }
        
        if lhs.metrics != rhs.metrics {
            return false
        }
        
        if lhs.intrinsicInsets != rhs.intrinsicInsets {
            return false
        }
        
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        
        if let lhsStatusBarHeight = lhs.statusBarHeight {
            if let rhsStatusBarHeight = rhs.statusBarHeight {
                if !lhsStatusBarHeight.isEqual(to: rhsStatusBarHeight) {
                    return false
                }
            } else {
                return false
            }
        } else if let _ = rhs.statusBarHeight {
            return false
        }
        
        if let lhsInputHeight = lhs.inputHeight {
            if let rhsInputHeight = rhs.inputHeight {
                if !lhsInputHeight.isEqual(to: rhsInputHeight) {
                    return false
                }
            } else {
                return false
            }
        } else if let _ = rhs.inputHeight {
            return false
        }
        
        if lhs.inputHeightIsInteractivellyChanging != rhs.inputHeightIsInteractivellyChanging {
            return false
        }
        
        return true
    }
}
