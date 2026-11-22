import Foundation
import UIKit
import SwiftUI

@available(iOS 17.0, *)
private final class QrStudioTimerModel: ObservableObject {
    @Published var text: String = ""
    @Published var color: Color = .black
}

@available(iOS 17.0, *)
private struct QrStudioTimerText: View {
    @ObservedObject var model: QrStudioTimerModel

    var body: some View {
        Text(self.model.text)
            .font(.system(size: 24.0, weight: .bold, design: .rounded).monospacedDigit())
            .kerning(-0.24)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(self.model.color)
            .contentTransition(.numericText(countsDown: true))
            .animation(.smooth(duration: 0.3), value: self.model.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@available(iOS 17.0, *)
final class QrStudioTimerLabel: UIView {
    private let model = QrStudioTimerModel()
    private let host: UIHostingController<QrStudioTimerText>

    override init(frame: CGRect) {
        self.host = UIHostingController(rootView: QrStudioTimerText(model: self.model))
        self.host.view.backgroundColor = .clear
        self.host.view.isUserInteractionEnabled = false
        self.host.sizingOptions = []
        self.host.safeAreaRegions = []

        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.addSubview(self.host.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func text(remaining: Int) -> String {
        return "\(remaining / 60):" + String(format: "%02d", remaining % 60)
    }

    func update(remaining: Int, color: UIColor, animated: Bool) {
        let text = QrStudioTimerLabel.text(remaining: remaining)
        let swiftColor = Color(uiColor: color)
        if self.model.color != swiftColor {
            self.model.color = swiftColor
        }
        if self.model.text != text {
            if animated {
                self.model.text = text
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.model.text = text
                }
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.host.view.frame = self.bounds
    }
}
