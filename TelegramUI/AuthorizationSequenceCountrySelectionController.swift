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

func localizedContryNamesAndCodes(strings: PresentationStrings) -> [((String, String), String, Int)] {
    let locale = localeWithStrings(strings)
    var result: [((String, String), String, Int)] = []
    for (id, code) in countryCodes {
        if let englishCountryName = usEnglishLocale.localizedString(forRegionCode: id), let countryName = locale.localizedString(forRegionCode: id) {
            result.append(((englishCountryName, countryName), id, code))
        } else {
            assertionFailure()
        }
    }
    return result
}

private final class InnerCoutrySearchResultsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let displayCodes: Bool
    private let theme: AuthorizationTheme
    
    private let tableView: UITableView
    
    var searchResults: [((String, String), String, Int)] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    var itemSelected: ((((String, String), String, Int)) -> Void)?
    
    init(strings: PresentationStrings, theme: AuthorizationTheme, displayCodes: Bool) {
        self.displayCodes = displayCodes
        self.theme = theme
        
        self.tableView = UITableView(frame: CGRect(), style: .plain)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        self.view.addSubview(self.tableView)
        self.tableView.frame = self.view.bounds
        self.tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.tableView.backgroundColor = self.theme.backgroundColor
        self.tableView.separatorColor = self.theme.separatorColor
        self.tableView.backgroundView = UIView()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let currentCell = tableView.dequeueReusableCell(withIdentifier: "CountryCell") {
            cell = currentCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "CountryCell")
            let label = UILabel()
            label.font = Font.medium(17.0)
            cell.accessoryView = label
            cell.selectedBackgroundView = UIView()
        }
        cell.textLabel?.text = self.searchResults[indexPath.row].0.1
        cell.detailTextLabel?.text = self.searchResults[indexPath.row].0.0
        if self.displayCodes, let label = cell.accessoryView as? UILabel {
            label.text = "+\(self.searchResults[indexPath.row].2)"
            label.sizeToFit()
            label.textColor = self.theme.primaryColor
        }
        cell.textLabel?.textColor = self.theme.primaryColor
        cell.detailTextLabel?.textColor = self.theme.primaryColor
        cell.backgroundColor = self.theme.backgroundColor
        cell.selectedBackgroundView?.backgroundColor = self.theme.itemHighlightedBackgroundColor
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.itemSelected?(self.searchResults[indexPath.row])
    }
}

private final class InnerCountrySelectionController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchBarDelegate {
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    private let displayCodes: Bool
    
    private let tableView: UITableView
    
    private let sections: [(String, [((String, String), String, Int)])]
    private let sectionTitles: [String]
    
    private var searchController: UISearchController!
    private var searchResultsController: InnerCoutrySearchResultsController!
    
    var dismiss: (() -> Void)?
    var itemSelected: ((((String, String), String, Int)) -> Void)?
    
