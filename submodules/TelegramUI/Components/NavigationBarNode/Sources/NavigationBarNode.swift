import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import EdgeEffect
import SideColumnLayout
import NavigationBarComponent

/// Presents the iPhone Duo side column's "…" menu: the buttons that did not fit. The app sets it where it creates its
/// shared context (Display and this module cannot build a context menu); while it is nil the "…" button does nothing.
public var navigationBarOverflowMenuPresenter: ((_ sourceView: UIView, _ items: [NavigationBarComponent.OverflowItem]) -> Void)?

/// The navigation bar every `ViewController` gets: `NavigationBarComponent` driven by the screen's
/// `UINavigationItem`, in a glass container under an edge effect, with the screen's content nodes, title view and
/// iPhone Duo side column.
public final class NavigationBarNode: ASDisplayNode, NavigationBar, NavigationBarComponentTransitionSource {
    private struct Layout {
        var size: CGSize
        var defaultHeight: CGFloat
        var additionalTopHeight: CGFloat
        var additionalContentHeight: CGFloat
        var additionalBackgroundHeight: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        var appearsHidden: Bool
    }

    /// The row band `NavigationBarImpl` centered its items in; the 44pt row sits in its middle.
    private static let nominalHeight: CGFloat = 60.0

    private var presentationData: NavigationBarPresentationData
    private var validLayout: Layout?
    private var requestedLayout = false
    private var requestedTransition: ContainedViewLayoutTransition = .immediate
    public var requestContainerLayout: ((ContainedViewLayoutTransition) -> Void)?

    public var backPressed: () -> Void = {}
    public var userInfo: Any?
    public var trailingButtonsInset: CGFloat = 0.0
    public var sideColumnPlacement: NavigationBarSideColumnPlacement?
    public var sideColumnExtentUpdated: ((ContainedViewLayoutTransition) -> Void)?
    private var appliedSideColumnExtent: NavigationBarSideColumnExtent?
    public var backButtonContextAction: ((UIView, ContextGesture) -> Void)? {
        didSet {
            self.requestLayout()
        }
    }
    public var enableAutomaticBackButton: Bool = true
    public var hidesBackButton: Bool = false {
        didSet {
            if self.hidesBackButton != oldValue {
                self.requestLayout()
            }
        }
    }
    public var passthroughTouches: Bool = true
    public var intrinsicCanTransitionInline: Bool = true
    public var secondaryContentHeight: CGFloat = 38.0

    private let clippingNode: SparseNode
    public let additionalContentNode: SparseNode
    public let customOverBackgroundContentView: UIView
    let edgeEffectViewImpl: EdgeEffectView
    private var backdropAlpha: CGFloat = 1.0
    private var edgeEffectExtension: CGFloat = 0.0
    private let glassContainer: GlassBackgroundContainerView
    /// Advanced by each change of the bar's glass: only the latest change's readaptation runs (`readaptGlass`).
    private var glassReadaptationGeneration = 0
    private(set) var glassReadaptationCountForTesting = 0
    private let row = ComponentView<Empty>()
    private var sideColumnContainer: GlassBackgroundContainerView?
    private var appliedSideColumn: SideColumnRegion?

    /// Everything the bar draws, in one view a navigation transition can lift (`takeView()`); the bar's own view
    /// stays in its screen as the containing view. Hosts group what a transition role hides or fades.
    let contentView: UIView
    private let backdropHost: UIView
    private let rowHost: SparseContainerView
    private let titleHost: SparseContainerView
    private let contentNodeHost: SparseNode
    private let columnHost: SparseContainerView
    private var isContentLifted = false
    private var transitionRole: NavigationBarTransitionRole?
    /// After a transition: the transition's glass still animating above this bar, which keeps its own capsules out
    /// until it hands over (`holdGlass`).
    private let glassHold = NavigationBarGlassHold()
    private var currentRowFrame: CGRect = CGRect()
    public var transitionContentFrameUpdated: ((CGRect) -> Void)?

    public private(set) var contentNode: NavigationBarContentNode?
    public private(set) var secondaryContentNode: ASDisplayNode?
    public private(set) var titleView: UIView?

    private var _item: UINavigationItem?
    private var itemListenerKeys: (title: Int, titleView: Int, left: Int, right: Int, rightItems: Int, badge: Int)?
    private var barButtonItemListeners: [ObjectIdentifier: (item: UIBarButtonItem, enabled: Int, title: Int)] = [:]
    private var _previousItem: NavigationPreviousAction?

    /// The content the row was last laid out with.
    private(set) var currentContent: NavigationBarComponent.Content?
    /// Whether the row was last laid out with its iPhone Duo column's buttons hidden (an active search).
    private(set) var currentHidesSideColumnButtons = false
    /// `setHidden` (the controller, from `displayNavigationBar`) fades the row; `setRowHiddenByScreen` (the screen) fades
    /// the glass container, since a capsule's native glass ignores the alpha of anything below that container. The row
    /// shows when neither hides it.
    private var isRowHiddenByController = false
    private var isRowHiddenByScreen = false

    private var rowTargetAlpha: CGFloat {
        return self.isRowHiddenByController ? 0.0 : 1.0
    }

    /// The glass container (row, title view, over-background content) gives way to a replacement content node and to
    /// what the screen puts in the row's place.
    private var glassContainerTargetAlpha: CGFloat {
        if let contentNode = self.contentNode, case .replacement = contentNode.mode {
            return 0.0
        }
        return self.isRowHiddenByScreen ? 0.0 : 1.0
    }

