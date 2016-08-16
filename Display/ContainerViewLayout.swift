
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

public struct ContainerViewLayout: Equatable {
    public let size: CGSize
    public let intrinsicInsets: UIEdgeInsets
    public let statusBarHeight: CGFloat?
    public let inputHeight: CGFloat?
    
    public init() {
        self.size = CGSize()
        self.intrinsicInsets = UIEdgeInsets()
        self.statusBarHeight = nil
        self.inputHeight = nil
    }
    
    public init(size: CGSize, intrinsicInsets: UIEdgeInsets, statusBarHeight: CGFloat?, inputHeight: CGFloat?) {
        self.size = size
        self.intrinsicInsets = intrinsicInsets
        self.statusBarHeight = statusBarHeight
        self.inputHeight = inputHeight
    }
    
    public func insets(options: ContainerViewLayoutInsetOptions) -> UIEdgeInsets {
        var insets = self.intrinsicInsets
        if let statusBarHeight = self.statusBarHeight where options.contains(.statusBar) {
            insets.top += statusBarHeight
        }
        if let inputHeight = self.inputHeight where options.contains(.input) {
            insets.bottom = max(inputHeight, insets.bottom)
        }
        return insets
    }
    
    public func addedInsets(insets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: self.size, intrinsicInsets: UIEdgeInsets(top: self.intrinsicInsets.top + insets.top, left: self.intrinsicInsets.left + insets.left, bottom: self.intrinsicInsets.bottom + insets.bottom, right: self.intrinsicInsets.right + insets.right), statusBarHeight: self.statusBarHeight, inputHeight: self.inputHeight)
    }
}

public func ==(lhs: ContainerViewLayout, rhs: ContainerViewLayout) -> Bool {
    if !lhs.size.equalTo(rhs.size) {
        return false
    }
    
    if lhs.intrinsicInsets != rhs.intrinsicInsets {
        return false
    }
    
    if let lhsStatusBarHeight = lhs.statusBarHeight {
        if let rhsStatusBarHeight = rhs.statusBarHeight {
            return lhsStatusBarHeight.isEqual(to: rhsStatusBarHeight)
        } else {
            return false
        }
    } else if let _ = rhs.statusBarHeight {
        return false
    }
    
    if let lhsInputHeight = lhs.inputHeight {
        if let rhsInputHeight = rhs.inputHeight {
            return lhsInputHeight.isEqual(to: rhsInputHeight)
        } else {
            return false
        }
    } else if let _ = rhs.inputHeight {
        return false
    }
    
    return true
}
