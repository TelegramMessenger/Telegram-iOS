import NGCoreUI
import UIKit

public extension CustomButton {
    func applyLotteryActionStyle() {
        self.applyStyle(
            font: .systemFont(ofSize: 16, weight: .semibold),
            foregroundColor: .lotteryForegroundTint,
            backgroundColor: .lotteryBackgroundTint,
            cornerRadius: 6,
            spacing: .zero,
            insets: .zero,
            imagePosition: .leading,
            imageSizeStrategy: .auto
        )
        
        let foregroundConfigurator = ButtonStateConfigurator.foregroundTint()
        self.stateConfigurator = ButtonStateConfigurator(configure: { button, state in
            switch state {
            case .disabled:
                button.backgroundColor = .white.withAlphaComponent(0.25)
            default:
                button.backgroundColor = .lotteryBackgroundTint
            }
            foregroundConfigurator.configure(button, state)
        })
        
        self.snp.makeConstraints { make in
            make.height.equalTo(54).priority(999)
        }
    }
}
