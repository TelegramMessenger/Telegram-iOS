import Foundation
import UIKit
import Display
import ComponentFlow

public final class PageIndicatorComponent: Component {
    private let pageCount: Int
    private let position: CGFloat
    private let inactiveColor: UIColor
    private let activeColor: UIColor
    
    public init(
        pageCount: Int,
        position: CGFloat,
        inactiveColor: UIColor,
        activeColor: UIColor
    ) {
        self.pageCount = pageCount
        self.position = position
        self.inactiveColor = inactiveColor
        self.activeColor = activeColor
    }
    
    public static func ==(lhs: PageIndicatorComponent, rhs: PageIndicatorComponent) -> Bool {
        if lhs.pageCount != rhs.pageCount {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        if !lhs.inactiveColor.isEqual(rhs.inactiveColor) {
            return false
        }
        if !lhs.activeColor.isEqual(rhs.activeColor) {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: PageIndicatorComponent?
        
        private let indicatorView: PageIndicatorView
        
        public override init(frame: CGRect) {
            self.indicatorView = PageIndicatorView(frame: frame)
            
            super.init(frame: frame)
            
            self.addSubview(self.indicatorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: PageIndicatorComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            self.indicatorView.pageCount = component.pageCount
            self.indicatorView.setProgress(progress: component.position)
            
            self.indicatorView.activeColor = component.activeColor
            self.indicatorView.inactiveColor = component.inactiveColor
                        
            let size = self.indicatorView.intrinsicContentSize
            self.indicatorView.frame = CGRect(origin: .zero, size: size)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class PageIndicatorView: UIView {
    var displayCount: Int {
        return min(11, self.pageCount)
    }
    var dotSize: CGFloat = 8.0
    var dotSpace: CGFloat = 10.0
    var smallDotSizeRatio: CGFloat = 0.5
    var mediumDotSizeRatio: CGFloat = 0.75
    
    public func setCurrentPage(at currentPage: Int, animated: Bool = false) {
        guard (currentPage < self.pageCount && currentPage >= 0) else { return }
        guard currentPage != self.currentPage else { return }
 
        self.scrollView.layer.removeAllAnimations()
        self.updateDot(at: currentPage, animated: animated)
        self.currentPage = currentPage
    }

    public private(set) var currentPage: Int = 0
    
    public var pageCount: Int = 0 {
        didSet {
            guard self.pageCount != oldValue else {
                return
            }
            self.update(currentPage: self.currentPage)
        }
    }

    public var inactiveColor: UIColor = .gray {
        didSet {
            guard !self.inactiveColor.isEqual(oldValue) else {
                return
            }
            self.updateDotColor(currentPage: self.currentPage)
        }
    }

    public var activeColor: UIColor = .blue {
        didSet {
            guard !self.activeColor.isEqual(oldValue) else {
                return
            }
            self.updateDotColor(currentPage: self.currentPage)
        }
    }

    public var animationDuration: Double = 0.3

    public init() {
        super.init(frame: .zero)

        self.setup()
        self.updateViewSize()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        
        self.scrollView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: self.itemSize * CGFloat(self.displayCount), height: self.itemSize)
    }

    public func setProgress(progress: CGFloat) {
        let currentPage = Int(round(progress * CGFloat(self.pageCount - 1)))
        self.setCurrentPage(at: currentPage, animated: true)
    }

    public func updateViewSize() {
        self.bounds.size = intrinsicContentSize
    }

    private let scrollView = UIScrollView()

    private var itemSize: CGFloat {
        return self.dotSize + self.dotSpace
    }
    
    private var items: [ItemView] = []

    private func setup() {
        self.backgroundColor = .clear

        self.scrollView.backgroundColor = .clear
        self.scrollView.isUserInteractionEnabled = false
        self.scrollView.showsHorizontalScrollIndicator = false

        self.addSubview(self.scrollView)
    }

    private func update(currentPage: Int) {
        if currentPage < self.displayCount {
            self.items = (-2..<(self.displayCount + 2))
                .map { ItemView(itemSize: self.itemSize, dotSize: self.dotSize, smallDotSizeRatio: self.smallDotSizeRatio, mediumDotSizeRatio: self.mediumDotSizeRatio, index: $0) }
        }
        else {
            guard let firstItem = self.items.first else { return }
            guard let lastItem = self.items.last else { return }
            self.items = (firstItem.index...lastItem.index)
                .map { ItemView(itemSize: self.itemSize, dotSize: self.dotSize, smallDotSizeRatio: self.smallDotSizeRatio, mediumDotSizeRatio: self.mediumDotSizeRatio, index: $0) }
        }

        self.scrollView.contentSize = .init(width: self.itemSize * CGFloat(self.pageCount), height: self.itemSize)

        self.scrollView.subviews.forEach { $0.removeFromSuperview() }
        self.items.forEach { self.scrollView.addSubview($0) }

        let size: CGSize = .init(width: self.itemSize * CGFloat(self.displayCount), height: self.itemSize)

        self.scrollView.bounds.size = size

        if self.displayCount < self.pageCount {
            self.scrollView.contentInset = .init(top: 0.0, left: self.itemSize * 2.0, bottom: 0, right: self.itemSize * 2.0)
        } else {
            self.scrollView.contentInset = .zero
        }

        self.updateDot(at: currentPage, animated: false)
    }

    private func updateDot(at currentPage: Int, animated: Bool) {
        self.updateDotColor(currentPage: currentPage)

        if self.pageCount > self.displayCount {
            self.updateDotPosition(currentPage: currentPage, animated: animated)
            self.updateDotSize(currentPage: currentPage, animated: animated)
        }
    }
    
    private func updateDotColor(currentPage: Int) {
        self.items.forEach {
            $0.dotColor = ($0.index == currentPage) ?
                self.activeColor : self.inactiveColor
        }
    }
    
    private func updateDotPosition(currentPage: Int, animated: Bool) {
        let duration = animated ? self.animationDuration : 0

        if currentPage == 0 {
            let x = -self.scrollView.contentInset.left
            self.moveScrollView(x: x, duration: duration)
        }
        else if currentPage == self.pageCount - 1 {
            let x = self.scrollView.contentSize.width - self.scrollView.bounds.width + self.scrollView.contentInset.right
            self.moveScrollView(x: x, duration: duration)
        }
        else if CGFloat(currentPage) * self.itemSize <= self.scrollView.contentOffset.x + self.itemSize {
            let x = self.scrollView.contentOffset.x - self.itemSize
            self.moveScrollView(x: x, duration: duration)
        }
        else if CGFloat(currentPage) * self.itemSize + self.itemSize >= self.scrollView.contentOffset.x + self.scrollView.bounds.width - self.itemSize {
            let x = self.scrollView.contentOffset.x + self.itemSize
            self.moveScrollView(x: x, duration: duration)
        }
    }

    private func updateDotSize(currentPage: Int, animated: Bool) {
        let duration = animated ? self.animationDuration : 0

        self.items.forEach { item in
            item.animateDuration = duration
            if item.index == currentPage {
                item.state = .normal
            } else if item.index < 0 {
                item.state = .none
            } else if item.index > self.pageCount - 1 {
                item.state = .none
            } else if item.frame.minX <= self.scrollView.contentOffset.x {
                item.state = .small
            } else if item.frame.maxX >= self.scrollView.contentOffset.x + self.scrollView.bounds.width {
                item.state = .small
            } else if item.frame.minX <= self.scrollView.contentOffset.x + self.itemSize {
                item.state = .medium
            } else if item.frame.maxX >= self.scrollView.contentOffset.x + self.scrollView.bounds.width - self.itemSize {
                item.state = .medium
            } else {
                item.state = .normal
            }
        }
    }

    private func moveScrollView(x: CGFloat, duration: TimeInterval) {
        let direction = self.behaviorDirection(x: x)
        self.reusedView(direction: direction)
        UIView.animate(withDuration: duration, animations: { [unowned self] in
            self.scrollView.contentOffset.x = x
        })
    }

    private enum Direction {
        case left
        case right
        case stay
    }

    private func behaviorDirection(x: CGFloat) -> Direction {
        switch x {
            case let x where x > self.scrollView.contentOffset.x:
                return .right
            case let x where x < self.scrollView.contentOffset.x:
                return .left
            default:
                return .stay
        }
    }

    private func reusedView(direction: Direction) {
        guard let firstItem = self.items.first else { return }
        guard let lastItem = self.items.last else { return }

        switch direction {
            case .left:
                lastItem.index = firstItem.index - 1
                lastItem.frame = CGRect(origin: CGPoint(x: CGFloat(lastItem.index) * self.itemSize, y: 0.0), size: CGSize(width: self.itemSize, height: self.itemSize))
                self.items.insert(lastItem, at: 0)
                self.items.removeLast()

            case .right:
                firstItem.index = lastItem.index + 1
                firstItem.frame = CGRect(origin: CGPoint(x: CGFloat(firstItem.index) * self.itemSize, y: 0.0), size: CGSize(width: self.itemSize, height: self.itemSize))
                self.items.insert(firstItem, at: self.items.count)
                self.items.removeFirst()

            case .stay:
                break
        }
    }
}


private class ItemView: UIView {
    enum State {
        case none
        case small
        case medium
        case normal
    }

    private let dotView = UIView()
    
    var index: Int

    var dotColor = UIColor.lightGray {
        didSet {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
            transition.updateBackgroundColor(layer: self.dotView.layer, color: dotColor)
        }
    }

    var state: State = .normal {
        didSet {
            self.updateDotSize(state: state)
        }
    }
    
    private let itemSize: CGFloat
    private let dotSize: CGFloat
    private let smallSizeRatio: CGFloat
    private let mediumSizeRatio: CGFloat

    var animateDuration: Double = 0.3

    init(itemSize: CGFloat, dotSize: CGFloat, smallDotSizeRatio: CGFloat, mediumDotSizeRatio: CGFloat, index: Int) {
        self.itemSize = itemSize
        self.dotSize = dotSize
        self.mediumSizeRatio = mediumDotSizeRatio
        self.smallSizeRatio = smallDotSizeRatio
        self.index = index
        
        let x = itemSize * CGFloat(index)
        let frame = CGRect(x: x, y: 0, width: itemSize, height: itemSize)

        super.init(frame: frame)
        
        self.backgroundColor = UIColor.clear
        
        self.dotView.frame.size = CGSize(width: dotSize, height: dotSize)
        self.dotView.center = CGPoint(x: itemSize / 2.0, y: itemSize / 2.0)
        self.dotView.backgroundColor = self.dotColor
        self.dotView.layer.cornerRadius = dotSize / 2.0
        self.dotView.layer.masksToBounds = true
        
        addSubview(dotView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateDotSize(state: State) {
        var size: CGSize
        
        switch state {
            case .normal:
                size = CGSize(width: self.dotSize, height: self.dotSize)
            case .medium:
                size = CGSize(width: self.dotSize * self.mediumSizeRatio, height: self.dotSize * self.mediumSizeRatio)
            case .small:
                size = CGSize( width: self.dotSize * self.smallSizeRatio, height: self.dotSize * self.smallSizeRatio
                )
            case .none:
                size = CGSize.zero
        }

        UIView.animate(withDuration: self.animateDuration, animations: { [unowned self] in
            self.dotView.layer.cornerRadius = size.height / 2.0
            self.dotView.layer.bounds.size = size
        })
    }
}


