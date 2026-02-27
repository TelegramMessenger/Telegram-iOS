import Foundation
import UIKit
import SolidRoundedButtonNode
import TelegramPresentationData

public extension SolidRoundedButtonTheme {
    convenience init(theme: PresentationTheme) {
        self.init(backgroundColor: theme.list.itemCheckColors.fillColor, backgroundColors: [], foregroundColor: theme.list.itemCheckColors.foregroundColor, disabledBackgroundColor: theme.list.plainBackgroundColor.mixedWith(theme.list.itemDisabledTextColor, alpha: 0.15), disabledForegroundColor: theme.list.itemDisabledTextColor)
    }
}
