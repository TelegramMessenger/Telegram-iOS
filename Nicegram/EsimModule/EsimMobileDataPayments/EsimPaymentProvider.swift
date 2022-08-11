import UIKit
import EsimPayments

public protocol EsimPaymentProvider {
    var identifier: String { get }
    
    func pay(_: EsimPaymentInfo, from: UIViewController, completion: @escaping (Result<String, PaymentError>) -> ())
}
