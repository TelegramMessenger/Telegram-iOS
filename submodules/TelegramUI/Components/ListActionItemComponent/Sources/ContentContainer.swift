import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent

private final class ContextOptionComponent: Component {
    let title: String
    let color: UIColor
    let isLast: Bool
    let action: () -> Void
    
    init(
        title: String,
        color: UIColor,
        isLast: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.color = color
        self.isLast = isLast
        self.action = action
    }
    
    static func ==(lhs: ContextOptionComponent, rhs: ContextOptionComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.isLast != rhs.isLast {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let backgroundView: UIView
        let title = ComponentView<Empty>()
        
        var component: ContextOptionComponent?
        
        override init(frame: CGRect) {
            self.backgroundView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.action()
            }
        }
        
        func update(component: ContextOptionComponent, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 8.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let size = CGSize(width: sideInset * 2.0 + titleSize.width, height: availableSize.height)
            let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((size.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            self.backgroundView.backgroundColor = component.color
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width + (component.isLast ? 1000.0 : 0.0), height: size.height)))
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ContentContainer: UIScrollView, UIScrollViewDelegate {
    private let closeOtherContextOptions: () -> Void
    
    private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
    
    private var ignoreScrollingEvents: Bool = false
    private var draggingBeganInClosedState: Bool = false
    private var didProcessScrollingCycle: Bool = false
    
    private var contextOptions: [ListActionItemComponent.ContextOption] = []
    private var optionsWidth: CGFloat = 0.0
    
    private var revealedStateTapRecognizer: UITapGestureRecognizer?
    
    init(closeOtherContextOptions: @escaping () -> Void) {
        self.closeOtherContextOptions = closeOtherContextOptions
        
        super.init(frame: CGRect())
        
        let revealedStateTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:)))
        self.revealedStateTapRecognizer = revealedStateTapRecognizer
        revealedStateTapRecognizer.isEnabled = false
        self.addGestureRecognizer(revealedStateTapRecognizer)
        
        self.delaysContentTouches = false
        self.canCancelContentTouches = true
        self.clipsToBounds = false
        self.contentInsetAdjustmentBehavior = .never
        self.automaticallyAdjustsScrollIndicatorInsets = false
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.alwaysBounceHorizontal = false
        self.alwaysBounceVertical = false
        self.scrollsToTop = false
        self.delegate = self
        
        self.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let self else {
                return false
            }
            
            if self.contentOffset.x != 0.0 {
                return true
            }
            
            return false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func onTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.revealedStateTapRecognizer?.isEnabled = self.contentOffset.x > 0.0
        if self.contentOffset.x > 0.0 {
            if !self.didProcessScrollingCycle {
                self.didProcessScrollingCycle = true
                self.closeOtherContextOptions()
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.didProcessScrollingCycle = false
        self.draggingBeganInClosedState = self.contentOffset.x == 0.0
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        targetContentOffset.pointee.x = self.contentOffset.x
        
        if self.contentOffset.x >= self.optionsWidth + 30.0 {
            self.contextOptions.last?.action()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if self.draggingBeganInClosedState {
                    if self.contentOffset.x > 20.0 {
                        self.setContentOffset(CGPoint(x: self.optionsWidth, y: 0.0), animated: true)
                    } else {
                        self.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
                    }
                } else {
                    if self.contentOffset.x < self.optionsWidth - 20.0 {
                        self.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
                    } else {
                        self.setContentOffset(CGPoint(x: self.optionsWidth, y: 0.0), animated: true)
                    }
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let revealedStateTapRecognizer = self.revealedStateTapRecognizer, revealedStateTapRecognizer.isEnabled {
            if self.bounds.contains(point), point.x < self.bounds.width {
                return self
            }
        }
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        return result
    }
    
    func closeContextOptions() {
        self.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
    }
    
    func update(size: CGSize, contextOptions: [ListActionItemComponent.ContextOption], transition: ComponentTransition) {
        self.contextOptions = contextOptions
        
        var validIds: [AnyHashable] = []
        var optionsWidth: CGFloat = 0.0
        for i in 0 ..< contextOptions.count {
            let option = contextOptions[i]
            validIds.append(option.id)
            
            let itemView: ComponentView<Empty>
            var itemTransition = transition
            if let current = self.itemViews[option.id] {
                itemView = current
            } else {
                itemTransition = itemTransition.withAnimation(.none)
                itemView = ComponentView()
                self.itemViews[option.id] = itemView
            }
            
            let itemSize = itemView.update(
                transition: itemTransition,
                component: AnyComponent(ContextOptionComponent(
                    title: option.title,
                    color: option.color,
                    isLast: i == contextOptions.count - 1,
                    action: option.action
                )),
                environment: {},
                containerSize: CGSize(width: 10000.0, height: size.height)
            )
            let itemFrame = CGRect(origin: CGPoint(x: size.width + optionsWidth, y: 0.0), size: itemSize)
            optionsWidth += itemSize.width
            if let itemComponentView = itemView.view {
                self.addSubview(itemComponentView)
                itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
            }
        }
        var removedIds: [AnyHashable] = []
        for (id, itemView) in self.itemViews {
            if !validIds.contains(id) {
                removedIds.append(id)
                if let itemComponentView = itemView.view {
                    itemComponentView.removeFromSuperview()
                }
            }
        }
        for id in removedIds {
            self.itemViews.removeValue(forKey: id)
        }
        self.optionsWidth = optionsWidth
        
        let contentSize = CGSize(width: size.width + optionsWidth, height: size.height)
        if self.contentSize != contentSize {
            self.contentSize = contentSize
        }
        self.isScrollEnabled = optionsWidth != 0.0
    }
}
