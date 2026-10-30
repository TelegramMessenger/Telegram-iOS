import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import AccountContext

/// The effort slider at the bottom of the agent composer's menu: a separator line, "Effort" with the chosen step's title, and a 30 pt track of five steps filled with a blue gradient up to its
/// knob.
final class AgentComposerEffortSliderItem: ContextMenuCustomItem {
    private let efforts: [AgentChatPlaceholderOptions.Effort]
    private let effort: AgentChatPlaceholderOptions.Effort
    private let effortChanged: (AgentChatPlaceholderOptions.Effort) -> Void

    init(efforts: [AgentChatPlaceholderOptions.Effort], effort: AgentChatPlaceholderOptions.Effort, effortChanged: @escaping (AgentChatPlaceholderOptions.Effort) -> Void) {
        self.efforts = efforts
        self.effort = effort
        self.effortChanged = effortChanged
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return AgentComposerEffortSliderNode(presentationData: presentationData, efforts: self.efforts, effort: self.effort, effortChanged: self.effortChanged)
    }
}

private final class AgentComposerEffortSliderNode: ASDisplayNode, ContextMenuCustomNode, ASGestureRecognizerDelegate {
    private static let width: CGFloat = 300.0
    private static let sideInset: CGFloat = 18.0
    private static let separatorHeight: CGFloat = 21.0
    private static let titleTop: CGFloat = 11.0
    private static let titleHeight: CGFloat = 22.0
    private static let trackTop: CGFloat = 21.0 + 11.0 + 22.0 + 8.0
    private static let trackHeight: CGFloat = 30.0
    private static let bottomInset: CGFloat = 21.0
    private static let knobSize: CGFloat = 24.0

    private var presentationData: PresentationData
    private let efforts: [AgentChatPlaceholderOptions.Effort]
    private let effortChanged: (AgentChatPlaceholderOptions.Effort) -> Void

    private let separatorView = UIView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let trackView = UIView()
    private let fillLayer = CAGradientLayer()
    private var dotLayers: [CALayer] = []
    private let knobView = UIView()

    private let hapticFeedback = HapticFeedback()

    private var effort: AgentChatPlaceholderOptions.Effort
    /// The knob's center while a finger drags it; nil when it rests on the chosen step.
    private var draggingKnobX: CGFloat?

    var needsSeparator: Bool {
        return false
    }

    var needsPadding: Bool {
        return false
    }