    private var rowView: NavigationBarComponent.View? {
        return self.row.view as? NavigationBarComponent.View
    }

    public init(presentationData: NavigationBarPresentationData) {
        self.presentationData = presentationData

        self.clippingNode = SparseNode()
        self.additionalContentNode = SparseNode()
        self.customOverBackgroundContentView = SparseContainerView()

        self.edgeEffectViewImpl = EdgeEffectView()
        self.edgeEffectViewImpl.isUserInteractionEnabled = false
        self.glassContainer = GlassBackgroundContainerView()

        self.contentView = UIView()
        self.backdropHost = UIView()
        self.backdropHost.isUserInteractionEnabled = false
        self.rowHost = SparseContainerView()
        self.titleHost = SparseContainerView()
        self.contentNodeHost = SparseNode()
        self.columnHost = SparseContainerView()

        super.init()

        self.glassHold.changed = { [weak self] in
            self?.applyGlassVisibility()
        }

        self.view.addSubview(self.contentView)
        self.contentView.addSubview(self.backdropHost)
        self.backdropHost.addSubview(self.edgeEffectViewImpl)
        self.contentView.addSubview(self.glassContainer)
        self.glassContainer.contentView.addSubview(self.customOverBackgroundContentView)
        self.glassContainer.contentView.addSubview(self.rowHost)
        self.glassContainer.contentView.addSubview(self.titleHost)
        self.contentView.addSubnode(self.clippingNode)
        self.contentView.addSubnode(self.additionalContentNode)
        self.contentView.addSubnode(self.contentNodeHost)
        self.contentView.addSubview(self.columnHost)

        self.backgroundColor = nil
        self.isOpaque = false
    }

    // MARK: - Item

    public var item: UINavigationItem? {
        get {
            return self._item
        } set(value) {
            if let previous = self._item, let keys = self.itemListenerKeys {
                previous.removeSetTitleListener(keys.title)
                previous.removeSetTitleViewListener(keys.titleView)
                previous.removeSetLeftBarButtonItemListener(keys.left)
                previous.removeSetRightBarButtonItemListener(keys.right)
                previous.removeSetMultipleRightBarButtonItemsListener(keys.rightItems)
                previous.removeSetBadgeListener(keys.badge)
            }
            self.itemListenerKeys = nil
            self._item = value

            if let item = value {
                let title = item.addSetTitleListener { [weak self] _, animated in
                    self?.itemContentUpdated(animated: animated)
                }
                let titleView = item.addSetTitleViewListener { [weak self] titleView in
                    self?.setTitleView(titleView)
                }
                let left = item.addSetLeftBarButtonItemListener { [weak self] _, _, animated in
                    self?.itemContentUpdated(animated: animated)
                }
                let right = item.addSetRightBarButtonItemListener { [weak self] _, _, animated in
                    self?.itemContentUpdated(animated: animated)
                }
                let rightItems = item.addSetMultipleRightBarButtonItemsListener { [weak self] _, animated in
                    self?.itemContentUpdated(animated: animated)
                }
                let badge = item.addSetBadgeListener { [weak self] _ in
                    self?.itemContentUpdated(animated: false)
                }
                self.itemListenerKeys = (title, titleView, left, right, rightItems, badge)
                self.setTitleView(item.titleView)
            } else {
                self.setTitleView(nil)
            }
            self.itemContentUpdated(animated: false)
        }
    }

    public var previousItem: NavigationPreviousAction? {
        get {
            if !self.enableAutomaticBackButton {
                return nil
            }
            return self._previousItem
        } set(value) {
            let value = self.enableAutomaticBackButton ? value : nil
            if self._previousItem != value {
                self._previousItem = value
                self.requestLayout()
            }
        }
    }

