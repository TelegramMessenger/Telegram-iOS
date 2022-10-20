import UIKit
import WebKit
import SnapKit
import Lottie
import EsimUI
import NGButton
import NGCustomViews
import NGTheme

protocol SpecialOfferViewControllerInput { }

protocol SpecialOfferViewControllerOutput {
    func viewDidLoad()
    func viewDidAppear()
    func didTapClose()
    func didTapRetry()
    func didTapSpecialOffer(url: URL)
}

final class SpecialOfferViewController: UIViewController, SpecialOfferViewControllerInput {
    
    //  MARK: - VIP
    
    var output: SpecialOfferViewControllerOutput!

    //  MARK: - UI Elements

    private let ngTheme: NGThemeColors
    private let contentView = UIView()
    private let webViewWrapper = PlaceholderableView(wrappedView: WKWebView())
    private var webView: WKWebView { webViewWrapper.wrappedView }
    private let closeButton = CustomButton()
    
    private let popupTransition: PopupTransition

    //  MARK: - Lifecycle
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.popupTransition = PopupTransition(blurStyle: ngTheme.blurStyle)
        
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = popupTransition
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = UIView()
        setupUI()
        layoutUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        closeButton.touchUpInside = { [weak self] in
            self?.output.didTapClose()
        }
        
        webView.navigationDelegate = self
        navigationController?.delegate = self
        
        output.viewDidLoad()
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        output.viewDidAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

//  MARK: - Output

extension SpecialOfferViewController: SpecialOfferPresenterOutput {
    func display(url: URL) {
        #if !targetEnvironment(simulator)
        let request = URLRequest(url: url)
        webView.load(request)
        #endif
        display(isLoading: true)
    }
}

//  MARK: - WKNavigationDelegate

extension SpecialOfferViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        display(isLoading: false)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webViewWrapper.showRetryPlaceholder(description: error.localizedDescription) { [weak self] in
            self?.output.didTapRetry()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webViewWrapper.showRetryPlaceholder(description: error.localizedDescription) { [weak self] in
            self?.output.didTapRetry()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if handle(navigationAction) {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

//  MARK: - Webview Handling

private extension SpecialOfferViewController {
    func handle(_ action: WKNavigationAction) -> Bool {
        guard let url = action.request.url,
              url.scheme == "ncg" else { return false }
        
        switch url.host {
        case "special-offer-click":
            guard let link = url.queryItems["url"],
                  let url = URL(string: link) else { return false }
            self.output.didTapSpecialOffer(url: url)
            return true
        default:
            return false
        }
    }
}

//  MARK: - Private Functions

private extension SpecialOfferViewController {
    func display(isLoading: Bool) {
        if isLoading {
            let loadingView = AnimationView(name: "NicegramLoader")
            loadingView.loopMode = .loop
            
            let loadingContainerView = UIView()
            
            loadingContainerView.addSubview(loadingView)
            
            loadingView.snp.makeConstraints { make in
                make.width.height.equalTo(50)
                make.center.equalToSuperview()
            }
            
            loadingView.play()
            webViewWrapper.showPlaceholder(loadingContainerView)
        } else {
            webViewWrapper.hidePlaceholder()
        }
    }
    
    func setupUI() {
        contentView.backgroundColor = ngTheme.backgroundColor
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        
        closeButton.backgroundColor = ngTheme.cardColor
        closeButton.layer.cornerRadius = 12
        closeButton.foregroundColor = ngTheme.reverseTitleColor
        closeButton.display(title: nil, image: UIImage(named: "ng.xmark")?.withRenderingMode(.alwaysTemplate))
    }
    
    func layoutUI() {
        contentView.addSubview(webViewWrapper)
        contentView.addSubview(closeButton)
        view.addSubview(contentView)
        
        webViewWrapper.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(12)
            make.width.height.equalTo(32)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            let screenSize = self.screenSize()
            make.width.equalTo(screenSize.width * Constants.widthAspectRatio).priority(500)
            make.height.equalTo(screenSize.height * Constants.heightAspectRatio).priority(500)
        }
    }
    
    func screenSize() -> CGSize {
        return UIScreen.main.bounds.size
    }
    
    struct Constants {
        static let widthAspectRatio: CGFloat = 343 / 375
        static let heightAspectRatio: CGFloat = 615 / 808
    }
}

extension SpecialOfferViewController: UINavigationControllerDelegate {
    func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
