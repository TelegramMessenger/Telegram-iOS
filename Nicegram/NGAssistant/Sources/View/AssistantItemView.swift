import UIKit
import SnapKit
import NGTheme

struct PersonalAssistantItem {
    enum Item {
        case virtualNumber
        case mobileData
        case referal
        case account
        
        case channel
        case chat
        
        case support
        case rateUs
        case logout
    }
    
    var image: UIImage?
    var title: String?
    var subtitle: String?
    var description: String?
    
    var item: PersonalAssistantItem.Item?
}

open class AssistantItemView: UIView {
    private let itemImageView = UIImageView()
    private let itemTitleLabel = UILabel()
    private let itemDescriptionLabel = UILabel()
    private let arrowImageView = UIImageView()
    
    private var itemTag: PersonalAssistantItem.Item?
    
    var onTouchUpInside: ((_ itemTag: PersonalAssistantItem.Item) -> Void)?
    
    let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
    
        super.init(frame: .zero)
        
        backgroundColor = .clear

        itemImageView.contentMode = .scaleToFill
        addSubview(itemImageView)
        itemImageView.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview().inset(16.0)
            $0.height.width.equalTo(29.0)
        }

        itemTitleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        itemTitleLabel.textColor = ngTheme.reverseTitleColor
        addSubview(itemTitleLabel)
        itemTitleLabel.snp.makeConstraints {
            $0.centerY.equalTo(itemImageView)
            $0.leading.equalTo(itemImageView.snp.trailing).offset(14.0)
            $0.trailing.equalToSuperview().inset(60.0)
        }

        itemDescriptionLabel.font = .systemFont(ofSize: 14.0, weight: .regular)
        itemDescriptionLabel.textColor = ngTheme.subtitleColor
        itemDescriptionLabel.numberOfLines = 0
        addSubview(itemDescriptionLabel)
        itemDescriptionLabel.snp.makeConstraints {
            $0.leading.equalTo(itemTitleLabel.snp.leading)
            $0.trailing.equalTo(itemTitleLabel.snp.trailing)
            $0.top.equalTo(itemTitleLabel.snp.bottom).offset(2.0)
            $0.bottom.equalToSuperview()
        }
        
        arrowImageView.image = UIImage(named: "ng.item.arrow")
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.isHidden = true
        addSubview(arrowImageView)
        arrowImageView.snp.makeConstraints {
            $0.height.equalTo(15.0)
            $0.width.equalTo(8.5)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(20.0)
        }
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(touchUpInside(_:)))
        self.addGestureRecognizer(gesture)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(item: PersonalAssistantItem, isArrowHidden: Bool = false) {
        itemImageView.image = item.image
        itemDescriptionLabel.text = item.description
        itemTag = item.item
        arrowImageView.isHidden = isArrowHidden

        if let subtitle = item.subtitle {
            let attrString = NSMutableAttributedString(
                string: item.title ?? "",
                attributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                    NSAttributedString.Key.foregroundColor: ngTheme.reverseTitleColor
                ]
            )
            attrString.append(
                NSMutableAttributedString(
                    string: " " + subtitle,
                    attributes: [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16, weight: .medium),
                        NSAttributedString.Key.foregroundColor: ngTheme.reverseTitleColor.withAlphaComponent(0.4)
                    ]
                )
            )

            itemTitleLabel.attributedText = attrString
        } else {
            itemTitleLabel.text = item.title
        }
    }
    
    @objc private func touchUpInside(_ sender: UITapGestureRecognizer) {
        guard let itemTag = itemTag else { return }

        onTouchUpInside?(itemTag)
    }
}
