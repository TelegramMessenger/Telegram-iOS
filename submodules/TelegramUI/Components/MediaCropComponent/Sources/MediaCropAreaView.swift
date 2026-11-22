import Foundation
import UIKit
import Display

private let mediaCropControlSize: CGFloat = 44.0
let mediaCropControlHitInset: CGFloat = 16.0
private let mediaCropGridThickness: CGFloat = 0.5
private let mediaCropGridFadeDuration: Double = 0.2

final class MediaCropControlView: UIView, UIGestureRecognizerDelegate {
    let handle: MediaCropHandle
    private let hitInsets: UIEdgeInsets

    var shouldBegin: ((MediaCropControlView) -> Bool)?
    var began: ((MediaCropControlView) -> Void)?
    var changed: ((MediaCropControlView, CGPoint) -> Void)?
    var ended: ((MediaCropControlView) -> Void)?

    private var beganInteraction = false
    private var endedInteraction = false

    init(handle: MediaCropHandle) {
        self.handle = handle
        switch handle {
        case .top, .bottom:
            self.hitInsets = UIEdgeInsets(top: -mediaCropControlHitInset, left: 0.0, bottom: -mediaCropControlHitInset, right: 0.0)
        case .left, .right:
            self.hitInsets = UIEdgeInsets(top: 0.0, left: -mediaCropControlHitInset, bottom: 0.0, right: -mediaCropControlHitInset)
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            self.hitInsets = UIEdgeInsets(top: -mediaCropControlHitInset, left: -mediaCropControlHitInset, bottom: -mediaCropControlHitInset, right: -mediaCropControlHitInset)
        }

        super.init(frame: .zero)

        self.isExclusiveTouch = true
        self.layer.contents = MediaCropAssets.transparentContents

        let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
        pressGestureRecognizer.minimumPressDuration = 0.1
        pressGestureRecognizer.delegate = self
        self.addGestureRecognizer(pressGestureRecognizer)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panGestureRecognizer.delegate = self
        self.addGestureRecognizer(panGestureRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.inset(by: self.hitInsets).contains(point)
    }

    private func begin() {
        if self.beganInteraction {
            return
        }
        self.began?(self)
        self.endedInteraction = false
        self.beganInteraction = true
    }

    private func end() {
        self.beganInteraction = false
        if self.endedInteraction {
            return
        }
        self.ended?(self)
        self.endedInteraction = true
    }

    @objc private func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            self.begin()
        case .ended, .cancelled:
            self.end()
        default:
            break
        }
    }

    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self.superview)
        switch gestureRecognizer.state {
        case .began, .changed:
            if gestureRecognizer.state == .began {
                self.begin()
            }
            self.changed?(self, CGPoint(x: translation.x.rounded(), y: translation.y))
            gestureRecognizer.setTranslation(.zero, in: self.superview)
        case .ended, .cancelled:
            self.end()
        default:
            break
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.shouldBegin?(self) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

final class MediaCropGridView: UIView {
    enum Mode {
        case major
        case minor
    }

    private let mode: Mode
    private var verticalLines: [UIView] = []
    private var horizontalLines: [UIView] = []
    private var targetHidden = true

    init(mode: Mode) {
        self.mode = mode

        super.init(frame: .zero)

        self.isUserInteractionEnabled = false
        self.isHidden = true
        self.alpha = 0.0

        let color: UIColor
        let count: Int
        switch mode {
        case .major:
            color = .white
            count = 2
        case .minor:
            color = UIColor(rgb: 0xeeeeee, alpha: 0.7)
            count = 9
        }
        for _ in 0 ..< count {
            let vertical = UIView()
            vertical.backgroundColor = color
            self.addSubview(vertical)
            self.verticalLines.append(vertical)

            let horizontal = UIView()
            horizontal.backgroundColor = color
            self.addSubview(horizontal)
            self.horizontalLines.append(horizontal)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func linePosition(index: Int, length: CGFloat) -> CGFloat {
        switch self.mode {
        case .major:
            return (length / 3.0 * CGFloat(index + 1)).rounded()
        case .minor:
            let section = index / 3
            let step = index % 3 + 1
            return (length / 3.0 / 3.0 * CGFloat(step) + length / 3.0 * CGFloat(section)).rounded()
        }
    }

    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        for (index, line) in self.verticalLines.enumerated() {
            transition.updateFrame(view: line, frame: CGRect(x: self.linePosition(index: index, length: size.width), y: 0.0, width: mediaCropGridThickness, height: size.height.rounded()))
        }
        for (index, line) in self.horizontalLines.enumerated() {
            transition.updateFrame(view: line, frame: CGRect(x: 0.0, y: self.linePosition(index: index, length: size.height), width: size.width.rounded(), height: mediaCropGridThickness))
        }
    }

    func setVisible(_ visible: Bool, animated: Bool) {
        let hidden = !visible
        if self.targetHidden == hidden {
            return
        }
        self.targetHidden = hidden
        if animated {
            self.isHidden = false
            UIView.animate(withDuration: mediaCropGridFadeDuration, delay: 0.0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
                self.alpha = hidden ? 0.0 : 1.0
            }, completion: { [weak self] finished in
                guard let self, finished, self.targetHidden == hidden else {
                    return
                }
                self.isHidden = hidden
            })
        } else {
            self.isHidden = hidden
            self.alpha = hidden ? 0.0 : 1.0
        }
    }
}

final class MediaCropAreaView: UIView {
    enum GridMode {
        case none
        case major
        case minor
    }

    private let cornersView: UIImageView
    private let midEdgeHandleViews: [MediaCropHandle: UIView]
    private let topEdgeHighlight = UIView()
    private let leftEdgeHighlight = UIView()
    private let rightEdgeHighlight = UIView()
    private let bottomEdgeHighlight = UIView()
    private var controls: [MediaCropControlView] = []
    private let majorGridView = MediaCropGridView(mode: .major)
    private let minorGridView = MediaCropGridView(mode: .minor)

    private(set) var isTracking = false
    private(set) var gridMode: GridMode = .none
    private var activeHandle: MediaCropHandle?

    var shouldBeginResizing: (() -> Bool)?
    var resizeBegan: ((MediaCropHandle) -> Void)?
    var resizeChanged: ((MediaCropHandle, CGPoint) -> Void)?
    var resizeEnded: ((MediaCropHandle) -> Void)?

    var isAspectRatioLocked = false {
        didSet {
            if self.isAspectRatioLocked != oldValue {
                self.updateEdgeHighlights()
            }
        }
    }

    override init(frame: CGRect) {
        self.cornersView = UIImageView(image: MediaCropAssets.cropFrame)
        var midEdgeHandleViews: [MediaCropHandle: UIView] = [:]
        for handle in [MediaCropHandle.top, .left, .bottom, .right] {
            let view = UIView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .white
            midEdgeHandleViews[handle] = view
        }
        self.midEdgeHandleViews = midEdgeHandleViews

        super.init(frame: frame)

        self.addSubview(self.cornersView)
        for handle in [MediaCropHandle.top, .left, .bottom, .right] {
            if let view = self.midEdgeHandleViews[handle] {
                self.addSubview(view)
            }
        }

        for highlight in [self.topEdgeHighlight, self.leftEdgeHighlight, self.rightEdgeHighlight, self.bottomEdgeHighlight] {
            highlight.backgroundColor = .white
            highlight.isHidden = true
            self.addSubview(highlight)
        }

        let handles: [MediaCropHandle] = [.top, .left, .bottom, .right, .topLeft, .topRight, .bottomLeft, .bottomRight]
        for handle in handles {
            let control = MediaCropControlView(handle: handle)
            control.shouldBegin = { [weak self] _ in
                guard let self else {
                    return true
                }
                return self.shouldBeginResizing?() ?? true
            }
            control.began = { [weak self] control in
                self?.controlBegan(control.handle)
            }
            control.changed = { [weak self] control, translation in
                self?.resizeChanged?(control.handle, translation)
            }
            control.ended = { [weak self] control in
                self?.controlEnded(control.handle)
            }
            self.addSubview(control)
            self.controls.append(control)
        }

        self.addSubview(self.majorGridView)
        self.addSubview(self.minorGridView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -mediaCropControlHitInset, dy: -mediaCropControlHitInset).contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result is MediaCropControlView {
            return result
        }
        return nil
    }

    private func controlBegan(_ handle: MediaCropHandle) {
        self.isTracking = true
        self.activeHandle = handle
        self.resizeBegan?(handle)
        self.updateEdgeHighlights()
    }

    private func controlEnded(_ handle: MediaCropHandle) {
        self.isTracking = false
        self.activeHandle = nil
        self.resizeEnded?(handle)
        self.updateEdgeHighlights()
    }

    private func updateEdgeHighlights() {
        let locked = self.isAspectRatioLocked
        self.topEdgeHighlight.isHidden = !(locked || self.activeHandle == .top)
        self.leftEdgeHighlight.isHidden = !(locked || self.activeHandle == .left)
        self.rightEdgeHighlight.isHidden = !(locked || self.activeHandle == .right)
        self.bottomEdgeHighlight.isHidden = !(locked || self.activeHandle == .bottom)
    }

    func setGridMode(_ mode: GridMode, animated: Bool) {
        if self.gridMode == mode {
            return
        }
        self.gridMode = mode
        self.majorGridView.setVisible(mode == .major, animated: animated)
        self.minorGridView.setVisible(mode == .minor, animated: animated)
    }

    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: .zero, size: size)
        transition.updateFrame(view: self.cornersView, frame: bounds.insetBy(dx: -mediaCropHandleThickness, dy: -mediaCropHandleThickness))

        let thickness = mediaCropHandleThickness
        let length = mediaCropMidEdgeHandleLength
        for (handle, view) in self.midEdgeHandleViews {
            let frame: CGRect
            let sideLength: CGFloat
            switch handle {
            case .top:
                frame = CGRect(x: (size.width - length) / 2.0, y: -thickness, width: length, height: thickness)
                sideLength = size.width
            case .bottom:
                frame = CGRect(x: (size.width - length) / 2.0, y: size.height, width: length, height: thickness)
                sideLength = size.width
            case .left:
                frame = CGRect(x: -thickness, y: (size.height - length) / 2.0, width: thickness, height: length)
                sideLength = size.height
            default:
                frame = CGRect(x: size.width, y: (size.height - length) / 2.0, width: thickness, height: length)
                sideLength = size.height
            }
            transition.updateFrame(view: view, frame: frame)
            transition.updateAlpha(layer: view.layer, alpha: mediaCropShowsMidEdgeHandle(sideLength: sideLength) ? 1.0 : 0.0)
        }

        transition.updateFrame(view: self.topEdgeHighlight, frame: CGRect(x: 0.0, y: -1.0, width: size.width, height: 2.0))
        transition.updateFrame(view: self.leftEdgeHighlight, frame: CGRect(x: -1.0, y: 0.0, width: 2.0, height: size.height))
        transition.updateFrame(view: self.rightEdgeHighlight, frame: CGRect(x: size.width - 1.0, y: 0.0, width: 2.0, height: size.height))
        transition.updateFrame(view: self.bottomEdgeHighlight, frame: CGRect(x: 0.0, y: size.height - 1.0, width: size.width, height: 2.0))

        let half = mediaCropControlSize / 2.0
        for control in self.controls {
            let frame: CGRect
            switch control.handle {
            case .top:
                frame = CGRect(x: half, y: -half, width: size.width - mediaCropControlSize, height: mediaCropControlSize)
            case .left:
                frame = CGRect(x: -half, y: half, width: mediaCropControlSize, height: size.height - mediaCropControlSize)
            case .bottom:
                frame = CGRect(x: half, y: size.height - half, width: size.width - mediaCropControlSize, height: mediaCropControlSize)
            case .right:
                frame = CGRect(x: size.width - half, y: half, width: mediaCropControlSize, height: size.height - mediaCropControlSize)
            case .topLeft:
                frame = CGRect(x: -half, y: -half, width: mediaCropControlSize, height: mediaCropControlSize)
            case .topRight:
                frame = CGRect(x: size.width - half, y: -half, width: mediaCropControlSize, height: mediaCropControlSize)
            case .bottomLeft:
                frame = CGRect(x: -half, y: size.height - half, width: mediaCropControlSize, height: mediaCropControlSize)
            case .bottomRight:
                frame = CGRect(x: size.width - half, y: size.height - half, width: mediaCropControlSize, height: mediaCropControlSize)
            }
            transition.updateFrame(view: control, frame: CGRect(origin: frame.origin, size: CGSize(width: max(0.0, frame.width), height: max(0.0, frame.height))))
        }

        transition.updateFrame(view: self.majorGridView, frame: bounds)
        self.majorGridView.update(size: size, transition: transition)
        transition.updateFrame(view: self.minorGridView, frame: bounds)
        self.minorGridView.update(size: size, transition: transition)
    }
}
