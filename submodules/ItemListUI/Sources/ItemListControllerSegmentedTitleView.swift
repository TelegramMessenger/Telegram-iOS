import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import HorizontalTabsComponent

/// A navigation-bar title of fixed-width tabs. It reports its size (`NavigationBarTitleView`), so the bar places it at
/// that width. A frame filling the space between the buttons changes width with them (Calls ▸ Edit), and the tabs, laid
/// out for the new width at once, would jump by half the change while the frame animates to it.
public final class ItemListControllerSegmentedTitleView: UIView, NavigationBarTitleView {
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
                self.requestUpdate?(.immediate)
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
    
    /// The width the bar offers (`updateLayout`); a host that frames the view itself offers its bounds.
    private var availableWidth: CGFloat?
    private var animateLayout: Bool = false
    
    public var indexUpdated: ((Int) -> Void)?
    public var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
    
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
        if size.width > 0.0 {
            let _ = self.update(availableWidth: self.availableWidth ?? size.width, containerSize: size, transition: .immediate)
        }
    }
    
    public func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        self.availableWidth = availableSize.width
        return self.update(availableWidth: availableSize.width, containerSize: nil, transition: ComponentTransition(transition))
    }
    
    public func animateLayoutTransition() {
    }
    
    /// Lays the tabs out centered in `containerSize`, or in their own size when it is nil, and returns their size.
    private func update(availableWidth: CGFloat, containerSize: CGSize?, transition: ComponentTransition) -> CGSize {
        
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
            containerSize: CGSize(width: availableWidth, height: 44.0)
        )
        
        let size = containerSize ?? tabSelectorSize
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
        
        return tabSelectorSize
    }
}
