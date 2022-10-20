import Foundation
import UIKit
import LegacyComponents
import Display

public final class LegacyEmptyController: TGViewController {
    override public init!(context: LegacyComponentsContext!) {
        super.init(context: context)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        self.view.backgroundColor = nil
        self.view.isOpaque = false
    }
    
    override public func present(context generator: ((LegacyComponentsContext?) -> UIViewController?)!) {
        if let context = self.context as? LegacyControllerContext, let controller = context.controller {
            let context = legacyContextGet()
            let presentationData = context?.sharedContext.currentPresentationData.with { $0 }
            
            let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: presentationData?.theme, initialLayout: controller.currentlyAppliedLayout)
            guard let presentedController = generator(legacyController.context) else {
                return
            }
            if let presentationData = presentationData {
                legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
            }
            presentedController.navigation_setDismiss({ [weak legacyController] in
                legacyController?.dismiss()
            }, rootController: nil)
            if let presentedController = presentedController as? TGViewController {
                presentedController.customDismissSelf = { [weak legacyController] in
                    legacyController?.dismiss()
                }
            } else if let presentedController = presentedController as? TGNavigationController {
                presentedController.customDismissSelf = { [weak legacyController] in
                    legacyController?.dismiss()
                }
            }
            legacyController.bind(controller: presentedController)
            controller.present(legacyController, in: .window(.root))
        } else {
            super.present(context: generator)
        }
    }
}
