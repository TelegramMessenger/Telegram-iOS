import UIKit

public protocol VirtualNumbersBuilder {
    func build() -> UIViewController
}

public class VirtualNumbersBuilderImpl: VirtualNumbersBuilder {
    public init() { }

    public func build() -> UIViewController {
        let controller = VirtualNumbersViewController()

        let router = VirtualNumbersRouter()
        router.parentViewController = controller

        let presenter = VirtualNumbersPresenter()
        presenter.output = controller

        let interactor = VirtualNumbersInteractor()
        interactor.output = presenter

        controller.output = interactor
        controller.router = router

        return controller
    }
}
