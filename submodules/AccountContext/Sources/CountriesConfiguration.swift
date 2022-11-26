import Foundation
import TelegramCore

public class CountriesConfiguration {
    public let countries: [Country]
    public let countriesByPrefix: [String: (Country, Country.CountryCode)]
    
    public init(countries: [Country]) {
        self.countries = countries
        
        var countriesByPrefix: [String: (Country, Country.CountryCode)] = [:]
        for country in countries {
            for code in country.countryCodes {
                if !code.prefixes.isEmpty {
                    for prefix in code.prefixes {
                        countriesByPrefix["\(code.code)\(prefix)"] = (country, code)
                    }
                } else {
                    countriesByPrefix[code.code] = (country, code)
                }
            }
        }
        
        self.countriesByPrefix = countriesByPrefix
    }
}
