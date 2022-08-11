import UIKit
import NGTheme

public protocol HintBuilder {
    func build() -> UIViewController
}

public class HintBuilderImpl: HintBuilder {
    private let ngTheme: NGThemeColors
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
    }

    public func build() -> UIViewController {
        let controller = HintViewController(ngTheme: ngTheme)

        let router = HintRouter()
        router.parentViewController = controller

        let presenter = HintPresenter()
        presenter.output = controller

        let interactor = HintInteractor()
        interactor.output = presenter

        controller.output = interactor
        controller.router = router

        return controller
    }
}
