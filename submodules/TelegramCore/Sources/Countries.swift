import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

public struct Country: PostboxCoding, Equatable {
    public static func == (lhs: Country, rhs: Country) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.localizedName == rhs.localizedName && lhs.countryCodes == rhs.countryCodes && lhs.hidden == rhs.hidden
    }
    
    public struct CountryCode: PostboxCoding, Equatable {
        public let code: String
        public let prefixes: [String]
        public let patterns: [String]
        
        public init(code: String, prefixes: [String], patterns: [String]) {
            self.code = code
            self.prefixes = prefixes
            self.patterns = patterns
        }
        
        public init(decoder: PostboxDecoder) {
            self.code = decoder.decodeStringForKey("c", orElse: "")
            self.prefixes = decoder.decodeStringArrayForKey("pfx")
            self.patterns = decoder.decodeStringArrayForKey("ptrn")
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeString(self.code, forKey: "c")
            encoder.encodeStringArray(self.prefixes, forKey: "pfx")
            encoder.encodeStringArray(self.patterns, forKey: "ptrn")
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
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeStringForKey("c", orElse: "")
        self.name = decoder.decodeStringForKey("n", orElse: "")
        self.localizedName = decoder.decodeOptionalStringForKey("ln")
        self.countryCodes = decoder.decodeObjectArrayForKey("cc").map { $0 as! CountryCode }
        self.hidden = decoder.decodeBoolForKey("h", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.id, forKey: "c")
        encoder.encodeString(self.name, forKey: "n")
        if let localizedName = self.localizedName {
            encoder.encodeString(localizedName, forKey: "ln")
        } else {
            encoder.encodeNil(forKey: "ln")
        }
        encoder.encodeObjectArray(self.countryCodes, forKey: "cc")
        encoder.encodeBool(self.hidden, forKey: "h")
    }
}

public final class CountriesList: PreferencesEntry, Equatable {
    public let countries: [Country]
    public let hash: Int32
 
    public init(countries: [Country], hash: Int32) {
        self.countries = countries
        self.hash = hash
    }
    
    public init(decoder: PostboxDecoder) {
        self.countries = decoder.decodeObjectArrayForKey("c").map { $0 as! Country }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.countries, forKey: "c")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? CountriesList {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: CountriesList, rhs: CountriesList) -> Bool {
        return lhs.countries == rhs.countries && lhs.hash == rhs.hash
    }
}


public func getCountriesList(accountManager: AccountManager, network: Network, langCode: String?, forceUpdate: Bool = false) -> Signal<[Country], NoError> {
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
                                return CountriesList(countries: result, hash: hash)
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
            if let countriesList = sharedData.entries[SharedDataKeys.countriesList] as? CountriesList {
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
