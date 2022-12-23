import NGCoreUI
import SnapKit
import UIKit

enum NextDrawViewState {
    case waiting(TimeInterval)
    case started
}

class NextDrawView: UIView {
    
    //  MARK: - UI Elements
    
    private let nextDrawLabel = UILabel()
    private let drawStartedLabel = UILabel()
    private let timerView = TimerView()
    private let descLabel = UILabel()
    private let descContainer = UIView()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        descContainer.roundCorners(topLeft: 0, topRight: 0, bottomLeft: 12, bottomRight: 12)
    }
    
    //  MARK: - Public Functions
    
    func display(state: NextDrawViewState) {
        let timeInterval: TimeInterval
        let showNextDraw: Bool
        let showDrawStarted: Bool
        let showDesc: Bool
        switch state {
        case .waiting(let _timeInterval):
            timeInterval = _timeInterval
            showNextDraw = true
            showDrawStarted = false
            showDesc = false
        case .started:
            timeInterval = .zero
            showNextDraw = false
            showDrawStarted = true
            showDesc = true
        }
        
        timerView.display(timeInterval: timeInterval)
        nextDrawLabel.isHidden = !showNextDraw
        drawStartedLabel.isHidden = !showDrawStarted
        descContainer.isHidden = !showDesc
    }
}

private extension NextDrawView {
    func setupUI() {
        nextDrawLabel.applyStyle(
            font: .systemFont(ofSize: 12, weight: .regular),
            textColor: .white.withAlphaComponent(0.5),
            textAlignment: .center,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        nextDrawLabel.text = ngLocalized("Lottery.NextDrawWaiting.Title").uppercased()
        
        drawStartedLabel.applyStyle(
            font: .systemFont(ofSize: 16, weight: .semibold),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        drawStartedLabel.text = ngLocalized("Lottery.NextDrawStarted.Title").uppercased()
        
        descLabel.applyStyle(
            font: .systemFont(ofSize: 10, weight: .regular),
            textColor: .white.withAlphaComponent(0.8),
            textAlignment: .center,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        descLabel.text = ngLocalized("Lottery.NextDrawStarted.Desc")
        
        descContainer.backgroundColor = .white.withAlphaComponent(0.05)
        
        descContainer.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().inset(9)
            make.top.greaterThanOrEqualToSuperview().inset(12)
        }
        descContainer.snp.makeConstraints { make in
            make.height.equalTo(66).priority(1)
            make.width.lessThanOrEqualTo(300)
        }
        
        let stack = UIStackView(
            arrangedSubviews: [nextDrawLabel, drawStartedLabel, timerView, descContainer],
            axis: .vertical,
            spacing: 12,
            alignment: .center
        )
        
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