    init(presentationData: PresentationData, efforts: [AgentChatPlaceholderOptions.Effort], effort: AgentChatPlaceholderOptions.Effort, effortChanged: @escaping (AgentChatPlaceholderOptions.Effort) -> Void) {
        self.presentationData = presentationData
        self.efforts = efforts
        self.effort = effort
        self.effortChanged = effortChanged

        super.init()

        self.fillLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.fillLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        self.fillLayer.colors = [UIColor(rgb: 0x5cadff).cgColor, UIColor(rgb: 0x007aff).cgColor]
        self.fillLayer.cornerRadius = Self.trackHeight * 0.5
        self.trackView.layer.cornerRadius = Self.trackHeight * 0.5
        self.trackView.layer.addSublayer(self.fillLayer)
        self.trackView.isUserInteractionEnabled = false

        for _ in 0 ..< efforts.count {
            let dotLayer = CALayer()
            dotLayer.backgroundColor = UIColor(white: 0.0, alpha: 0.3).cgColor
            dotLayer.cornerRadius = 3.0
            dotLayer.compositingFilter = "overlayBlendMode"
            self.trackView.layer.addSublayer(dotLayer)
            self.dotLayers.append(dotLayer)
        }

        self.knobView.backgroundColor = .white
        self.knobView.layer.cornerRadius = Self.knobSize * 0.5
        self.knobView.layer.shadowColor = UIColor.black.cgColor
        self.knobView.layer.shadowOpacity = 0.18
        self.knobView.layer.shadowRadius = 1.5
        self.knobView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        self.knobView.layer.shadowPath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: CGSize(width: Self.knobSize, height: Self.knobSize))).cgPath
        self.trackView.addSubview(self.knobView)

        self.updateColors()
    }

    override func didLoad() {
        super.didLoad()

        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.addSubview(self.separatorView)
        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.valueLabel)
        self.view.addSubview(self.trackView)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panGestureRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.view.addGestureRecognizer(panGestureRecognizer)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }

    private func updateColors() {
        let theme = self.presentationData.theme
        self.separatorView.backgroundColor = theme.contextMenu.itemSeparatorColor
        self.trackView.backgroundColor = UIColor(rgb: 0x787880, alpha: theme.overallDarkAppearance ? 0.32 : 0.16)
        self.titleLabel.attributedText = NSAttributedString(string: self.presentationData.strings.Agent_Effort, font: Font.regular(17.0), textColor: theme.contextMenu.primaryColor)
        self.updateValueLabel()
    }

    private func updateValueLabel() {
        self.valueLabel.attributedText = NSAttributedString(string: self.effort.title, font: Font.regular(17.0), textColor: self.presentationData.theme.contextMenu.primaryColor)
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.updateColors()
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let size = CGSize(width: Self.width, height: Self.trackTop + Self.trackHeight + Self.bottomInset)
        return (size, { [weak self] size, transition in
            guard let self else {
                return
            }
            let contentWidth = size.width - Self.sideInset * 2.0
            transition.updateFrame(view: self.separatorView, frame: CGRect(x: Self.sideInset, y: floor(Self.separatorHeight * 0.5), width: contentWidth, height: UIScreenPixel))

            let titleY = Self.separatorHeight + Self.titleTop
            let titleSize = self.titleLabel.sizeThatFits(CGSize(width: contentWidth, height: Self.titleHeight))
            transition.updateFrame(view: self.titleLabel, frame: CGRect(x: Self.sideInset, y: titleY, width: titleSize.width, height: Self.titleHeight))
            self.layoutValueLabel(width: size.width)

            transition.updateFrame(view: self.trackView, frame: CGRect(x: Self.sideInset, y: Self.trackTop, width: contentWidth, height: Self.trackHeight))
            for (index, dotLayer) in self.dotLayers.enumerated() {
                dotLayer.frame = CGRect(x: self.stepX(index, trackWidth: contentWidth) - 3.0, y: Self.trackHeight * 0.5 - 3.0, width: 6.0, height: 6.0)
            }
            self.layoutKnob(transition: transition)
        })
    }

    private func layoutValueLabel(width: CGFloat) {
        let valueSize = self.valueLabel.sizeThatFits(CGSize(width: width, height: Self.titleHeight))
        self.valueLabel.frame = CGRect(x: width - Self.sideInset - valueSize.width, y: Self.separatorHeight + Self.titleTop, width: valueSize.width, height: Self.titleHeight)
    }

    /// The knob's center on the track for a step: the end steps put the knob 3 pt from the track's ends.
    private func stepX(_ index: Int, trackWidth: CGFloat) -> CGFloat {
        let inset = Self.trackHeight * 0.5
        let stepCount = CGFloat(max(1, self.efforts.count - 1))
        return inset + (trackWidth - inset * 2.0) * CGFloat(index) / stepCount
    }

    private func stepIndex(_ effort: AgentChatPlaceholderOptions.Effort) -> Int {
        return self.efforts.firstIndex(of: effort) ?? 0
    }

    private func nearestEffort(knobX: CGFloat) -> AgentChatPlaceholderOptions.Effort {
        let trackWidth = self.trackView.bounds.width
        let cases = self.efforts
        var result = cases[0]
        var minDistance: CGFloat = .greatestFiniteMagnitude
        for (index, effort) in cases.enumerated() {
            let distance = abs(self.stepX(index, trackWidth: trackWidth) - knobX)
            if distance < minDistance {
                minDistance = distance
                result = effort
            }
        }
        return result
    }

    private func layoutKnob(transition: ContainedViewLayoutTransition) {
        let trackWidth = self.trackView.bounds.width
        let knobX = self.draggingKnobX ?? self.stepX(self.stepIndex(self.effort), trackWidth: trackWidth)
        let knobY = Self.trackHeight * 0.5
        transition.updateFrame(view: self.knobView, frame: CGRect(x: knobX - Self.knobSize * 0.5, y: knobY - Self.knobSize * 0.5, width: Self.knobSize, height: Self.knobSize))
        // The fill ends 3 pt past the knob, so at the first step it is a blue ring around the knob.
        transition.updateFrame(layer: self.fillLayer, frame: CGRect(x: 0.0, y: 0.0, width: knobX + Self.trackHeight * 0.5, height: Self.trackHeight))
    }

    private func setEffort(_ effort: AgentChatPlaceholderOptions.Effort) {
        guard self.effort != effort else {
            return
        }
        self.effort = effort
        self.hapticFeedback.tap()
        self.updateValueLabel()
        self.layoutValueLabel(width: self.bounds.width)
        self.effortChanged(effort)
    }

    private func knobX(location: CGPoint) -> CGFloat {
        let trackWidth = self.trackView.bounds.width
        let x = self.view.convert(location, to: self.trackView).x
        return max(self.stepX(0, trackWidth: trackWidth), min(self.stepX(self.efforts.count - 1, trackWidth: trackWidth), x))
    }

    @objc private func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began, .changed:
            let knobX = self.knobX(location: gestureRecognizer.location(in: self.view))
            let wasDragging = self.draggingKnobX != nil
            self.draggingKnobX = knobX
            self.setEffort(self.nearestEffort(knobX: knobX))
            self.layoutKnob(transition: wasDragging ? .immediate : .animated(duration: 0.2, curve: .easeInOut))
        case .ended, .cancelled, .failed:
            self.draggingKnobX = nil
            self.layoutKnob(transition: .animated(duration: 0.3, curve: .spring))
        default:
            break
        }
    }

    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let knobX = self.knobX(location: gestureRecognizer.location(in: self.view))
        self.setEffort(self.nearestEffort(knobX: knobX))
        self.layoutKnob(transition: .animated(duration: 0.3, curve: .spring))
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
    }
}
