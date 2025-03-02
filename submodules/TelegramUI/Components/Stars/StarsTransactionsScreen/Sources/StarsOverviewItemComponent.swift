import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import AccountContext
import MultilineTextComponent
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import TelegramCore

final class StarsOverviewItemComponent: Component {
    let theme: PresentationTheme
    let dateTimeFormat: PresentationDateTimeFormat
    let title: String
    let value: StarsAmount
    let rate: Double
    
    init(
        theme: PresentationTheme,
        dateTimeFormat: PresentationDateTimeFormat,
        title: String,
        value: StarsAmount,
        rate: Double
    ) {
        self.theme = theme
        self.dateTimeFormat = dateTimeFormat
        self.title = title
        self.value = value
        self.rate = rate
    }
    
    static func ==(lhs: StarsOverviewItemComponent, rhs: StarsOverviewItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.rate != rhs.rate {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = UIImageView()
        private let value = ComponentView<Empty>()
        private let usdValue = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        
        private var component: StarsOverviewItemComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.icon.image = UIImage(bundleImageName: "Premium/Stars/StarMedium")
            
            self.addSubview(self.icon)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StarsOverviewItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 16.0
            
            var valueOffset: CGFloat = 0.0
            if let icon = self.icon.image {
                self.icon.frame = CGRect(origin: CGPoint(x: sideInset - 1.0, y: 10.0), size: icon.size)
                valueOffset += icon.size.width
            }
            
            let valueString = formatStarsAmountText(component.value, dateTimeFormat: component.dateTimeFormat)
            let usdValueString = formatTonUsdValue(component.value.value, divide: false, rate: component.rate, dateTimeFormat: component.dateTimeFormat)
            
            let valueSize = self.value.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: valueString, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let valueFrame = CGRect(origin: CGPoint(x: sideInset + valueOffset + 2.0, y: 10.0), size: valueSize)
            if let valueView = self.value.view {
                if valueView.superview == nil {
                    self.addSubview(valueView)
                }
                valueView.frame = valueFrame
            }
            
            let usdValueSize = self.usdValue.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "≈\(usdValueString)", font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let usdValueFrame = CGRect(origin: CGPoint(x: sideInset + valueOffset + valueSize.width + 6.0, y: 14.0), size: usdValueSize)
            if let usdValueView = self.usdValue.view {
                if usdValueView.superview == nil {
                    self.addSubview(usdValueView)
                }
                usdValueView.frame = usdValueFrame
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.title, font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: 32.0), size: titleSize)
                titleView.frame = titleFrame
            }
            
            return CGSize(width: availableSize.width, height: 59.0)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
