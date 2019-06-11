import Foundation
import UIKit
import LegacyComponents

func makeLegacyNavigationController(rootController: UIViewController) -> TGNavigationController {
    return TGNavigationController.make(withRootController: rootController)
}

