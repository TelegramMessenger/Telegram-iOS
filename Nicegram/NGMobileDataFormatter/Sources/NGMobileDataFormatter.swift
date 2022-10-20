import Foundation
import NGLocalization
import NGModels
import NGMoneyFormatter

public class MobileDataFormatter {
    
    //  MARK: - Dependencies
    
    private let moneyFormatter: MoneyFormatter
    
    //  MARK: - Lifecycle
    
    public init(moneyFormatter: MoneyFormatter) {
        self.moneyFormatter = moneyFormatter
    }
    
    //  MARK: - Public Functions

    public func pricePerMb(_ price: Money) -> String {
        let priceString = moneyFormatter.format(price, minimumFractionDigits: 3)
        return ngLocalized("Nicegram.Internet.Countries.Price", with: priceString)
    }
}
