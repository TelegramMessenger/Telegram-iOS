import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

extension UISearchBar {
    func setTextColor(_ color: UIColor) {
        for view in self.subviews {
            if let view = view as? UITextField {
                view.textColor = color
                return
            } else {
                for subview in view.subviews {
                    if let subview = subview as? UITextField {
                        subview.textColor = color
                    }
                }
            }
        }
    }
}

private final class LanguageAccessoryView: UIView {
    private let check: UIImageView
    private let indicator: ActivityIndicator
    
    init(theme: PresentationTheme) {
        self.check = UIImageView()
        self.check.image = PresentationResourcesItemList.checkIconImage(theme)
        
        self.indicator = ActivityIndicator(type: .custom(theme.list.itemAccentColor, 22.0, 1.0, false))
        
        super.init(frame: CGRect())
        
        self.addSubview(self.check)
        self.addSubnode(self.indicator)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeToFit() {
        self.frame = CGRect(origin: CGPoint(), size: self.check.image!.size)
        
        let size = self.bounds.size
        
        if let image = self.check.image {
            let checkSize = image.size
            self.check.frame = CGRect(origin: CGPoint(x: floor((size.width - checkSize.width) / 2.0), y: floor((size.height - checkSize.height) / 2.0)), size: checkSize)
        }
        
        let indicatorSize = self.indicator.measure(CGSize(width: 22.0, height: 22.0))
        self.indicator.frame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
    }
    
    func setType(_ type: Int) {
        switch type {
            case 0:
                self.check.isHidden = true
                self.indicator.isHidden = true
            case 1:
                self.check.isHidden = false
                self.indicator.isHidden = true
            case 2:
                self.check.isHidden = true
                self.indicator.isHidden = false
            default:
                break
        }
    }
}

private final class InnerCoutrySearchResultsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let tableView: UITableView
    private var presentationData: PresentationData
    
    var searchResults: [LocalizationInfo] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    var itemSelected: ((LocalizationInfo) -> Void)?
    
    init(presentationData : PresentationData) {
        self.tableView = UITableView(frame: CGRect(), style: .plain)
        self.presentationData = presentationData
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        self.view.addSubview(self.tableView)
        if #available(iOSApplicationExtension 11.0, *) {
            self.tableView.contentInsetAdjustmentBehavior = .never
        }
        self.tableView.frame = self.view.bounds
        self.tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        updateThemeAndStrings()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let currentCell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell") {
            cell = currentCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "LanguageCell")
            cell.selectedBackgroundView = UIView()
        }
        cell.textLabel?.text = self.searchResults[indexPath.row].title
        cell.detailTextLabel?.text = self.searchResults[indexPath.row].localizedTitle
        
        cell.textLabel?.textColor = self.presentationData.theme.chatList.titleColor
        cell.detailTextLabel?.textColor = self.presentationData.theme.chatList.titleColor
        cell.backgroundColor = self.presentationData.theme.chatList.itemBackgroundColor
        cell.selectedBackgroundView?.backgroundColor = self.presentationData.theme.chatList.itemHighlightedBackgroundColor
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.itemSelected?(self.searchResults[indexPath.row])
    }
    
    func updatePresentationData(_ presentationData : PresentationData) {
        let previousTheme = self.presentationData.theme
        let previousStrings = self.presentationData.strings
        
        self.presentationData = presentationData
        
        if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
            self.updateThemeAndStrings()
        }
    }
    
    private func updateThemeAndStrings() {
        self.view.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.tableView.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.tableView.separatorColor = self.presentationData.theme.chatList.itemSeparatorColor
        
        self.tableView.reloadData()
    }
}

private final class InnerLanguageSelectionController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchBarDelegate {
    private let account: Account
    
    private let tableView: UITableView
    
    private var languages: [LocalizationInfo]
    
    private var searchController: UISearchController!
    private var searchResultsController: InnerCoutrySearchResultsController!
    
    var dismiss: (() -> Void)?
    
    private var languagesDisposable: Disposable?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var applyingLanguage: (LocalizationInfo, Disposable)?
    
    init(account: Account) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.tableView = UITableView(frame: CGRect(), style: .plain)
        
        self.languages = []
        
        super.init(nibName: nil, bundle: nil)
        
