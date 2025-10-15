import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import TelegramCore
import BundleIconComponent
import MultilineTextComponent
import MoreButtonNode
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting

final class PriceButtonComponent: Component {
    let price: CurrencyAmount
    let dateTimeFormat: PresentationDateTimeFormat

    init(
        price: CurrencyAmount,
        dateTimeFormat: PresentationDateTimeFormat
    ) {
        self.price = price
        self.dateTimeFormat = dateTimeFormat
    }

    static func ==(lhs: PriceButtonComponent, rhs: PriceButtonComponent) -> Bool {
        return lhs.price == rhs.price && lhs.dateTimeFormat == rhs.dateTimeFormat
    }

    final class View: UIView {
        private let backgroundView = UIView()
        
        private let icon = UIImageView()
        private let text = ComponentView<Empty>()
                
        private var component: PriceButtonComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            self.addSubview(self.backgroundView)
            
            self.backgroundView.addSubview(self.icon)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: PriceButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            if previousComponent?.price.currency != component.price.currency {
                switch component.price.currency {
                case .stars:
                    self.icon.image = UIImage(bundleImageName: "Premium/Stars/ButtonStar")?.withRenderingMode(.alwaysTemplate)
                case .ton:
                    self.icon.image = UIImage(bundleImageName: "Ads/TonAbout")?.withRenderingMode(.alwaysTemplate)
                }
            }
                        
            var backgroundSize = CGSize(width: 42.0, height: 30.0)
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: formatCurrencyAmountText(component.price, dateTimeFormat: component.dateTimeFormat),
                        font: Font.semibold(11.0),
                        textColor: UIColor(rgb: 0xffffff)
                    ))
                )),
                environment: {},
                containerSize: availableSize
            )
            let textFrame = CGRect(origin: CGPoint(x: 32.0, y: floorToScreenPixels((backgroundSize.height - textSize.height) / 2.0)), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.backgroundView.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
            }
            backgroundSize.width += textSize.width
            
            self.backgroundView.layer.cornerRadius = backgroundSize.height / 2.0
            
            let backgroundColor: UIColor = UIColor(rgb: 0xffffff, alpha: 0.1)
            transition.setBackgroundColor(view: self.backgroundView, color: backgroundColor)
            
            let backgroundFrame = CGRect(origin: .zero, size: backgroundSize)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            
            if let iconSize = self.icon.image?.size {
                let iconFrame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((backgroundSize.height - iconSize.height) / 2.0)), size: iconSize)
                transition.setFrame(view: self.icon, frame: iconFrame)
            }
            self.icon.tintColor = UIColor(rgb: 0xffffff)
            
            return backgroundSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ButtonsComponent: Component {
    let theme: PresentationTheme
    let isOverlay: Bool
    let showMoreButton: Bool
    let closePressed: () -> Void
    let morePressed: (ASDisplayNode, ContextGesture?) -> Void

    init(
        theme: PresentationTheme,
        isOverlay: Bool,
        showMoreButton: Bool,
        closePressed: @escaping () -> Void,
        morePressed: @escaping (ASDisplayNode, ContextGesture?) -> Void
    ) {
        self.theme = theme
        self.isOverlay = isOverlay
        self.showMoreButton = showMoreButton
        self.closePressed = closePressed
        self.morePressed = morePressed
    }

    static func ==(lhs: ButtonsComponent, rhs: ButtonsComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.isOverlay == rhs.isOverlay && lhs.showMoreButton == rhs.showMoreButton
    }

    final class View: UIView {
        private let backgroundView = UIView()
        
        private let closeButton = HighlightTrackingButton()
        private let closeIcon = UIImageView()
        private let moreNode = MoreButtonNode(theme: defaultPresentationTheme, size: CGSize(width: 36.0, height: 36.0), encircled: false)
                
        private var component: ButtonsComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            self.addSubview(self.backgroundView)
            
            self.closeIcon.image = generateCloseButtonImage()
            self.moreNode.updateColor(.white, transition: .immediate)

            self.backgroundView.addSubview(self.moreNode.view)
            self.backgroundView.addSubview(self.closeButton)
            self.backgroundView.addSubview(self.closeIcon)
            
            self.closeButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.closeIcon.layer.removeAnimation(forKey: "opacity")
                    self.closeIcon.alpha = 0.6
                } else {
                    self.closeIcon.alpha = 1.0
                    self.closeIcon.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                }
            }
            self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func closePressed() {
            guard let component = self.component else {
                return
            }
            component.closePressed()
        }
    
        func update(component: ButtonsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                        
            let backgroundSize = CGSize(width: component.showMoreButton ? 70.0 : 30.0, height: 30.0)
            self.backgroundView.layer.cornerRadius = backgroundSize.height / 2.0
            
            let backgroundColor: UIColor = component.isOverlay ? UIColor(rgb: 0xffffff, alpha: 0.1) : UIColor(rgb: 0x808084, alpha: 0.1)            
            let foregroundColor: UIColor = component.isOverlay ? .white : component.theme.actionSheet.inputClearButtonColor
            transition.setBackgroundColor(view: self.backgroundView, color: backgroundColor)
            transition.setTintColor(view: self.closeIcon, color: foregroundColor)
            
            let backgroundFrame = CGRect(origin: .zero, size: backgroundSize)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
                                                               
            transition.setFrame(view: self.moreNode.view, frame: CGRect(origin: CGPoint(x: -7.0, y: -4.0), size: CGSize(width: 36.0, height: 36.0)))
            transition.setAlpha(view: self.moreNode.view, alpha: component.showMoreButton ? 1.0 : 0.0)
            self.moreNode.action = { [weak self] node, gesture in
                guard let self, let component = self.component else {
                    return
                }
                component.morePressed(node, gesture)
            }
            
            let closeFrame = CGRect(origin: CGPoint(x: backgroundSize.width - 30.0 - (component.showMoreButton ? 3.0 : 0.0), y: 0.0), size: CGSize(width: 30.0, height: 30.0))
            transition.setFrame(view: self.closeIcon, frame: closeFrame)
            transition.setFrame(view: self.closeButton, frame: closeFrame)

            return backgroundSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateCloseButtonImage() -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
                
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(UIColor.white.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })?.withRenderingMode(.alwaysTemplate)
}

func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}
