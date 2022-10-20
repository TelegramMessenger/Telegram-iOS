import UIKit
import NGTheme

public protocol ScanQRBuilder {
    func build(string: String) -> UIViewController
}

public class ScanQRBuilderImpl: ScanQRBuilder {
    
    //  MARK: - Dependencies
    
    private let ngTheme: NGThemeColors
    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
    }
    
    //  MARK: - Public Functions

    public func build(string: String) -> UIViewController {
        let controller = ScanQRViewController(ngTheme: ngTheme)

        let router = ScanQRRouter()
        router.parentViewController = controller

        let presenter = ScanQRPresenter()
        presenter.output = controller

        let interactor = ScanQRInteractor(string: string)
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