    private func itemContentUpdated(animated: Bool) {
        self.syncBarButtonItemListeners()
        self.requestLayout(transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }

    /// Follows the enabled state and title of every bar button item the item shows, as `NavigationButtonItemNode` did.
    private func syncBarButtonItemListeners() {
        var current: [UIBarButtonItem] = []
        if let item = self._item {
            if let leftItem = item.leftBarButtonItem {
                current.append(leftItem)
            }
            if let rightItems = item.rightBarButtonItems, !rightItems.isEmpty {
                current.append(contentsOf: rightItems)
            } else if let rightItem = item.rightBarButtonItem {
                current.append(rightItem)
            }
        }
        let currentIds = Set(current.map { ObjectIdentifier($0) })
        let removedIds = self.barButtonItemListeners.keys.filter { !currentIds.contains($0) }
        for id in removedIds {
            if let entry = self.barButtonItemListeners.removeValue(forKey: id) {
                entry.item.removeSetEnabledListener(entry.enabled)
                entry.item.removeSetTitleListener(entry.title)
            }
        }
        for barButtonItem in current {
            let id = ObjectIdentifier(barButtonItem)
            if self.barButtonItemListeners[id] == nil {
                let enabled = barButtonItem.addSetEnabledListener { [weak self] _ in
                    self?.requestLayout()
                }
                let title = barButtonItem.addSetTitleListener { [weak self] _ in
                    self?.requestLayout()
                }
                self.barButtonItemListeners[id] = (barButtonItem, enabled, title)
            }
        }
    }

    private func setTitleView(_ titleView: UIView?) {
        if self.titleView === titleView {
            return
        }
        if let previous = self.titleView {
            (previous as? NavigationBarTitleView)?.requestUpdate = nil
            (previous as? NavigationBarGlassPillTitleView)?.isGlassPillDetached = false
            previous.removeFromSuperview()
        }
        self.titleView = titleView
        if let titleView {
            self.titleHost.addSubview(titleView)
            if let titleView = titleView as? NavigationBarTitleView {
                titleView.requestUpdate = { [weak self, weak titleView] transition in
                    guard let self, let titleView, self.titleView === titleView else {
                        return
                    }
                    if let requestContainerLayout = self.requestContainerLayout {
                        requestContainerLayout(transition)
                    } else {
                        self.requestLayout()
                    }
                }
            }
        }
        self.applyGlassVisibility()
        self.requestLayout()
    }

    /// The title's glass pill (the chat header) as the transition's second right platter, in the row's coordinates; nil
    /// without one, while the row is hidden, or when two right platters leave it no slot.
    private var transitionTitlePill: NavigationBarTransitionTitlePill? {
        guard let titleView = self.titleView as? NavigationBarGlassPillTitleView, titleView.superview === self.titleHost, let pillFrame = titleView.glassPillFrame, !pillFrame.isEmpty, let rowView = self.rowView, rowView.primaryHasRoomForTitlePill, self.transitionRowAlpha >= 0.5 else {
            return nil
        }
        // The title host and the row host share a frame, so the title view's frame is in the row's coordinates.
        let frame = titleView.convert(pillFrame, to: self.titleHost)
        // Its contents are lent live while the bar's glass is detached; the title view takes them back when it is not.
        return NavigationBarTransitionTitlePill(frame: frame, signature: ObjectIdentifier(titleView), lendContent: { [weak titleView] in
            return titleView?.lendGlassPillContent() ?? UIView()
        })
    }

    private var transitionRowAlpha: CGFloat {
        return self.glassContainer.alpha * (self.rowView?.alpha ?? 1.0)
    }

    // MARK: - Layout

    private func requestLayout(transition: ContainedViewLayoutTransition = .immediate) {
        if transition.isAnimated {
            self.requestedTransition = transition
        }
        self.requestedLayout = true
        self.setNeedsLayout()
    }

    override public func layout() {
        super.layout()

        if let validLayout = self.validLayout, self.requestedLayout {
            let transition = self.requestedTransition
            self.requestedLayout = false
            self.requestedTransition = .immediate
            self.update(layout: validLayout, transition: transition, isContainerLayout: false)
        }
    }

    public func updateLayout(size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, transition: ContainedViewLayoutTransition) {
        let layout = Layout(size: size, defaultHeight: defaultHeight, additionalTopHeight: additionalTopHeight, additionalContentHeight: additionalContentHeight, additionalBackgroundHeight: additionalBackgroundHeight, leftInset: leftInset, rightInset: rightInset, appearsHidden: appearsHidden)
        self.validLayout = layout
        self.requestedLayout = false
        self.requestedTransition = .immediate
        self.update(layout: layout, transition: transition, isContainerLayout: true)
    }

    private func sideColumnRegion(placement: NavigationBarSideColumnPlacement?) -> SideColumnRegion? {
        guard let placement, !placement.layout.presentedInFormSheet else {
            return nil
        }
        return SideColumnLayout.sideColumnRegion(layout: placement.layout, minY: (placement.layout.statusBarHeight ?? 0.0) + 8.0, reservedBelow: placement.reservedBelow)
    }

    private func sideColumnExtent(region: SideColumnRegion?, content: NavigationBarComponent.Content) -> NavigationBarSideColumnExtent? {
        guard let region, let frame = NavigationBarComponent.sideColumnContentFrame(content: content, columnLength: region.frame.height) else {
            return nil
        }
        return NavigationBarSideColumnExtent(edge: region.edge, frame: frame.offsetBy(dx: region.frame.minX, dy: region.frame.minY))
    }

    public func sideColumnExtent(placement: NavigationBarSideColumnPlacement) -> NavigationBarSideColumnExtent? {
        return self.sideColumnExtent(region: self.sideColumnRegion(placement: placement), content: self.makeContent())
    }

    /// The content the bar would lay out now (tests).
    func currentContentForTesting() -> NavigationBarComponent.Content {
        return self.makeContent()
    }

    private func makeContent() -> NavigationBarComponent.Content {
        return navigationBarContent(
            item: self._item,
            previousItem: self.previousItem,
            hidesBackButton: self.hidesBackButton,
            backPressed: { [weak self] in
                self?.backPressed()
            },
            backContextAction: self.backButtonContextAction
        )
    }

    private func update(layout: Layout, transition: ContainedViewLayoutTransition, isContainerLayout: Bool) {
        let size = layout.size
        let contentFrame = CGRect(origin: CGPoint(), size: size)
        // While lifted, reported once the whole layout is done (every return below), so the renderer reads this
        // layout's row, content and column rather than the previous ones.
        defer {
            if self.isContentLifted {
                self.transitionContentFrameUpdated?(contentFrame)
            }
        }
        if self.isContentLifted {
            transition.updateBounds(layer: self.contentView.layer, bounds: contentFrame)
        } else {
            transition.updateFrame(view: self.contentView, frame: contentFrame)
        }
        transition.updateFrame(view: self.backdropHost, frame: contentFrame)
        transition.updateFrame(node: self.contentNodeHost, frame: contentFrame)

        let theme = self.presentationData.theme
        let contentVerticalOrigin = layout.additionalTopHeight + 2.0

        let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + layout.additionalBackgroundHeight))

