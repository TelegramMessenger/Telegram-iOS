import UIKit

public protocol PaymentProvider {
    var identifier: String { get }
    
    func pay(price: Double, currency: PaymentCurrency, description: String?, from: UIViewController, completion: @escaping (Result<String, PaymentError>) -> ())
}
