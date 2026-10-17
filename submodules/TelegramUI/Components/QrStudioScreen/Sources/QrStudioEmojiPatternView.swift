import Foundation
import UIKit
import Display
import TelegramCore
import AccountContext

private final class QrStudioPatternNode {
    let layer = SimpleLayer()
    var fileId: Int64?
    var isUsed = false
    var isTemplate = false
}

final class QrStudioEmojiPatternView: UIView, QrStudioBackgroundContent {
    private static let lattice = QrStudioLattice(dx: 86.0, dy: 70.0, velocity: CGVector(dx: -3.5, dy: -5.5), lag: 0.04 ... 0.26, orbit: 3.0 ... 10.0)
    private static let nodeSide: CGFloat = 38.0

    private let context: AccountContext
    private var isDark: Bool
    private let meshView = QrStudioMeshBackgroundView(palette: QrStudioPalette.fallback)
    private let nodesLayer = SimpleLayer()
    private var files: [TelegramMediaFile]
    private var previousFiles: [TelegramMediaFile]?
    private var changedAt: Double = -10.0
    private var animations: [Int64: QrStudioPhasedAnimation] = [:]
    private var nodes: [Int64: QrStudioPatternNode] = [:]
    private var reusableNodes: [QrStudioPatternNode] = []

    private var size = CGSize()
    private var revealCenter = CGPoint()
    private var bornAt: Double = -10.0
    private var isVisible = true

    let wantsFullFrameRate: Bool = true
    static func canonicalExportItems(size: CGSize, fileCount: Int) -> [QrStudioExportPatternItem] {
        let squeeze = QrStudioEdgeSqueeze(size: size)
        let cells = QrStudioEmojiPatternView.lattice.cells(in: size, at: 0.0, offset: CGSize(), margin: squeeze.margin, drift: QrStudioDrift(), tilt: SIMD2<Double>(0.0, 0.0))
        return cells.map { QrStudioEmojiPatternView.exportItem(cell: $0, time: 0.0, fileCount: fileCount) }
    }

    private static func exportItem(cell: QrStudioLattice.Cell, time: Double, fileCount: Int) -> QrStudioExportPatternItem {
        let phase = cell.hash * 2.0 * .pi
        let isBig = cell.r.isMultiple(of: 2)
        return QrStudioExportPatternItem(
            content: .sticker(qrStudioEmojiIndex(r: cell.r, c: cell.c, count: fileCount)),
            point: CGPoint(x: cell.point.x, y: cell.point.y + CGFloat(3.0 * sin(time * 0.45 + phase))),
            side: CGFloat(48.0 * (isBig ? 1.3 : 0.9) * (0.92 + 0.16 * cell.hash)) * QrStudioEmojiPatternView.nodeSide / 48.0,
            degrees: (cell.hash - 0.5) * 26.0 + 4.0 * sin(time * 0.3 + phase),
            hash: cell.hash
        )
    }

    var templateTintColor: UIColor = .black {
        didSet {
            guard self.templateTintColor != oldValue else {
                return
            }
            for (_, node) in self.nodes where node.isTemplate {
                node.layer.layerTintColor = self.templateTintColor.cgColor
            }
        }
    }

    init(context: AccountContext, files: [TelegramMediaFile], isDark: Bool = false) {
        self.context = context
        self.files = files
        self.isDark = isDark

        super.init(frame: CGRect())

        self.backgroundColor = .white
        self.clipsToBounds = true
        self.meshView.alpha = isDark ? 1.0 : 0.0
        self.addSubview(self.meshView)
        self.layer.addSublayer(self.nodesLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, revealCenter: CGPoint) {
        self.size = size
        self.revealCenter = revealCenter
        self.meshView.frame = CGRect(origin: CGPoint(), size: size)
        self.meshView.update(size: size, revealCenter: revealCenter)
        self.nodesLayer.frame = CGRect(origin: CGPoint(), size: size)
    }

    func beginReveal(at time: Double) {
        self.bornAt = time
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        self.meshView.setVisible(isVisible && self.isDark)
        for (_, animation) in self.animations {
            animation.setPaused(!isVisible)
        }
    }

    func setDark(_ isDark: Bool) {
        guard self.isDark != isDark else {
            return
        }
        self.isDark = isDark
        self.meshView.setVisible(self.isVisible && isDark)
        UIView.animate(withDuration: 0.45, delay: 0.0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.meshView.alpha = isDark ? 1.0 : 0.0
        })
    }

    func updateFiles(_ files: [TelegramMediaFile], at time: Double) {
        guard files.map({ $0.fileId }) != self.files.map({ $0.fileId }) else {
            return
        }
        self.previousFiles = self.files
        self.files = files
        self.changedAt = time
    }

    private func animation(for file: TelegramMediaFile) -> QrStudioPhasedAnimation {
        if let current = self.animations[file.fileId.id] {
            return current
        }
        let animation = QrStudioPhasedAnimation(context: self.context, file: file, pointSize: CGSize(width: QrStudioEmojiPatternView.nodeSide, height: QrStudioEmojiPatternView.nodeSide), hostLayer: self.layer, placeholderColor: self.isDark ? UIColor(white: 1.0, alpha: 0.12) : UIColor(white: 0.0, alpha: 0.08))
        animation.setPaused(!self.isVisible)
        self.animations[file.fileId.id] = animation
        return animation
    }

