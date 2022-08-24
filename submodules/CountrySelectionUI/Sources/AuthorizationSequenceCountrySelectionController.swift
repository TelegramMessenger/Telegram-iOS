import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import SearchBarNode
import AppBundle
import TelegramCore

private func loadCountryCodes() -> [Country] {
    guard let filePath = getAppBundle().path(forResource: "PhoneCountries", ofType: "txt") else {
        return []
    }
    guard let stringData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        return []
    }
    guard let data = String(data: stringData, encoding: .utf8) else {
        return []
    }
    
    let delimiter = ";"
    let endOfLine = "\n"
    
    var result: [Country] = []
    var countriesByPrefix: [String: (Country, Country.CountryCode)] = [:]
    
    var currentLocation = data.startIndex
    
    let locale = Locale(identifier: "en-US")
    
    while true {
        guard let codeRange = data.range(of: delimiter, options: [], range: currentLocation ..< data.endIndex) else {
            break
        }
        
        let countryCode = String(data[currentLocation ..< codeRange.lowerBound])
        
        guard let idRange = data.range(of: delimiter, options: [], range: codeRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let countryId = String(data[codeRange.upperBound ..< idRange.lowerBound])
        
        guard let patternRange = data.range(of: delimiter, options: [], range: idRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let pattern = String(data[idRange.upperBound ..< patternRange.lowerBound])
        
        let maybeNameRange = data.range(of: endOfLine, options: [], range: patternRange.upperBound ..< data.endIndex)
        
        let countryName = locale.localizedString(forIdentifier: countryId) ?? ""
        if let _ = Int(countryCode) {
            let code = Country.CountryCode(code: countryCode, prefixes: [], patterns: !pattern.isEmpty ? [pattern] : [])
            let country = Country(id: countryId, name: countryName, localizedName: nil, countryCodes: [code], hidden: false)
            result.append(country)
            countriesByPrefix["\(code.code)"] = (country, code)
        }
        
        if let maybeNameRange = maybeNameRange {
            currentLocation = maybeNameRange.upperBound
        } else {
            break
        }
    }
    
    countryCodesByPrefix = countriesByPrefix
    
    return result
}

private var countryCodes: [Country] = loadCountryCodes()
private var countryCodesByPrefix: [String: (Country, Country.CountryCode)] = [:]

public func loadServerCountryCodes(accountManager: AccountManager<TelegramAccountManagerTypes>, engine: TelegramEngineUnauthorized, completion: @escaping () -> Void) {
    let _ = (engine.localization.getCountriesList(accountManager: accountManager, langCode: nil)
    |> deliverOnMainQueue).start(next: { countries in
        countryCodes = countries
        
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
        countryCodesByPrefix = countriesByPrefix
                
        Queue.mainQueue().async {
            completion()
        }
    })
}

public func loadServerCountryCodes(accountManager: AccountManager<TelegramAccountManagerTypes>, engine: TelegramEngine, completion: @escaping () -> Void) {
    let _ = (engine.localization.getCountriesList(accountManager: accountManager, langCode: nil)
    |> deliverOnMainQueue).start(next: { countries in
        countryCodes = countries

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
        countryCodesByPrefix = countriesByPrefix
        Queue.mainQueue().async {
            completion()
        }
    })
}

private final class AuthorizationSequenceCountrySelectionNavigationContentNode: NavigationBarContentNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, cancel: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme), strings: strings, fieldStyle: .modern)
        let placeholderText = strings.Common_Search
        let searchBarFont = Font.regular(17.0)
        
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    override var nominalHeight: CGFloat {
        return 54.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 54.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}

private func removePlus(_ text: String?) -> String {
    var result = ""
    if let text = text {
        for c in text {
            if c != "+" {
                result += String(c)
            }
        }
    }
    return result
}

public final class AuthorizationSequenceCountrySelectionController: ViewController {
    static func countries() -> [Country] {
        return countryCodes
    }
    
