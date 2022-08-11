import UIKit
import SnapKit
import NGButton

open class AssistantWalletContainerView: UIView {
    private let walletIcon = UIImageView()
    private let walletStaticLabel = UILabel()
    private let walletAmountLabel = UILabel()
    /// Probbly should chaange the naming
    private let addButton = ActionButton()

    public var buttonTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        walletIcon.contentMode = .scaleToFill
        walletIcon.image = UIImage(named: "PAWallet")
        addSubview(walletIcon)
        walletIcon.snp.makeConstraints {
            $0.width.equalTo(12.0)
            $0.height.equalTo(11.0)
            $0.leading.top.equalToSuperview().inset(2.0)
        }

        walletStaticLabel.text = "My wallet".uppercased()
        walletStaticLabel.font = .systemFont(ofSize: 12.0, weight: .medium)
        walletStaticLabel.textColor = .white.withAlphaComponent(0.5)
        addSubview(walletStaticLabel)
        walletStaticLabel.snp.makeConstraints {
            $0.centerY.equalTo(walletIcon)
            $0.leading.equalTo(walletIcon.snp.trailing).offset(6.0)
            $0.width.equalTo(80.0)
        }

        addButton.layer.cornerRadius = 12
        addButton.backgroundColor = .white.withAlphaComponent(0.1)
        addButton.titleLabel?.font = .systemFont(ofSize: 28.0, weight: .medium)
        addButton.setTitle("+", for: .normal)
        addButton.touchUpInside = {
            self.buttonTapped?()
        }
        addSubview(addButton)
        addButton.snp.makeConstraints {
            $0.height.width.equalTo(56.0)
            $0.top.trailing.equalToSuperview()
        }


        let attrString = NSMutableAttributedString(
            string: "$",
            attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16, weight: .regular)]
        )

        attrString.append(
            NSMutableAttributedString(
                string: "359.43",
                attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 32, weight: .regular)]
            )
        )

        walletAmountLabel.attributedText = attrString
        walletAmountLabel.textColor = .white
        addSubview(walletAmountLabel)
        walletAmountLabel.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalTo(walletStaticLabel.snp.bottom).offset(4.0)
            $0.bottom.equalToSuperview()
            $0.trailing.equalTo(addButton.snp.leading).offset(-12.0)
        }

    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
