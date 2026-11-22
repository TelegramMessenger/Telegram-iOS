import Foundation
import UIKit
import LegacyComponents

public func makeLegacyNavigationController(rootController: UIViewController) -> TGNavigationController {
    return TGNavigationController.make(withRootController: rootController)
}