    public static func lookupCountryNameById(_ id: String, strings: PresentationStrings) -> String? {
        for country in self.countries() {
            if id == country.id {
                let locale = localeWithStrings(strings)
                if let countryName = locale.localizedString(forRegionCode: id) {
                    return countryName
                } else {
                    return nil
                }
            }
        }
        return nil
    }
        
    static func lookupCountryById(_ id: String) -> Country? {
        return countryCodes.first { $0.id == id }
    }
    
    public static func lookupCountryIdByNumber(_ number: String, preferredCountries: [String: String]) -> (Country, Country.CountryCode)? {
        let number = removePlus(number)
        var results: [(Country, Country.CountryCode)]? = nil
        if number.count == 1, let preferredCountryId = preferredCountries[number], let country = lookupCountryById(preferredCountryId), let code = country.countryCodes.first {
            return (country, code)
        }
        
        for i in 0..<number.count {
            let prefix = String(number.prefix(number.count - i))
            if let country = countryCodesByPrefix[prefix] {
                if var currentResults = results {
                    if let result = currentResults.first, result.1.code.count > country.1.code.count {
                        break
                    } else {
                        currentResults.append(country)
                    }
                } else {
                    results = [country]
                }
            }
        }
        if let results = results {
            if !preferredCountries.isEmpty, let (_, code) = results.first {
                if let preferredCountry = preferredCountries[code.code] {
                    for (country, code) in results {
                        if country.id == preferredCountry {
                            return (country, code)
                        }
                    }
                }
            }
            return results.first
        } else {
            return nil
        }
    }
    
    public static func lookupCountryIdByCode(_ code: Int) -> String? {
        for country in self.countries() {
            for countryCode in country.countryCodes {
                if countryCode.code == "\(code)" {
                    return country.id
                }
            }
        }
        return nil
    }
    
    public static func lookupPatternByNumber(_ number: String, preferredCountries: [String: String]) -> String? {
        let number = removePlus(number)
        if let (_, code) = lookupCountryIdByNumber(number, preferredCountries: preferredCountries), !code.patterns.isEmpty {
            var prefixes: [String: String] = [:]
            for pattern in code.patterns {
                let cleanPattern = pattern.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "X", with: "")
                let cleanPrefix = "\(code.code)\(cleanPattern)"
                prefixes[cleanPrefix] = pattern
            }
            for i in 0..<number.count {
                let prefix = String(number.prefix(number.count - i))
                if let pattern = prefixes[prefix] {
                    return pattern
                }
            }
            return code.patterns.first
        }
        return nil
    }
    
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let displayCodes: Bool
    
    private var navigationContentNode: AuthorizationSequenceCountrySelectionNavigationContentNode?
    
    private var controllerNode: AuthorizationSequenceCountrySelectionControllerNode {
        return self.displayNode as! AuthorizationSequenceCountrySelectionControllerNode
    }
    
    public var completeWithCountryCode: ((Int, String) -> Void)?
    public var dismissed: (() -> Void)?
    
    public init(strings: PresentationStrings, theme: PresentationTheme, displayCodes: Bool = true) {
        self.theme = theme
        self.strings = strings
        self.displayCodes = displayCodes
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.navigationPresentation = .modal
        
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        
        let navigationContentNode = AuthorizationSequenceCountrySelectionNavigationContentNode(theme: theme, strings: strings, cancel: { [weak self] in
            self?.dismissed?()
            self?.dismiss()
        })
        self.navigationContentNode = navigationContentNode
        navigationContentNode.setQueryUpdated { [weak self] query in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            strongSelf.controllerNode.updateSearchQuery(query)
        }
        self.navigationBar?.setContentNode(navigationContentNode, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceCountrySelectionControllerNode(theme: self.theme, strings: self.strings, displayCodes: self.displayCodes, itemSelected: { [weak self] args in
            let (_, countryId, code) = args
            self?.completeWithCountryCode?(code, countryId)
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Queue.mainQueue().justDispatch {
            self.navigationContentNode?.activate()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    private func cancelPressed() {
        self.dismissed?()
        self.dismiss(completion: nil)
    }
}
