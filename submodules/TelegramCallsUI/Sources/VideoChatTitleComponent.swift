import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import HierarchyTrackingLayer
import ChatTitleActivityNode

final class VideoChatTitleComponent: Component {
    let title: String
    let status: String
    let isRecording: Bool
    let strings: PresentationStrings
    let tapAction: (() -> Void)?
    let longTapAction: (() -> Void)?

    init(
        title: String,
        status: String,
        isRecording: Bool,
        strings: PresentationStrings,
        tapAction: (() -> Void)?,
        longTapAction: (() -> Void)?
    ) {
        self.title = title
        self.status = status
        self.isRecording = isRecording
        self.strings = strings
        self.tapAction = tapAction
        self.longTapAction = longTapAction
    }

    static func ==(lhs: VideoChatTitleComponent, rhs: VideoChatTitleComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        if lhs.isRecording != rhs.isRecording {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if (lhs.tapAction == nil) != (rhs.tapAction == nil) {
            return false
        }
        if (lhs.longTapAction == nil) != (rhs.longTapAction == nil) {
            return false
        }
        return true
    }

    final class View: UIView {
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        private let title = ComponentView<Empty>()
        private let status = ComponentView<Empty>()
        private var recordingImageView: UIImageView?
        
        private var activityStatusNode: ChatTitleActivityNode?

        private var component: VideoChatTitleComponent?
        private var isUpdating: Bool = false
        
        private var currentActivityStatus: String?
        private var currentSize: CGSize?
        
        private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
        
        public var recordingIndicatorView: UIView? {
            return self.recordingImageView
        }
        
        override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.updateAnimations()
            }
            
            let tapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            tapRecognizer.tapActionAtPoint = { _ in
                return .waitForSingleTap
            }
            self.addGestureRecognizer(tapRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                    if case .tap = gesture {
                        component.tapAction?()
                    } else if case .longTap = gesture {
                        component.longTapAction?()
                    }
                }
            }
        }
        
        private func updateAnimations() {
            if let recordingImageView = self.recordingImageView {
                if recordingImageView.layer.animation(forKey: "blink") == nil {
                    let animation = CAKeyframeAnimation(keyPath: "opacity")
                    animation.values = [1.0 as NSNumber, 1.0 as NSNumber, 0.55 as NSNumber]
                    animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
                    animation.duration = 0.7
                    animation.autoreverses = true
                    animation.repeatCount = Float.infinity
                    recordingImageView.layer.add(animation, forKey: "blink")
                }
            }
        }
        
        func updateActivityStatus(value: String?, transition: ComponentTransition) {
            if self.currentActivityStatus == value {
                return
            }
            self.currentActivityStatus = value
            
            guard let currentSize = self.currentSize, let statusView = self.status.view else {
                return
            }
            
            let alphaTransition: ComponentTransition
            if transition.animation.isImmediate {
                alphaTransition = .immediate
            } else {
                alphaTransition = .easeInOut(duration: 0.2)
            }
            
            if let value {
                let activityStatusNode: ChatTitleActivityNode
                if let current = self.activityStatusNode {
                    activityStatusNode = current
                } else {
                    activityStatusNode = ChatTitleActivityNode()
                    self.activityStatusNode = activityStatusNode
                }
                
                let _ = activityStatusNode.transitionToState(.recordingVoice(NSAttributedString(string: value, font: Font.regular(13.0), textColor: UIColor(rgb: 0x34c759)), UIColor(rgb: 0x34c759)), animation: .none)
                let activityStatusSize = activityStatusNode.updateLayout(CGSize(width: currentSize.width, height: 100.0), alignment: .center)
                let activityStatusFrame = CGRect(origin: CGPoint(x: floor((currentSize.width - activityStatusSize.width) * 0.5), y: statusView.center.y - activityStatusSize.height * 0.5), size: activityStatusSize)
                
                let activityStatusNodeView = activityStatusNode.view
                activityStatusNodeView.center = activityStatusFrame.center
                activityStatusNodeView.bounds = CGRect(origin: CGPoint(), size: activityStatusFrame.size)
                if activityStatusNodeView.superview == nil {
                    self.addSubview(activityStatusNode.view)
                    ComponentTransition.immediate.setTransform(view: activityStatusNodeView, transform: CATransform3DMakeTranslation(0.0, -10.0, 0.0))
                    activityStatusNodeView.alpha = 0.0
                }
                transition.setTransform(view: activityStatusNodeView, transform: CATransform3DIdentity)
                alphaTransition.setAlpha(view: activityStatusNodeView, alpha: 1.0)
                
                transition.setTransform(view: statusView, transform: CATransform3DMakeTranslation(0.0, 10.0, 0.0))
                alphaTransition.setAlpha(view: statusView, alpha: 0.0)
            } else {
                if let activityStatusNode = self.activityStatusNode {
                    self.activityStatusNode = nil
                    let activityStatusNodeView = activityStatusNode.view
                    transition.setTransform(view: activityStatusNodeView, transform: CATransform3DMakeTranslation(0.0, -10.0, 0.0))
                    alphaTransition.setAlpha(view: activityStatusNodeView, alpha: 0.0, completion: { [weak activityStatusNodeView] _ in
                        activityStatusNodeView?.removeFromSuperview()
                    })
                }
                
                transition.setTransform(view: statusView, transform: CATransform3DIdentity)
                alphaTransition.setAlpha(view: statusView, alpha: 1.0)
            }
        }
        
        func update(component: VideoChatTitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            self.tapRecognizer?.isEnabled = component.longTapAction != nil || component.tapAction != nil
            
            let spacing: CGFloat = 1.0
            
            var maxTitleWidth = availableSize.width
            if component.isRecording {
                maxTitleWidth -= 10.0
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: maxTitleWidth, height: 100.0)
            )
            
            let statusComponent: AnyComponent<Empty>
            statusComponent = AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: component.status, font: Font.regular(13.0), textColor: UIColor(white: 1.0, alpha: 0.5)))
            ))
            
            let statusSize = self.status.update(
                transition: .immediate,
                component: statusComponent,
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: titleSize.height + spacing + statusSize.height)
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let statusFrame = CGRect(origin: CGPoint(x: floor((size.width - statusSize.width) * 0.5), y: titleFrame.maxY + spacing), size: statusSize)
            if let statusView = self.status.view {
                if statusView.superview == nil {
                    statusView.isUserInteractionEnabled = false
                    self.addSubview(statusView)
                }
                transition.setPosition(view: statusView, position: statusFrame.center)
                statusView.bounds = CGRect(origin: CGPoint(), size: statusFrame.size)
            }
            
            if component.isRecording {
                var recordingImageTransition = transition
                let recordingImageView: UIImageView
                if let current = self.recordingImageView {
                    recordingImageView = current
                } else {
                    recordingImageTransition = recordingImageTransition.withAnimation(.none)
                    recordingImageView = UIImageView()
                    recordingImageView.image = generateFilledCircleImage(diameter: 8.0, color: UIColor(rgb: 0xFF3B2F))
                    self.recordingImageView = recordingImageView
                    self.addSubview(recordingImageView)
                    transition.animateScale(view: recordingImageView, from: 0.0001, to: 1.0)
                }
                let recordingImageFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 5.0, y: titleFrame.minY + floor(titleFrame.height - 8.0) * 0.5 + 1.0), size: CGSize(width: 8.0, height: 8.0))
                recordingImageTransition.setFrame(view: recordingImageView, frame: recordingImageFrame)
                
                self.updateAnimations()
            } else {
                if let recordingImageView = self.recordingImageView {
                    self.recordingImageView = nil
                    transition.setScale(view: recordingImageView, scale: 0.0001, completion: { [weak recordingImageView] _ in
                        recordingImageView?.removeFromSuperview()
                    })
                }
            }
            
            self.currentSize = size
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
