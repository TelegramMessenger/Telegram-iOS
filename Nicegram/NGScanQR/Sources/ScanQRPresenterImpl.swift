import UIKit
import NGLocalization

protocol ScanQRPresenterInput { }

protocol ScanQRPresenterOutput: AnyObject {
    func display(navigationTitle: String)
    func display(qrImage: UIImage)
    func display(description: String)
    func display(buttonTitle: String)
}

final class ScanQRPresenter: ScanQRPresenterInput {
    
    //  MARK: - VIP
    
    weak var output: ScanQRPresenterOutput!
    
    //  MARK: - Lifecycle
    
    init() { }
}

//  MARK: - Output

extension ScanQRPresenter: ScanQRInteractorOutput {
    func viewDidLoad() {
        output.display(navigationTitle: ngLocalized("Nicegram.QRCode.Title"))
        output.display(description: ngLocalized("Nicegram.QRCode.Description"))
        output.display(buttonTitle: ngLocalized("Nicegram.QRCode.Share"))
    }
    
    func present(qrImage: UIImage) {
        self.output.display(qrImage: qrImage)
    }
}
