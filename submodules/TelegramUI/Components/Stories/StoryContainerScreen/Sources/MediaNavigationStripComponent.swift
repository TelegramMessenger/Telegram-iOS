import Foundation
import UIKit
import Display
import ComponentFlow
import HierarchyTrackingLayer

final class MediaNavigationStripComponent: Component {
    final class EnvironmentType: Equatable {
        let currentProgress: Double
        let currentIsBuffering: Bool
        
        init(currentProgress: Double, currentIsBuffering: Bool) {
            self.currentProgress = currentProgress
            self.currentIsBuffering = currentIsBuffering
        }
        
        static func ==(lhs: EnvironmentType, rhs: EnvironmentType) -> Bool {
            if lhs.currentProgress != rhs.currentProgress {
                return false
            }
            if lhs.currentIsBuffering != rhs.currentIsBuffering {
                return false
            }
            return true
        }
    }
    
    let index: Int
    let count: Int
    
    init(index: Int, count: Int) {
        self.index = index
        self.count = count
    }

    static func ==(lhs: MediaNavigationStripComponent, rhs: MediaNavigationStripComponent) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        return true
    }
    
    private final class ItemLayer: SimpleLayer {
        let foregroundLayer: SimpleLayer
        var bufferingGradientLayer: SimpleGradientLayer?
        var bufferingLayer: HierarchyTrackingLayer?
        
        override init() {
            self.foregroundLayer = SimpleLayer()
            
            super.init()
            
            self.cornerRadius = 1.5
            
            self.foregroundLayer.cornerRadius = 1.5
            self.addSublayer(self.foregroundLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override init(layer: Any) {
            self.foregroundLayer = SimpleLayer()
            
            super.init(layer: layer)
        }
        
        private func updateProgressAnimation(size: CGSize) {
            guard let bufferingGradientLayer = self.bufferingGradientLayer else {
                return
            }
            
            let gradientWidth: CGFloat = floor(max(10.0, size.width * 0.6))
            
            bufferingGradientLayer.frame = CGRect(origin: CGPoint(x: -gradientWidth, y: 0.0), size: CGSize(width: gradientWidth, height: 3.0))
            
            let animation = bufferingGradientLayer.makeAnimation(from: 0.0 as NSNumber, to: (size.width + gradientWidth * 2.0) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.6, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
            animation.repeatCount = Float.infinity
            bufferingGradientLayer.add(animation, forKey: "shimmer")
        }
        
        func updateIsBuffering(size: CGSize, isBuffering: Bool) {
            if isBuffering {
                let bufferingLayer: HierarchyTrackingLayer
                if let current = self.bufferingLayer {
                    bufferingLayer = current
                } else {
                    bufferingLayer = HierarchyTrackingLayer()
                    bufferingLayer.cornerRadius = 1.5
                    bufferingLayer.masksToBounds = true
                    self.bufferingLayer = bufferingLayer
                    self.addSublayer(bufferingLayer)
                    bufferingLayer.didEnterHierarchy = { [weak self] in
                        guard let self, !self.bounds.isEmpty else {
                            return
                        }
                        self.updateProgressAnimation(size: self.bounds.size)
                    }
                }
                
                let bufferingGradientLayer: SimpleGradientLayer
                if let current = self.bufferingGradientLayer {
                    bufferingGradientLayer = current
                } else {
                    bufferingGradientLayer = SimpleGradientLayer()
                    self.bufferingGradientLayer = bufferingGradientLayer
                    bufferingLayer.addSublayer(bufferingGradientLayer)
                    
                    let colorCount = 7
                    bufferingGradientLayer.colors = (0 ..< colorCount).map { index -> CGColor in
                        let t = CGFloat(index) / CGFloat(colorCount - 1)
                        let fraction: CGFloat = 1.0 - max(0.0, min(1.0, abs(0.5 - t) / 0.5))
                        return UIColor(white: 1.0, alpha: 0.3 * sin(fraction)).cgColor
                    }
                }
                
                bufferingLayer.frame = CGRect(origin: CGPoint(), size: size)
                
                self.updateProgressAnimation(size: size)
            } else if let bufferingLayer = self.bufferingLayer {
                self.bufferingLayer = nil
                self.bufferingGradientLayer = nil
                bufferingLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak bufferingLayer] _ in
                    bufferingLayer?.removeFromSuperlayer()
                })
            }
        }
    }

    final class View: UIView {
        private var visibleItems: [Int: ItemLayer] = [:]
        
        private var component: MediaNavigationStripComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 1.0
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateCurrentItemProgress(value: CGFloat, isBuffering: Bool, transition: Transition) {
            guard let component = self.component else {
                return
            }
            guard let itemLayer = self.visibleItems[component.index] else {
                return
            }
            
            let itemFrame = itemLayer.bounds
            transition.setFrame(layer: itemLayer.foregroundLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: value * itemFrame.width, height: itemFrame.height)))
            itemLayer.updateIsBuffering(size: itemFrame.size, isBuffering: isBuffering)
        }
        
        func update(component: MediaNavigationStripComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            
            let environment = environment[EnvironmentType.self].value
            
            let spacing: CGFloat = 3.0
            let itemHeight: CGFloat = 2.0
            let minItemWidth: CGFloat = 2.0
            
            var validIndices: [Int] = []
            if component.count != 0 {
                let idealItemWidth: CGFloat = (availableSize.width - CGFloat(component.count - 1) * spacing) / CGFloat(component.count)
                
                let itemWidth: CGFloat
                if idealItemWidth < minItemWidth {
                    itemWidth = minItemWidth
                } else {
                    itemWidth = idealItemWidth
                }
                
                var globalWidth: CGFloat = CGFloat(component.count) * itemWidth + CGFloat(component.count - 1) * spacing
                if globalWidth > availableSize.width && globalWidth <= availableSize.width + 1.0 {
                    globalWidth = availableSize.width
                }
                
                let globalFocusedFrame = CGRect(origin: CGPoint(x: CGFloat(component.index) * (itemWidth + spacing), y: 0.0), size: CGSize(width: itemWidth, height: itemHeight))
                var globalOffset: CGFloat = floor(globalFocusedFrame.midX - availableSize.width * 0.5)
                if globalOffset > globalWidth - availableSize.width {
                    globalOffset = globalWidth - availableSize.width
                }
                if globalOffset < 0.0 {
                    globalOffset = 0.0
                }
                
                let potentiallyVisibleCount = Int(ceil((availableSize.width + spacing) / (itemWidth + spacing)))
                let overflowDistance: CGFloat = 24.0
                let potentialOverflowCount = 10
                let _ = overflowDistance
                for i in (component.index - potentiallyVisibleCount) ... (component.index + potentiallyVisibleCount + potentialOverflowCount) {
                    if i < 0 {
                        continue
                    }
                    if i >= component.count {
                        continue
                    }
                    let itemFrame = CGRect(origin: CGPoint(x: -globalOffset + CGFloat(i) * (itemWidth + spacing), y: 0.0), size: CGSize(width: itemWidth, height: itemHeight))
                    if itemFrame.maxY < 0.0 || itemFrame.minY >= availableSize.width {
                        continue
                    }
                    
                    validIndices.append(i)
                    
                    let itemLayer: ItemLayer
                    if let current = self.visibleItems[i] {
                        itemLayer = current
                    } else {
                        itemLayer = ItemLayer()
                        self.layer.addSublayer(itemLayer)
                        self.visibleItems[i] = itemLayer
                        itemLayer.cornerRadius = itemHeight * 0.5
                    }
                    
                    transition.setFrame(layer: itemLayer, frame: itemFrame)
                    
                    itemLayer.backgroundColor = UIColor(white: 1.0, alpha: 0.5).cgColor
                    itemLayer.foregroundLayer.backgroundColor = UIColor(white: 1.0, alpha: 1.0).cgColor
                    
                    let itemProgress: CGFloat
                    var itemIsBuffering = false
                    if i < component.index {
                        itemProgress = 1.0
                    } else if i == component.index {
                        itemProgress = max(0.0, min(1.0, environment.currentProgress))
                        itemIsBuffering = environment.currentIsBuffering
                    } else {
                        itemProgress = 0.0
                    }
                    
                    transition.setFrame(layer: itemLayer.foregroundLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: itemProgress * itemFrame.width, height: itemFrame.height)))
                    itemLayer.updateIsBuffering(size: itemFrame.size, isBuffering: itemIsBuffering)
                }
            }
            
            var removedIndices: [Int] = []
            for (index, itemLayer) in self.visibleItems {
                if !validIndices.contains(index) {
                    removedIndices.append(index)
                    itemLayer.removeFromSuperlayer()
                }
            }
            for index in removedIndices {
                self.visibleItems.removeValue(forKey: index)
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
