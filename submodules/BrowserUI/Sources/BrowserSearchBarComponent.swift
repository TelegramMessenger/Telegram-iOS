import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramPresentationData
import AccountContext
import BundleIconComponent
import SearchInputPanelComponent

final class SearchBarContentComponent: Component {
    public typealias EnvironmentType = BrowserNavigationBarEnvironment
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let performAction: ActionSlot<BrowserScreen.Action>
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        performAction: ActionSlot<BrowserScreen.Action>
    ) {
        self.theme = theme
        self.strings = strings
        self.performAction = performAction
    }
    
    static func ==(lhs: SearchBarContentComponent, rhs: SearchBarContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }

    final class View: UIView {
        private let queryPromise = ValuePromise<String>()
        private var queryDisposable: Disposable?
        
        private let searchInput = ComponentView<Empty>()
        
        private var component: SearchBarContentComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let throttledSearchQuery = self.queryPromise.get()
            |> mapToSignal { query -> Signal<String, NoError> in
                if !query.isEmpty {
                    return (.complete() |> delay(0.6, queue: Queue.mainQueue()))
                    |> then(.single(query))
                } else {
                    return .single(query)
                }
            }
            
            self.queryDisposable = (throttledSearchQuery
            |> deliverOnMainQueue).start(next: { [weak self] query in
                if let self {
                    self.component?.performAction.invoke(.updateSearchQuery(query))
                }
            })
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SearchBarContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let searchInputSize = self.searchInput.update(
                transition: transition,
                component: AnyComponent(
                    SearchInputPanelComponent(
                        theme: component.theme,
                        strings: component.strings,
                        metrics: .init(widthClass: .compact, heightClass: .compact, orientation: nil),
                        safeInsets: UIEdgeInsets(),
                        placeholder: component.strings.Common_Search,
                        hasEdgeEffect: false,
                        updated: { [weak self] query in
                            guard let self else {
                                return
                            }
                            self.queryPromise.set(query)
                        },
                        cancel: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.component?.performAction.invoke(.updateSearchActive(false))
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let searchInputView = self.searchInput.view as? SearchInputPanelComponent.View {
                if searchInputView.superview == nil {
                    self.addSubview(searchInputView)
                    
                    searchInputView.activateInput()
                }
                transition.setFrame(view: searchInputView, frame: CGRect(origin: .zero, size: searchInputSize))
            }
        
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<BrowserNavigationBarEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
