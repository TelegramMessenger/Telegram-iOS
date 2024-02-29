import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import ListSectionComponent
import SliderComponent

public final class ListItemSliderSelectorComponent: Component {
    public let theme: PresentationTheme
    public let values: [String]
    public let selectedIndex: Int
    public let selectedIndexUpdated: (Int) -> Void
    
    public init(
        theme: PresentationTheme,
        values: [String],
        selectedIndex: Int,
        selectedIndexUpdated: @escaping (Int) -> Void
    ) {
        self.theme = theme
        self.values = values
        self.selectedIndex = selectedIndex
        self.selectedIndexUpdated = selectedIndexUpdated
    }
    
    public static func ==(lhs: ListItemSliderSelectorComponent, rhs: ListItemSliderSelectorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.values != rhs.values {
            return false
        }
        if lhs.selectedIndex != rhs.selectedIndex {
            return false
        }
        return true
    }
    
    public final class View: UIView, ListSectionComponent.ChildView {
        private var titles: [ComponentView<Empty>] = []
        private var slider = ComponentView<Empty>()
        
        private var component: ListItemSliderSelectorComponent?
        private weak var state: EmptyComponentState?
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: ListItemSliderSelectorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 13.0
            let titleSideInset: CGFloat = 20.0
            let titleClippingSideInset: CGFloat = 14.0
            
            let titleAreaWidth: CGFloat = availableSize.width - titleSideInset * 2.0
            
            for i in 0 ..< component.values.count {
                var titleTransition = transition
                let title: ComponentView<Empty>
                if self.titles.count > i {
                    title = self.titles[i]
                } else {
                    titleTransition = titleTransition.withAnimation(.none)
                    title = ComponentView()
                    self.titles.append(title)
                }
                let titleSize = title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.values[i], font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                var titleFrame = CGRect(origin: CGPoint(x: titleSideInset - floor(titleSize.width * 0.5), y: 14.0), size: titleSize)
                if component.values.count > 1 {
                    titleFrame.origin.x += floor(CGFloat(i) / CGFloat(component.values.count - 1) * titleAreaWidth)
                }
                if titleFrame.minX < titleClippingSideInset {
                    titleFrame.origin.x = titleSideInset
                }
                if titleFrame.maxX > availableSize.width - titleClippingSideInset {
                    titleFrame.origin.x = availableSize.width - titleClippingSideInset - titleSize.width
                }
                if let titleView = title.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                    titleTransition.setPosition(view: titleView, position: titleFrame.center)
                }
            }
            if self.titles.count > component.values.count {
                for i in component.values.count ..< self.titles.count {
                    self.titles[i].view?.removeFromSuperview()
                }
                self.titles.removeLast(self.titles.count - component.values.count)
            }
            
            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(SliderComponent(
                    valueCount: component.values.count,
                    value: component.selectedIndex,
                    trackBackgroundColor: component.theme.list.controlSecondaryColor,
                    trackForegroundColor: component.theme.list.itemAccentColor,
                    valueUpdated: { [weak self] value in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.selectedIndexUpdated(value)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let sliderFrame = CGRect(origin: CGPoint(x: sideInset, y: 36.0), size: sliderSize)
            if let sliderView = self.slider.view {
                if sliderView.superview == nil {
                    self.addSubview(sliderView)
                }
                transition.setFrame(view: sliderView, frame: sliderFrame)
            }
            
            self.separatorInset = 16.0
            
            return CGSize(width: availableSize.width, height: 88.0)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
