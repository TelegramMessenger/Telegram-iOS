import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import HorizontalTabsComponent

public final class ItemListControllerSegmentedTitleView: UIView {
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
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
        
        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        
        super.init(frame: CGRect())
        
        self.addSubview(self.backgroundContainer)
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
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
        
        let mappedItems: [HorizontalTabsComponent.Tab] = zip(0 ..< self.segments.count, self.segments).map { index, segment in
            return HorizontalTabsComponent.Tab(
                id: AnyHashable(index),
                content: .title(HorizontalTabsComponent.Tab.Title(text: segment, entities: [], enableAnimations: false)),
                badge: nil,
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.indexUpdated?(index)
                },
                contextAction: nil,
                deleteAction: nil
            )
        }
        
        var transition = transition
        if self.animateLayout {
            transition = .spring(duration: 0.4)
            self.animateLayout = false
        }
        
        let tabSelectorSize = self.tabSelector.update(
            transition: transition,
            component: AnyComponent(HorizontalTabsComponent(
                context: nil,
                theme: self.theme,
                tabs: mappedItems,
                selectedTab: AnyHashable(self.index),
                isEditing: false,
                layout: .fit
            )),
            environment: {},
            containerSize: CGSize(width: size.width, height: 44.0)
        )
        
        let tabSelectorFrame = CGRect(origin: CGPoint(x: floor((size.width - tabSelectorSize.width) / 2.0), y: floor((size.height - tabSelectorSize.height) / 2.0)), size: tabSelectorSize)
        
        transition.setFrame(view: self.backgroundContainer, frame: tabSelectorFrame)
        self.backgroundContainer.update(size: tabSelectorFrame.size, isDark: self.theme.overallDarkAppearance, transition: transition)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: tabSelectorFrame.size))
        self.backgroundView.update(size: tabSelectorFrame.size, cornerRadius: tabSelectorFrame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)
        
        if let tabSelectorView = self.tabSelector.view as? HorizontalTabsComponent.View {
            if tabSelectorView.superview == nil {
                self.backgroundView.contentView.addSubview(tabSelectorView)
                tabSelectorView.setOverlayContainerView(overlayContainerView: self)
            }
            transition.setFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(), size: tabSelectorFrame.size))
        }
    }
}
