import Foundation
import UIKit

public enum ActionSheetControllerThemeBackgroundType {
    case light
    case dark
}

public final class ActionSheetControllerTheme {
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
    
    public init(dimColor: UIColor, backgroundType: ActionSheetControllerThemeBackgroundType, itemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, standardActionTextColor: UIColor, destructiveActionTextColor: UIColor, disabledActionTextColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, controlAccentColor: UIColor) {
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
    }
}
