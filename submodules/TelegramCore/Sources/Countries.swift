import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

public struct Country {
    public struct CountryCode {
        public let code: String
        public let prefixes: [String]
        public let patterns: [String]
        
        public init(code: String, prefixes: [String], patterns: [String]) {
            self.code = code
            self.prefixes = prefixes
            self.patterns = patterns
        }
    }
    
    public let code: String
    public let defaultName: String
    public let name: String
    public let countryCodes: [CountryCode]
    
    public init(code: String, defaultName: String, name: String, countryCodes: [CountryCode]) {
        self.code = code
        self.defaultName = defaultName
        self.name = name
        self.countryCodes = countryCodes
    }
}

public func getCountriesList(network: Network, langCode: String) -> Signal<[Country], NoError> {
    return network.request(Api.functions.help.getCountriesList(langCode: langCode, hash: 0))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.help.CountriesList?, NoError> in
        return .single(nil)
    }
    |> map { result in
        if let result = result {
            switch result {
                case let .countriesList(apiCountries, hash):
                    return apiCountries.map { Country(apiCountry: $0) }
                case .countriesListNotModified:
                    return []
            }
        } else {
            return []
        }
    }
}

extension Country.CountryCode {
    init(apiCountryCode: Api.help.CountryCode) {
        switch apiCountryCode {
            case let .countryCode(_, countryCode, apiPrefixes, apiPatterns):
                let prefixes: [String] = apiPrefixes.flatMap { $0 } ?? []
                let patterns: [String] = apiPatterns.flatMap { $0 } ?? []
                self.init(code: countryCode, prefixes: prefixes, patterns: patterns)
        }
    }
}

extension Country {
    init(apiCountry: Api.help.Country) {
        switch apiCountry {
            case let .country(iso2, defaultName, name, countryCodes):
                self.init(code: iso2, defaultName: defaultName, name: name, countryCodes: countryCodes.map { Country.CountryCode(apiCountryCode: $0) })
        }
    }
}
