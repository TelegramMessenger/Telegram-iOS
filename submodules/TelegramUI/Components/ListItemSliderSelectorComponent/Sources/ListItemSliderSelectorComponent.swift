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
    public final class Discrete: Equatable {
        public let values: [String]
        public let markPositions: Bool
        public let selectedIndex: Int
        public let minSelectedIndex: Int?
        public let title: String?
        public let selectedIndexUpdated: (Int) -> Void
        
        public init(values: [String], markPositions: Bool, selectedIndex: Int, minSelectedIndex: Int? = nil, title: String?, selectedIndexUpdated: @escaping (Int) -> Void) {
            self.values = values
            self.markPositions = markPositions
            self.selectedIndex = selectedIndex
            self.minSelectedIndex = minSelectedIndex
            self.title = title
            self.selectedIndexUpdated = selectedIndexUpdated
        }
        
        public static func ==(lhs: Discrete, rhs: Discrete) -> Bool {
            if lhs.values != rhs.values {
                return false
            }
            if lhs.markPositions != rhs.markPositions {
                return false
            }
            if lhs.selectedIndex != rhs.selectedIndex {
                return false
            }
            if lhs.minSelectedIndex != rhs.minSelectedIndex {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            return true
        }
    }
    
    public final class Continuous: Equatable {
        public let value: CGFloat
        public let minValue: CGFloat?
        public let lowerBoundTitle: String
        public let upperBoundTitle: String
        public let title: String
        public let valueUpdated: (CGFloat) -> Void
        
        public init(value: CGFloat, minValue: CGFloat? = nil, lowerBoundTitle: String, upperBoundTitle: String, title: String, valueUpdated: @escaping (CGFloat) -> Void) {
            self.value = value
            self.minValue = minValue
            self.lowerBoundTitle = lowerBoundTitle
            self.upperBoundTitle = upperBoundTitle
            self.title = title
            self.valueUpdated = valueUpdated
        }
        
        public static func ==(lhs: Continuous, rhs: Continuous) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            if lhs.minValue != rhs.minValue {
                return false
            }
            if lhs.lowerBoundTitle != rhs.lowerBoundTitle {
                return false
            }
            if lhs.upperBoundTitle != rhs.upperBoundTitle {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            return true
        }
    }
    
    public enum Content: Equatable {
        case discrete(Discrete)
        case continuous(Continuous)
    }
    
    public let theme: PresentationTheme
    public let content: Content
    
    public init(
        theme: PresentationTheme,
        content: Content
    ) {
        self.theme = theme
        self.content = content
    }
    
    public static func ==(lhs: ListItemSliderSelectorComponent, rhs: ListItemSliderSelectorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.content != rhs.content {
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
            var mainTitleValue: String?
            
            switch component.content {
            case let .discrete(discrete):
                mainTitleValue = discrete.title
                
                for i in 0 ..< discrete.values.count {
                    if discrete.title != nil {
                        if i != 0 && i != discrete.values.count - 1 {
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
                            text: .plain(NSAttributedString(string: discrete.values[i], font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                        )),
                        environment: {},
                        containerSize: CGSize(width: 100.0, height: 100.0)
                    )
                    var titleFrame = CGRect(origin: CGPoint(x: titleSideInset - floor(titleSize.width * 0.5), y: 14.0), size: titleSize)
                    if discrete.values.count > 1 {
                        titleFrame.origin.x += floor(CGFloat(i) / CGFloat(discrete.values.count - 1) * titleAreaWidth)
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
            case let .continuous(continuous):
                mainTitleValue = continuous.title
                
                for i in 0 ..< 2 {
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
                            text: .plain(NSAttributedString(string: i == 0 ? continuous.lowerBoundTitle : continuous.upperBoundTitle, font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor))
                        )),
                        environment: {},
                        containerSize: CGSize(width: 100.0, height: 100.0)
                    )
                    var titleFrame = CGRect(origin: CGPoint(x: titleSideInset, y: 14.0), size: titleSize)
                    if i == 1 {
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
            
            if let title = mainTitleValue {
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
            
            let sliderSize: CGSize
            switch component.content {
            case let .discrete(discrete):
                sliderSize = self.slider.update(
                    transition: transition,
                    component: AnyComponent(SliderComponent(
                        content: .discrete(SliderComponent.Discrete(
                            valueCount: discrete.values.count,
                            value: discrete.selectedIndex,
                            minValue: discrete.minSelectedIndex,
                            markPositions: discrete.markPositions,
                            valueUpdated: { [weak self] value in
                                guard let self, let component = self.component, case let .discrete(discrete) = component.content else {
                                    return
                                }
                                discrete.selectedIndexUpdated(value)
                            })
                        ),
                        trackBackgroundColor: component.theme.list.controlSecondaryColor,
                        trackForegroundColor: component.theme.list.itemAccentColor,
                        minTrackForegroundColor: component.theme.list.itemAccentColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.6)
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
            case let .continuous(continuous):
                sliderSize = self.slider.update(
                    transition: transition,
                    component: AnyComponent(SliderComponent(
                        content: .continuous(SliderComponent.Continuous(
                            value: continuous.value,
                            minValue: continuous.minValue,
                            valueUpdated: { [weak self] value in
                                guard let self, let component = self.component, case let .continuous(continuous) = component.content else {
                                    return
                                }
                                continuous.valueUpdated(value)
                            })
                        ),
                        trackBackgroundColor: component.theme.list.controlSecondaryColor,
                        trackForegroundColor: component.theme.list.itemAccentColor,
                        minTrackForegroundColor: component.theme.list.itemAccentColor.mixedWith(component.theme.list.itemBlocksBackgroundColor, alpha: 0.6)
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
            }
            
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
