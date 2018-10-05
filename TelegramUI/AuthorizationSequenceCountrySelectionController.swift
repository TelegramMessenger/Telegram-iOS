import Foundation
import Display
import AsyncDisplayKit

private func loadCountryCodes() -> [(String, Int)] {
    guard let filePath = frameworkBundle.path(forResource: "PhoneCountries", ofType: "txt") else {
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

final class AuthorizationSequenceCountrySelectionTheme {
    let statusBar: PresentationThemeStatusBarStyle
    let searchBar: SearchBarNodeTheme
    let listBackground: UIColor
    let listSeparator: UIColor
    let listAccent: UIColor
    let listPrimary: UIColor
    let listItemHighlight: UIColor
    
    init(statusBar: PresentationThemeStatusBarStyle, searchBar: SearchBarNodeTheme, listBackground: UIColor, listSeparator: UIColor, listAccent: UIColor, listPrimary: UIColor, listItemHighlight: UIColor) {
        self.statusBar = statusBar
        self.searchBar = searchBar
        self.listBackground = listBackground
        self.listSeparator = listSeparator
        self.listAccent = listAccent
        self.listPrimary = listPrimary
        self.listItemHighlight = listItemHighlight
    }
    
    convenience init(presentationTheme: PresentationTheme) {
        self.init(statusBar: presentationTheme.rootController.statusBar.style, searchBar: SearchBarNodeTheme(theme: presentationTheme), listBackground: presentationTheme.list.plainBackgroundColor, listSeparator: presentationTheme.list.itemPlainSeparatorColor, listAccent: presentationTheme.list.itemAccentColor, listPrimary: presentationTheme.list.itemPrimaryTextColor, listItemHighlight: presentationTheme.list.itemHighlightedBackgroundColor)
    }
    
    convenience init(authorizationTheme: AuthorizationTheme) {
        let keyboard: PresentationThemeKeyboardColor
        switch authorizationTheme.keyboardAppearance {
            case .dark:
                keyboard = .dark
            default:
                keyboard = .light
        }
        self.init(statusBar: PresentationThemeStatusBarStyle(authorizationTheme.statusBarStyle), searchBar: SearchBarNodeTheme(background: authorizationTheme.navigationBarBackgroundColor, separator: authorizationTheme.navigationBarSeparatorColor, inputFill: authorizationTheme.searchBarFillColor, primaryText: authorizationTheme.searchBarTextColor, placeholder: authorizationTheme.searchBarPlaceholderColor, inputIcon: authorizationTheme.searchBarPlaceholderColor, inputClear: authorizationTheme.searchBarPlaceholderColor, accent: authorizationTheme.accentColor, keyboard: keyboard), listBackground: authorizationTheme.backgroundColor, listSeparator: authorizationTheme.separatorColor, listAccent: authorizationTheme.accentColor, listPrimary: authorizationTheme.primaryColor, listItemHighlight: authorizationTheme.itemHighlightedBackgroundColor)
    }
}

private final class AuthorizationSequenceCountrySelectionNavigationContentNode: NavigationBarContentNode {
    private let theme: AuthorizationSequenceCountrySelectionTheme
    private let strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    
    init(theme: AuthorizationSequenceCountrySelectionTheme, strings: PresentationStrings, cancel: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: theme.searchBar, strings: strings)
        let placeholderText = strings.Common_Search
        let searchBarFont = Font.regular(14.0)
        
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.searchBar.placeholder)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query in
            self?.queryUpdated?(query)
        }
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let searchBarFrame = CGRect(origin: CGPoint(), size: size)
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: size, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}

final class AuthorizationSequenceCountrySelectionController: ViewController {
    static func lookupCountryNameById(_ id: String, strings: PresentationStrings) -> String? {
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
    static func lookupCountryIdByCode(_ code: Int) -> String? {
        for (itemId, itemCode) in countryCodes {
            if itemCode == code {
                return itemId
            }
        }
        return nil
    }
    
    private let theme: AuthorizationSequenceCountrySelectionTheme
    private let strings: PresentationStrings
    private let displayCodes: Bool
    
    private var navigationContentNode: AuthorizationSequenceCountrySelectionNavigationContentNode?
    
    private var controllerNode: AuthorizationSequenceCountrySelectionControllerNode {
        return self.displayNode as! AuthorizationSequenceCountrySelectionControllerNode
    }
    
    var completeWithCountryCode: ((Int, String) -> Void)?
    var dismissed: (() -> Void)?
    
    init(strings: PresentationStrings, theme: AuthorizationSequenceCountrySelectionTheme, displayCodes: Bool = true) {
        self.theme = theme
        self.strings = strings
        self.displayCodes = displayCodes
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: theme.searchBar.accent, disabledButtonColor: UIColor(rgb: 0xd0d0d0), primaryTextColor: theme.searchBar.primaryText, backgroundColor: theme.searchBar.background, separatorColor: theme.searchBar.separator, badgeBackgroundColor: theme.searchBar.accent, badgeStrokeColor: .clear, badgeTextColor: theme.searchBar.background), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.statusBar.statusBarStyle = theme.statusBar.style
        
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
    
    required init(coder aDecoder: NSCoder) {
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.animateIn()
        self.navigationContentNode?.activate()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func cancelPressed() {
        self.dismissed?()
        self.dismiss(completion: nil)
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.navigationContentNode?.deactivate()
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        })
    }
}
