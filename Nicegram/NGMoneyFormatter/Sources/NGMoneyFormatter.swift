import Foundation
import NGModels

public class MoneyFormatter {
    
    //  MARK: - Private Properties

    private let numberFormatter = NumberFormatter()
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func format(_ money: Money, minimumFractionDigits: Int = 2) -> String {
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = money.currency.isoCode
        numberFormatter.minimumFractionDigits = minimumFractionDigits
        return numberFormatter.string(from: money.amount.nsNumber) ?? "\(money.amount)"
    }
}

private extension Double {
    var nsNumber: NSNumber {
        return NSNumber(value: self)
    }
}
