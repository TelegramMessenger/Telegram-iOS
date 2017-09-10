import Foundation
import Display
import AsyncDisplayKit

private func loadCountryNamesAndCodes() -> [(String, String, Int)] {
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
    
    var result: [(String, String, Int)] = []
    
    var currentLocation = data.startIndex
    
    while true {
        guard let codeRange = data.range(of: delimiter, options: [], range: currentLocation ..< data.endIndex) else {
            break
        }
        
        let countryCode = data.substring(with: currentLocation ..< codeRange.lowerBound)
        
        guard let idRange = data.range(of: delimiter, options: [], range: codeRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let countryId = data.substring(with: codeRange.upperBound ..< idRange.lowerBound)
        
        let maybeNameRange = data.range(of: endOfLine, options: [], range: idRange.upperBound ..< data.endIndex)
        let nameRangeIndex = maybeNameRange?.lowerBound ?? data.endIndex
        
        var countryName = data.substring(with: idRange.upperBound ..< nameRangeIndex)
        if countryName.hasSuffix("\r") {
            countryName = countryName.substring(to: countryName.index(before: countryName.endIndex))
        }
        
        if let countryCodeInt = Int(countryCode) {
            result.append((countryName, countryId, countryCodeInt))
        }
        
        if let maybeNameRange = maybeNameRange {
            currentLocation = maybeNameRange.upperBound
        } else {
            break
        }
    }
    
    return result
}

private let countryNamesAndCodes: [(String, String, Int)] = loadCountryNamesAndCodes()

private final class InnerCoutrySearchResultsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let displayCodes: Bool
    
    private let tableView: UITableView
    
    var searchResults: [(String, String, Int)] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    var itemSelected: (((String, String, Int)) -> Void)?
    
    init(displayCodes: Bool) {
        self.displayCodes = displayCodes
        
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
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let currentCell = tableView.dequeueReusableCell(withIdentifier: "CountryCell") {
            cell = currentCell
        } else {
            cell = UITableViewCell()
            let label = UILabel()
            label.font = Font.medium(17.0)
            cell.accessoryView = label
        }
        cell.textLabel?.text = self.searchResults[indexPath.row].0
        if self.displayCodes, let label = cell.accessoryView as? UILabel {
            label.text = "+\(self.searchResults[indexPath.row].1)"
            label.sizeToFit()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.itemSelected?(self.searchResults[indexPath.row])
    }
}

private final class InnerCountrySelectionController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchBarDelegate {
    private let displayCodes: Bool
    
    private let tableView: UITableView
    
    private let sections: [(String, [(String, String, Int)])]
    private let sectionTitles: [String]
    
    private var searchController: UISearchController!
    private var searchResultsController: InnerCoutrySearchResultsController!
    
    var dismiss: (() -> Void)?
    var itemSelected: (((String, String, Int)) -> Void)?
    
    init(displayCodes: Bool) {
        self.displayCodes = displayCodes
        
        self.tableView = UITableView(frame: CGRect(), style: .plain)
        
        var sections: [(String, [(String, String, Int)])] = []
        for (name, id, code) in countryNamesAndCodes.sorted(by: { lhs, rhs in
            return lhs.0 < rhs.0
        }) {
            let title = name.substring(to: name.index(after: name.startIndex)).uppercased()
            if sections.isEmpty || sections[sections.count - 1].0 != title {
                sections.append((title, []))
            }
            sections[sections.count - 1].1.append((name, id, code))
        }
        self.sections = sections
        var sectionTitles = sections.map { $0.0 }
        sectionTitles.insert(UITableViewIndexSearch, at: 0)
        self.sectionTitles = sectionTitles
        
        super.init(nibName: nil, bundle: nil)
        
        self.title = "Select Country"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.definesPresentationContext = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        self.searchResultsController = InnerCoutrySearchResultsController(displayCodes: self.displayCodes)
        self.searchResultsController.itemSelected = { [weak self] item in
            self?.itemSelected?(item)
        }
        
        self.searchController = UISearchController(searchResultsController: self.searchResultsController)
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = true
        self.searchController.searchBar.delegate = self
        
        self.view.addSubview(self.tableView)
        self.tableView.tableHeaderView = self.searchController.searchBar
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.tableView.frame = self.view.bounds
        self.view.addSubview(self.tableView)
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
            cell = UITableViewCell()
            let label = UILabel()
            label.font = Font.medium(17.0)
            cell.accessoryView = label
        }
        cell.textLabel?.text = self.sections[indexPath.section].1[indexPath.row].0
        if self.displayCodes, let label = cell.accessoryView as? UILabel {
            label.text = "+\(self.sections[indexPath.section].1[indexPath.row].1)"
            label.sizeToFit()
        }
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
        
        var results: [(String, String, Int)] = []
        for (_, items) in self.sections {
            for item in items {
                if item.0.lowercased().hasPrefix(normalizedQuery) {
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
    static func lookupCountryNameById(_ id: String) -> String? {
        for (name, itemId, _) in countryNamesAndCodes {
            if id == itemId {
                return name
            }
        }
        return nil
    }
    
    private var controllerNode: AuthorizationSequenceCountrySelectionControllerNode {
        return self.displayNode as! AuthorizationSequenceCountrySelectionControllerNode
    }
    
    private let innerNavigationController: UINavigationController
    private let innerController: InnerCountrySelectionController
    
    var completeWithCountryCode: ((Int, String) -> Void)?
    
    init(displayCodes: Bool = true) {
        self.innerController = InnerCountrySelectionController(displayCodes: displayCodes)
        self.innerNavigationController = UINavigationController(rootViewController: self.innerController)
        
        super.init(navigationBarTheme: nil)
        
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
        
        self.innerNavigationController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.innerController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
        //self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
    
    private func cancelPressed() {
        self.controllerNode.animateOut()
    }
}
