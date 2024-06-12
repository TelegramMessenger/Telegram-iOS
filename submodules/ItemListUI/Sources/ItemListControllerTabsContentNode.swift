import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import TabSelectorComponent

private let searchBarFont = Font.regular(17.0)

final class ItemListControllerTabsContentNode: NavigationBarContentNode {
    private let tabSelector = ComponentView<Empty>()
    
    var theme: PresentationTheme {
        didSet {
            if self.theme !== oldValue {
                self.update()
            }
        }
    }
    var segments: [String] {
        didSet {
            if self.segments != oldValue {
                self.update()
            }
        }
    }
    
    var index: Int {
        didSet {
            if self.index != oldValue {
                self.update(transition: .animated(duration: 0.35, curve: .spring))
            }
        }
    }
    
    var transitionFraction: CGFloat? {
        didSet {
            if self.transitionFraction != oldValue {
                self.update(transition: self.transitionFraction == nil ? .animated(duration: 0.35, curve: .spring) : .immediate)
            }
        }
    }
        
    var indexUpdated: ((Int) -> Void)?
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    init(theme: PresentationTheme, segments: [String], selectedIndex: Int) {
        self.theme = theme
        self.segments = segments
        self.index = selectedIndex
        
        super.init()
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    private func update(transition: ContainedViewLayoutTransition = .immediate) {
        guard let (size, leftInset, rightInset) = self.validLayout else {
            return
        }
        self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
        
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstTime = self.validLayout == nil
        self.validLayout = (size, leftInset, rightInset)
    
        let mappedItems = zip(0 ..< self.segments.count, self.segments).map { index, segment in
            return TabSelectorComponent.Item(
                id: AnyHashable(index),
                title: segment
            )
        }
        
        let tabSelectorSize = self.tabSelector.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(TabSelectorComponent(
                colors: TabSelectorComponent.Colors(
                    foreground: self.theme.list.itemSecondaryTextColor,
                    selection: self.theme.list.itemAccentColor
                ),
                customLayout: TabSelectorComponent.CustomLayout(
                    font: Font.medium(14.0),
                    spacing: 24.0,
                    lineSelection: true
                ),
                items: mappedItems,
                selectedId: AnyHashable(self.index),
                setSelectedId: { [weak self] id in
                    guard let self, let index = id.base as? Int else {
                        return
                    }
                    self.indexUpdated?(index)
                },
                transitionFraction: self.transitionFraction
            )),
            environment: {},
            containerSize: CGSize(width: size.width, height: 44.0)
        )
        let tabSelectorFrame = CGRect(origin: CGPoint(x: floor((size.width - tabSelectorSize.width) / 2.0), y: floor((size.height - tabSelectorSize.height) / 2.0) + 4.0), size: tabSelectorSize)
        if let tabSelectorView = self.tabSelector.view {
            if tabSelectorView.superview == nil {
                self.view.addSubview(tabSelectorView)
            }
            transition.updateFrame(view: tabSelectorView, frame: tabSelectorFrame)
        }
        
        if isFirstTime {
            self.requestContainerLayout(.immediate)
        }
    }
    
    override var height: CGFloat {
        return self.nominalHeight
    }
    
    override var clippedHeight: CGFloat {
        return self.nominalHeight
    }
    
    override var nominalHeight: CGFloat {
        return 54.0// + self.additionalHeight
    }
    
    override var mode: NavigationBarContentMode {
        return .expansion
    }
}
