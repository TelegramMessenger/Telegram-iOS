import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import HierarchyTrackingLayer

private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)

private let latePurple = UIColor(rgb: 0x974aa9)
private let latePink = UIColor(rgb: 0xf0436c)

final class VideoChatScheduledInfoComponent: Component {
    let timestamp: Int32
    let strings: PresentationStrings

    init(
        timestamp: Int32,
        strings: PresentationStrings
    ) {
        self.timestamp = timestamp
        self.strings = strings
    }

    static func ==(lhs: VideoChatScheduledInfoComponent, rhs: VideoChatScheduledInfoComponent) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let countdownText = ComponentView<Empty>()
        private let dateText = ComponentView<Empty>()
        
        private let countdownContainerView: UIView
        private let countdownMaskView: UIView
        private let countdownGradientLayer: SimpleGradientLayer
        private let hierarchyTrackingLayer: HierarchyTrackingLayer

        private var component: VideoChatScheduledInfoComponent?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.countdownContainerView = UIView()
            self.countdownMaskView = UIView()
            
            self.countdownGradientLayer = SimpleGradientLayer()
            self.countdownGradientLayer.type = .radial
            self.countdownGradientLayer.colors = [pink.cgColor, purple.cgColor, purple.cgColor]
            self.countdownGradientLayer.locations = [0.0, 0.85, 1.0]
            self.countdownGradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
            self.countdownGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
            
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            
            self.countdownContainerView.layer.addSublayer(self.countdownGradientLayer)
            self.addSubview(self.countdownContainerView)
            
            self.countdownContainerView.mask = self.countdownMaskView
            
            self.hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] value in
                guard let self else {
                    return
                }
                if value {
                    self.updateAnimations()
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateAnimations() {
            if let _ = self.countdownGradientLayer.animation(forKey: "movement") {
            } else {
                let previousValue = self.countdownGradientLayer.startPoint
                let newValue = CGPoint(x: CGFloat.random(in: 0.65 ..< 0.85), y: CGFloat.random(in: 0.1 ..< 0.45))
                self.countdownGradientLayer.startPoint = newValue
                
                CATransaction.begin()
                
                let animation = CABasicAnimation(keyPath: "startPoint")
                animation.duration = Double.random(in: 0.8 ..< 1.4)
                animation.fromValue = previousValue
                animation.toValue = newValue
                
                CATransaction.setCompletionBlock { [weak self] in
                    guard let self else {
                        return
                    }
                    if self.hierarchyTrackingLayer.isInHierarchy {
                        self.updateAnimations()
                    }
                }
                
                self.countdownGradientLayer.add(animation, forKey: "movement")
                CATransaction.commit()
            }
        }
        
        func update(component: VideoChatScheduledInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Starts in", font: Font.with(size: 23.0, design: .round, weight: .semibold), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 200.0)
            )
            
            let remainingSeconds: Int32 = max(0, component.timestamp - Int32(Date().timeIntervalSince1970))
            let countdownText: String
            if remainingSeconds >= 86400 {
                countdownText = scheduledTimeIntervalString(strings: component.strings, value: remainingSeconds)
            } else {
                countdownText = textForTimeout(value: abs(remainingSeconds))
                /*if remainingSeconds < 0 && !self.isLate {
                    self.isLate = true
                    self.foregroundGradientLayer.colors = [latePink.cgColor, latePurple.cgColor, latePurple.cgColor]
                }*/
            }
            
            let countdownTextSize = self.countdownText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: countdownText, font: Font.with(size: 68.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 400.0)
            )
            
            let dateText = humanReadableStringForTimestamp(strings: component.strings, dateTimeFormat: PresentationDateTimeFormat(), timestamp: component.timestamp, alwaysShowTime: true).string
            
            let dateTextSize = self.dateText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: dateText, font: Font.with(size: 23.0, design: .round, weight: .semibold), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 400.0)
            )
            
            let titleSpacing: CGFloat = 5.0
            let dateSpacing: CGFloat = 5.0
            
            let contentHeight: CGFloat = titleSize.height + titleSpacing + countdownTextSize.height + dateSpacing + dateTextSize.height
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((availableSize.height - contentHeight) * 0.5)), size: titleSize)
            let countdownTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - countdownTextSize.width) * 0.5), y: titleFrame.maxY + titleSpacing), size: countdownTextSize)
            let dateTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - dateTextSize.width) * 0.5), y: countdownTextFrame.maxY + dateSpacing), size: dateTextSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            if let countdownTextView = self.countdownText.view {
                if countdownTextView.superview == nil {
                    self.countdownMaskView.addSubview(countdownTextView)
                }
                transition.setFrame(view: countdownTextView, frame: CGRect(origin: CGPoint(), size: countdownTextFrame.size))
            }
            
            transition.setFrame(view: self.countdownContainerView, frame: countdownTextFrame)
            transition.setFrame(view: self.countdownMaskView, frame: CGRect(origin: CGPoint(), size: countdownTextFrame.size))
            transition.setFrame(layer: self.countdownGradientLayer, frame: CGRect(origin: CGPoint(), size: countdownTextFrame.size))
            
            if let dateTextView = self.dateText.view {
                if dateTextView.superview == nil {
                    self.addSubview(dateTextView)
                }
                transition.setPosition(view: dateTextView, position: dateTextFrame.center)
                dateTextView.bounds = CGRect(origin: CGPoint(), size: dateTextFrame.size)
            }
            
            self.updateAnimations()
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
