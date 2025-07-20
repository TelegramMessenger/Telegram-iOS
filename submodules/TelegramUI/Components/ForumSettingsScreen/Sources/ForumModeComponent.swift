import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import AccountContext
import TelegramPresentationData
import PlainButtonComponent
import MultilineTextComponent
import LottieComponent

final class ForumModeComponent: Component {
    enum Mode: Equatable {
        case tabs
        case list
    }
    let theme: PresentationTheme
    let strings: PresentationStrings
    let mode: Mode?
    let modeUpdated: (Mode) -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        mode: Mode?,
        modeUpdated: @escaping (Mode) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.mode = mode
        self.modeUpdated = modeUpdated
    }
    
    static func ==(lhs: ForumModeComponent, rhs: ForumModeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let tabs = ComponentView<Empty>()
        private let list = ComponentView<Empty>()
        
        private var component: ForumModeComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ForumModeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: availableSize.width, height: 224.0)
            
            let sideInset = (size.width - 160.0 * 2.0) / 2.0
            let tabsSize = self.tabs.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            ItemComponent(
                                theme: component.theme,
                                animation: "ForumTabs",
                                title: component.strings.PeerInfo_Topics_Tabs,
                                isSelected: component.mode == .tabs
                            )
                        ),
                        effectAlignment: .center,
                        action: {
                            component.modeUpdated(.tabs)
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 160.0, height: size.height)
            )
            if let tabsView = self.tabs.view {
                if tabsView.superview == nil {
                    self.addSubview(tabsView)
                }
                transition.setFrame(view: tabsView, frame: CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: tabsSize))
            }
            
            let listSize = self.list.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            ItemComponent(
                                theme: component.theme,
                                animation: "ForumList",
                                title: component.strings.PeerInfo_Topics_List,
                                isSelected: component.mode == .list
                            )
                        ),
                        effectAlignment: .center,
                        action: {
                            component.modeUpdated(.list)
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 160.0, height: size.height)
            )
            if let listView = self.list.view {
                if listView.superview == nil {
                    self.addSubview(listView)
                }
                transition.setFrame(view: listView, frame: CGRect(origin: CGPoint(x: sideInset + tabsSize.width, y: 0.0), size: listSize))
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ItemComponent: Component {
    let theme: PresentationTheme
    let animation: String
    let title: String
    let isSelected: Bool
    
    init(
        theme: PresentationTheme,
        animation: String,
        title: String,
        isSelected: Bool
    ) {
        self.theme = theme
        self.animation = animation
        self.title = title
        self.isSelected = isSelected
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.animation != rhs.animation {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let animation = ComponentView<Empty>()
        private let selection = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?
                
        override init(frame: CGRect) {
            super.init(frame: frame)

        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            let size = CGSize(width: availableSize.width, height: 224.0)
            
            let animationSize = self.animation.update(
                transition: transition,
                component: AnyComponent(
                    LottieComponent(
                        content: LottieComponent.AppBundleContent(name: component.animation),
                        color: component.isSelected ? component.theme.list.itemCheckColors.fillColor : component.theme.list.itemSecondaryTextColor,
                        loop: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 170.0, height: 170.0)
            )
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.addSubview(animationView)
                }
                transition.setFrame(view: animationView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - animationSize.width) / 2.0), y: 9.0), size: animationSize))
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: component.title, font: Font.medium(13.0), textColor: component.isSelected ? component.theme.list.itemCheckColors.foregroundColor : component.theme.list.itemPrimaryTextColor)))
                ),
                environment: {},
                containerSize: size
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - 23.0), size: titleSize)
            
            let selectionFrame = titleFrame.insetBy(dx: -10.0, dy: -6.0)
            let _ = self.selection.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(color: component.theme.list.itemCheckColors.fillColor, cornerRadius: selectionFrame.size.height / 2.0)),
                environment: {},
                containerSize: selectionFrame.size
            )
            if let selectionView = self.selection.view {
                if selectionView.superview == nil {
                    self.addSubview(selectionView)
                }
                transition.setFrame(view: selectionView, frame: selectionFrame)
                selectionView.alpha = component.isSelected ? 1.0 : 0.0
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            if previousComponent?.isSelected != component.isSelected && component.isSelected {
                if let animationView = self.animation.view as? LottieComponent.View {
                    animationView.playOnce()
                }
            }
                        
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
