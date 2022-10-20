import UIKit
import SnapKit
import NGButton
import NGCustomViews
import NGExtensions
import NGToast
import NGTheme

protocol SetupEsimViewControllerInput { }

protocol SetupEsimViewControllerOutput {
    func viewDidLoad()
    
    func supportTapped()
    func playVideoTapped()
    func scanQrTapped()
    func lpaTapped()
    func activationCodeTapped()
    func apnTapped()
    func dataRoamingTapped()
    func doneTapped()
}

final class SetupEsimViewController: UIViewController, SetupEsimViewControllerInput {
    
    //  MARK: - VIP
    
    var output: SetupEsimViewControllerOutput!
    
    //  MARK: - UI Elements
    
    private let ngTheme: NGThemeColors
    
    private let headerView: NavigationHeaderView
    
    private let videoGradientView = GradientView()
    private let playButton = CustomButton()
    
    private let installStepView: EsimSetupStepView
    private let lpaView: DescriptionItemView
    private let codeView: DescriptionItemView
    
    private let apnStepView: EsimSetupStepView
    private let apnView: DescriptionItemView
    
    private let roamingStepView: EsimSetupStepView
    private let roamingView: DescriptionItemView
    
    private let button = CustomButton()
    
    private let scrollView = UIScrollView()
    private let containerView = UIView()
    
    //  MARK: - Lifecycle
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.headerView = NavigationHeaderView(ngTheme: ngTheme)
        self.installStepView = EsimSetupStepView(ngTheme: ngTheme)
        self.lpaView = DescriptionItemView(ngTheme: ngTheme)
        self.codeView = DescriptionItemView(ngTheme: ngTheme)
        self.apnStepView = EsimSetupStepView(ngTheme: ngTheme)
        self.apnView = DescriptionItemView(ngTheme: ngTheme)
        self.roamingStepView = EsimSetupStepView(ngTheme: ngTheme)
        self.roamingView = DescriptionItemView(ngTheme: ngTheme)
        
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
        
        headerView.onButtonTap = { [weak self] in
            self?.output.supportTapped()
        }
        
        playButton.touchUpInside = { [weak self] in
            self?.output.playVideoTapped()
        }
        
        installStepView.buttonTouchUpInside = { [weak self] in
            self?.output.scanQrTapped()
        }
        
        lpaView.onTap = { [weak self] in
            self?.output.lpaTapped()
        }
        codeView.onTap = { [weak self] in
            self?.output.activationCodeTapped()
        }
        apnView.onTap = { [weak self] in
            self?.output.apnTapped()
        }
        roamingView.onTap = { [weak self] in
            self?.output.dataRoamingTapped()
        }
        
        button.touchUpInside = { [weak self] in
            self?.output.doneTapped()
        }
        
        output.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

//  MARK: - Output

extension SetupEsimViewController: SetupEsimPresenterOutput {
    func displayHeader(title: String, buttonImage: UIImage?) {
        headerView.display(title: title, buttonImage: buttonImage)
    }
    
    func display(videoTitle: String) {
        playButton.display(title: videoTitle, image: UIImage(named: "ng.play.fill")?.withRenderingMode(.alwaysTemplate))
    }
    
    func displayInstallStep(item: EsimSetupStepViewModel) {
        installStepView.display(item: item)
    }
    
    func display(lpaItem: DescriptionItemViewModel) {
        lpaView.display(item: lpaItem)
    }
    
    func display(activationCodeItem: DescriptionItemViewModel) {
        codeView.display(item: activationCodeItem)
    }
    
    func displayApnStep(item: EsimSetupStepViewModel) {
        apnStepView.display(item: item)
    }
    
    func display(apnItem: DescriptionItemViewModel) {
        apnView.display(item: apnItem)
    }
    
    func displayRoamingStep(item: EsimSetupStepViewModel) {
        roamingStepView.display(item: item)
    }
    
    func display(roamingItem: DescriptionItemViewModel) {
        roamingView.display(item: roamingItem)
    }
    
    func display(buttonTitle: String) {
        button.display(title: buttonTitle, image: nil)
    }
    
    func copy(text: String) {
        UIPasteboard.general.string = text
        NGToast.showCopiedToast()
    }
}

//  MARK: - Private Functions

private extension SetupEsimViewController {
    func setupUI() {
        view.backgroundColor = ngTheme.backgroundColor
        
        videoGradientView.colors = .defaultGradient
        videoGradientView.clipsToBounds = true
        videoGradientView.layer.cornerRadius = 12
        
        playButton.foregroundColor = .white
        playButton.configureImageContainer { imageContainer in
            imageContainer.backgroundColor = .white.withAlphaComponent(0.2)
            imageContainer.layer.cornerRadius = 16
            imageContainer.snp.makeConstraints { make in
                make.width.height.equalTo(32)
            }
        }
        playButton.configureTitleLabel { playLabel in
            playLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        }
        playButton.spacing = 8
        playButton.insets = UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16)
        
        installStepView.display(descriptionViews: [lpaView, codeView])
        apnStepView.display(descriptionViews: [apnView])
        roamingStepView.display(descriptionViews: [roamingView])
        
        button.applyMainActionStyle()
        
        let stepsStack = UIStackView(arrangedSubviews: [installStepView, apnStepView, roamingStepView])
        stepsStack.axis = .vertical
        stepsStack.spacing = 16
        
        let stack = UIStackView(arrangedSubviews: [headerView, videoGradientView, stepsStack, button])
        stack.axis = .vertical
        stack.spacing = 24
        if #available(iOS 11.0, *) {
            stack.setCustomSpacing(16, after: videoGradientView)
            stack.setCustomSpacing(55, after: stepsStack)
        }
        
        videoGradientView.addSubview(playButton)
        
        containerView.addSubview(stack)
        scrollView.addSubview(containerView)
        view.addSubview(scrollView)
        
        playButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        button.snp.makeConstraints { make in
            make.height.equalTo(54)
        }
        
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().priority(.low)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeArea.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}


