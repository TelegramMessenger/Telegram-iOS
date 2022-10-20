import UIKit
import NGModels
import NGScanQR
import NGTheme

public protocol SetupEsimBuilder {
    func build(activationInfo: EsimActivationInfo) -> UIViewController
}

public class SetupEsimBuilderImpl: SetupEsimBuilder {
    
    //  MARK: - Dependencies
    
    private let ngTheme: NGThemeColors
    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
    }

    public func build(activationInfo: EsimActivationInfo) -> UIViewController {
        let controller = SetupEsimViewController(ngTheme: ngTheme)

        let router = SetupEsimRouter(
            scanQrBuilder: ScanQRBuilderImpl(
                ngTheme: ngTheme
            )
        )
        router.parentViewController = controller

        let presenter = SetupEsimPresenter()
        presenter.output = controller

        let interactor = SetupEsimInteractor(activationInfo: activationInfo)
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