    private func nodeKey(r: Int, c: Int) -> Int64 {
        return (Int64(r) << 32) | Int64(UInt32(truncatingIfNeeded: c))
    }

    func tick(time: Double, pan: QrStudioPan, drift: QrStudioDrift, tilt: SIMD2<Double>) {
        if self.isVisible && self.isDark {
            self.meshView.tick(time: time, pan: pan, drift: drift, tilt: tilt)
        }
        guard self.isVisible, !self.files.isEmpty, self.size.width > 0.0, self.size.height > 0.0 else {
            return
        }

        if self.previousFiles != nil, time - self.changedAt > 1.0 {
            self.previousFiles = nil
            let currentIds = Set(self.files.map { $0.fileId.id })
            for (_, node) in self.nodes {
                if let fileId = node.fileId, !currentIds.contains(fileId) {
                    self.detach(node)
                    node.fileId = nil
                }
            }
            self.animations = self.animations.filter { currentIds.contains($0.key) }
        }

        let squeeze = QrStudioEdgeSqueeze(size: self.size)
        let cells = QrStudioEmojiPatternView.lattice.cells(in: self.size, at: time, offset: pan.offset(at: time), margin: squeeze.margin, drift: drift, tilt: tilt)
        let since = time - self.bornAt
        let nodeSide = QrStudioEmojiPatternView.nodeSide

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (_, node) in self.nodes {
            node.isUsed = false
        }

        for cell in cells {
            let phase = cell.hash * 2.0 * .pi
            let swayed = CGPoint(x: cell.point.x, y: cell.point.y + CGFloat(3.0 * sin(time * 0.45 + phase)))
            let (point, k) = squeeze.apply(swayed)
            let alpha = squeeze.alpha(k)
            let enter = QrStudioReveal.entrance(point, center: self.revealCenter, since: since)
            guard alpha > 0.0, enter > 0.01 else {
                continue
            }

            var fileIndex = qrStudioEmojiIndex(r: cell.r, c: cell.c, count: self.files.count)
            var pop: Double = 1.0
            if let previousFiles = self.previousFiles, !previousFiles.isEmpty {
                let previousIndex = qrStudioEmojiIndex(r: cell.r, c: cell.c, count: previousFiles.count)
                let local = QrStudioCurve.clamp01((time - self.changedAt - cell.hash * 0.3) / 0.45)
                if previousFiles[previousIndex].fileId != self.files[fileIndex].fileId && local < 1.0 {
                    if local < 0.3 {
                        pop = max(0.0, 1.0 - local / 0.4)
                        fileIndex = -1 - previousIndex
                    } else {
                        pop = QrStudioCurve.backOut((local - 0.3) / 0.7)
                    }
                }
            }

            let key = self.nodeKey(r: cell.r, c: cell.c)
            let node: QrStudioPatternNode
            if let current = self.nodes[key] {
                node = current
            } else {
                if let reused = self.reusableNodes.popLast() {
                    node = reused
                } else {
                    node = QrStudioPatternNode()
                    node.layer.bounds = CGRect(x: 0.0, y: 0.0, width: nodeSide, height: nodeSide)
                }
                node.layer.isHidden = false
                self.nodesLayer.addSublayer(node.layer)
                self.nodes[key] = node
            }
            node.isUsed = true

            let file: TelegramMediaFile?
            if fileIndex >= 0 {
                file = self.files[fileIndex]
            } else if let previousFiles = self.previousFiles {
                file = previousFiles[-1 - fileIndex]
            } else {
                file = nil
            }
            if node.fileId != file?.fileId.id {
                self.detach(node)
                node.fileId = file?.fileId.id
                if let file {
                    self.animation(for: file).attach(node.layer, group: qrStudioPhaseGroup(hash: cell.hash))
                    node.isTemplate = file.isCustomTemplateEmoji
                    node.layer.layerTintColor = node.isTemplate ? self.templateTintColor.cgColor : nil
                }
            }

            let isBig = cell.r.isMultiple(of: 2)
            let side = 48.0 * (isBig ? 1.3 : 0.9) * (0.92 + 0.16 * cell.hash) * Double(k) * enter * pop * Double(nodeSide) / 48.0
            let scale = CGFloat(side) / nodeSide
            let degrees = (cell.hash - 0.5) * 26.0 + 4.0 * sin(time * 0.3 + phase)

            node.layer.position = point
            node.layer.opacity = Float(alpha)
            node.layer.transform = CATransform3DRotate(CATransform3DMakeScale(scale, scale, 1.0), CGFloat(degrees * .pi / 180.0), 0.0, 0.0, 1.0)
        }

        for (key, node) in self.nodes where !node.isUsed {
            self.detach(node)
            node.fileId = nil
            node.layer.contents = nil
            node.layer.removeFromSuperlayer()
            self.reusableNodes.append(node)
            self.nodes.removeValue(forKey: key)
        }

        CATransaction.commit()
    }

    private func detach(_ node: QrStudioPatternNode) {
        for (_, animation) in self.animations {
            animation.detach(node.layer)
        }
    }
}
