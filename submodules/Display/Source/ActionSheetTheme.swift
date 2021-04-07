import Foundation
import UIKit

public enum ActionSheetControllerThemeBackgroundType {
    case light
    case dark
}

public final class ActionSheetControllerTheme: Equatable {
    public let dimColor: UIColor
    public let backgroundType: ActionSheetControllerThemeBackgroundType
    public let itemBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let standardActionTextColor: UIColor
    public let destructiveActionTextColor: UIColor
    public let disabledActionTextColor: UIColor
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let controlAccentColor: UIColor
    public let controlColor: UIColor
    public let switchFrameColor: UIColor
    public let switchContentColor: UIColor
    public let switchHandleColor: UIColor
    public let baseFontSize: CGFloat
    
    public init(dimColor: UIColor, backgroundType: ActionSheetControllerThemeBackgroundType, itemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, standardActionTextColor: UIColor, destructiveActionTextColor: UIColor, disabledActionTextColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, controlAccentColor: UIColor, controlColor: UIColor, switchFrameColor: UIColor, switchContentColor: UIColor, switchHandleColor: UIColor, baseFontSize: CGFloat) {
        self.dimColor = dimColor
        self.backgroundType = backgroundType
        self.itemBackgroundColor = itemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.standardActionTextColor = standardActionTextColor
        self.destructiveActionTextColor = destructiveActionTextColor
        self.disabledActionTextColor = disabledActionTextColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.controlAccentColor = controlAccentColor
        self.controlColor = controlColor
        self.switchFrameColor = switchFrameColor
        self.switchContentColor = switchContentColor
        self.switchHandleColor = switchHandleColor
        self.baseFontSize = min(26.0, baseFontSize)
    }
    
    public static func ==(lhs: ActionSheetControllerTheme, rhs: ActionSheetControllerTheme) -> Bool {
        if lhs.dimColor != rhs.dimColor {
            return false
        }
        if lhs.backgroundType != rhs.backgroundType {
            return false
        }
        if lhs.itemBackgroundColor != rhs.itemBackgroundColor {
            return false
        }
        if lhs.itemHighlightedBackgroundColor != rhs.itemHighlightedBackgroundColor {
            return false
        }
        if lhs.standardActionTextColor != rhs.standardActionTextColor {
            return false
        }
        if lhs.destructiveActionTextColor != rhs.destructiveActionTextColor {
            return false
        }
        if lhs.disabledActionTextColor != rhs.disabledActionTextColor {
            return false
        }
        if lhs.primaryTextColor != rhs.primaryTextColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.controlAccentColor != rhs.controlAccentColor {
            return false
        }
        if lhs.controlColor != rhs.controlColor {
            return false
        }
        if lhs.switchFrameColor != rhs.switchFrameColor {
            return false
        }
        if lhs.switchContentColor != rhs.switchContentColor {
            return false
        }
        if lhs.switchHandleColor != rhs.switchHandleColor {
            return false
        }
        if lhs.baseFontSize != rhs.baseFontSize {
            return false
        }
        return true
    }
}
