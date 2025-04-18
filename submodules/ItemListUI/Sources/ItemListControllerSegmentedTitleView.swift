import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import TabSelectorComponent

public final class ItemListControllerSegmentedTitleView: UIView {
    private let tabSelector = ComponentView<Empty>()
    
    public var theme: PresentationTheme {
        didSet {
            if self.theme !== oldValue {
                self.setNeedsLayout()
            }
        }
    }
    public var segments: [String] {
        didSet {
            if self.segments != oldValue {
                self.setNeedsLayout()
            }
        }
    }
    
    public var index: Int {
        didSet {
            if self.index != oldValue {
                self.animateLayout = true
                self.setNeedsLayout()
            }
        }
    }
    
    private var validLayout: CGSize?
    private var animateLayout: Bool = false
    
    public var indexUpdated: ((Int) -> Void)?
    
    public init(theme: PresentationTheme, segments: [String], selectedIndex: Int) {
        self.theme = theme
        self.segments = segments
        self.index = selectedIndex
        
        super.init(frame: CGRect())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        self.validLayout = size
        self.update(transition: .immediate)
    }
    
    private func update(transition: ComponentTransition) {
        guard let size = self.validLayout else {
            return
        }
        
        let mappedItems = zip(0 ..< self.segments.count, self.segments).map { index, segment in
            return TabSelectorComponent.Item(
                id: AnyHashable(index),
                title: segment
            )
        }
        
        var transition = transition
        if self.animateLayout {
            transition = .spring(duration: 0.4)
            self.animateLayout = false
        }
        
        let tabSelectorSize = self.tabSelector.update(
            transition: transition,
            component: AnyComponent(TabSelectorComponent(
                colors: TabSelectorComponent.Colors(
                    foreground: self.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.8),
                    selection: self.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.05)
                ),
                customLayout: TabSelectorComponent.CustomLayout(
                    font: Font.medium(15.0),
                    spacing: 8.0
                ),
                items: mappedItems,
                selectedId: AnyHashable(self.index),
                setSelectedId: { [weak self] id in
                    guard let self, let index = id.base as? Int else {
                        return
                    }
                    self.indexUpdated?(index)
                }
            )),
            environment: {},
            containerSize: CGSize(width: size.width, height: 44.0)
        )
        let tabSelectorFrame = CGRect(origin: CGPoint(x: floor((size.width - tabSelectorSize.width) / 2.0), y: floor((size.height - tabSelectorSize.height) / 2.0)), size: tabSelectorSize)
        if let tabSelectorView = self.tabSelector.view {
            if tabSelectorView.superview == nil {
                self.addSubview(tabSelectorView)
            }
            transition.setFrame(view: tabSelectorView, frame: tabSelectorFrame)
        }
    }
}
