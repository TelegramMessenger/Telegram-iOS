import Foundation

public struct ToolbarAction: Equatable {
    public let title: String
    public let isEnabled: Bool
    
    public init(title: String, isEnabled: Bool) {
        self.title = title
        self.isEnabled = isEnabled
    }
}

public struct Toolbar: Equatable {
    public let leftAction: ToolbarAction?
    public let rightAction: ToolbarAction?
    
    public init(leftAction: ToolbarAction?, rightAction: ToolbarAction?) {
        self.leftAction = leftAction
        self.rightAction = rightAction
    }
}
