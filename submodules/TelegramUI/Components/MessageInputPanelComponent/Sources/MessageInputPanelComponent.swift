import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

public final class MessageInputPanelComponent: Component {
    public init() {
        
    }
    
    public static func ==(lhs: MessageInputPanelComponent, rhs: MessageInputPanelComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private let fieldBackgroundView: UIImageView
        private let fieldPlaceholder = ComponentView<Empty>()
        
        private let attachmentIconView: UIImageView
        private let recordingIconView: UIImageView
        private let stickerIconView: UIImageView
        
        private var component: MessageInputPanelComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.fieldBackgroundView = UIImageView()
            self.attachmentIconView = UIImageView()
            self.recordingIconView = UIImageView()
            self.stickerIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.fieldBackgroundView)
            
            self.addSubview(self.fieldBackgroundView)
            self.addSubview(self.attachmentIconView)
            self.addSubview(self.recordingIconView)
            self.addSubview(self.stickerIconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: MessageInputPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let insets = UIEdgeInsets(top: 5.0, left: 41.0, bottom: 5.0, right: 41.0)
            let fieldCornerRadius: CGFloat = 16.0
            
            self.component = component
            self.state = state
            
            if self.fieldBackgroundView.image == nil {
                self.fieldBackgroundView.image = generateStretchableFilledCircleImage(diameter: fieldCornerRadius * 2.0, color: nil, strokeColor: UIColor(white: 1.0, alpha: 0.16), strokeWidth: 1.0, backgroundColor: nil)
            }
            if self.attachmentIconView.image == nil {
                self.attachmentIconView.image = UIImage(bundleImageName: "Chat/Input/Text/IconAttachment")?.withRenderingMode(.alwaysTemplate)
                self.attachmentIconView.tintColor = .white
            }
            if self.recordingIconView.image == nil {
                self.recordingIconView.image = UIImage(bundleImageName: "Chat/Input/Text/IconMicrophone")?.withRenderingMode(.alwaysTemplate)
                self.recordingIconView.tintColor = .white
            }
            if self.stickerIconView.image == nil {
                self.stickerIconView.image = UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconStickers")?.withRenderingMode(.alwaysTemplate)
                self.stickerIconView.tintColor = .white
            }
            
            let fieldFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: availableSize.width - insets.left - insets.right, height: availableSize.height - insets.top - insets.bottom))
            transition.setFrame(view: self.fieldBackgroundView, frame: fieldFrame)
            
            let rightFieldInset: CGFloat = 34.0
            
            let placeholderSize = self.fieldPlaceholder.update(
                transition: .immediate,
                component: AnyComponent(Text(text: "Reply Privately...", font: Font.regular(17.0), color: UIColor(white: 1.0, alpha: 0.16))),
                environment: {},
                containerSize: fieldFrame.size
            )
            if let fieldPlaceholderView = self.fieldPlaceholder.view {
                if fieldPlaceholderView.superview == nil {
                    fieldPlaceholderView.layer.anchorPoint = CGPoint()
                    fieldPlaceholderView.isUserInteractionEnabled = false
                    self.addSubview(fieldPlaceholderView)
                }
                fieldPlaceholderView.bounds = CGRect(origin: CGPoint(), size: placeholderSize)
                transition.setPosition(view: fieldPlaceholderView, position: CGPoint(x: fieldFrame.minX + 12.0, y: fieldFrame.minY + floor((fieldFrame.height - placeholderSize.height) * 0.5)))
            }
            
            if let image = self.attachmentIconView.image {
                transition.setFrame(view: self.attachmentIconView, frame: CGRect(origin: CGPoint(x: floor((insets.left - image.size.width) * 0.5), y: floor((availableSize.height - image.size.height) * 0.5)), size: image.size))
            }
            if let image = self.recordingIconView.image {
                transition.setFrame(view: self.recordingIconView, frame: CGRect(origin: CGPoint(x: availableSize.width - insets.right + floor((insets.right - image.size.width) * 0.5), y: floor((availableSize.height - image.size.height) * 0.5)), size: image.size))
            }
            if let image = self.stickerIconView.image {
                transition.setFrame(view: self.stickerIconView, frame: CGRect(origin: CGPoint(x: fieldFrame.maxX - rightFieldInset + floor((rightFieldInset - image.size.width) * 0.5), y: fieldFrame.minY + floor((fieldFrame.height - image.size.height) * 0.5)), size: image.size))
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
