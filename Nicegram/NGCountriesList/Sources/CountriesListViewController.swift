import UIKit
import SnapKit
import NGCustomViews
import NGExtensions
import NGTheme

protocol CountriesListViewControllerInput { }

protocol CountriesListViewControllerOutput {
    func viewDidLoad()
    
    func didChangeSearchText(to: String)
}

final class CountriesListViewController: UIViewController, CountriesListViewControllerInput {
    
    //  MARK: - VIP
    
    var output: CountriesListViewControllerOutput!
    
    //  MARK: - Logic
    
    private var items: [DescriptionItemViewModel] = []
    
    //  MARK: - UI Elements
    
    private let ngTheme: NGThemeColors

    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    
    //  MARK: - Lifecycle

    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = ngTheme.backgroundColor
        
        tableView.backgroundColor = .clear
        tableView.register(DescriptionItemCell.self, forCellReuseIdentifier: DescriptionItemCell.reuseIdentifier)
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeArea.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.hidesNavigationBarDuringPresentation = false
            definesPresentationContext = true
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        
        tableView.dataSource = self
        
        output.viewDidLoad()
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}

extension CountriesListViewController: CountriesListPresenterOutput {
    func display(navigationTitle: String) {
        navigationItem.title = navigationTitle
    }
    
    func display(searchPlaceholder: String) {
        searchController.searchBar.placeholder = searchPlaceholder
    }
    
    func display(items: [DescriptionItemViewModel]) {
        self.items = items
        self.tableView.reloadData()
    }
}

extension CountriesListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DescriptionItemCell.reuseIdentifier, for: indexPath) as! DescriptionItemCell
        
        cell.ngTheme = ngTheme
        cell.imageContainerSize = CGSize(width: 29, height: 29)
        cell.imageSizeStrategy = .size(CGSize(width: 29, height: 29))
        cell.configureTitleImageView { imageView in
            imageView.contentMode = .scaleAspectFill
        }
        
        cell.display(item: items[indexPath.row])
        
        return cell
    }
}

extension CountriesListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        output.didChangeSearchText(to: searchController.searchBar.text ?? "")
    }
}
