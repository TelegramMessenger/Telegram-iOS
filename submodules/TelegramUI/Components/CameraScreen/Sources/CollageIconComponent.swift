import Foundation
import UIKit
import Display
import ComponentFlow
import Camera
import CameraButtonComponent

private func generateCollageIcon(grid: Camera.CollageGrid, crossed: Bool) -> UIImage? {
    return generateImage(CGSize(width: 36.0, height: 36.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: .zero, size: size)
        context.clear(bounds)
                      
        let lineWidth = 2.0 - UIScreenPixel
        context.setLineWidth(lineWidth)
        context.setStrokeColor(UIColor.white.cgColor)

        let iconBounds = bounds.insetBy(dx: 11.0, dy: 9.0)
        let path = UIBezierPath(roundedRect: iconBounds, cornerRadius: 3.0)
        context.addPath(path.cgPath)
        context.strokePath()
        
        let rowHeight = iconBounds.height / CGFloat(grid.rows.count)
        
        var yOffset: CGFloat = iconBounds.minY + lineWidth / 2.0
        for i in 0 ..< grid.rows.count {
            let row = grid.rows[i]
            var xOffset: CGFloat = iconBounds.minX
            let lineCount = max(0, row.columns - 1)
            let colWidth = iconBounds.width / CGFloat(max(row.columns, 1))
            for _ in 0 ..< lineCount {
                xOffset += colWidth
                context.move(to: CGPoint(x: xOffset, y: yOffset))
                context.addLine(to: CGPoint(x: xOffset, y: yOffset + rowHeight))
                context.strokePath()
            }
            yOffset += rowHeight
            
            if i != grid.rows.count - 1 {
                context.move(to: CGPoint(x: iconBounds.minX, y: yOffset - lineWidth / 2.0))
                context.addLine(to: CGPoint(x: iconBounds.maxX, y: yOffset - lineWidth / 2.0))
                context.strokePath()
            }
        }
        
        if crossed {
            context.setLineCap(.round)
            
            let startPoint = CGPoint(x: iconBounds.minX - 3.0, y: iconBounds.minY - 2.0)
            let endPoint = CGPoint(x: iconBounds.maxX + 4.0, y: iconBounds.maxY + 1.0)
            
            context.setBlendMode(.clear)
            context.move(to: startPoint.offsetBy(dx: 0.0, dy: lineWidth))
            context.addLine(to: endPoint.offsetBy(dx: 0.0, dy: lineWidth))
            context.strokePath()
            
            context.setBlendMode(.normal)
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    })
}

final class CollageIconComponent: Component {
    typealias EnvironmentType = Empty
    
    let grid: Camera.CollageGrid
    let crossed: Bool
    let isSelected: Bool
    let tintColor: UIColor
    
    init(
        grid: Camera.CollageGrid,
        crossed: Bool,
        isSelected: Bool,
        tintColor: UIColor
    ) {
        self.grid = grid
        self.crossed = crossed
        self.isSelected = isSelected
        self.tintColor = tintColor
    }
    
