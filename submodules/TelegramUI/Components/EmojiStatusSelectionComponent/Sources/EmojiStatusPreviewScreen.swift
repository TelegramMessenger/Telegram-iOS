import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import ComponentFlow
import TelegramPresentationData
import AccountContext
import ComponentDisplayAdapters
import MultilineTextComponent
import EmojiStatusComponent
import TelegramStringFormatting
import SolidRoundedButtonComponent
import PresentationDataUtils

protocol ContextMenuItemWithAction: AnyObject {
    func performAction() -> ContextMenuPerformActionResult
}

enum ContextMenuPerformActionResult {
    case none
    case clearHighlight
}

private final class ContextMenuActionItem: Component, ContextMenuItemWithAction {
    typealias EnvironmentType = ContextMenuActionItemEnvironment
    
    let title: String
    let action: () -> ContextMenuPerformActionResult
    
    init(title: String, action: @escaping () -> ContextMenuPerformActionResult) {
        self.title = title
        self.action = action
    }
    
    static func ==(lhs: ContextMenuActionItem, rhs: ContextMenuActionItem) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    func performAction() -> ContextMenuPerformActionResult {
        return self.action()
    }
    
    final class View: UIView {
        private let titleView: ComponentView<Empty>
        
        override init(frame: CGRect) {
            self.titleView = ComponentView<Empty>()
            
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ContextMenuActionItem, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let contextEnvironment = environment[EnvironmentType.self].value
            
            let sideInset: CGFloat = 16.0
            let height: CGFloat = 44.0
            
            let titleSize = self.titleView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: contextEnvironment.theme.contextMenu.primaryColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            if let view = self.titleView.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: titleFrame)
            }
            
            return CGSize(width: sideInset * 2.0 + titleSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ContextMenuActionItemEnvironment: Equatable {
    let theme: PresentationTheme
    
    init(
        theme: PresentationTheme
    ) {
        self.theme = theme
    }
    
    static func ==(lhs: ContextMenuActionItemEnvironment, rhs: ContextMenuActionItemEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
}

private final class ContextMenuActionsComponent: Component {
    let theme: PresentationTheme
    let items: [AnyComponentWithIdentity<ContextMenuActionItemEnvironment>]
    
    init(
        theme: PresentationTheme,
        items: [AnyComponentWithIdentity<ContextMenuActionItemEnvironment>]
    ) {
        self.theme = theme
        self.items = items
    }
    
    static func ==(lhs: ContextMenuActionsComponent, rhs: ContextMenuActionsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class View: UIButton {
        private final class ItemView {
            let view = ComponentView<ContextMenuActionItemEnvironment>()
            let separatorView = UIView()
        }
        
        private let backgroundView: BlurredBackgroundView
        private var itemViews: [AnyHashable: ItemView] = [:]
        private var highligntedBackgroundView: UIView?
        
        private var component: ContextMenuActionsComponent?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 14.0
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.setHighlightedItem(id: self.itemAtPoint(point: touch.location(in: self)))
            
            return super.beginTracking(touch, with: event)
        }
        
        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.setHighlightedItem(id: self.itemAtPoint(point: touch.location(in: self)))
            
            return super.continueTracking(touch, with: event)
        }
        
        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            if let component = self.component, let touch = touch, let id = self.itemAtPoint(point: touch.location(in: self)) {
                self.setHighlightedItem(id: id)
                for item in component.items {
                    if item.id == id {
                        if let itemComponent = item.component.wrapped as? ContextMenuItemWithAction {
                            switch itemComponent.performAction() {
                            case .none:
                                break
                            case .clearHighlight:
                                self.setHighlightedItem(id: nil)
                            }
                        }
                        break
                    }
                }
            } else {
                self.setHighlightedItem(id: nil)
            }
            
            super.endTracking(touch, with: event)
        }
        
        override func cancelTracking(with event: UIEvent?) {
            self.setHighlightedItem(id: nil)
            
            super.cancelTracking(with: event)
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            self.setHighlightedItem(id: nil)
            
            super.touchesCancelled(touches, with: event)
        }
        
        private func itemAtPoint(point: CGPoint) -> AnyHashable? {
            for (id, itemView) in self.itemViews {
                guard let itemComponentView = itemView.view.view else {
                    continue
                }
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemComponentView.frame.minY), size: CGSize(width: self.bounds.width, height: itemComponentView.bounds.height))
                if itemFrame.contains(point) {
                    return id
                }
            }
            return nil
        }
        
