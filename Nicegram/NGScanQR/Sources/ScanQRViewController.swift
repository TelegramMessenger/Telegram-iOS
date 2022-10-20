import UIKit
import SnapKit
import NGButton
import NGExtensions
import NGTheme

protocol ScanQRViewControllerInput { }

protocol ScanQRViewControllerOutput {
    func viewDidLoad()
    func shareTapped(sourceView: UIView?)
}

final class ScanQRViewController: UIViewController, ScanQRViewControllerInput {
    
    //  MARK: - VIP
    
    var output: ScanQRViewControllerOutput!
    
    //  MARK: - UI Elements
    
    private let ngTheme: NGThemeColors

    private let qrImageView = UIImageView()
    private let scanLineView = ScanLineView()
    private let scanView = ScanView()
    private let descriptionLabel = UILabel()
    private let button = CustomButton()
    
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
        setupUI()
    }
        

    override func viewDidLoad() {
        super.viewDidLoad()
        
        button.touchUpInside = { [weak self] in
            self?.output.shareTapped(sourceView: self?.button)
        }
        
        output.viewDidLoad()
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

//  MARK: - Output

extension ScanQRViewController: ScanQRPresenterOutput {
    func display(navigationTitle: String) {
        navigationItem.title = navigationTitle
    }
    
    func display(qrImage: UIImage) {
        qrImageView.image = qrImage
    }
    
    func display(description: String) {
        descriptionLabel.text = description
    }
    
    func display(buttonTitle: String) {
        button.display(title: buttonTitle, image: nil)
    }
}

//  MARK: - Private Functions
    
private extension ScanQRViewController {
    func setupUI() {
        view.backgroundColor = ngTheme.backgroundColor
        
        qrImageView.contentMode = .scaleAspectFit
        
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = ngTheme.descriptionColor
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        
        button.applyMainActionStyle()
        
        let contentView = UIView()
        
        view.addSubview(contentView)
        view.addSubview(button)
        
        contentView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeArea.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(button.snp.top)
        }
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualTo(self.view.safeArea.bottom)
            make.bottom.equalToSuperview().inset(36).priority(999)
            make.height.equalTo(54)
        }
        
        let stack = UIStackView(arrangedSubviews: [scanView, descriptionLabel])
        stack.axis = .vertical
        stack.spacing = 50
        stack.alignment = .center
    
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(40)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().inset(15)
        }
        
        scanView.addSubview(qrImageView)
        qrImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(35)
        }
        
        view.addSubview(scanLineView)
        scanLineView.snp.makeConstraints { make in
            make.leading.equalTo(scanView)
            make.trailing.equalTo(scanView)
            make.bottom.equalTo(scanView.snp.top)
            make.height.equalTo(23)
        }
    }
}

private extension NGThemeColors {
    var descriptionColor: UIColor {
        switch theme {
        case .white: return .ngBodyThree
        case .dark: return .white
        }
    }
}