    static func ==(lhs: CollageIconComponent, rhs: CollageIconComponent) -> Bool {
        if lhs.grid != rhs.grid {
            return false
        }
        if lhs.crossed != rhs.crossed {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconView = UIImageView()
                
        private var component: CollageIconComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                     
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: CollageIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
                        
            if component.grid != previousComponent?.grid {
                let image = generateCollageIcon(grid: component.grid, crossed: component.crossed)
                let selectedImage = generateImage(CGSize(width: 36.0, height: 36.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    context.setFillColor(UIColor.white.cgColor)
                    context.fillEllipse(in: CGRect(origin: .zero, size: size))
                    
                    if let image, let cgImage = image.cgImage {
                        context.setBlendMode(.clear)
                        context.clip(to: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) / 2.0), y: floorToScreenPixels((size.height - image.size.height) / 2.0) - 1.0), size: image.size), mask: cgImage)
                        context.fill(CGRect(origin: .zero, size: size))
                    }
                })?.withRenderingMode(.alwaysTemplate)
                
                self.iconView.image = image

                if self.iconView.isHighlighted {
                    self.iconView.isHighlighted = false
                    self.iconView.highlightedImage = selectedImage
                    self.iconView.isHighlighted = true
                } else {
                    self.iconView.highlightedImage = selectedImage
                }
            }
            
            let size = CGSize(width: 36.0, height: 36.0)
            self.iconView.frame = CGRect(origin: .zero, size: size)
            self.iconView.isHighlighted = component.isSelected
            
            self.iconView.tintColor = component.tintColor
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class CollageIconCarouselComponent: Component {
    typealias EnvironmentType = Empty
    
    let grids: [Camera.CollageGrid]
    let selected: (Camera.CollageGrid) -> Void
    
    init(
        grids: [Camera.CollageGrid],
        selected: @escaping (Camera.CollageGrid) -> Void
    ) {
        self.grids = grids
        self.selected = selected
    }
    
    static func ==(lhs: CollageIconCarouselComponent, rhs: CollageIconCarouselComponent) -> Bool {
        if lhs.grids != rhs.grids {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let clippingView = UIView()
        private let scrollView = UIScrollView()
        
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
                
        private var component: CollageIconCarouselComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                                 
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            
            self.addSubview(self.clippingView)
            self.clippingView.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: CollageIconCarouselComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let inset: CGFloat = 27.0
            let spacing: CGFloat = availableSize.width > 290.0 ? 7.0 : 8.0
            var contentWidth: CGFloat = inset
            let buttonSize = CGSize(width: 40.0, height: 40.0)
            
            var validIds: [AnyHashable] = []
            for grid in component.grids {
                validIds.append(grid)
                
                let itemView: ComponentView<Empty>
                if let current = itemViews[grid] {
                    itemView = current
                } else {
                    itemView = ComponentView()
                    self.itemViews[grid] = itemView
                }
                let itemSize = itemView.update(
                    transition: .immediate,
                    component: AnyComponent(CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "content",
                            component: AnyComponent(
                                CollageIconComponent(
                                    grid: grid,
                                    crossed: false,
                                    isSelected: false,
                                    tintColor: .white
                                )
                            )
                        ),
                        action: { [weak self] in
                            if let component = self?.component {
                                component.selected(grid)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: buttonSize
                )
                if let view = itemView.view {
                    if view.superview == nil {
                        self.scrollView.addSubview(view)
                        
                        view.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                        view.layer.shadowRadius = 3.0
                        view.layer.shadowColor = UIColor.black.cgColor
                        view.layer.shadowOpacity = 0.25
                        view.layer.rasterizationScale = UIScreenScale
                        view.layer.shouldRasterize = true
                    }
                    view.frame = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: itemSize)
                }
                contentWidth += itemSize.width + spacing
            }
            
            let contentSize = CGSize(width: contentWidth, height: buttonSize.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.scrollView.frame = CGRect(origin: .zero, size: availableSize)
            self.clippingView.frame = CGRect(origin: .zero, size: availableSize)
            
            if self.clippingView.mask == nil {
                if let maskImage = generateGradientImage(size: CGSize(width: 42.0, height: 10.0), colors: [UIColor.clear, UIColor.black, UIColor.black, UIColor.clear], locations: [0.0, 0.2, 0.8, 1.0], direction: .horizontal) {
                    let maskView = UIImageView(image: maskImage.stretchableImage(withLeftCapWidth: 13, topCapHeight: 0))
                    self.clippingView.mask = maskView
                }
            }
            self.clippingView.mask?.frame = CGRect(origin: .zero, size: availableSize)
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            return availableSize
        }
        
        func animateIn() {
            guard self.frame.width > 0.0 else {
                return
            }
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            for (_, itemView) in self.itemViews {
                itemView.view?.layer.animatePosition(from: CGPoint(x: self.frame.width, y: 0.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            guard self.frame.width > 0.0 else {
                return
            }
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion()
            })
            for (_, itemView) in self.itemViews {
                itemView.view?.layer.animatePosition(from: .zero, to: CGPoint(x: self.frame.width + self.scrollView.contentOffset.x, y: 0.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            }
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
