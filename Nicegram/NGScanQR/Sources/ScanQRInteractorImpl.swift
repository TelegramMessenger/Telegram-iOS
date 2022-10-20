import Foundation
import UIKit
import NGExtensions

typealias ScanQRInteractorInput = ScanQRViewControllerOutput

protocol ScanQRInteractorOutput {
    func viewDidLoad()
    func present(qrImage: UIImage)
}

final class ScanQRInteractor {
    
    //  MARK: - VIP
    
    var output: ScanQRInteractorOutput!
    var router: ScanQRRouter!
    
    //  MARK: - Logic
    
    private let string: String
    private var qrImage: UIImage?
    
    //  MARK: - Lifecycle
    
    init(string: String) {
        self.string = string
    }
}

//  MARK: - Output

extension ScanQRInteractor: ScanQRInteractorInput {
    func viewDidLoad() {
        output.viewDidLoad()
        
        DispatchQueue.global().async {
            if let image = self.generateQRCode(from: self.string)?.convertedToJpeg() {
                DispatchQueue.main.async {
                    self.qrImage = image
                    self.output.present(qrImage: image)
                }
            }
        }
    }
    
    func shareTapped(sourceView: UIView?) {
        guard let qrImage = qrImage else { return }
        router.routeToShareItems(items: [qrImage], sourceView: sourceView)
    }
}

//  MARK: - Private Functions

private extension ScanQRInteractor {
    func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)

            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }

        return nil
    }
}
