import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public struct Country: Codable, Equatable {
    public static func == (lhs: Country, rhs: Country) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.localizedName == rhs.localizedName && lhs.countryCodes == rhs.countryCodes && lhs.hidden == rhs.hidden
    }
    
    public struct CountryCode: Codable, Equatable {
        public let code: String
        public let prefixes: [String]
        public let patterns: [String]
        
        public init(code: String, prefixes: [String], patterns: [String]) {
            self.code = code
            self.prefixes = prefixes
            self.patterns = patterns
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.code = try container.decode(String.self, forKey: "c")
            self.prefixes = try container.decode([String].self, forKey: "pfx")
            self.patterns = try container.decode([String].self, forKey: "ptrn")
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.code, forKey: "c")
            try container.encode(self.prefixes, forKey: "pfx")
            try container.encode(self.patterns, forKey: "ptrn")
        }
    }
    
    public let id: String
    public let name: String
    public let localizedName: String?
    public let countryCodes: [CountryCode]
    public let hidden: Bool
    
    public init(id: String, name: String, localizedName: String?, countryCodes: [CountryCode], hidden: Bool) {
        self.id = id
        self.name = name
        self.localizedName = localizedName
        self.countryCodes = countryCodes
        self.hidden = hidden
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.id = try container.decode(String.self, forKey: "c")
        self.name = try container.decode(String.self, forKey: "n")
        self.localizedName = try container.decodeIfPresent(String.self, forKey: "ln")
        self.countryCodes = try container.decode([CountryCode].self, forKey: "cc")
        self.hidden = try container.decode(Bool.self, forKey: "h")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.id, forKey: "c")
        try container.encode(self.name, forKey: "n")
        try container.encodeIfPresent(self.localizedName, forKey: "ln")
        try container.encode(self.countryCodes, forKey: "cc")
        try container.encode(self.hidden, forKey: "h")
    }
}

public final class CountriesList: Codable, Equatable {
    public let countries: [Country]
    public let hash: Int32
 
    public init(countries: [Country], hash: Int32) {
        self.countries = countries
        self.hash = hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.countries = try container.decode([Country].self, forKey: "c")
        self.hash = try container.decode(Int32.self, forKey: "h")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.countries, forKey: "c")
        try container.encode(self.hash, forKey: "h")
    }
    
    public static func ==(lhs: CountriesList, rhs: CountriesList) -> Bool {
        return lhs.countries == rhs.countries && lhs.hash == rhs.hash
    }
}


func _internal_getCountriesList(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, langCode: String?, forceUpdate: Bool = false) -> Signal<[Country], NoError> {
    let fetch: ([Country]?, Int32?) -> Signal<[Country], NoError> = { current, hash in
        return network.request(Api.functions.help.getCountriesList(langCode: langCode ?? "", hash: hash ?? 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<[Country], NoError> in
            switch result {
                case let .countriesList(apiCountries, hash):
                    let result = apiCountries.compactMap { Country(apiCountry: $0) }
                    if result == current {
                        return .complete()
                    } else {
                        let _ = accountManager.transaction { transaction in
                            transaction.updateSharedData(SharedDataKeys.countriesList, { _ in
                                return PreferencesEntry(CountriesList(countries: result, hash: hash))
                            })
                        }.start()
                        return .single(result)
                    }
                case .countriesListNotModified:
                    return .complete()
            }
        }
    }
    
    if forceUpdate {
        return fetch(nil, nil)
    } else {
        return accountManager.sharedData(keys: [SharedDataKeys.countriesList])
        |> take(1)
        |> map { sharedData -> ([Country], Int32) in
            if let countriesList = sharedData.entries[SharedDataKeys.countriesList]?.get(CountriesList.self) {
                return (countriesList.countries, countriesList.hash)
            } else {
                return ([], 0)
            }
        } |> mapToSignal { current, hash -> Signal<[Country], NoError> in
            return .single(current)
            |> then(fetch(current, hash))
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
            case let .country(flags, iso2, defaultName, name, countryCodes):
                self.init(id: iso2, name: defaultName, localizedName: name, countryCodes: countryCodes.map { Country.CountryCode(apiCountryCode: $0) }, hidden: (flags & 1 << 0) != 0)
        }
    }
}