        private func setHighlightedItem(id: AnyHashable?) {
            if let component = self.component, let id = id, let itemView = self.itemViews[id], let itemComponentView = itemView.view.view {
                let highligntedBackgroundView: UIView
                if let current = self.highligntedBackgroundView {
                    highligntedBackgroundView = current
                } else {
                    highligntedBackgroundView = UIView()
                    self.highligntedBackgroundView = highligntedBackgroundView
                    var found = false
                    outer: for subview in self.subviews {
                        for (_, listItemView) in self.itemViews {
                            if subview === listItemView.view.view {
                                self.insertSubview(highligntedBackgroundView, belowSubview: subview)
                                found = true
                                break outer
                            }
                        }
                    }
                    if !found {
                        self.insertSubview(highligntedBackgroundView, aboveSubview: self.backgroundView)
                    }
                    
                    highligntedBackgroundView.backgroundColor = component.theme.contextMenu.itemHighlightedBackgroundColor
                }
                var highlightFrame = CGRect(origin: CGPoint(x: 0.0, y: itemComponentView.frame.minY), size: CGSize(width: self.bounds.width, height: itemComponentView.bounds.height))
                if id != component.items.last?.id {
                    highlightFrame.size.height += UIScreenPixel
                }
                
                highligntedBackgroundView.frame = highlightFrame
            } else {
                if let highligntedBackgroundView = self.highligntedBackgroundView {
                    self.highligntedBackgroundView = nil
                    highligntedBackgroundView.removeFromSuperview()
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            return self
        }
        
        func update(component: ContextMenuActionsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let availableItemSize = availableSize
            
            var itemsSize = CGSize()
            var validIds = Set<AnyHashable>()
            var currentItems: [(id: AnyHashable, itemFrame: CGRect, itemTransition: Transition)] = []
            for i in 0 ..< component.items.count {
                let item = component.items[i]
                validIds.insert(item.id)
                
                let itemView: ItemView
                var itemTransition = transition
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ItemView()
                    self.itemViews[item.id] = itemView
                    self.insertSubview(itemView.separatorView, aboveSubview: self.backgroundView)
                }
                
                let itemSize = itemView.view.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {
                        ContextMenuActionItemEnvironment(theme: component.theme)
                    },
                    containerSize: availableItemSize
                )
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsSize.height), size: itemSize)
                if let view = itemView.view.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    itemTransition.setFrame(view: view, frame: itemFrame)
                }
                currentItems.append((item.id, itemFrame, itemTransition))
                itemsSize.width = max(itemsSize.width, itemSize.width)
                itemsSize.height += itemSize.height
            }
            
            itemsSize.width = max(itemsSize.width, 180.0)
            
            for i in 0 ..< currentItems.count {
                let item = currentItems[i]
                guard let itemView = self.itemViews[item.id] else {
                    continue
                }
                itemView.separatorView.backgroundColor = component.theme.contextMenu.itemSeparatorColor
                itemView.separatorView.isHidden = i == currentItems.count - 1
                item.itemTransition.setFrame(view: itemView.separatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: item.itemFrame.maxY), size: CGSize(width: itemsSize.width, height: UIScreenPixel)))
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.view.view?.removeFromSuperview()
                    itemView.separatorView.removeFromSuperview()
                }
            }
            
            self.backgroundView.updateColor(color: component.theme.contextMenu.backgroundColor, transition: .immediate)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: itemsSize))
            self.backgroundView.update(size: itemsSize, transition: transition.containedViewLayoutTransition)
            
            return itemsSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class TimeSelectionControlComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let bottomInset: CGFloat
    let apply: (Int32) -> Void
    let cancel: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        bottomInset: CGFloat,
        apply: @escaping (Int32) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.bottomInset = bottomInset
        self.apply = apply
        self.cancel = cancel
    }
    
    static func ==(lhs: TimeSelectionControlComponent, rhs: TimeSelectionControlComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let pickerView: UIDatePicker
        private let titleView: ComponentView<Empty>
        private let leftButtonView: ComponentView<Empty>
        private let actionButtonView: ComponentView<Empty>
        
        private var component: TimeSelectionControlComponent?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.pickerView = UIDatePicker()
            
            self.titleView = ComponentView<Empty>()
            self.leftButtonView = ComponentView<Empty>()
            self.actionButtonView = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            self.pickerView.timeZone = TimeZone(secondsFromGMT: 0)
            self.pickerView.datePickerMode = .countDownTimer
            self.pickerView.datePickerMode = .dateAndTime
            if #available(iOS 13.4, *) {
                self.pickerView.preferredDatePickerStyle = .wheels
            }
            self.pickerView.minimumDate = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT()))
            self.pickerView.maximumDate = Date(timeIntervalSince1970: Double(Int32.max - 1))
            
            self.addSubview(self.pickerView)
            self.pickerView.addTarget(self, action: #selector(self.datePickerUpdated), for: .valueChanged)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func datePickerUpdated() {
        }
        
        func update(component: TimeSelectionControlComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            if self.component?.theme !== component.theme {
                UILabel.setDateLabel(component.theme.list.itemPrimaryTextColor)
                
                self.pickerView.setValue(component.theme.list.itemPrimaryTextColor, forKey: "textColor")
                
                self.backgroundView.updateColor(color: component.theme.contextMenu.backgroundColor, transition: .immediate)
            }
            
            self.component = component
            
            let topPanelHeight: CGFloat = 54.0
            let pickerSpacing: CGFloat = 10.0
            
            let pickerSize = CGSize(width: availableSize.width, height: 216.0)
            let pickerFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + pickerSpacing), size: pickerSize)
            
            let titleSize = self.titleView.update(
                transition: transition,
                component: AnyComponent(Text(text: component.strings.EmojiStatusSetup_SetUntil, font: Font.semibold(17.0), color: component.theme.list.itemPrimaryTextColor)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            if let titleComponentView = self.titleView.view {
                if titleComponentView.superview == nil {
                    self.addSubview(titleComponentView)
                }
                transition.setFrame(view: titleComponentView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: floor((topPanelHeight - titleSize.height) / 2.0)), size: titleSize))
            }
            
            let leftButtonSize = self.leftButtonView.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(
                        text: component.strings.Common_Cancel,
                        font: Font.regular(17.0),
                        color: component.theme.list.itemAccentColor
                    )),
                    action: { [weak self] in
                        self?.component?.cancel()
                    }
                ).minSize(CGSize(width: 16.0, height: topPanelHeight))),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            if let leftButtonComponentView = self.leftButtonView.view {
                if leftButtonComponentView.superview == nil {
                    self.addSubview(leftButtonComponentView)
                }
                transition.setFrame(view: leftButtonComponentView, frame: CGRect(origin: CGPoint(x: 16.0, y: floor((topPanelHeight - leftButtonSize.height) / 2.0)), size: leftButtonSize))
            }
            
            let actionButtonSize = self.actionButtonView.update(
                transition: transition,
                component: AnyComponent(SolidRoundedButtonComponent(
                    title: component.strings.EmojiStatusSetup_SetUntil,
                    icon: nil,
                    theme: SolidRoundedButtonComponent.Theme(theme: component.theme),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: false,
                    action: { [weak self] in
                        guard let strongSelf = self, let component = strongSelf.component else {
                            return
                        }
                        
                        let timestamp = Int32(strongSelf.pickerView.date.timeIntervalSince1970 - Double(TimeZone.current.secondsFromGMT()))
                        component.apply(timestamp)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 50.0)
            )
            let actionButtonFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - actionButtonSize.width) / 2.0), y: pickerFrame.maxY + pickerSpacing), size: actionButtonSize)
            if let actionButtonComponentView = self.actionButtonView.view {
                if actionButtonComponentView.superview == nil {
                    self.addSubview(actionButtonComponentView)
                }
                transition.setFrame(view: actionButtonComponentView, frame: actionButtonFrame)
            }
            
            self.pickerView.frame = pickerFrame
            
            var size = CGSize(width: availableSize.width, height: actionButtonFrame.maxY)
            if component.bottomInset.isZero {
                size.height += 10.0
            } else {
                size.height += max(10.0, component.bottomInset)
            }
            
            self.backgroundView.update(size: size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class EmojiStatusPreviewScreenComponent: Component {
    struct StatusResult {
        let timestamp: Int32
        let sourceView: UIView
    }
    
    final class TransitionAnimation {
        enum TransitionType {
            case animateIn(sourceLayer: CALayer)
        }
        
        let transitionType: TransitionType
        
        init(transitionType: TransitionType) {
            self.transitionType = transitionType
        }
    }
    
    private enum CurrentState {
        case menu
        case timeSelection
    }
    
    typealias EnvironmentType = Empty
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let bottomInset: CGFloat
    let item: EmojiStatusComponent
    let dismiss: (StatusResult?) -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        bottomInset: CGFloat,
        item: EmojiStatusComponent,
        dismiss: @escaping (StatusResult?) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.bottomInset = bottomInset
        self.item = item
        self.dismiss = dismiss
    }
    
    static func ==(lhs: EmojiStatusPreviewScreenComponent, rhs: EmojiStatusPreviewScreenComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.item != rhs.item {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let itemView: ComponentView<Empty>
        private let actionsView: ComponentView<Empty>
        private let timeSelectionView: ComponentView<Empty>
        
        private var currentState: CurrentState = .menu
        
        private var component: EmojiStatusPreviewScreenComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.itemView = ComponentView<Empty>()
            self.actionsView = ComponentView<Empty>()
            self.timeSelectionView = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func backgroundTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                switch self.currentState {
                case .menu:
                    self.component?.dismiss(nil)
                case .timeSelection:
                    self.toggleState()
                }
            }
        }
        
        private func toggleState() {
            switch self.currentState {
            case .menu:
                self.currentState = .timeSelection
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.5, curve: .spring)))
            case .timeSelection:
                self.currentState = .menu
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
            }
        }
        
        func update(component: EmojiStatusPreviewScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let itemSpacing: CGFloat = 12.0
            
            let itemSize = self.itemView.update(
                transition: transition,
                component: AnyComponent(component.item),
                environment: {},
                containerSize: CGSize(width: 128.0, height: 128.0)
            )
            
            var menuItems: [AnyComponentWithIdentity<ContextMenuActionItemEnvironment>] = []
            let delayDurations: [Int] = [
                1 * 60 * 60,
                2 * 60 * 60,
                8 * 60 * 60,
                2 * 24 * 60 * 60
            ]
            for duration in delayDurations {
                menuItems.append(AnyComponentWithIdentity(id: duration, component: AnyComponent(ContextMenuActionItem(
                    title: setTimeoutForIntervalString(strings: component.strings, value: Int32(duration)),
                    action: { [weak self] in
                        guard let strongSelf = self, let component = strongSelf.component else {
                            return .none
                        }
                        guard let itemComponentView = strongSelf.itemView.view else {
                            return .none
                        }
                        component.dismiss(StatusResult(timestamp: Int32(Date().timeIntervalSince1970) + Int32(duration), sourceView: itemComponentView))
                        return .none
                    }
                ))))
            }
            menuItems.append(AnyComponentWithIdentity(id: "Other", component: AnyComponent(ContextMenuActionItem(
                title: component.strings.EmojiStatusSetup_TimerOther,
                action: { [weak self] in
                    self?.toggleState()
                    return .clearHighlight
                }
            ))))
            
            let actionsSize = self.actionsView.update(
                transition: transition,
                component: AnyComponent(ContextMenuActionsComponent(
                    theme: component.theme,
                    items: menuItems
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let timeSelectionSize = self.timeSelectionView.update(
                transition: transition,
                component: AnyComponent(TimeSelectionControlComponent(
                    theme: component.theme,
                    strings: component.strings,
                    bottomInset: component.bottomInset,
                    apply: { [weak self] timestamp in
                        guard let strongSelf = self, let component = strongSelf.component else {
                            return
                        }
                        guard let itemComponentView = strongSelf.itemView.view else {
                            return
                        }
                        component.dismiss(StatusResult(timestamp: timestamp, sourceView: itemComponentView))
                    },
                    cancel: { [weak self] in
                        self?.toggleState()
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let totalContentHeight = itemSize.height + itemSpacing + max(actionsSize.height, timeSelectionSize.height)
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((availableSize.height - totalContentHeight) / 2.0)), size: CGSize(width: availableSize.width, height: totalContentHeight))
            
            let itemFrame = CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.width - itemSize.width) / 2.0), y: contentFrame.minY), size: itemSize)
            let actionsFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - actionsSize.width) / 2.0), y: itemFrame.maxY + itemSpacing), size: actionsSize)
            
            var timeSelectionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - timeSelectionSize.width) / 2.0), y: availableSize.height - timeSelectionSize.height), size: timeSelectionSize)
            if case .menu = self.currentState {
                timeSelectionFrame.origin.y = availableSize.height
            }
            
            if let itemComponentView = self.itemView.view {
                if itemComponentView.superview == nil {
                    self.addSubview(itemComponentView)
                }
                transition.setFrame(view: itemComponentView, frame: itemFrame)
            }
            
            if let actionsComponentView = self.actionsView.view {
                if actionsComponentView.superview == nil {
                    self.addSubview(actionsComponentView)
                }
                transition.setPosition(view: actionsComponentView, position: actionsFrame.center)
                transition.setBounds(view: actionsComponentView, bounds: CGRect(origin: CGPoint(), size: actionsFrame.size))
                
                if case .menu = self.currentState {
                    transition.setTransform(view: actionsComponentView, transform: CATransform3DIdentity)
                    transition.setAlpha(view: actionsComponentView, alpha: 1.0)
                    actionsComponentView.isUserInteractionEnabled = true
                } else {
                    transition.setTransform(view: actionsComponentView, transform: CATransform3DMakeScale(0.001, 0.001, 1.0))
                    transition.setAlpha(view: actionsComponentView, alpha: 0.0)
                    actionsComponentView.isUserInteractionEnabled = false
                }
            }
            
            if let timeSelectionComponentView = self.timeSelectionView.view {
                if timeSelectionComponentView.superview == nil {
                    self.addSubview(timeSelectionComponentView)
                }
                transition.setFrame(view: timeSelectionComponentView, frame: timeSelectionFrame)
            }
            
            self.backgroundView.updateColor(color: component.theme.contextMenu.dimColor, transition: .immediate)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.backgroundView.update(size: availableSize, transition: transition.containedViewLayoutTransition)
            
            if let transitionAnimation = transition.userData(TransitionAnimation.self) {
                switch transitionAnimation.transitionType {
                case let .animateIn(sourceLayer):
                    var additionalPositionDifference = CGPoint()
                    if let copyLayer = sourceLayer.snapshotContentTree(), let itemComponentView = self.itemView.view {
                        sourceLayer.isHidden = true
                        copyLayer.frame = sourceLayer.convert(sourceLayer.bounds, to: self.layer)
                        self.layer.addSublayer(copyLayer)
                        
                        copyLayer.animatePosition(from: copyLayer.frame.center, to: itemComponentView.frame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                        copyLayer.animateScale(from: 1.0, to: itemComponentView.bounds.width / copyLayer.bounds.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                        copyLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyLayer] _ in
                            copyLayer?.removeFromSuperlayer()
                        })
                        
                        additionalPositionDifference = CGPoint(x: itemComponentView.frame.center.x - copyLayer.frame.center.x, y: itemComponentView.frame.center.y - copyLayer.frame.center.y)
                        itemComponentView.layer.animatePosition(from: copyLayer.frame.center, to: itemComponentView.frame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                        itemComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.16)
                        itemComponentView.layer.animateScale(from: copyLayer.bounds.width / itemComponentView.bounds.width, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    
                    self.backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    
                    if let actionsComponentView = self.actionsView.view {
                        actionsComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        actionsComponentView.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6)
                        actionsComponentView.layer.animateSpring(from: (-actionsComponentView.bounds.height / 2.0) as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.translation.y", duration: 0.6)
                        
                        let _ = additionalPositionDifference
                    }
                }
            }
            
            return availableSize
        }
        
        func animateOut(targetLayer: CALayer?, completion: @escaping () -> Void) {
            if let targetLayer = targetLayer, let itemComponentView = self.itemView.view {
                targetLayer.isHidden = false
                let targetLayerPosition = targetLayer.position
                let targetLayerSuperlayer = targetLayer.superlayer
                var targetLayerIndexPosition: UInt32?
                if let targetLayerSuperlayer = targetLayerSuperlayer {
                    if let index = targetLayerSuperlayer.sublayers?.firstIndex(of: targetLayer) {
                        targetLayerIndexPosition = UInt32(index)
                    }
                }
                
                let localTargetPosition = targetLayer.convert(targetLayer.bounds.center, to: self.layer)
                self.layer.addSublayer(targetLayer)
                targetLayer.position = localTargetPosition
                
                targetLayer.animatePosition(from: itemComponentView.frame.center, to: localTargetPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                targetLayer.animateScale(from: itemComponentView.bounds.width / targetLayer.bounds.width, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak targetLayer, weak targetLayerSuperlayer] _ in
                    if let targetLayer = targetLayer, let targetLayerSuperlayer = targetLayerSuperlayer {
                        if let targetLayerIndexPosition = targetLayerIndexPosition {
                            targetLayerSuperlayer.insertSublayer(targetLayer, at: targetLayerIndexPosition)
                            targetLayer.position = targetLayerPosition
                        }
                    }
                    completion()
                })
                targetLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.16)
                
                itemComponentView.layer.animatePosition(from: itemComponentView.frame.center, to: localTargetPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                itemComponentView.layer.animateScale(from: 1.0, to: targetLayer.bounds.width / itemComponentView.bounds.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                itemComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                
                self.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                if let actionsComponentView = self.actionsView.view {
                    actionsComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    })
                }
                
                if let timeSelectionComponentView = self.timeSelectionView.view {
                    timeSelectionComponentView.layer.animatePosition(from: timeSelectionComponentView.layer.position, to: CGPoint(x: timeSelectionComponentView.layer.position.x, y: self.bounds.height + timeSelectionComponentView.bounds.height / 2.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
            } else {
                self.backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                if let actionsComponentView = self.actionsView.view {
                    actionsComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        completion()
                    })
                    
                    if let timeSelectionComponentView = self.timeSelectionView.view {
                        timeSelectionComponentView.layer.animatePosition(from: timeSelectionComponentView.layer.position, to: CGPoint(x: timeSelectionComponentView.layer.position.x, y: self.bounds.height + timeSelectionComponentView.bounds.height / 2.0), duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    }
                } else {
                    completion()
                }
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
