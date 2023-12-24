import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import MessageInlineBlockBackgroundView

public final class ForwardInfoPanelComponent: Component {
    public let authorName: String
    public let text: String
    public let isChannel: Bool
    public let isVibrant: Bool
    public let fillsWidth: Bool
    
    public init(
        authorName: String,
        text: String,
        isChannel: Bool,
        isVibrant: Bool,
        fillsWidth: Bool
    ) {
        self.authorName = authorName
        self.text = text
        self.isChannel = isChannel
        self.isVibrant = isVibrant
        self.fillsWidth = fillsWidth
    }
    
    public static func ==(lhs: ForwardInfoPanelComponent, rhs: ForwardInfoPanelComponent) -> Bool {
        if lhs.authorName != rhs.authorName {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isChannel != rhs.isChannel {
            return false
        }
        if lhs.isVibrant != rhs.isVibrant {
            return false
        }
        if lhs.fillsWidth != rhs.fillsWidth {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        public let backgroundView: UIImageView
//        private let blurBackgroundView: BlurredBackgroundView
        private let blurBackgroundView: UIVisualEffectView
        private let blockView: MessageInlineBlockBackgroundView
        private var iconView: UIImageView?
        private var title = ComponentView<Empty>()
        private var text = ComponentView<Empty>()
        
        private var component: ForwardInfoPanelComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
//            self.blurBackgroundView = BlurredBackgroundView(color: UIColor(rgb: 0x000000, alpha: 0.4))
            
            if #available(iOS 13.0, *) {
                self.blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            } else {
                self.blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            }
            self.blurBackgroundView.clipsToBounds = true
            
            self.backgroundView = UIImageView()
            self.backgroundView.image = generateStretchableFilledCircleImage(radius: 4.0, color: UIColor(white: 1.0, alpha: 0.4))
            
            self.blockView = MessageInlineBlockBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.blockView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ForwardInfoPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var titleOffset: CGFloat = 0.0
            let sideInset: CGFloat = !component.text.isEmpty ? 9.0 : 6.0
            
            let iconView: UIImageView
            if let current = self.iconView {
                iconView = current
            } else {
                iconView = UIImageView(image: UIImage(bundleImageName: component.isChannel ? "Stories/RepostChannel" : "Stories/RepostUser")?.withRenderingMode(.alwaysTemplate))
                iconView.alpha = 0.55
                iconView.tintColor = .white
                self.addSubview(iconView)
                self.iconView = iconView
            }
            if let image = iconView.image {
                iconView.frame = CGRect(origin: CGPoint(x: sideInset + UIScreenPixel, y: 5.0), size: image.size)
            }
            titleOffset += 13.0
       
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.authorName,
                        font: Font.semibold(14.0),
                        textColor: .white
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - titleOffset - 20.0, height: availableSize.height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: sideInset + titleOffset, y: 3.0), size: titleSize)
            if let view = self.title.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = titleFrame
            }
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.text,
                        font: Font.regular(14.0),
                        textColor: .white
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 20.0, height: availableSize.height)
            )
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: 20.0), size: textSize)
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = textFrame
            }
            
            let width: CGFloat
            let size: CGSize
            if component.fillsWidth {
                width = availableSize.width
            } else {
                width = max(titleFrame.maxX, textFrame.maxX) + sideInset
            }
            
            if !component.text.isEmpty {
                size = CGSize(width: width, height: 40.0)
                let lineColor: UIColor
                if !component.isVibrant {
                    self.blurBackgroundView.frame = CGRect(origin: .zero, size: size)
                    self.insertSubview(self.blurBackgroundView, at: 0)
                    
                    lineColor = UIColor(white: 1.0, alpha: 0.55)
                } else {
                    lineColor = UIColor(white: 1.0, alpha: 0.5)
                }
                self.blurBackgroundView.layer.cornerRadius = 4.0
                
                self.blockView.update(size: size, isTransparent: true, primaryColor: lineColor, secondaryColor: nil, thirdColor: nil, backgroundColor: nil, pattern: nil, animation: .None)
                self.blockView.frame = CGRect(origin: .zero, size: size)
            } else {
                size = CGSize(width: titleFrame.maxX + sideInset, height: 23.0)
                
                if !component.isVibrant {
                    self.blurBackgroundView.frame = CGRect(origin: .zero, size: size)
                    self.insertSubview(self.blurBackgroundView, at: 0)
                }
                self.blurBackgroundView.layer.cornerRadius = size.height / 2.0
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
