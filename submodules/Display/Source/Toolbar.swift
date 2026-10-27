import Foundation
import UIKit

public struct ToolbarAction: Equatable {
    public enum Color: Equatable {
        case accent
        case custom(UIColor)
    }

    public let title: String
    public let isEnabled: Bool
    public let color: Color
    
    public init(title: String, isEnabled: Bool, color: Color = .accent) {
        self.title = title
        self.isEnabled = isEnabled
        self.color = color
    }

    /// The colour a toolbar draws the title in instead of its own: the custom colour while the action is enabled; a
    /// disabled action looks like any other.
    public var customTitleColor: UIColor? {
        guard self.isEnabled, case let .custom(color) = self.color else {
            return nil
        }
        return color
    }
}

public struct Toolbar: Equatable {
    public let leftAction: ToolbarAction?
    public let rightAction: ToolbarAction?
    public let middleAction: ToolbarAction?
    
    public init(leftAction: ToolbarAction?, rightAction: ToolbarAction?, middleAction: ToolbarAction?) {
        self.leftAction = leftAction
        self.rightAction = rightAction
        self.middleAction = middleAction
    }
}
