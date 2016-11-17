import Foundation
import UIKit
import TelegramLegacyComponents

func makeLegacyNavigationController(rootController: UIViewController) -> TGNavigationController {
    return TGNavigationController.make(withRootController: rootController)
}

