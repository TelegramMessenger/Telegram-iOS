import Foundation
import UIKit
import OverlayStatusController
import TelegramPresentationData

public extension OverlayStatusController {
    convenience init(theme: PresentationTheme, type: OverlayStatusControllerType) {
        self.init(style: theme.actionSheet.backgroundType == .light ? .light : .dark, type: type)
    }
}
