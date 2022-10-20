import Foundation
import UIKit
import NGLocalization
import NGModels

public class RegionsFormatter {
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func localizedRegionName(isoCode: String) -> String {
        switch isoCode.lowercased() {
        case "europe": return ngLocalized("Nicegram.MobileData.MyEsim.Europe")
        case "asia": return ngLocalized("Nicegram.MobileData.MyEsim.Asia")
        case "america": return ngLocalized("Nicegram.MobileData.MyEsim.CountriesOfAmerica")
        case "africa": return ngLocalized("Nicegram.MobileData.MyEsim.Africa")
        case "worldwide": return ngLocalized("Nicegram.MobileData.MyEsim.Worldwide")
        default: return localizedCountryName(isoCode: isoCode) ?? isoCode
        }
    }

    public func localizedCountryName(isoCode: String) -> String? {
        let appLocale = Locale.currentAppLocale
        return appLocale.localizedString(forRegionCode: isoCode)
    }
    
    public func countryFlagImage(isoCode: String) -> UIImage? {
        return UIImage(named: isoCode.uppercased())
    }
}

public extension RegionsFormatter {    
    func localizedCountryName(_ country: EsimCountry) -> String {
        return localizedCountryName(isoCode: country.isoCode) ?? country.name
    }
    
    func countryFlagImage(_ country: EsimCountry) -> UIImage? {
        return countryFlagImage(isoCode: country.isoCode)
    }
}
