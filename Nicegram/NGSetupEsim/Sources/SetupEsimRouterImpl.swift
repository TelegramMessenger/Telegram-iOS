import UIKit
import NGScanQR

protocol SetupEsimRouterInput: AnyObject {
    func routeToSupport()
    func routeToVideo(url: URL)
    func routeToScanQR(string: String)
    func routeToAppSettings()
    func dismiss()
}

final class SetupEsimRouter: SetupEsimRouterInput {
    weak var parentViewController: SetupEsimViewController?
    
    //  MARK: - Dependencies
    
    private let scanQrBuilder: ScanQRBuilder
    
    //  MARK: - Lifecycle
    
    init(scanQrBuilder: ScanQRBuilder) {
        self.scanQrBuilder = scanQrBuilder
    }
    
    //  MARK: - Public Functions
    
    func routeToSupport() {
        if let url = URL(string: "ncg://resolve?domain=nicegram_support_manager"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.openURL(url)
        }
    }
    
    func routeToVideo(url: URL) {
        UIApplication.shared.openURL(url)
    }

    func routeToScanQR(string: String) {
        let vc = scanQrBuilder.build(string: string)
        parentViewController?.navigationController?.pushViewController(vc, animated: true)
    }
    
    func routeToAppSettings() {
        parentViewController?.routeToAppSettings()
    }

    func dismiss() {
        parentViewController?.navigationController?.popViewController(animated: true)
    }
}
