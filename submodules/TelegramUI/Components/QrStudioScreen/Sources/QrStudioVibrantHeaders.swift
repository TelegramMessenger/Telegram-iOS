import Foundation
import UIKit
import Display

final class QrStudioVibrantHeaders {
    private let mirrorView = UIView()
    private var labels: [UILabel] = []

    init() {
        self.mirrorView.isUserInteractionEnabled = false
        self.mirrorView.layer.anchorPoint = CGPoint()
    }

    func attach(to container: UIView?) {
        guard let container else {
            self.mirrorView.removeFromSuperview()
            return
        }
        if self.mirrorView.superview !== container {
            container.addSubview(self.mirrorView)
        }
    }

    func update(size: CGSize, headers: [(text: NSAttributedString, frame: CGRect)], isEnabled: Bool) {
        self.mirrorView.isHidden = !isEnabled
        self.mirrorView.bounds = CGRect(origin: self.mirrorView.bounds.origin, size: size)
        self.mirrorView.layer.position = CGPoint()
        while self.labels.count < headers.count {
            let label = UILabel()
            self.mirrorView.addSubview(label)
            self.labels.append(label)
        }
        for (index, label) in self.labels.enumerated() {
            if index < headers.count {
                let text = NSMutableAttributedString(attributedString: headers[index].text)
                text.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(location: 0, length: text.length))
                label.attributedText = text
                label.textAlignment = .center
                label.frame = headers[index].frame
                label.isHidden = false
            } else {
                label.isHidden = true
            }
        }
    }

    func setContentOffset(_ offset: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.mirrorView.bounds = CGRect(origin: offset, size: self.mirrorView.bounds.size)
        CATransaction.commit()
    }
}