        var glassContainerFrame = backgroundFrame
        glassContainerFrame.size.height += 44.0
        transition.updateFrame(view: self.glassContainer, frame: glassContainerFrame)
        self.glassContainer.update(size: glassContainerFrame.size, isDark: theme.overallDarkAppearance, transition: ComponentTransition(transition))
        let glassContentBounds = CGRect(origin: CGPoint(), size: glassContainerFrame.size)
        transition.updateFrame(view: self.rowHost, frame: glassContentBounds)
        transition.updateFrame(view: self.titleHost, frame: glassContentBounds)

        if let edgeEffectColor = theme.edgeEffectColor, edgeEffectColor.alpha == 0.0 {
            self.edgeEffectViewImpl.isHidden = true
        } else {
            self.edgeEffectViewImpl.isHidden = false

            let edgeEffectHeight: CGFloat = size.height + layout.additionalBackgroundHeight + 24.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: -20.0), size: CGSize(width: size.width, height: 20.0 + edgeEffectHeight))
            transition.updatePosition(layer: self.edgeEffectViewImpl.layer, position: edgeEffectFrame.center)
            transition.updateBounds(layer: self.edgeEffectViewImpl.layer, bounds: CGRect(origin: CGPoint(), size: edgeEffectFrame.size))
            self.edgeEffectViewImpl.update(content: theme.edgeEffectColor ?? .white, blur: true, rect: CGRect(origin: CGPoint(), size: edgeEffectFrame.size), edge: .top, edgeSize: min(64.0, edgeEffectHeight), transition: ComponentTransition(transition))
        }

        let apparentAdditionalHeight: CGFloat = self.secondaryContentNode != nil ? (self.secondaryContentHeight) : 0.0

        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.additionalContentNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + layout.additionalBackgroundHeight)))
        if let contentNode = self.contentNode {
            switch contentNode.mode {
            case .replacement:
                let contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: contentVerticalOrigin), size: CGSize(width: size.width, height: contentNode.nominalHeight))
                transition.updateFrame(node: contentNode, frame: contentNodeFrame)
                // It takes the bar's row, so its trailing end keeps clear of a status island beside the bar (iPhone Duo).
                let _ = contentNode.updateLayout(size: contentNodeFrame.size, leftInset: layout.leftInset, rightInset: layout.rightInset + self.trailingButtonsInset, transition: transition)
            case .expansion:
                let expansionHeight = contentNode.height
                let additionalExpansionHeight: CGFloat = self.secondaryContentNode != nil && layout.appearsHidden ? (self.secondaryContentHeight) : 0.0
                var contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - (layout.appearsHidden ? 0.0 : layout.additionalContentHeight) - expansionHeight - apparentAdditionalHeight - additionalExpansionHeight), size: CGSize(width: size.width, height: expansionHeight))
                if layout.appearsHidden {
                    contentNodeFrame.origin.y = size.height - contentNode.height + contentVerticalOrigin
                    if self.secondaryContentNode != nil {
                        contentNodeFrame.origin.y += self.secondaryContentHeight
                    }
                }
                transition.updateFrame(node: contentNode, frame: contentNodeFrame)
                let _ = contentNode.updateLayout(size: contentNodeFrame.size, leftInset: layout.leftInset, rightInset: layout.rightInset, transition: transition)
            }
        }

        let rowFrame = CGRect(x: 0.0, y: contentVerticalOrigin + floor((NavigationBarNode.nominalHeight - 44.0) * 0.5), width: size.width, height: 44.0)
        self.currentRowFrame = rowFrame
        let sideColumn = self.sideColumnRegion(placement: self.sideColumnPlacement)
        let content = self.makeContent()
        self.currentContent = content
        // The bar changed under the transition's glass: it hands over now rather than settle on the old bar.
        self.glassHold.barLaidOut(content: content, rowFrame: rowFrame)
        let sideColumnExtent = self.sideColumnExtent(region: sideColumn, content: content)
        let sideColumnExtentChanged = sideColumnExtent != self.appliedSideColumnExtent
        self.appliedSideColumnExtent = sideColumnExtent
        var hidesSideColumnButtons = false
        if let contentNode = self.contentNode, case .replacement = contentNode.mode {
            hidesSideColumnButtons = true
        }
        self.currentHidesSideColumnButtons = hidesSideColumnButtons
        let rowTransition = ComponentTransition(transition)
        let _ = self.row.update(
            transition: rowTransition,
            component: AnyComponent(NavigationBarComponent(
                theme: theme,
                strings: self.presentationData.strings,
                leftInset: layout.leftInset + 16.0,
                rightInset: layout.rightInset + 16.0,
                trailingButtonsInset: self.trailingButtonsInset,
                primaryContent: content,
                secondaryContent: nil,
                secondaryTransition: 0.0,
                sideColumnLength: sideColumn?.frame.height,
                hidesSideColumnButtons: hidesSideColumnButtons,
                openSideColumnOverflow: { sourceView, items in
                    navigationBarOverflowMenuPresenter?(sourceView, items)
                }
            )),
            environment: {},
            containerSize: rowFrame.size
        )
        guard let rowView = self.rowView else {
            return
        }
        if rowView.superview == nil {
            // Its host is below the title view's: the row answers hits on its whole frame, the title view takes its own.
            self.rowHost.addSubview(rowView)
            rowView.glassNeedsReadaptation = { [weak self] in
                self?.readaptGlass()
            }
            rowView.plattersDetached = self.transitionRole != nil || self.glassHold.isHeld
            rowView.frame = rowFrame
            rowView.alpha = self.rowTargetAlpha
        } else {
            transition.updateFrame(view: rowView, frame: rowFrame)
        }

        self.updateSideColumn(rowView: rowView, region: sideColumn, transition: rowTransition)
        self.layoutTitleView(layout: layout, rowView: rowView, contentVerticalOrigin: contentVerticalOrigin, transition: transition)

        if sideColumnExtentChanged && !isContainerLayout {
            self.sideColumnExtentUpdated?(transition)
        }
    }

    /// `NavigationBarImpl`'s title-view placement, against the row's button widths.
    private func layoutTitleView(layout: Layout, rowView: NavigationBarComponent.View, contentVerticalOrigin: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let titleView = self.titleView else {
            return
        }
        let size = layout.size
        let nominalHeight = NavigationBarNode.nominalHeight

        var leftTitleInset: CGFloat = layout.leftInset
        var rightTitleInset: CGFloat = layout.rightInset
        if rowView.primaryLeftButtonsWidth != 0.0 {
            leftTitleInset = layout.leftInset + 16.0 + rowView.primaryLeftButtonsWidth + 10.0
        }
        if rowView.primaryRightButtonsWidth != 0.0 {
            rightTitleInset = layout.rightInset + self.trailingButtonsInset + 16.0 + rowView.primaryRightButtonsWidth + 10.0
        }
        (leftTitleInset, rightTitleInset) = navigationBarTitleInsets(leftInset: layout.leftInset, rightInset: layout.rightInset, leftTitleInset: leftTitleInset, rightTitleInset: rightTitleInset)

        if let titleView = titleView as? NavigationBarTitleView {
            var titleViewTransition = transition
            if titleView.frame.isEmpty {
                titleViewTransition = .immediate
            }
            let titleSize = titleView.updateLayout(availableSize: CGSize(width: size.width - leftTitleInset - rightTitleInset, height: nominalHeight), transition: titleViewTransition)
            let titleX = navigationBarTitleViewOriginX(width: size.width, leftInset: layout.leftInset, rightInset: layout.rightInset, leftTitleInset: leftTitleInset, rightTitleInset: rightTitleInset, titleWidth: titleSize.width)
            let titleFrame = CGRect(origin: CGPoint(x: titleX, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
            titleViewTransition.updateFrame(view: titleView, frame: titleFrame)
        } else {
            let titleHorizontalFrame = navigationBarFillingTitleFrame(width: size.width, leftInset: layout.leftInset, rightInset: layout.rightInset, leftTitleInset: leftTitleInset, rightTitleInset: rightTitleInset)
            let titleSize = CGSize(width: titleHorizontalFrame.width, height: nominalHeight)
            let titleFrame = CGRect(origin: CGPoint(x: titleHorizontalFrame.x, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
            var titleViewTransition = transition
            if titleView.frame.isEmpty {
                titleViewTransition = .immediate
                titleView.frame = titleFrame
            }
            titleViewTransition.updateFrame(view: titleView, frame: titleFrame)
        }
    }

    /// iPhone Duo: hosts the row's side column at its region in a glass container of its own, as
    /// `ChatListNavigationBar` does. The column hides with the bar because it lives in it.
    private func updateSideColumn(rowView: NavigationBarComponent.View, region: SideColumnRegion?, transition: ComponentTransition) {
        let change = sideColumnPlacementChange(from: self.appliedSideColumn, to: region)
        self.appliedSideColumn = region
        if region == nil && self.sideColumnContainer == nil {
            return
        }
        let container: GlassBackgroundContainerView
        if let current = self.sideColumnContainer {
            container = current
        } else {
            container = GlassBackgroundContainerView()
            container.alpha = 0.0
            self.sideColumnContainer = container
            self.columnHost.addSubview(container)
        }
        let sideColumnView = rowView.sideColumnView
        if sideColumnView.superview !== container.contentView {
            container.contentView.addSubview(sideColumnView)
        }
        if let region {
            var frameTransition = transition
            switch change {
            case .appear:
                frameTransition = .immediate
            case .move:
                // A rotation or the strip switching sides: fade instead of flying across the screen.
                frameTransition = .immediate
                if case let .curve(duration, _) = transition.animation, container.alpha > 0.0, let snapshotView = container.snapshotView(afterScreenUpdates: false) {
                    snapshotView.isUserInteractionEnabled = false
                    snapshotView.frame = container.frame
                    self.columnHost.insertSubview(snapshotView, aboveSubview: container)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    container.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5, delay: duration * 0.5)
                }
            case .none, .disappear, .animate:
                break
            }
            frameTransition.setFrame(view: container, frame: region.frame)
            container.update(size: region.frame.size, isDark: self.presentationData.theme.overallDarkAppearance, transition: frameTransition)
            frameTransition.setFrame(view: sideColumnView, frame: CGRect(origin: CGPoint(), size: region.frame.size))
        }
        let isVisible = region != nil
        transition.setAlpha(view: container, alpha: isVisible ? 1.0 : 0.0)
        container.isUserInteractionEnabled = isVisible
    }

    // MARK: - NavigationBar

    public var isBackInSideColumn: Bool {
        guard let sideColumnContainer = self.sideColumnContainer, sideColumnContainer.isUserInteractionEnabled else {
            return false
        }
        return self.rowView?.isBackInSideColumn ?? false
    }

    public func animateButtonsIn(duration: Double) {
        self.rowView?.animateButtonsIn(duration: duration)
    }

    public var isBackdropVisible: Bool {
        return self.backdropAlpha == 1.0
    }

    public func setBackdropAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        let alpha = max(0.0, min(1.0, alpha))
        self.backdropAlpha = alpha
        transition.updateAlpha(layer: self.edgeEffectViewImpl.layer, alpha: alpha)
    }

    public func updatePresentationData(_ presentationData: NavigationBarPresentationData, transition: ContainedViewLayoutTransition) {
        if presentationData.theme !== self.presentationData.theme || presentationData.strings !== self.presentationData.strings {
            let glassChanged = presentationData.theme.glassTintColor != self.presentationData.theme.glassTintColor
            self.presentationData = presentationData
            self.requestLayout(transition: transition)
            if glassChanged {
                self.readaptGlass(after: transition)
            }
        }
    }

    /// UIKit's glass keeps how it adapted to the backdrop when it joined the bar's container (`readaptToBackdrop`). A
    /// change of the bar's glass comes with one of the backdrop behind it, on the same transition: the profile's bar turns
    /// tinted as its white header gives way to the cover. Once that transition is over and no capsule is still animating
    /// its change, the glass adapts again; otherwise a capsule that came while the bar was plain (the profile's Edit, back
    /// from its media tabs) stayed light over the cover.
    private func readaptGlass(after transition: ContainedViewLayoutTransition) {
        self.glassReadaptationGeneration += 1
        let generation = self.glassReadaptationGeneration
        var delay: Double = 0.0
        if case let .animated(duration, _) = transition {
            delay = duration * UIView.animationDurationFactor()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: { [weak self] in
            guard let self, self.glassReadaptationGeneration == generation else {
                return
            }
            let readapt: () -> Void = { [weak self] in
                guard let self, self.glassReadaptationGeneration == generation else {
                    return
                }
                self.readaptGlass()
            }
            if let rowView = self.rowView {
                rowView.afterInPlaceAnimations(readapt)
            } else {
                readapt()
            }
        })
    }

    private func readaptGlass() {
        self.glassContainer.readaptToBackdrop()
        self.sideColumnContainer?.readaptToBackdrop()
        self.glassReadaptationCountForTesting += 1
    }

    public func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer? {
        return self.rowView?.navigationButtonContextContainer(sourceView: sourceView)
    }

    public var canTransitionInline: Bool {
        if let contentNode = self.contentNode, case .replacement = contentNode.mode {
            return false
        } else {
            return self.intrinsicCanTransitionInline
        }
    }

    public func contentHeight(defaultHeight: CGFloat) -> CGFloat {
        var result: CGFloat = 0.0
        if let contentNode = self.contentNode {
            switch contentNode.mode {
            case .expansion:
                result += defaultHeight + contentNode.height
            case .replacement:
                result += contentNode.height
            }
        } else {
            result += defaultHeight
        }

        if let _ = self.secondaryContentNode {
            result += self.secondaryContentHeight
        }

        return result
    }

    public func setContentNode(_ contentNode: NavigationBarContentNode?, animated: Bool) {
        let transition: ComponentTransition = animated ? .easeInOut(duration: 0.2) : .immediate

        if self.contentNode !== contentNode {
            if let previous = self.contentNode {
                if animated {
                    previous.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self, weak previous] _ in
                        if let self, let previous, previous !== self.contentNode {
                            previous.removeFromSupernode()
                        }
                    })
                } else {
                    previous.removeFromSupernode()
                }
            }
            self.contentNode = contentNode
            self.contentNode?.requestContainerLayout = { [weak self] transition in
                guard let self else {
                    return
                }
                self.requestContainerLayout?(transition)
            }
            if let contentNode {
                contentNode.layer.removeAnimation(forKey: "opacity")
                self.contentNodeHost.addSubnode(contentNode)
                if animated {
                    contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }

                if case .replacement = contentNode.mode {
                    // The content takes the row's place: the glass container (row, title view, over-background
                    // content) gives way, as NavigationBarImpl's buttons and background container did.
                    if !self.glassContainer.alpha.isZero {
                        transition.setAlpha(view: self.glassContainer, alpha: 0.0)
                    }
                }

                if !self.bounds.size.width.isZero {
                    self.requestedLayout = true
                    self.layout()
                } else {
                    self.requestLayout()
                }
            } else {
                if self.glassContainer.alpha != self.glassContainerTargetAlpha {
                    transition.setAlpha(view: self.glassContainer, alpha: self.glassContainerTargetAlpha)
                }
                // Brings the side column's buttons back.
                self.requestLayout()
            }
        }
    }

    public func setSecondaryContentNode(_ secondaryContentNode: ASDisplayNode?, animated: Bool) {
        if self.secondaryContentNode !== secondaryContentNode {
            if let previous = self.secondaryContentNode, previous.supernode === self.clippingNode {
                if animated {
                    previous.layer.animateAlpha(from: previous.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] finished in
                        if finished {
                            previous?.removeFromSupernode()
                            previous?.layer.removeAllAnimations()
                        }
                    })
                } else {
                    previous.removeFromSupernode()
                }
            }
            self.secondaryContentNode = secondaryContentNode
            if let secondaryContentNode {
                self.clippingNode.addSubnode(secondaryContentNode)

                if animated {
                    secondaryContentNode.layer.animateAlpha(from: 0.0, to: secondaryContentNode.alpha, duration: 0.3)
                }
            }
        }
    }

    public func executeBack() -> Bool {
        let content = self.makeContent()
        if content.back != nil {
            content.backPressed()
        } else if let leftItem = self._item?.leftBarButtonItem {
            // The leading item, even an empty one: a screen sets one to keep the back button away (editing modes).
            leftItem.performActionOnTarget()
        } else {
            self.backPressed()
        }
        return true
    }

    public func setHidden(_ hidden: Bool, animated: Bool) {
        // Also while a replacement content node is set: it fades the glass container, this the row inside it.
        self.isRowHiddenByController = hidden
        guard let rowView = self.rowView else {
            return
        }
        let targetAlpha = self.rowTargetAlpha
        let previousAlpha = rowView.alpha
        if previousAlpha != targetAlpha {
            rowView.alpha = targetAlpha
            if animated {
                rowView.layer.animateAlpha(from: previousAlpha, to: targetAlpha, duration: 0.2)
            }
        }
    }

    public func setRowHiddenByScreen(_ hidden: Bool, transition: ContainedViewLayoutTransition) {
        if self.isRowHiddenByScreen == hidden {
            return
        }
        self.isRowHiddenByScreen = hidden
        // Through the views' alpha, as `setContentNode` fades the glass container: native glass faded through its
        // layer's opacity did not come back when shown again (measured on the iOS 27 simulator).
        ComponentTransition(transition).setAlpha(view: self.glassContainer, alpha: self.glassContainerTargetAlpha)
        ComponentTransition(transition).setAlpha(view: self.columnHost, alpha: self.columnHostTargetAlpha)
    }

    /// The back button's frame in `view`'s coordinates (an expansion's back-button hole).
    public func backButtonFrame(in view: UIView) -> CGRect? {
        guard let backView = self.rowView?.backButtonView, backView.superview != nil else {
            return nil
        }
        return backView.convert(backView.bounds, to: view)
    }

    public func rightButtonView(for item: UIBarButtonItem) -> UIView? {
        return self.rowView?.rightButtonViews[AnyHashable(ObjectIdentifier(item))]
    }

    /// The glass capsule a right button sits in (a right pill, or one of iPhone Duo's side column capsules, which are
    /// wider than the button), and the press UIKit draws or has just drawn on it.
    public func rightButtonCapsule(for item: UIBarButtonItem) -> (container: UIView, pressScale: CGFloat)? {
        guard let rowView = self.rowView, let buttonView = self.rightButtonView(for: item) else {
            return nil
        }
        return rowView.rightButtonCapsule(containing: buttonView)
    }
    
    public func lendLeftCapsule(in view: UIView) -> NavigationBarLentCapsule? {
        guard self.glassContainer.alpha > 0.0, self.transitionRole == nil else {
            return nil
        }
        return self.rowView?.lendLeftCapsule(in: view)
    }

    public func returnLeftCapsule() {
        self.rowView?.returnLeftCapsule()
    }

    public func updateEdgeEffectExtension(value: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.edgeEffectExtension == value {
            return
        }
        self.edgeEffectExtension = value
        transition.updateTransform(layer: self.edgeEffectViewImpl.layer, transform: CATransform3DMakeTranslation(0.0, max(0.0, min(20.0, self.edgeEffectExtension)), 0.0))
    }

    // MARK: - Navigation transition

    public func takeView() -> NavigationBarTransitionTakeViewInfo? {
        // A bar its screen faded out (a full-screen mini app) would come back at full opacity once lifted.
        guard !self.isContentLifted, self.intrinsicCanTransitionInline, self.alpha >= 1.0, self.contentView.superview === self.view else {
            return nil
        }
        self.isContentLifted = true
        return NavigationBarTransitionTakeViewInfo(containingView: self.view, contentView: self.contentView)
    }

    public func putBack() {
        guard self.isContentLifted else {
            return
        }
        self.isContentLifted = false
        self.transitionContentFrameUpdated = nil
        self.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
        self.view.insertSubview(self.contentView, at: 0)
        self.contentView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }

    public func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        // In a role the renderer draws the glass (capsules, the iPhone Duo column) and the backdrop once above both
        // screens. Everything else, the title included, stays as it is and rides this bar's screen (UIKit's matching
        // views): no fade, no drift. The capsules leave the hierarchy because alpha does not hide native glass; the
        // column's container can be faded because it is a glass container itself.
        self.transitionRole = role
        self.backdropHost.alpha = role != nil ? 0.0 : 1.0
        self.applyGlassVisibility()
    }

    /// The column hides while a transition's glass draws it, and while the screen hides the row.
    private var columnHostTargetAlpha: CGFloat {
        let detached = self.transitionRole != nil || self.glassHold.isHeld
        return (detached || self.isRowHiddenByScreen) ? 0.0 : 1.0
    }

    private func applyGlassVisibility() {
        let detached = self.transitionRole != nil || self.glassHold.isHeld
        // While the transition's glass lingers above the bar it draws the column's capsules too.
        self.columnHost.alpha = self.columnHostTargetAlpha
        self.rowView?.plattersDetached = detached
        // And the title's glass pill, which it treats as the second right platter.
        if let titleView = self.titleView as? NavigationBarGlassPillTitleView {
            titleView.isGlassPillDetached = detached && self.transitionTitlePill != nil
        }
    }

    var columnHostAlphaForTesting: CGFloat {
        return self.columnHost.alpha
    }

    var glassContainerAlphaForTesting: CGFloat {
        return self.glassContainer.alpha
    }

    /// The animation duration factor (Slow Animations) the hold's cap stretches with.
    public var glassHoldDurationFactor: () -> Double {
        get {
            return self.glassHold.durationFactor
        }
        set {
            self.glassHold.durationFactor = newValue
        }
    }

    public func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool {
        self.glassHold.hold(held, interrupted: interrupted, content: self.currentContent, rowFrame: self.currentRowFrame)
        self.applyGlassVisibility()
        return true
    }

    override public func didExitHierarchy() {
        super.didExitHierarchy()
        self.leftHierarchy()
    }

    override public func didEnterHierarchy() {
        super.didEnterHierarchy()
        self.enteredHierarchy()
    }

    func leftHierarchy() {
        self.glassHold.barLeftHierarchy()
    }

    func enteredHierarchy() {
        self.glassHold.barEnteredHierarchy()
    }

    public var componentTransitionState: NavigationBarComponentTransitionState? {
        guard let layout = self.validLayout, let content = self.currentContent else {
            return nil
        }
        let theme = self.presentationData.theme
        var backdropColor: UIColor? = theme.edgeEffectColor ?? .white
        if let edgeEffectColor = theme.edgeEffectColor, edgeEffectColor.alpha == 0.0 {
            backdropColor = nil
        }
        return NavigationBarComponentTransitionState(content: content, theme: theme, strings: self.presentationData.strings, rowFrame: self.currentRowFrame, rowAlpha: self.transitionRowAlpha, leftInset: layout.leftInset + 16.0, rightInset: layout.rightInset + 16.0, trailingButtonsInset: self.trailingButtonsInset, sideColumnFrame: self.appliedSideColumn?.frame, hidesSideColumnButtons: self.currentHidesSideColumnButtons, backdropHeight: layout.size.height + layout.additionalBackgroundHeight, backdropColor: backdropColor, backdropAlpha: self.backdropAlpha, backdropExtension: self.edgeEffectExtension, leadingPressScale: self.rowView?.detachedLeftPressScale ?? 1.0, leadingPressGlow: self.rowView?.detachedLeftPressGlow ?? 0.0, trailingPressScales: self.rowView?.detachedRightPressScales ?? [], trailingPressGlows: self.rowView?.detachedRightPressGlows ?? [], titlePill: self.transitionTitlePill)
    }

    // Tests.
    var transitionRowHostAlpha: CGFloat { return self.rowHost.alpha }
    var transitionBackdropHostAlpha: CGFloat { return self.backdropHost.alpha }
    var transitionExtrasAlpha: CGFloat { return self.titleHost.alpha }
    var rowViewForTesting: NavigationBarComponent.View? { return self.rowView }

    // MARK: - Touches and accessibility

    /// Whether a point is on the bar: its bounds, or the iPhone Duo column hanging below them.
    private func isPointOnBar(_ point: CGPoint, with event: UIEvent?) -> Bool {
        if self.bounds.contains(point) {
            return true
        }
        if let sideColumnContainer = self.sideColumnContainer, sideColumnContainer.isUserInteractionEnabled, sideColumnContainer.alpha > 0.0, let rowView = self.rowView {
            let columnView = rowView.sideColumnView
            return columnView.hitTest(self.view.convert(point, to: columnView), with: event) != nil
        }
        return false
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.glassHold.isHeld, event.flatMap({ $0.type == .touches }) ?? true, self.isPointOnBar(point, with: event) {
            // A touch on the bar while the transition's glass finishes above it: it hands over now, so the touch finds
            // the bar's own capsules. UIKit asks the bar about every touch on the screen (it is the screen's topmost
            // subnode), and a touch elsewhere leaves the glass to finish, as on iOS.
            self.glassHold.interrupt()
        }
        if let result = self.additionalContentNode.view.hitTest(self.view.convert(point, to: self.additionalContentNode.view), with: event) {
            return result
        }
        // iPhone Duo: the column hangs below the bar; only its shapes take touches (`sideColumnView` is sparse).
        if let sideColumnContainer = self.sideColumnContainer, sideColumnContainer.isUserInteractionEnabled, sideColumnContainer.alpha > 0.0, let rowView = self.rowView {
            let columnView = rowView.sideColumnView
            if let result = rowView.sideColumnHitTest(self.view.convert(point, to: columnView), with: event) {
                return result
            }
        }

        guard let result = super.hitTest(point, with: event) else {
            if !self.bounds.contains(point) {
                if let result = self.customOverBackgroundContentView.hitTest(self.view.convert(point, to: self.customOverBackgroundContentView), with: event) {
                    if result !== self.glassContainer.contentView {
                        return result
                    }
                }
            }
            return nil
        }

        if result === self.view || result === self.contentView || result === self.glassContainer || result === self.glassContainer.contentView || result === self.rowView || result === self.clippingNode.view {
            // The row spans the bar, above a screen's own controls over the background (ComposePoll's Cancel and
            // Send); they take the touches its buttons leave.
            if let result = self.customOverBackgroundContentView.hitTest(self.view.convert(point, to: self.customOverBackgroundContentView), with: event) {
                return result
            }
            if self.passthroughTouches {
                return nil
            }
        }

        return result
    }

    override public var accessibilityElements: [Any]? {
        get {
            var elements: [Any] = []
            if let rowView = self.rowView, !self.glassContainer.alpha.isZero {
                elements.append(contentsOf: rowView.leadingAccessibilityElements)
                if let titleView = self.titleView, titleView.superview != nil {
                    titleView.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(titleView.bounds, in: titleView)
                    elements.append(titleView)
                } else if let titleElement = rowView.titleAccessibilityElement {
                    elements.append(titleElement)
                }
                elements.append(contentsOf: rowView.trailingAccessibilityElements)
            }
            if let contentNode = self.contentNode {
                addAccessibilityChildren(of: contentNode, container: self, to: &elements)
            }
            if let secondaryContentNode = self.secondaryContentNode {
                addAccessibilityChildren(of: secondaryContentNode, container: self, to: &elements)
            }
            return elements
        } set(value) {
        }
    }
}

