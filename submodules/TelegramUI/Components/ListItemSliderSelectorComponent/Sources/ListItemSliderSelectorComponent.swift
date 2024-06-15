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
    public let markPositions: Bool
    public let selectedIndex: Int
    public let title: String?
    public let selectedIndexUpdated: (Int) -> Void
    
    public init(
        theme: PresentationTheme,
        values: [String],
        markPositions: Bool,
        selectedIndex: Int,
        title: String?,
        selectedIndexUpdated: @escaping (Int) -> Void
    ) {
        self.theme = theme
        self.values = values
        self.markPositions = markPositions
        self.selectedIndex = selectedIndex
        self.title = title
        self.selectedIndexUpdated = selectedIndexUpdated
    }
    
    public static func ==(lhs: ListItemSliderSelectorComponent, rhs: ListItemSliderSelectorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.values != rhs.values {
            return false
        }
        if lhs.markPositions != rhs.markPositions {
            return false
        }
        if lhs.selectedIndex != rhs.selectedIndex {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    public final class View: UIView, ListSectionComponent.ChildView {
        private var titles: [Int: ComponentView<Empty>] = [:]
        private var mainTitle: ComponentView<Empty>?
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
                
        func update(component: ListItemSliderSelectorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 13.0
            let titleSideInset: CGFloat = 20.0
            let titleClippingSideInset: CGFloat = 14.0
            
            let titleAreaWidth: CGFloat = availableSize.width - titleSideInset * 2.0
            
            var validIds: [Int] = []
            for i in 0 ..< component.values.count {
                if component.title != nil {
                    if i != 0 && i != component.values.count - 1 {
                        continue
                    }
                }
                
                validIds.append(i)
                
                var titleTransition = transition
                let title: ComponentView<Empty>
                if let current = self.titles[i] {
                    title = current
                } else {
                    titleTransition = titleTransition.withAnimation(.none)
                    title = ComponentView()
                    self.titles[i] = title
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
            var removeIds: [Int] = []
            for (id, title) in self.titles {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    title.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.titles.removeValue(forKey: id)
            }
            
            if let title = component.title {
                let mainTitle: ComponentView<Empty>
                var mainTitleTransition = transition
                if let current = self.mainTitle {
                    mainTitle = current
                } else {
                    mainTitleTransition = mainTitleTransition.withAnimation(.none)
                    mainTitle = ComponentView()
                    self.mainTitle = mainTitle
                }
                let mainTitleSize = mainTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: title, font: Font.regular(16.0), textColor: component.theme.list.itemPrimaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let mainTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - mainTitleSize.width) * 0.5), y: 10.0), size: mainTitleSize)
                if let mainTitleView = mainTitle.view {
                    if mainTitleView.superview == nil {
                        self.addSubview(mainTitleView)
                    }
                    mainTitleView.bounds = CGRect(origin: CGPoint(), size: mainTitleFrame.size)
                    mainTitleTransition.setPosition(view: mainTitleView, position: mainTitleFrame.center)
                }
            } else {
                if let mainTitle = self.mainTitle {
                    self.mainTitle = nil
                    mainTitle.view?.removeFromSuperview()
                }
            }
            
            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(SliderComponent(
                    valueCount: component.values.count,
                    value: component.selectedIndex,
                    markPositions: component.markPositions,
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
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