        self.title = self.presentationData.strings.Settings_AppLanguage
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.definesPresentationContext = true
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    if strongSelf.searchResultsController != nil {
                        strongSelf.searchResultsController.updatePresentationData(presentationData)
                    }
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
                    }
                }
        })
        
        self.languagesDisposable = (availableLocalizations(postbox: account.postbox, network: account.network, allowCached: true)
            |> deliverOnMainQueue).start(next: { [weak self] languages in
                if let strongSelf = self {
                    strongSelf.languages = languages
                    if strongSelf.isViewLoaded {
                        strongSelf.tableView.reloadData()
                    }
                }
            })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.languagesDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.applyingLanguage?.1.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.title = self.presentationData.strings.Settings_AppLanguage
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        if self.isViewLoaded {
            self.searchController.searchBar.placeholder = self.presentationData.strings.Common_Search
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        self.searchResultsController = InnerCoutrySearchResultsController(presentationData: self.presentationData)
        self.searchResultsController.itemSelected = { [weak self] language in
            if let strongSelf = self {
                strongSelf.searchController.searchBar.resignFirstResponder()
                strongSelf.applyLanguage(language)
            }
        }
        
        self.searchController = UISearchController(searchResultsController: self.searchResultsController)
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = true
        self.searchController.searchBar.delegate = self
        self.searchController.searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 6.0, vertical: 0.0)
        
        self.tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(self.tableView)
        self.tableView.tableHeaderView = self.searchController.searchBar
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.tableView.separatorColor = self.presentationData.theme.chatList.itemSeparatorColor
        self.tableView.backgroundView = UIView()
        
        self.tableView.frame = self.view.bounds
        self.view.addSubview(self.tableView)
        
        self.searchController.searchBar.placeholder = self.presentationData.strings.Common_Search
        self.searchController.searchBar.barTintColor = self.presentationData.theme.chatList.backgroundColor
        self.searchController.searchBar.tintColor = self.presentationData.theme.rootController.navigationBar.accentTextColor
        self.searchController.searchBar.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.searchController.searchBar.setTextColor(self.presentationData.theme.chatList.titleColor)
        
        let searchImage = generateImage(CGSize(width: 8.0, height: 28.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(self.presentationData.theme.chatList.regularSearchBarColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - size.width), size: CGSize(width: size.width, height: size.width)))
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.width / 2.0), size: CGSize(width: size.width, height: size.height - size.width)))
        })
        self.searchController.searchBar.setSearchFieldBackgroundImage(searchImage, for: [])
        self.searchController.searchBar.backgroundImage = UIImage()
                
        if let textFieldOfSearchBar = self.searchController.searchBar.value(forKey: "searchField") as? UITextField {
            textFieldOfSearchBar.font = Font.regular(14.0)
            textFieldOfSearchBar.keyboardAppearance = self.presentationData.theme.chatList.searchBarKeyboardColor == .light ? .default : .dark
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.languages.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let currentCell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell") {
            cell = currentCell
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "LanguageCell")
            cell.selectedBackgroundView = UIView()
            cell.accessoryView = LanguageAccessoryView(theme: self.presentationData.theme)
            cell.accessoryView?.sizeToFit()
        }
        cell.textLabel?.text = self.languages[indexPath.row].title
        cell.textLabel?.textColor = self.presentationData.theme.chatList.titleColor
        cell.detailTextLabel?.text = self.languages[indexPath.row].localizedTitle
        cell.detailTextLabel?.textColor = self.presentationData.theme.chatList.titleColor
        cell.backgroundColor = self.presentationData.theme.chatList.itemBackgroundColor
        cell.selectedBackgroundView?.backgroundColor = self.presentationData.theme.chatList.itemHighlightedBackgroundColor
        
        var type: Int = 0
        if let (info, _) = self.applyingLanguage, info.languageCode == self.languages[indexPath.row].languageCode {
            type = 2
        } else if self.presentationData.strings.primaryComponent.languageCode == self.languages[indexPath.row].languageCode {
            type = 1
        }
        
        (cell.accessoryView as? LanguageAccessoryView)?.setType(type)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.applyLanguage(self.languages[indexPath.row])
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let normalizedQuery = searchController.searchBar.text?.lowercased() else {
            self.searchResultsController.searchResults = []
            return
        }
        
        var results: [LocalizationInfo] = []
        for language in self.languages {
            if language.title.lowercased().hasPrefix(normalizedQuery) || language.localizedTitle.lowercased().hasPrefix(normalizedQuery) {
                results.append(language)
            }
        }
        self.searchResultsController.searchResults = results
    }
    
    @objc func cancelPressed() {
        self.dismiss?()
    }
    
    private func applyLanguage(_ language: LocalizationInfo) {
        if let (info, disposable) = self.applyingLanguage {
            if info.languageCode == language.languageCode {
                return
            } else {
                disposable.dispose()
                self.applyingLanguage = nil
                self.tableView.reloadData()
            }
        }
        if language.languageCode != self.presentationData.strings.primaryComponent.languageCode {
            self.applyingLanguage = (language, (downloadAndApplyLocalization(postbox: self.account.postbox, network: self.account.network, languageCode: language.languageCode)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                if let strongSelf = self {
                    strongSelf.applyingLanguage = nil
                    strongSelf.tableView.reloadData()
                }
            }))
            self.tableView.reloadData()
        }
    }
}

final class LanguageSelectionController: ViewController {
    private var controllerNode: LanguageSelectionControllerNode {
        return self.displayNode as! LanguageSelectionControllerNode
    }
    
    private let innerNavigationController: UINavigationController
    private let innerController: InnerLanguageSelectionController
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    init(account: Account) {
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.innerController = InnerLanguageSelectionController(account: account)
        self.innerNavigationController = UINavigationController(rootViewController: self.innerController)
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.innerNavigationController.navigationBar.barTintColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.innerNavigationController.navigationBar.tintColor = self.presentationData.theme.rootController.navigationBar.accentTextColor
        self.innerNavigationController.navigationBar.shadowImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(self.presentationData.theme.rootController.navigationBar.separatorColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
        })
        self.innerNavigationController.navigationBar.isTranslucent = false
        self.innerNavigationController.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: Font.semibold(17.0), NSAttributedStringKey.foregroundColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor]
        
        self.innerController.dismiss = { [weak self] in
            self?.cancelPressed()
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
                    }
                }
            })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
    }
    
    override public func loadDisplayNode() {
        self.displayNode = LanguageSelectionControllerNode()
        self.displayNodeDidLoad()
        
        self.innerNavigationController.willMove(toParentViewController: self)
        self.addChildViewController(self.innerNavigationController)
        self.displayNode.view.addSubview(self.innerNavigationController.view)
        self.innerNavigationController.didMove(toParentViewController: self)
        
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
    }
    
    private func cancelPressed() {
        self.controllerNode.animateOut()
    }
}
