import UIKit
import SnapKit
import NGExtensions
import NGCustomViews
import EsimAuth
import NGLoadingIndicator
import NGTheme

typealias HintViewControllerInput = AssistantPresenterOutput

protocol HintViewControllerOutput {
    func handleViewDidLoad()
}

final class HintViewController: UIViewController {
    var output: HintViewControllerOutput!
    var router: HintRouterInput!

    private let hintView: HintView
    private let blurEffectView = UIVisualEffectView()

    private let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.hintView = HintView(ngTheme: ngTheme)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = .clear
        navigationController?.delegate = self

        let blurEffect = UIBlurEffect(style: ngTheme.blurStyle)
        blurEffectView.effect = blurEffect
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = 0
        view.addSubview(blurEffectView)
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(hitDismiss(_:)))
        view.addGestureRecognizer(gesture)
        
        view.addSubview(hintView)
        hintView.snp.makeConstraints {
            $0.top.equalTo(self.view.safeArea.top).inset(4.0)
            $0.trailing.equalToSuperview().inset(16.0)
            $0.width.equalTo(340.0)
        }
        hintView.alpha = 0
        
        let emptyNavigationBarItem = UIBarButtonItem()
        emptyNavigationBarItem.customView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 16.0, height: 44.0)))
        let nicegramItem = UIBarButtonItem(image: UIImage(named: "NicegramMain"), style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItems = [emptyNavigationBarItem, nicegramItem]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        output.handleViewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIView.animate(withDuration: 0.3) {
            self.blurEffectView.alpha = 1
            self.hintView.alpha = 1
        }
    }
    
    @objc func hitDismiss(_ sender: UITapGestureRecognizer) {    
        UIView.animate(withDuration: 0.3) {
            self.blurEffectView.alpha = 0
            self.hintView.alpha = 0
        } completion: { _ in
            self.router.dismiss()
        }
    }
}

extension HintViewController: HintPresenterOutput { 
    func display(titleText: String?, subtitleText: String?, mobileDataText: String?, virtualNumberText: String?, walletText: String?, supportText: String?, footerText: String?) {
        hintView.display(titleText: titleText, subtitleText: subtitleText, mobileDataText: mobileDataText, virtualNumberText: virtualNumberText, walletText: walletText, supportText: supportText, footerText: footerText)
    }
}

extension HintViewController: UINavigationControllerDelegate {
    func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
