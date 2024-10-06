import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import BundleIconComponent
import MultilineTextComponent
import UrlEscaping

final class TitleBarContentComponent: Component {
    public typealias EnvironmentType = BrowserNavigationBarEnvironment
    
    let theme: PresentationTheme
    let title: String
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: TitleBarContentComponent, rhs: TitleBarContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }

    final class View: UIView {
        private var titleContent = ComponentView<Empty>()
        private var component: TitleBarContentComponent?
        
        init() {
            super.init(frame: CGRect())
        }
        
        required public init?(coder: NSCoder) {
            fatalError()
        }
       
        func update(component: TitleBarContentComponent, availableSize: CGSize, environment: Environment<BrowserNavigationBarEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component

            let titleSize = self.titleContent.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.rootController.navigationBar.primaryTextColor)),
                        horizontalAlignment: .center,
                        truncationType: .end,
                        maximumNumberOfLines: 1
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 36.0, height: availableSize.height)
            )
            let titleContentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleContentView = self.titleContent.view {
                if titleContentView.superview == nil {
                    self.addSubview(titleContentView)
                }
                transition.setPosition(view: titleContentView, position: titleContentFrame.center)
                titleContentView.bounds = CGRect(origin: .zero, size: titleContentFrame.size)
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<BrowserNavigationBarEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}