    init(strings: PresentationStrings, theme: AuthorizationTheme, displayCodes: Bool) {
        self.strings = strings
        self.theme = theme
        self.displayCodes = displayCodes
        
        self.tableView = UITableView(frame: CGRect(), style: .plain)
        
        let countryNamesAndCodes = localizedContryNamesAndCodes(strings: strings)
        
        var sections: [(String, [((String, String), String, Int)])] = []
        for (names, id, code) in countryNamesAndCodes.sorted(by: { lhs, rhs in
            return lhs.0 < rhs.0
        }) {
            let title = String(names.1[names.1.startIndex ..< names.1.index(after: names.1.startIndex)]).uppercased()
            if sections.isEmpty || sections[sections.count - 1].0 != title {
                sections.append((title, []))
            }
            sections[sections.count - 1].1.append((names, id, code))
        }
        self.sections = sections
        var sectionTitles = sections.map { $0.0 }
        sectionTitles.insert(UITableViewIndexSearch, at: 0)
        self.sectionTitles = sectionTitles
        
        super.init(nibName: nil, bundle: nil)
        
        self.title = strings.Login_SelectCountry_Title
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.definesPresentationContext = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        self.searchResultsController = InnerCoutrySearchResultsController(strings: self.strings, theme: self.theme, displayCodes: self.displayCodes)
        self.searchResultsController.itemSelected = { [weak self] item in
            self?.itemSelected?(item)
        }
        
        self.searchController = UISearchController(searchResultsController: self.searchResultsController)
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.searchController.searchBar.delegate = self
        self.searchController.searchBar.keyboardAppearance = self.theme.keyboardAppearance
        self.searchController.hidesNavigationBarDuringPresentation = true
        
        self.view.addSubview(self.tableView)
        self.tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.tableHeaderView = self.searchController.searchBar
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.sectionIndexColor = self.theme.accentColor
        
        self.tableView.backgroundColor = self.theme.backgroundColor
        self.tableView.separatorColor = self.theme.separatorColor
        self.tableView.backgroundView = UIView()
        
        self.tableView.frame = self.view.bounds
        self.view.addSubview(self.tableView)
        
        self.searchController.searchBar.barTintColor = self.theme.searchBarBackgroundColor
        self.searchController.searchBar.tintColor = self.theme.accentColor
        self.searchController.searchBar.backgroundColor = self.theme.searchBarBackgroundColor
        self.searchController.searchBar.setTextColor(theme.searchBarTextColor)
        
        
        let searchImage = generateImage(CGSize(width: 8.0, height: 28.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(self.theme.searchBarFillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - size.width), size: CGSize(width: size.width, height: size.width)))
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.width / 2.0), size: CGSize(width: size.width, height: size.height - size.width)))
        })
        self.searchController.searchBar.setSearchFieldBackgroundImage(searchImage, for: [])
        self.searchController.searchBar.backgroundImage = UIImage()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if #available(iOSApplicationExtension 11.0, *) {
            var frame = self.searchController.view.frame
            frame.origin.y = 12.0
            self.searchController.view.frame = frame
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        

    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].1.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].0
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.backgroundView?.backgroundColor = self.theme.backgroundColor
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = self.theme.primaryColor
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return self.sectionTitles
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if index == 0 {
            return 0
        } else {
            return max(0, index - 1)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let currentCell = tableView.dequeueReusableCell(withIdentifier: "CountryCell") {
            cell = currentCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "CountryCell")
            let label = UILabel()
            label.font = Font.medium(17.0)
            cell.accessoryView = label
            cell.selectedBackgroundView = UIView()
        }
        cell.textLabel?.text = self.sections[indexPath.section].1[indexPath.row].0.1
        cell.detailTextLabel?.text = self.sections[indexPath.section].1[indexPath.row].0.0
        if self.displayCodes, let label = cell.accessoryView as? UILabel {
            label.text = "+\(self.sections[indexPath.section].1[indexPath.row].2)"
            label.sizeToFit()
            label.textColor = self.theme.primaryColor
        }
        cell.textLabel?.textColor = self.theme.primaryColor
        cell.detailTextLabel?.textColor = self.theme.primaryColor
        cell.backgroundColor = self.theme.backgroundColor
        cell.selectedBackgroundView?.backgroundColor = self.theme.itemHighlightedBackgroundColor
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.itemSelected?(self.sections[indexPath.section].1[indexPath.row])
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let normalizedQuery = searchController.searchBar.text?.lowercased() else {
            self.searchResultsController.searchResults = []
            return
        }
        
        var results: [((String, String), String, Int)] = []
        for (_, items) in self.sections {
            for item in items {
                if item.0.0.lowercased().hasPrefix(normalizedQuery) || item.0.1.lowercased().hasPrefix(normalizedQuery) {
                    results.append(item)
                }
            }
        }
        self.searchResultsController.searchResults = results
    }
    
    @objc func cancelPressed() {
        self.dismiss?()
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
    
    private let theme: AuthorizationTheme
    
    private var controllerNode: AuthorizationSequenceCountrySelectionControllerNode {
        return self.displayNode as! AuthorizationSequenceCountrySelectionControllerNode
    }
    
    private let innerNavigationController: UINavigationController
    private let innerController: InnerCountrySelectionController
    
    var completeWithCountryCode: ((Int, String) -> Void)?
    
    init(strings: PresentationStrings, theme: AuthorizationTheme, displayCodes: Bool = true) {
        self.theme = theme
        self.innerController = InnerCountrySelectionController(strings: strings, theme: theme, displayCodes: displayCodes)
        self.innerNavigationController = UINavigationController(rootViewController: self.innerController)
        self.innerController.navigation_setNavigationController(self.innerNavigationController)
        self.innerNavigationController.navigationBar.barTintColor = theme.navigationBarBackgroundColor
        self.innerNavigationController.navigationBar.tintColor = theme.accentColor
        self.innerNavigationController.navigationBar.shadowImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.navigationBarSeparatorColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
        })
        self.innerNavigationController.navigationBar.isTranslucent = false
        self.innerNavigationController.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: Font.semibold(17.0), NSAttributedStringKey.foregroundColor: theme.navigationBarTextColor]
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = theme.statusBarStyle
        
        self.innerController.dismiss = { [weak self] in
            self?.cancelPressed()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceCountrySelectionControllerNode()
        self.displayNodeDidLoad()
        
        self.innerNavigationController.willMove(toParentViewController: self)
        self.addChildViewController(self.innerNavigationController)
        self.displayNode.view.addSubview(self.innerNavigationController.view)
        self.innerNavigationController.didMove(toParentViewController: self)
        
        self.innerController.itemSelected = { [weak self] args in
            let (_, countryId, code) = args
            self?.completeWithCountryCode?(code, countryId)
            self?.controllerNode.animateOut()
        }
        
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.innerNavigationController.viewWillAppear(false)
        self.innerNavigationController.viewDidAppear(false)
        
        self.controllerNode.animateIn()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        transition.animateView {
            self.innerNavigationController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            //self.innerController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
        }
    }
    
    private func cancelPressed() {
        self.controllerNode.animateOut()
    }
}
