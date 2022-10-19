import UIKit
import SnapKit
import NGButton
import NGExtensions
import NGStrings

class OnboardingViewController: UIViewController {
    
    //  MARK: - UI Elements

    private let pagesStack = UIStackView()
    private let scrollView = UIScrollView()
    private let pageControl = UIStackView()
    private let nextButton = CustomButton()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
    
    //  MARK: - Handlers
    
    private let onComplete: () -> Void
    
    //  MARK: - Logic
    
    private let items: [OnboardingPageViewModel]
    private let languageCode: String
    
    //  MARK: - Lifecycle
    
    init(items: [OnboardingPageViewModel], languageCode: String, onComplete: @escaping () -> Void) {
        self.items = items
        self.languageCode = languageCode
        self.onComplete = onComplete
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = UIView()
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.delegate = self
        
        display(items: self.items)
        display(buttonTitle: l("NicegramOnboarding.Continue", languageCode))
        
        nextButton.touchUpInside = { [weak self] in
            self?.goToNextPage()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIApplication.shared.internalSetStatusBarHidden(true, animation: animated ? .fade : .none)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateViewAccordingToCurrentScrollOffset()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UIApplication.shared.internalSetStatusBarHidden(false, animation: animated ? .fade : .none)
    }
}

extension OnboardingViewController {
    func display(items: [OnboardingPageViewModel]) {
        pagesStack.removeAllArrangedSubviews()
        pageControl.removeAllArrangedSubviews()
        
        for item in items {
            let pageView = OnboardingPageView()
            pageView.display(item)
            
            pagesStack.addArrangedSubview(pageView)
            pageView.snp.makeConstraints { make in
                make.width.equalTo(scrollView)
            }
            
            let pageIndicator = UIView()
            pageIndicator.layer.cornerRadius = 4
            pageIndicator.snp.makeConstraints { make in
                make.width.equalTo(8)
            }
            pageControl.addArrangedSubview(pageIndicator)
        }
    }
    
    func display(buttonTitle: String) {
        nextButton.display(title: buttonTitle, image: nil)
    }
}

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateViewAccordingToCurrentScrollOffset()
    }
}

//  MARK: - Private Functions

private extension OnboardingViewController {
    func goToNextPage() {
        let scrollViewWidth = scrollView.frame.width
        guard !scrollViewWidth.isZero else { return }
        
        let currentPage = (scrollView.contentOffset.x + (0.5 * scrollViewWidth)) / scrollViewWidth
        
        let nextPage = Int(currentPage) + 1
        guard items.indices.contains(nextPage) else {
            onComplete()
            return
        }
        
        let visibleRect = CGRect(
            origin: CGPoint(
                x: scrollViewWidth * CGFloat(nextPage),
                y: 0
            ),
            size: scrollView.frame.size
        )
        scrollView.scrollRectToVisible(visibleRect, animated: true)
    }
    
    func updateViewAccordingToCurrentScrollOffset() {
        let offset = scrollView.contentOffset
        let scrollViewSize = scrollView.frame.size
        guard !scrollViewSize.width.isZero else { return }
        
        let pageViews = (pagesStack.arrangedSubviews as? [OnboardingPageView]) ?? []
        for (index, pageView) in pageViews.enumerated() {
            let pageFrame = pageView.frame
            let visibleRect = CGRect(origin: offset, size: scrollViewSize)
            let intersection = pageFrame.intersection(visibleRect)
            
            let fractionWidth = intersection.width / scrollViewSize.width
            
            let pageIndicatorColor = linearInterpolatedColor(from: Constants.inactivePageIndicatorColor, to: Constants.activePageIndicatorColor, fraction: fractionWidth)
            let pageIndicatorWidth = Constants.inactivePageIndicatorWidth + (Constants.activePageIndicatorWidth - Constants.inactivePageIndicatorWidth) * fractionWidth
            
            let pageIndicator = pageControl.arrangedSubviews[index]
            pageIndicator.backgroundColor = pageIndicatorColor
            pageIndicator.snp.updateConstraints { make in
                make.width.equalTo(pageIndicatorWidth)
            }
        
            pageControl.layoutIfNeeded()
            
            var pageView = pageView
            if UIView.userInterfaceLayoutDirection(for: scrollView.semanticContentAttribute) == .rightToLeft {
                pageView = pageViews[pageViews.count - index - 1]
            }
            if fractionWidth >= 0.5 {
                pageView.playVideo()
            } else {
                pageView.pauseVideo()
            }
        }
    }
}

//  MARK: - Constants

private extension OnboardingViewController {
    struct Constants {
        static let inactivePageIndicatorColor = UIColor.ngInactiveButton
        static let activePageIndicatorColor = UIColor.white
        
        static let inactivePageIndicatorWidth = CGFloat(8)
        static let activePageIndicatorWidth = CGFloat(24)
    }
}

//  MARK: - Setup UI

private extension OnboardingViewController {
    func setupUI() {
        view.backgroundColor = .black
        
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        
        pageControl.spacing = 8
        
        nextButton.applyMainActionStyle()
        
        for view in [scrollView, pagesStack, pageControl] {
            if UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .rightToLeft {
                view.transform = CGAffineTransform(rotationAngle: .pi)
            }
        }
        
        let scrollContentView = UIView()
        
        scrollContentView.addSubview(pagesStack)
        pagesStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        scrollView.addSubview(scrollContentView)
        scrollContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalToSuperview().priority(1)
        }
        
        view.addSubview(scrollView)
        view.addSubview(pageControl)
        view.addSubview(nextButton)
        
        nextButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(self.view.safeArea.bottom).inset(50)
        }
        
        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(nextButton.snp.top).offset(-32)
            make.height.equalTo(8)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(pageControl.snp.top).offset(-32)
        }
    }
}
