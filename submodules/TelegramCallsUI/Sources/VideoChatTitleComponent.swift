import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import HierarchyTrackingLayer

final class VideoChatTitleComponent: Component {
    let title: String
    let status: String
    let isRecording: Bool
    let strings: PresentationStrings

    init(
        title: String,
        status: String,
        isRecording: Bool,
        strings: PresentationStrings
    ) {
        self.title = title
        self.status = status
        self.isRecording = isRecording
        self.strings = strings
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
        return true
    }

    final class View: UIView {
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        private let title = ComponentView<Empty>()
        private var status: ComponentView<Empty>?
        private var recordingImageView: UIImageView?

        private var component: VideoChatTitleComponent?
        private var isUpdating: Bool = false
        
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
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
        
        func update(component: VideoChatTitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let spacing: CGFloat = 1.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let status: ComponentView<Empty>
            if let current = self.status {
                status = current
            } else {
                status = ComponentView()
                self.status = status
            }
            let statusComponent: AnyComponent<Empty>
            statusComponent = AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: component.status, font: Font.regular(13.0), textColor: UIColor(white: 1.0, alpha: 0.5)))
            ))
            
            let statusSize = status.update(
                transition: .immediate,
                component: statusComponent,
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: titleSize.height + spacing + statusSize.height)
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: 0.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let statusFrame = CGRect(origin: CGPoint(x: floor((size.width - statusSize.width) * 0.5), y: titleFrame.maxY + spacing), size: statusSize)
            if let statusView = status.view {
                if statusView.superview == nil {
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
