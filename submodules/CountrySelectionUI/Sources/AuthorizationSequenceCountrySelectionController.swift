import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting
import SearchBarNode
import AppBundle

private func loadCountryCodes() -> [(String, Int)] {
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
    
    var result: [(String, Int)] = []
    
    var currentLocation = data.startIndex
    
    while true {
        guard let codeRange = data.range(of: delimiter, options: [], range: currentLocation ..< data.endIndex) else {
            break
        }
        
        let countryCode = String(data[currentLocation ..< codeRange.lowerBound])
        
        guard let idRange = data.range(of: delimiter, options: [], range: codeRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let countryId = String(data[codeRange.upperBound ..< idRange.lowerBound])
        
        let maybeNameRange = data.range(of: endOfLine, options: [], range: idRange.upperBound ..< data.endIndex)
        
        if let countryCodeInt = Int(countryCode) {
            result.append((countryId, countryCodeInt))
        }
        
        if let maybeNameRange = maybeNameRange {
            currentLocation = maybeNameRange.upperBound
        } else {
            break
        }
    }
    
    return result
}

private let countryCodes: [(String, Int)] = loadCountryCodes()

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
            //self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query in
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

public final class AuthorizationSequenceCountrySelectionController: ViewController {
    public static func lookupCountryNameById(_ id: String, strings: PresentationStrings) -> String? {
        for (itemId, _) in countryCodes {
            if id == itemId {
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
    
    public static func lookupCountryIdByCode(_ code: Int) -> String? {
        for (itemId, itemCode) in countryCodes {
            if itemCode == code {
                return itemId
            }
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
        
        self.navigationContentNode?.activate()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func cancelPressed() {
        self.dismissed?()
        self.dismiss(completion: nil)
    }
}
