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
import GlassBackgroundComponent

final class TitleBarContentComponent: Component {
    public typealias EnvironmentType = BrowserNavigationBarEnvironment
    
    let theme: PresentationTheme
    let title: String
    let readingProgress: CGFloat
    let loadingProgress: Double?
    
    init(
        theme: PresentationTheme,
        title: String,
        readingProgress: CGFloat,
        loadingProgress: Double?
    ) {
        self.theme = theme
        self.title = title
        self.readingProgress = readingProgress
        self.loadingProgress = loadingProgress
    }
    
    static func ==(lhs: TitleBarContentComponent, rhs: TitleBarContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.readingProgress != rhs.readingProgress {
            return false
        }
        if lhs.loadingProgress != rhs.loadingProgress {
            return false
        }
        return true
    }

    final class View: UIView {
        private let backgroundView = GlassBackgroundView()
        private let clippingView = UIView()
        private let readingProgressView = UIView()
        private var titleContent = ComponentView<Empty>()
        private var component: TitleBarContentComponent?
        
        init() {
            super.init(frame: CGRect())
            
            self.clippingView.clipsToBounds = true
            
            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.clippingView)
            self.clippingView.addSubview(self.readingProgressView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError()
        }
       
        func update(component: TitleBarContentComponent, availableSize: CGSize, environment: Environment<BrowserNavigationBarEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let collapseFraction = environment[BrowserNavigationBarEnvironment.self].fraction
                        
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
                containerSize: CGSize(width: availableSize.width - 42.0, height: availableSize.height)
            )
            let titleContentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleContentView = self.titleContent.view {
                if titleContentView.superview == nil {
                    self.addSubview(titleContentView)
                }
                transition.setPosition(view: titleContentView, position: titleContentFrame.center)
                titleContentView.bounds = CGRect(origin: .zero, size: titleContentFrame.size)
            }
            
            let expandedBackgroundWidth = availableSize.width - 14.0 * 2.0
            let collapsedBackgroundWidth = titleSize.width + 32.0
            let backgroundSize = CGSize(width: expandedBackgroundWidth * (1.0 - collapseFraction) + collapsedBackgroundWidth * collapseFraction, height: 44.0)
            self.backgroundView.update(size: backgroundSize, cornerRadius: backgroundSize.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - backgroundSize.width) / 2.0), y: floor((availableSize.height - backgroundSize.height) / 2.0)), size: backgroundSize)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            transition.setFrame(view: self.clippingView, frame: CGRect(origin: .zero, size: backgroundFrame.size))
            transition.setCornerRadius(layer: self.clippingView.layer, cornerRadius: backgroundFrame.size.height * 0.5)
            
            self.readingProgressView.backgroundColor = component.theme.rootController.navigationBar.primaryTextColor.withMultipliedAlpha(0.07)
            self.readingProgressView.frame = CGRect(origin: .zero, size: CGSize(width: backgroundSize.width * component.readingProgress, height: backgroundSize.height))
            
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
