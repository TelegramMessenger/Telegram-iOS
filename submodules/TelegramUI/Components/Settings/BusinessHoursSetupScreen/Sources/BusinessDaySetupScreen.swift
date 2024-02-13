import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import ListSectionComponent
import ListActionItemComponent
import BundleIconComponent
import LottieComponent
import Markdown
import LocationUI
import TelegramStringFormatting
import PlainButtonComponent

final class BusinessDaySetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let dayIndex: Int
    let day: BusinessHoursSetupScreenComponent.Day

    init(
        context: AccountContext,
        dayIndex: Int,
        day: BusinessHoursSetupScreenComponent.Day
    ) {
        self.context = context
        self.dayIndex = dayIndex
        self.day = day
    }

    static func ==(lhs: BusinessDaySetupScreenComponent, rhs: BusinessDaySetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.dayIndex != rhs.dayIndex {
            return false
        }
        if lhs.day != rhs.day {
            return false
        }

        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let navigationTitle = ComponentView<Empty>()
        private let generalSection = ComponentView<Empty>()
        private var rangeSections: [Int: ComponentView<Empty>] = [:]
        private let addSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: BusinessDaySetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private(set) var isOpen: Bool = false
        private(set) var ranges: [BusinessHoursSetupScreenComponent.WorkingHourRange] = []
        private var nextRangeId: Int = 0
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        var scrolledUp = true
        private func updateScrolling(transition: Transition) {
            let navigationRevealOffsetY: CGFloat = 0.0
            
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentOffset.y - navigationRevealOffsetY) / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
            
            var scrolledUp = false
            if navigationAlpha < 0.5 {
                scrolledUp = true
            } else if navigationAlpha > 0.5 {
                scrolledUp = false
            }
            
            if self.scrolledUp != scrolledUp {
                self.scrolledUp = scrolledUp
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
            
            if let navigationTitleView = self.navigationTitle.view {
                transition.setAlpha(view: navigationTitleView, alpha: 1.0)
            }
        }
        
        private func openRangeDateSetup(rangeId: Int, isStartTime: Bool) {
            guard let component = self.component else {
                return
            }
            guard let range = self.ranges.first(where: { $0.id == rangeId }) else {
                return
            }
            
            let controller = TimeSelectionActionSheet(context: component.context, currentValue: Int32(isStartTime ? range.startTime : range.endTime), applyValue: { [weak self] value in
                guard let self else {
                    return
                }
                guard let value else {
                    return
                }
                if let index = self.ranges.firstIndex(where: { $0.id == rangeId }) {
                    if isStartTime {
                        self.ranges[index].startTime = Int(value)
                    } else {
                        self.ranges[index].endTime = Int(value)
                    }
                    self.state?.updated(transition: .immediate)
                }
            })
            self.environment?.controller()?.present(controller, in: .window(.root))
        }
        
        func update(component: BusinessDaySetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            if self.component == nil {
                self.isOpen = component.day.ranges != nil
                self.ranges = component.day.ranges ?? []
                self.nextRangeId = (self.ranges.map(\.id).max() ?? 0) + 1
            }
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            //TODO:localize
            let title: String
            switch component.dayIndex {
            case 0:
                title = "Monday"
            case 1:
                title = "Tuesday"
            case 2:
                title = "Wednesday"
            case 3:
                title = "Thursday"
            case 4:
                title = "Friday"
            case 5:
                title = "Saturday"
            case 6:
                title = "Sunday"
            default:
                title = " "
            }
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: title, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - navigationTitleSize.width) / 2.0), y: environment.statusBarHeight + floor((environment.navigationHeight - environment.statusBarHeight - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.addSubview(navigationTitleView)
                    }
                }
                transition.setFrame(view: navigationTitleView, frame: navigationTitleFrame)
            }
            
            let bottomContentInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 32.0
            
            let _ = bottomContentInset
            let _ = sectionSpacing
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            contentHeight += 16.0
            
            //TODO:localize
            let generalSectionSize = self.generalSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: "Open On This Day",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isOpen, action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.isOpen = !self.isOpen
                                self.state?.updated(transition: .spring(duration: 0.4))
                            })),
                            action: nil
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let generalSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: generalSectionSize)
            if let generalSectionView = self.generalSection.view {
                if generalSectionView.superview == nil {
                    self.scrollView.addSubview(generalSectionView)
                }
                transition.setFrame(view: generalSectionView, frame: generalSectionFrame)
            }
            contentHeight += generalSectionSize.height
            contentHeight += sectionSpacing
            
            var rangesSectionsHeight: CGFloat = 0.0
            for range in self.ranges {
                let rangeId = range.id
                var rangeSectionTransition = transition
                let rangeSection: ComponentView<Empty>
                if let current = self.rangeSections[range.id] {
                    rangeSection = current
                } else {
                    rangeSection = ComponentView()
                    self.rangeSections[range.id] = rangeSection
                    rangeSectionTransition = rangeSectionTransition.withAnimation(.none)
                }
                
                let startHours = range.startTime / (60 * 60)
                let startMinutes = range.startTime % (60 * 60)
                let startText = stringForShortTimestamp(hours: Int32(startHours), minutes: Int32(startMinutes), dateTimeFormat: PresentationDateTimeFormat())
                let endHours = range.endTime / (60 * 60)
                let endMinutes = range.endTime % (60 * 60)
                let endText = stringForShortTimestamp(hours: Int32(endHours), minutes: Int32(endMinutes), dateTimeFormat: PresentationDateTimeFormat())
                
                var rangeSectionItems: [AnyComponentWithIdentity<Empty>] = []
                rangeSectionItems.append(AnyComponentWithIdentity(id: rangeSectionItems.count, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Opening time",
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: startText, font: Font.regular(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                        )),
                        background: AnyComponent(RoundedRectangle(color: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1), cornerRadius: 6.0)),
                        effectAlignment: .center,
                        minSize: nil,
                        contentInsets: UIEdgeInsets(top: 7.0, left: 8.0, bottom: 7.0, right: 8.0),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.openRangeDateSetup(rangeId: rangeId, isStartTime: true)
                        },
                        animateAlpha: true,
                        animateScale: false
                    ))), insets: .custom(UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)), allowUserInteraction: true),
                    accessory: nil,
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.openRangeDateSetup(rangeId: rangeId, isStartTime: true)
                    }
                ))))
                rangeSectionItems.append(AnyComponentWithIdentity(id: rangeSectionItems.count, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Closing time",
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: endText, font: Font.regular(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                        )),
                        background: AnyComponent(RoundedRectangle(color: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1), cornerRadius: 6.0)),
                        effectAlignment: .center,
                        minSize: nil,
                        contentInsets: UIEdgeInsets(top: 7.0, left: 8.0, bottom: 7.0, right: 8.0),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.openRangeDateSetup(rangeId: rangeId, isStartTime: false)
                        },
                        animateAlpha: true,
                        animateScale: false
                    ))), insets: .custom(UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)), allowUserInteraction: true),
                    accessory: nil,
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.openRangeDateSetup(rangeId: rangeId, isStartTime: false)
                    }
                ))))
                rangeSectionItems.append(AnyComponentWithIdentity(id: rangeSectionItems.count, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Remove",
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemDestructiveColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    accessory: nil,
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.ranges.removeAll(where: { $0.id == rangeId })
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                ))))
                
                let rangeSectionSize = rangeSection.update(
                    transition: rangeSectionTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: nil,
                        items: rangeSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let rangeSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + rangesSectionsHeight), size: rangeSectionSize)
                if let rangeSectionView = rangeSection.view {
                    var animateIn = false
                    if rangeSectionView.superview == nil {
                        animateIn = true
                        rangeSectionView.layer.allowsGroupOpacity = true
                        self.scrollView.addSubview(rangeSectionView)
                    }
                    rangeSectionTransition.setFrame(view: rangeSectionView, frame: rangeSectionFrame)
                    
                    let alphaTransition = transition.animation.isImmediate ? transition : .easeInOut(duration: 0.25)
                    if self.isOpen {
                        if animateIn {
                            if !transition.animation.isImmediate {
                                alphaTransition.animateAlpha(view: rangeSectionView, from: 0.0, to: 1.0)
                                transition.animateScale(view: rangeSectionView, from: 0.001, to: 1.0)
                            }
                        } else {
                            alphaTransition.setAlpha(view: rangeSectionView, alpha: 1.0)
                        }
                    } else {
                        alphaTransition.setAlpha(view: rangeSectionView, alpha: 0.0)
                    }
                }
                
                rangesSectionsHeight += rangeSectionSize.height
                rangesSectionsHeight += sectionSpacing
            }
            var removeRangeSectionIds: [Int] = []
            for (id, rangeSection) in self.rangeSections {
                if !self.ranges.contains(where: { $0.id == id }) {
                    removeRangeSectionIds.append(id)
                    
                    if let rangeSectionView = rangeSection.view {
                        if !transition.animation.isImmediate {
                            Transition.easeInOut(duration: 0.2).setAlpha(view: rangeSectionView, alpha: 0.0, completion: { [weak rangeSectionView] _ in
                                rangeSectionView?.removeFromSuperview()
                            })
                            transition.setScale(view: rangeSectionView, scale: 0.001)
                        } else {
                            rangeSectionView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeRangeSectionIds {
                self.rangeSections.removeValue(forKey: id)
            }
            
            //TODO:localize
            let addSectionSize = self.addSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Specify your working hours during the day.",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: "Add a Set of Hours",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            leftIcon: AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                                name: "Chat List/AddIcon",
                                tintColor: environment.theme.list.itemAccentColor
                            ))),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                let rangeId = self.nextRangeId
                                self.nextRangeId += 1
                                self.ranges.append(BusinessHoursSetupScreenComponent.WorkingHourRange(
                                    id: rangeId, startTime: 9 * (60 * 60), endTime: 18 * (60 * 60)))
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let addSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + rangesSectionsHeight), size: addSectionSize)
            if let addSectionView = self.addSection.view {
                if addSectionView.superview == nil {
                    self.scrollView.addSubview(addSectionView)
                }
                transition.setFrame(view: addSectionView, frame: addSectionFrame)
                
                let alphaTransition = transition.animation.isImmediate ? transition : .easeInOut(duration: 0.25)
                alphaTransition.setAlpha(view: addSectionView, alpha: self.isOpen ? 1.0 : 0.0)
            }
            rangesSectionsHeight += addSectionSize.height
            
            if self.isOpen {
                contentHeight += rangesSectionsHeight
            }
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class BusinessDaySetupScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let updateDay: (BusinessHoursSetupScreenComponent.Day) -> Void
    
    init(context: AccountContext, dayIndex: Int, day: BusinessHoursSetupScreenComponent.Day, updateDay: @escaping (BusinessHoursSetupScreenComponent.Day) -> Void) {
        self.context = context
        self.updateDay = updateDay
        
        super.init(context: context, component: BusinessDaySetupScreenComponent(
            context: context,
            dayIndex: dayIndex,
            day: day
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessDaySetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessDaySetupScreenComponent.View else {
                return true
            }
            
            self.updateDay(BusinessHoursSetupScreenComponent.Day(ranges: componentView.isOpen ? componentView.ranges : nil))
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
}
