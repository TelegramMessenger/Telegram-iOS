import UIKit
import SnapKit
import NGAlert
import NGCustomViews
import NGExtensions
import NGLoadingIndicator
import NGToast
import NGTheme

protocol MyEsimsViewControllerInput { }

protocol MyEsimsViewControllerOutput {
    func viewDidLoad()
    func didTapGetNewEsim()
    func didTapOnEsim(with: String)
    func didTapTopUpOnEsim(with: String)
    func didTapCopyPhoneOnEsim(with: String)
    func didTapFaqOnEsim(with: String)
    func didTapRetryFetch()
    func didPullToRefresh()
}

final class MyEsimsViewController: UIViewController, MyEsimsViewControllerInput {
    
    //  MARK: - VIP
    
    var output: MyEsimsViewControllerOutput!
    
    //  MARK: - UI Elements
    
    private let ngTheme: NGThemeColors
    
    private let headerView: NavigationHeaderView
    private let tableViewWrapper = PlaceholderableView(wrappedView: UITableView(frame: .zero, style: .grouped))
    private var tableView: UITableView { tableViewWrapper.wrappedView }
    private let refreshControl = UIRefreshControl()
    private let loadingIndicator = NGLoadingIndicator()
    
    //  MARK: - Logic

    private var items: [MyEsimViewModel] = []
    private var sectionTitle: String?

    //  MARK: - Lifecycle
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.headerView = NavigationHeaderView(ngTheme: ngTheme)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = UIView()
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        refreshControl.addTarget(self, action: #selector(refreshControlValueChanged), for: .valueChanged)
        
        headerView.onButtonTap = { [weak self] in
            self?.output.didTapGetNewEsim()
        }
        
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

//  MARK: - Output

extension MyEsimsViewController: MyEsimsPresenterOutput {    
    func displayHeader(title: String, buttonImage: UIImage) {
        headerView.display(title: title, buttonImage: buttonImage)
    }
    
    func display(sectionTitle: String) {
        self.sectionTitle = sectionTitle
        tableView.reloadData()
    }
    
    func display(items: [MyEsimViewModel]) {
        self.items = items
        self.tableView.reloadData()
    }
    
    func displayEmptyState(message: String, buttonTitle: String) {
        tableView.isScrollEnabled = false
        tableViewWrapper.showEmptyStatePlaceholder(description: message, buttonTitle: buttonTitle) { [weak self] in
            self?.output.didTapGetNewEsim()
        }
    }
    
    func displayFetchErrorAsPlaceholder(message: String) {
        tableView.isScrollEnabled = false
        tableViewWrapper.showRetryPlaceholder(description: message) { [weak self] in
            self?.output.didTapRetryFetch()
        }
    }

    func displayErrorToast(message: String) {
        NGToast.showErrorToast(message: message)
    }
    
    func displayErrorModal(message: String) {
        NGAlertController.showErrorAlert(message: message, ngTheme: ngTheme, from: self)
    }
    
    func display(isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating(on: self.view)
        } else {
            loadingIndicator.stopAnimating()
        }
    }
    
    func display(isRefreshing: Bool) {
        if isRefreshing {
            refreshControl.beginRefreshing()
        } else {
            refreshControl.endRefreshing()
        }
    }
    
    func hidePlaceholder() {
        tableView.isScrollEnabled = true
        tableViewWrapper.hidePlaceholder()
    }
    
    func copy(text: String) {
        UIPasteboard.general.string = text
        NGToast.showCopiedToast()
    }
}

//  MARK: - Data Source

extension MyEsimsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MyEsimCell.reuseIdentifier, for: indexPath) as! MyEsimCell
        
        cell.ngTheme = ngTheme
        
        let item = items[indexPath.row]
        cell.display(item: item)
        
        cell.onTap = { [weak self] in
            self?.output.didTapOnEsim(with: item.id)
        }
        
        cell.onTopUpTap = { [weak self] in
            self?.output.didTapTopUpOnEsim(with: item.id)
        }
        
        cell.onCopyPhoneTap = { [weak self] in
            self?.output.didTapCopyPhoneOnEsim(with: item.id)
        }
        
        cell.onFaqTap = { [weak self] in
            self?.output.didTapFaqOnEsim(with: item.id)
        }
        
        return cell
    }
}

extension MyEsimsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .ngSubtitle
        label.text = sectionTitle
        
        let view = UIView()
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(2)
            make.top.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().inset(16)
        }
        
        return view
    }
}

//  MARK: - Private Functions

private extension MyEsimsViewController {
    func setupUI() {
        view.backgroundColor = ngTheme.backgroundColor
        
        headerView.configureTitleButton { btn in
            btn.imageSizeStrategy = .size(CGSize(width: 24, height: 24))
        }
        
        tableViewWrapper.shouldHideWrappedView = false
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset.top = 24
        tableView.estimatedRowHeight = 200
        tableView.register(MyEsimCell.self, forCellReuseIdentifier: MyEsimCell.reuseIdentifier)
        
        refreshControl.tintColor = ngTheme.reverseTitleColor.withAlphaComponent(0.6)
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        }
        
        view.addSubview(headerView)
        view.addSubview(tableViewWrapper)
        
        headerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        tableViewWrapper.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    @objc func refreshControlValueChanged() {
        output.didPullToRefresh()
    }
}
