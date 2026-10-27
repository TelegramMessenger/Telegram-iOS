import UIKit
import MediaGrid

final class DemoCellLayer: MediaGridCellLayer {
    private var checkLayer: CAShapeLayer?
    private var isCompact = false
    private var selectedState = false

    override func bind(index: Int, detail: MediaGridCellDetail) {
        super.bind(index: index, detail: detail)
        self.isCompact = detail == .compact
        if detail == .full && self.checkLayer == nil {
            let layer = CAShapeLayer()
            layer.actions = ["contents": NSNull(), "hidden": NSNull(), "fillColor": NSNull(), "path": NSNull(), "position": NSNull()]
            self.addSublayer(layer)
            self.checkLayer = layer
            self.updateCheck()
        }
        self.checkLayer?.isHidden = self.isCompact
    }

    override func setSelected(_ selected: Bool) {
        self.selectedState = selected
        self.updateCheck()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        self.updateCheck()
    }

    private func updateCheck() {
        guard let layer = self.checkLayer else {
            return
        }
        let diameter: CGFloat = 22.0
        let rect = CGRect(x: self.bounds.width - diameter - 6.0, y: 6.0, width: diameter, height: diameter)
        layer.frame = self.bounds
        let path = UIBezierPath(ovalIn: rect)
        if self.selectedState {
            path.move(to: CGPoint(x: rect.minX + 6.0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + 10.0, y: rect.midY + 4.0))
            path.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.midY - 4.0))
        }
        layer.path = path.cgPath
        layer.fillColor = self.selectedState ? UIColor.systemBlue.cgColor : UIColor.black.withAlphaComponent(0.25).cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 1.5
        layer.fillRule = .nonZero
    }
}
