import Foundation
import Display
import AsyncDisplayKit

private let countryNamesAndCodes: [(String, Int)] = [
    ("Jamaica", 1876),
    ("Saint Kitts & Nevis", 1869),
    ("Trinidad & Tobago", 1868),
    ("Saint Vincent & the Grenadines", 1784),
    ("Dominica", 1767),
    ("Saint Lucia", 1758),
    ("Sint Maarten", 1721),
    ("American Samoa", 1684),
    ("Guam", 1671),
    ("Northern Mariana Islands", 1670),
    ("Montserrat", 1664),
    ("Turks & Caicos Islands", 1649),
    ("Grenada", 1473),
    ("Bermuda", 1441),
    ("Cayman Islands", 1345),
    ("US Virgin Islands", 1340),
    ("British Virgin Islands", 1284),
    ("Antigua & Barbuda", 1268),
    ("Anguilla", 1264),
    ("Barbados", 1246),
    ("Bahamas", 1242),
    ("Uzbekistan", 998),
    ("Kyrgyzstan", 996),
    ("Georgia", 995),
    ("Azerbaijan", 994),
    ("Turkmenistan", 993),
    ("Tajikistan", 992),
    ("Nepal", 977),
    ("Mongolia", 976),
    ("Bhutan", 975),
    ("Qatar", 974),
    ("Bahrain", 973),
    ("Israel", 972),
    ("United Arab Emirates", 971),
    ("Palestine", 970),
    ("Oman", 968),
    ("Yemen", 967),
    ("Saudi Arabia", 966),
    ("Kuwait", 965),
    ("Iraq", 964),
    ("Syrian Arab Republic", 963),
    ("Jordan", 962),
    ("Lebanon", 961),
    ("Maldives", 960),
    ("Taiwan", 886),
    ("Bangladesh", 880),
    ("Laos", 856),
    ("Cambodia", 855),
    ("Macau", 853),
    ("Hong Kong", 852),
    ("North Korea", 850),
    ("Marshall Islands", 692),
    ("Micronesia", 691),
    ("Tokelau", 690),
    ("French Polynesia", 689),
    ("Tuvalu", 688),
    ("New Caledonia", 687),
    ("Kiribati", 686),
    ("Samoa", 685),
    ("Niue", 683),
    ("Cook Islands", 682),
    ("Wallis & Futuna", 681),
    ("Palau", 680),
    ("Fiji", 679),
    ("Vanuatu", 678),
    ("Solomon Islands", 677),
    ("Tonga", 676),
    ("Papua New Guinea", 675),
    ("Nauru", 674),
    ("Brunei Darussalam", 673),
    ("Norfolk Island", 672),
    ("Timor-Leste", 670),
    ("Bonaire, Sint Eustatius & Saba", 599),
    ("Curaçao", 599),
    ("Uruguay", 598),
    ("Suriname", 597),
    ("Martinique", 596),
    ("Paraguay", 595),
    ("French Guiana", 594),
    ("Ecuador", 593),
    ("Guyana", 592),
    ("Bolivia", 591),
    ("Guadeloupe", 590),
    ("Haiti", 509),
    ("Saint Pierre & Miquelon", 508),
    ("Panama", 507),
    ("Costa Rica", 506),
    ("Nicaragua", 505),
    ("Honduras", 504),
    ("El Salvador", 503),
    ("Guatemala", 502),
    ("Belize", 501),
    ("Falkland Islands", 500),
    ("Liechtenstein", 423),
    ("Slovakia", 421),
    ("Czech Republic", 420),
    ("Macedonia", 389),
    ("Bosnia & Herzegovina", 387),
    ("Slovenia", 386),
    ("Croatia", 385),
    ("Montenegro", 382),
    ("Serbia", 381),
    ("Ukraine", 380),
    ("San Marino", 378),
    ("Monaco", 377),
    ("Andorra", 376),
    ("Belarus", 375),
    ("Armenia", 374),
    ("Moldova", 373),
    ("Estonia", 372),
    ("Latvia", 371),
    ("Lithuania", 370),
    ("Bulgaria", 359),
    ("Finland", 358),
    ("Cyprus", 357),
    ("Malta", 356),
    ("Albania", 355),
    ("Iceland", 354),
    ("Ireland", 353),
    ("Luxembourg", 352),
    ("Portugal", 351),
    ("Gibraltar", 350),
    ("Greenland", 299),
    ("Faroe Islands", 298),
    ("Aruba", 297),
    ("Eritrea", 291),
    ("Saint Helena", 290),
    ("Comoros", 269),
    ("Swaziland", 268),
    ("Botswana", 267),
    ("Lesotho", 266),
    ("Malawi", 265),
    ("Namibia", 264),
    ("Zimbabwe", 263),
    ("Réunion", 262),
    ("Madagascar", 261),
    ("Zambia", 260),
    ("Mozambique", 258),
    ("Burundi", 257),
    ("Uganda", 256),
    ("Tanzania", 255),
    ("Kenya", 254),
    ("Djibouti", 253),
    ("Somalia", 252),
    ("Ethiopia", 251),
    ("Rwanda", 250),
    ("Sudan", 249),
    ("Seychelles", 248),
    ("Saint Helena", 247),
    ("Diego Garcia", 246),
    ("Guinea-Bissau", 245),
    ("Angola", 244),
    ("Congo (Dem. Rep.)", 243),
    ("Congo (Rep.)", 242),
    ("Gabon", 241),
    ("Equatorial Guinea", 240),
    ("São Tomé & Príncipe", 239),
    ("Cape Verde", 238),
    ("Cameroon", 237),
    ("Central African Rep.", 236),
    ("Chad", 235),
    ("Nigeria", 234),
    ("Ghana", 233),
    ("Sierra Leone", 232),
    ("Liberia", 231),
    ("Mauritius", 230),
    ("Benin", 229),
    ("Togo", 228),
    ("Niger", 227),
    ("Burkina Faso", 226),
    ("Côte d`Ivoire", 225),
    ("Guinea", 224),
    ("Mali", 223),
    ("Mauritania", 222),
    ("Senegal", 221),
    ("Gambia", 220),
    ("Libya", 218),
    ("Tunisia", 216),
    ("Algeria", 213),
    ("Morocco", 212),
    ("South Sudan", 211),
    ("Iran", 98),
    ("Myanmar", 95),
    ("Sri Lanka", 94),
    ("Afghanistan", 93),
    ("Pakistan", 92),
    ("India", 91),
    ("Turkey", 90),
    ("China", 86),
    ("Vietnam", 84),
    ("South Korea", 82),
    ("Japan", 81),
    ("Thailand", 66),
    ("Singapore", 65),
    ("New Zealand", 64),
    ("Philippines", 63),
    ("Indonesia", 62),
    ("Australia", 61),
    ("Malaysia", 60),
    ("Venezuela", 58),
    ("Colombia", 57),
    ("Chile", 56),
    ("Brazil", 55),
    ("Argentina", 54),
    ("Cuba", 53),
    ("Mexico", 52),
    ("Peru", 51),
    ("Germany", 49),
    ("Poland", 48),
    ("Norway", 47),
    ("Sweden", 46),
    ("Denmark", 45),
    ("United Kingdom", 44),
    ("Austria", 43),
    ("Switzerland", 41),
    ("Romania", 40),
    ("Italy", 39),
    ("Hungary", 36),
    ("Spain", 34),
    ("France", 33),
    ("Belgium", 32),
    ("Netherlands", 31),
    ("Greece", 30),
    ("South Africa", 27),
    ("Egypt", 20),
    ("Russian Federation", 7),
    ("Kazakhstan", 7),
    ("USA", 1),
    ("Puerto Rico", 1),
    ("Dominican Rep.", 1),
    ("Canada", 1)
]

private final class InnerCoutrySearchResultsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let tableView: UITableView
    
    var searchResults: [(String, Int)] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    var itemSelected: (((String, Int)) -> Void)?
    
    init() {
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
        if let label = cell.accessoryView as? UILabel {
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
    private let tableView: UITableView
    
    private let sections: [(String, [(String, Int)])]
    private let sectionTitles: [String]
    
    private var searchController: UISearchController!
    private var searchResultsController: InnerCoutrySearchResultsController!
    
    var dismiss: (() -> Void)?
    var itemSelected: (((String, Int)) -> Void)?
    
    init() {
        self.tableView = UITableView(frame: CGRect(), style: .plain)
        
        var sections: [(String, [(String, Int)])] = []
        for (name, code) in countryNamesAndCodes.sorted(by: { lhs, rhs in
            return lhs.0 < rhs.0
        }) {
            let title = name.substring(to: name.index(after: name.startIndex)).uppercased()
            if sections.isEmpty || sections[sections.count - 1].0 != title {
                sections.append((title, []))
            }
            sections[sections.count - 1].1.append((name, code))
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
        
        self.searchResultsController = InnerCoutrySearchResultsController()
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
        if let label = cell.accessoryView as? UILabel {
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
        
        var results: [(String, Int)] = []
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
    private var controllerNode: AuthorizationSequenceCountrySelectionControllerNode {
        return self.displayNode as! AuthorizationSequenceCountrySelectionControllerNode
    }
    
    private let innerNavigationController: UINavigationController
    private let innerController: InnerCountrySelectionController
    
    var completeWithCountryCode: ((Int) -> Void)?
    
    override init(navigationBar: NavigationBar = NavigationBar()) {
        self.innerController = InnerCountrySelectionController()
        self.innerNavigationController = UINavigationController(rootViewController: self.innerController)
        
        super.init(navigationBar: navigationBar)
        
        self.navigationBar.isHidden = true
        
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
        
        self.innerController.itemSelected = { [weak self] _, code in
            self?.completeWithCountryCode?(code)
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
