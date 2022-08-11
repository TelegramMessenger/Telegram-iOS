import UIKit
import SnapKit
import NGAlert
import NGButton
import NGCustomViews
import NGExtensions
import NGLoadingIndicator
import NGPicker
import NGTheme

protocol PurchaseEsimViewControllerInput { }

protocol PurchaseEsimViewControllerOutput {
    func viewDidLoad()
    func selectOffer(with: Int)
    func purchaseTapped()
    func seeAllCountriesTapped()
    func retryPurchaseTapped()
    func retryFetchTapped()
}

final class PurchaseEsimViewController: UIViewController, PurchaseEsimViewControllerInput {
    
    //  MARK: - VIP
    
    var output: PurchaseEsimViewControllerOutput!
    
    //  MARK: - UI Elements
    
    private let ngTheme: NGThemeColors
    
    private let contentViewWrapper = PlaceholderableView(wrappedView: UIView())
    private var contentView: UIView { contentViewWrapper.wrappedView }
    
    private let picker = NGPicker<PickerTitleViewModel, NGPickerTitleCell>()
    private let cardView = HeaderCardView()
    private let pickerContainerView = UIView()
    private let mainSection: DescriptionsSectionView
    private let additionalSection: DescriptionsSectionView
    private let countriesSection: DescriptionsSectionView
    private let bottomView: BottomButtonView
    private let scrollView = UIScrollView()
    private let containerView = UIView()
    private let loadingIndicator = NGLoadingIndicator()
    
    //  MARK: - Lifecycle
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.mainSection = DescriptionsSectionView(ngTheme: ngTheme)
        self.additionalSection = DescriptionsSectionView(ngTheme: ngTheme)
        self.countriesSection = DescriptionsSectionView(ngTheme: ngTheme)
        self.bottomView = BottomButtonView(ngTheme: ngTheme)
        
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
        
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        
        embed(picker, in: pickerContainerView)
        picker.display = { [weak self] item, cell in
            cell.ngTheme = self?.ngTheme
            cell.display(item: item)
        }
        picker.onSelect = { [weak self] item in
            self?.output.selectOffer(with: item.id)
        }
        
        countriesSection.buttonTouchUpInside = { [weak self] in
            self?.output.seeAllCountriesTapped()
        }
        
        bottomView.buttonTouchUpInside = { [weak self] in
            self?.output.purchaseTapped()
        }
        
        output.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.adjustBottomInsetToNotBeCovered(by: bottomView)
    }
}

//  MARK: - Output

extension PurchaseEsimViewController: PurchaseEsimPresenterOutput {
    func display(navigationTitle: String) {
        navigationItem.title = navigationTitle
    }
    
    func displayHeader(item: HeaderCardViewModel) {
        cardView.display(item: item)
    }
    
    func display(pickerItems: [PickerTitleViewModel]) {
        picker.display(items: pickerItems)
    }
    
    func select(pirckerItemWith id: Int, animated: Bool) {
        picker.selectItem(with: id, animated: animated)
    }
    
    func displayMain(section: DescriptionsSectionViewModel) {
        mainSection.display(item: section)
    }
    
    func displayAdditional(section: DescriptionsSectionViewModel?) {
        if let section = section {
            additionalSection.display(item: section)
            additionalSection.isHidden = false
        } else {
            additionalSection.isHidden = true
        }
    }
    
    func displayCountries(section: DescriptionsSectionViewModel) {
        countriesSection.display(item: section)
    }

    func display(buttonTitle: String) {
        bottomView.display(buttonTitle: buttonTitle)
    }
    
    func displayPurchaseError(message: String) {
        NGAlertController.showRetryableErrorAlert(message: message, ngTheme: ngTheme, from: self) { [weak self] in
            self?.output.retryPurchaseTapped()
        }
    }
    
    func displayButton(isLoading: Bool) {
        bottomView.display(isLoading: isLoading)
    }
    
    func display(isLoading: Bool) {
        contentView.isHidden = isLoading
        if isLoading {
            loadingIndicator.startAnimating(on: self.view)
        } else {
            loadingIndicator.stopAnimating()
        }
    }
    
    func displayFetchError(message: String) {
        contentViewWrapper.showRetryPlaceholder(description: message) { [weak self] in
            self?.output.retryFetchTapped()
        }
    }
    
    func hidePlaceholders() {
        contentViewWrapper.hidePlaceholder()
    }
    
    func handleOrienation() {
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
}

//  MARK: - Private Functions

private extension PurchaseEsimViewController {
    func setupUI() {
        view.backgroundColor = ngTheme.cardColor
        
        mainSection.itemsSpacing = 12
        mainSection.configureDescriptionItemView = { view in
            view.imageContainerSize = CGSize(width: 29, height: 29)
        }
        
        additionalSection.configureDescriptionItemView = { view in
            view.imageContainerSize = CGSize(width: 29, height: 29)
        }
        
        countriesSection.configureDescriptionItemView = { view in
            view.imageContainerSize = CGSize(width: 29, height: 29)
            view.imageSizeStrategy = .size(CGSize(width: 29, height: 29))
            view.configureTitleImageView { imageView in
                imageView.contentMode = .scaleAspectFill
            }
        }
        
        scrollView.backgroundColor = ngTheme.backgroundColor
        
        let headerView = UIView()
        headerView.backgroundColor = ngTheme.cardColor
        
        let headerStack = UIStackView(arrangedSubviews: [cardView.padding(left: 8, right: 8), pickerContainerView])
        headerStack.axis = .vertical
        headerStack.spacing = 16
        
        headerView.addSubview(headerStack)
        pickerContainerView.snp.makeConstraints { make in
            make.height.equalTo(34)
        }
        headerStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(16)
        }
        
        let sectionsStack = UIStackView(arrangedSubviews: [mainSection, .separator(ngTheme: ngTheme), additionalSection, .separator(ngTheme: ngTheme), countriesSection])
        sectionsStack.axis = .vertical
        sectionsStack.spacing = 24
        sectionsStack.layoutMargins = UIEdgeInsets(top: 24, left: 16, bottom: 0, right: 16)
        sectionsStack.isLayoutMarginsRelativeArrangement = true
        if #available(iOS 11.0, *) {
            sectionsStack.insetsLayoutMarginsFromSafeArea = false
        }
        
        let stack = UIStackView(arrangedSubviews: [headerView, sectionsStack])
        stack.axis = .vertical
        stack.spacing = 0
        
        containerView.addSubview(stack)
        scrollView.addSubview(containerView)
        
        contentView.addSubview(scrollView)
        contentView.addSubview(bottomView)
        
        view.addSubview(contentViewWrapper)
        
        stack.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().priority(.low)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeArea.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        bottomView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        contentViewWrapper.snp.makeConstraints { make in
            make.top.equalTo(view.safeArea.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

private extension UIViewController {
    func embed(_ vc: UIViewController, in view: UIView) {
        addChild(vc)
        
        view.addSubview(vc.view)
        vc.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        vc.didMove(toParent: self)
    }
}
