import UIKit
import SnapKit
import NGButton
import NGExtensions

public enum ExparationType: String {
    case active = "Renews"
    case expires = "Expires"
    case unactive = "Expired"
}

/// NOTE: Name should be changed
public enum Available {
    case calls
    case messages
}

public struct MyNumberItem {
    let title: String?
    let phoneNumber: String?
    let exparationType: ExparationType?
    let date: String?

    public init(
        title: String?,
        phoneNumber: String?,
        exparationType: ExparationType?,
        date: String?
    ) {
        self.title = title
        self.phoneNumber = phoneNumber
        self.exparationType = exparationType
        self.date = date
    }
}

public class MyNumberView: UIView {
    private let titleLabel = UILabel()
    private let moreButton = ActionButton()
    private let countryImageView = UIImageView()
    private let phoneNumberLabel = UILabel()
    private let stateLabel = UILabel()
    /// NOTE: Name should be changed
    private let availableView = UIStackView()
    private let copyButton = ActionButton()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .ngCardBackground

        addSubview(moreButton)
        moreButton.setImage(UIImage(named: "MoreButton"), for: .normal)
        moreButton.backgroundColor = .clear
        moreButton.snp.makeConstraints {
            $0.height.width.equalTo(24.0)
            $0.trailing.top.equalToSuperview().inset(16.0)
        }

        addSubview(titleLabel)
        titleLabel.textAlignment = .natural
        titleLabel.font = .systemFont(ofSize: 16.0, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(16.0)
            $0.trailing.equalTo(moreButton.snp.leading).offset(-16.0)
            $0.top.equalToSuperview().inset(17.5)
        }

        addSubview(countryImageView)
        countryImageView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(16.0)
            $0.top.equalTo(titleLabel.snp.bottom).offset(20.0)
        }

        addSubview(phoneNumberLabel)
        phoneNumberLabel.textAlignment = .natural
        phoneNumberLabel.font = .systemFont(ofSize: 18.0, weight: .semibold)
        phoneNumberLabel.textColor = .white
        phoneNumberLabel.snp.makeConstraints {
            $0.leading.equalTo(countryImageView.snp.trailing).offset(8.0)
            $0.centerY.equalTo(countryImageView)
        }

        addSubview(copyButton)
        copyButton.setImage(UIImage(named: "CopyButton"), for: .normal)
        copyButton.snp.makeConstraints {
            $0.centerY.equalTo(countryImageView)
            $0.height.width.equalTo(24.0)
            $0.leading.equalTo(phoneNumberLabel.snp.trailing).offset(16.0)
        }

        addSubview(stateLabel)
        stateLabel.textAlignment = .natural
        stateLabel.font = .systemFont(ofSize: 14.0, weight: .medium)
        stateLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(16.0)
            $0.bottom.equalToSuperview().inset(19.0)
        }

        let separatorView = UIView()
        separatorView.backgroundColor = .white.withAlphaComponent(0.35)
        addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.leading.equalTo(stateLabel.snp.trailing).offset(16.0)
            $0.height.equalTo(20.0)
            $0.width.equalTo(0.33)
            $0.centerY.equalTo(stateLabel)
        }

        addSubview(availableView)
        availableView.alignment = .fill
        availableView.axis = .horizontal
        availableView.distribution = .fillEqually
        availableView.spacing = 4
        availableView.snp.makeConstraints {
            $0.leading.equalTo(separatorView.snp.trailing).offset(16.0)
            $0.trailing.lessThanOrEqualToSuperview().inset(16.0)
            $0.centerY.equalTo(stateLabel)
            $0.height.equalTo(24.0)
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func display(numberItem: MyNumberItem) {
        titleLabel.text = numberItem.title
        phoneNumberLabel.text = numberItem.phoneNumber
        guard let type = numberItem.exparationType,
              let date = numberItem.date else { return }
        stateLabel.text = "\(type.rawValue) \(date)"
        switch type {
        case .active:
            stateLabel.textColor = .ngSubtitle
        case .expires:
            stateLabel.textColor = .ngLightOrange
        case .unactive:
            stateLabel.textColor = .ngRedThree
        }
        setup(items: [.calls, .messages])
    }

    /// NOTE: Name should be changed
    private func setup(items: [Available]) {
        for item in items {
            switch item {
            case .calls:
                let callsView = UIImageView()
                callsView.image = UIImage(named: "CallsImage")
                callsView.snp.makeConstraints {
                    $0.width.height.equalTo(24.0)
                }
                availableView.addArrangedSubview(callsView)
            case .messages:
                let messagesView = UIImageView()
                messagesView.image = UIImage(named: "MessagesImage")
                messagesView.snp.makeConstraints {
                    $0.width.height.equalTo(24.0)
                }
                availableView.addArrangedSubview(messagesView)
            }
        }
        availableView.layoutSubviews()
    }
}
