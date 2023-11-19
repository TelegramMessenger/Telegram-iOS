import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import SolidRoundedButtonNode
import PresentationDataUtils
import UIKitRuntimeUtils
import ReplayKit

private let textFont = Font.with(size: 14.0, design: .camera, weight: .regular)
private let selectedTextFont = Font.with(size: 14.0, design: .camera, weight: .semibold)

final class WheelControlNodeNew: ASDisplayNode, UIGestureRecognizerDelegate {
    struct Item: Equatable {
        public let title: String
        
        public init(title: String) {
            self.title = title
        }
    }

    private let maskNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    private var itemNodes: [HighlightTrackingButtonNode]
    
    private var validLayout: CGSize?

    private var _items: [Item]
    private var _selectedIndex: Int = 0
    
    public var selectedIndex: Int {
        get {
            return self._selectedIndex
        }
        set {
            guard newValue != self._selectedIndex else {
                return
            }
            self._selectedIndex = newValue
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        guard index != self._selectedIndex else {
            return
        }
        self._selectedIndex = index
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    public var selectedIndexChanged: (Int) -> Void = { _ in }
        
    public init(items: [Item], selectedIndex: Int) {
        self._items = items
        self._selectedIndex = selectedIndex
        
        self.maskNode = ASDisplayNode()
        self.maskNode.setLayerBlock({
            let maskLayer = CAGradientLayer()
            maskLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
            maskLayer.locations = [0.0, 0.15, 0.85, 1.0]
            maskLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            maskLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
            return maskLayer
        })
        self.containerNode = ASDisplayNode()
        
        self.itemNodes = items.map { item in
            let itemNode = HighlightTrackingButtonNode()
            itemNode.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
            itemNode.titleNode.maximumNumberOfLines = 1
            itemNode.titleNode.truncationMode = .byTruncatingTail
            itemNode.accessibilityLabel = item.title
            itemNode.accessibilityTraits = [.button]
            itemNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: -5.0, bottom: -10.0, right: -5.0)
            itemNode.setTitle(item.title.uppercased(), with: textFont, with: .white, for: .normal)
            itemNode.titleNode.shadowColor = UIColor.black.cgColor
            itemNode.titleNode.shadowOffset = CGSize()
            itemNode.titleNode.layer.shadowRadius = 2.0
            itemNode.titleNode.layer.shadowOpacity = 0.3
            itemNode.titleNode.layer.masksToBounds = false
            itemNode.titleNode.layer.shouldRasterize = true
            itemNode.titleNode.layer.rasterizationScale = UIScreen.main.scale
            return itemNode
        }
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.containerNode)
        
        self.itemNodes.forEach(self.containerNode.addSubnode(_:))
        self.setupButtons()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.layer.mask = self.maskNode.layer
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        transition.updateFrame(node: self.maskNode, frame: bounds)
        
        let spacing: CGFloat = 15.0
        if !self.itemNodes.isEmpty {
            var leftOffset: CGFloat = 0.0
            var selectedItemNode: ASDisplayNode?
            for i in 0 ..< self.itemNodes.count {
                let itemNode = self.itemNodes[i]
                let itemSize = itemNode.measure(size)
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: leftOffset, y: (size.height - itemSize.height) / 2.0), size: itemSize))
                
                leftOffset += itemSize.width + spacing
                
                let isSelected = self.selectedIndex == i
                if isSelected {
                    selectedItemNode = itemNode
                }
                if itemNode.isSelected != isSelected {
                    itemNode.isSelected = isSelected
                    let title = itemNode.attributedTitle(for: .normal)?.string ?? ""
                    itemNode.setTitle(title, with: isSelected ? selectedTextFont : textFont, with: isSelected ? UIColor(rgb: 0xffd60a) : .white, for: .normal)
                    if isSelected {
                        itemNode.accessibilityTraits.insert(.selected)
                    } else {
                        itemNode.accessibilityTraits.remove(.selected)
                    }
                }
            }
            
            let totalWidth = leftOffset - spacing
            if let selectedItemNode = selectedItemNode {
                let itemCenter = selectedItemNode.frame.center
                transition.updateFrame(node: self.containerNode, frame: CGRect(x: bounds.width / 2.0 - itemCenter.x, y: 0.0, width: totalWidth, height: bounds.height))
                
                for i in 0 ..< self.itemNodes.count {
                    let itemNode = self.itemNodes[i]
                    let convertedBounds = itemNode.view.convert(itemNode.bounds, to: self.view)
                    let position = convertedBounds.center
                    let offset = position.x - bounds.width / 2.0
                    let angle = abs(offset / bounds.width * 0.99)
                    let sign: CGFloat = offset > 0 ? 1.0 : -1.0
                    
                    var transform = CATransform3DMakeTranslation(-22.0 * angle * angle * sign, 0.0, 0.0)
                    transform = CATransform3DRotate(transform, angle, 0.0, sign, 0.0)
                    transition.animateView {
                        itemNode.transform = transform
                    }
                }
            }
        }
    }
    
    private func setupButtons() {
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            itemNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
        }
    }
    
    @objc private func buttonPressed(_ button: HighlightTrackingButtonNode) {
        guard let index = self.itemNodes.firstIndex(of: button) else {
            return
        }
        
        self._selectedIndex = index
        self.selectedIndexChanged(index)
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .slide))
        }
    }
}
