import NGCoreUI
import SnapKit
import UIKit

class TimerView: UIView {
    
    //  MARK: - UI Elements

    private let dayLabel = UILabel()
    private let hourLabel = UILabel()
    private let minLabel = UILabel()
    private let secLabel = UILabel()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(timeInterval: TimeInterval) {
        let components = decompose(timeInterval: timeInterval)
        
        dayLabel.text = formatTimeComponent(components.days)
        hourLabel.text = formatTimeComponent(components.hours)
        minLabel.text = formatTimeComponent(components.minutes)
        secLabel.text = formatTimeComponent(components.seconds)
    }
}

private extension TimerView {
    func setupUI() {
        [dayLabel, hourLabel, minLabel, secLabel].forEach { $0.applyTimeComponentStyle() }
        
        let stack = UIStackView(
            arrangedSubviews: [dayLabel, .twoDots(), hourLabel, .twoDots(), minLabel, .twoDots(), secLabel],
            axis: .horizontal,
            spacing: 8,
            alignment: .center
        )
        
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        addCaption(to: dayLabel, with: ngLocalized("Lottery.NextDraw.Day"))
        addCaption(to: hourLabel, with: ngLocalized("Lottery.NextDraw.Hour"))
        addCaption(to: minLabel, with: ngLocalized("Lottery.NextDraw.Min"))
        addCaption(to: secLabel, with: ngLocalized("Lottery.NextDraw.Sec"))
    }
    
    func addCaption(to: UIView, with text: String) {
        let captionLabel = UILabel()
        captionLabel.applyStyle(
            font: .systemFont(ofSize: 12, weight: .regular),
            textColor: .white.withAlphaComponent(0.5),
            textAlignment: .center,
            numberOfLines: 1,
            adjustFontSize: .yes(0.5)
        )
        captionLabel.text = text.uppercased()
        
        addSubview(captionLabel)
        captionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(to)
            make.top.equalTo(to.snp.bottom).offset(0)
            make.bottom.equalToSuperview()
        }
        captionLabel.snp.contentHuggingHorizontalPriority = 1
        captionLabel.snp.contentCompressionResistanceHorizontalPriority = 1
    }
    
    func decompose(timeInterval: TimeInterval) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        var currentValue = Int(timeInterval)
        
        let seconds = currentValue % 60
        currentValue /= 60
        
        let minutes = currentValue % 60
        currentValue /= 60
        
        let hours = currentValue % 24
        
        let days = currentValue / 24
        
        return (days, hours, minutes, seconds)
    }
    
    func formatTimeComponent(_ value: Int) -> String {
        return String(format: "%02d", value)
    }
}

private extension UILabel {
    func applyTimeComponentStyle() {
        self.applyStyle(
            font: .monospacedDigitSystemFont(ofSize: 40, weight: .bold),
            textColor: .lotteryBackgroundTint,
            textAlignment: .center,
            numberOfLines: 1,
            adjustFontSize: .no
        )
    }
}

private extension UIView {
    static func twoDots() -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .lotteryBackgroundTint
        imageView.image = UIImage(named: "ng.lottery.twodots")?.withRenderingMode(.alwaysTemplate)
        return imageView
    }
}
