import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class GalleryControllerInteraction {
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let dismissController: () -> Void
    let replaceRootController: (ViewController, ValuePromise<Bool>?) -> Void
    
    init(presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, dismissController: @escaping () -> Void, replaceRootController: @escaping (ViewController, ValuePromise<Bool>?) -> Void) {
        self.presentController = presentController
        self.dismissController = dismissController
        self.replaceRootController = replaceRootController
    }
}

open class GalleryFooterContentNode: ASDisplayNode {
    var requestLayout: ((ContainedViewLayoutTransition) -> Void)?
    var controllerInteraction: GalleryControllerInteraction?
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 0.0
    }
}
