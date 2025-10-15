import Foundation
import UIKit
import AsyncDisplayKit

private let titleFont = Font.bold(11.0)

public final class CollectionIndexNode: ASDisplayNode {
    public static let searchIndex: String = "_$search$_"
    
    private var currentSize: CGSize?
    private var currentSections: [String] = []
    private var currentColor: UIColor?
    private var titleNodes: [String: (node: ImmediateTextNode, size: CGSize)] = [:]
    private var scrollFeedback: HapticFeedback?
    
    private var currentSelectedIndex: String?
    public var indexSelected: ((String) -> Void)?
    
    override public init() {
        super.init()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    public func update(size: CGSize, color: UIColor, sections: [String], transition: ContainedViewLayoutTransition) {
        if self.currentColor == nil || !color.isEqual(self.currentColor) {
            self.currentColor = color
            for (title, nodeAndSize) in self.titleNodes {
                nodeAndSize.node.attributedText = NSAttributedString(string: title, font: titleFont, textColor: color)
                let _ = nodeAndSize.node.updateLayout(CGSize(width: 100.0, height: 100.0))
            }
        }
        
        if self.currentSize == size && self.currentSections == sections {
            return
        }
        
        self.currentSize = size
        self.currentSections = sections
        
        let itemHeight: CGFloat = 15.0
        let verticalInset: CGFloat = 10.0
        let maxHeight = size.height - verticalInset * 2.0
        
        let maxItemCount = min(sections.count, Int(floor(maxHeight / itemHeight)))
        let skipCount: Int
        if sections.isEmpty {
            skipCount = 1
        } else {
            skipCount = Int(ceil(CGFloat(sections.count) / CGFloat(maxItemCount)))
        }
        let actualCount: CGFloat = ceil(CGFloat(sections.count) / CGFloat(skipCount))
        
        let totalHeight = actualCount * itemHeight
        let verticalOrigin = verticalInset + floor((maxHeight - totalHeight) / 2.0)
        
        var validTitles = Set<String>()
        
        var currentIndex = 0
        var displayIndex = 0
        var addedLastTitle = false
        
        let addTitle: (Int) -> Void = { index in
            let title = sections[index]
            let nodeAndSize: (node: ImmediateTextNode, size: CGSize)
            var animate = false
            if let current = self.titleNodes[title] {
                animate = true
                nodeAndSize = current
            } else {
                let node = ImmediateTextNode()
                node.attributedText = NSAttributedString(string: title, font: titleFont, textColor: color)
                let nodeSize = node.updateLayout(CGSize(width: 100.0, height: 100.0))
                nodeAndSize = (node, nodeSize)
                self.addSubnode(node)
                self.titleNodes[title] = nodeAndSize
            }
            validTitles.insert(title)
            let previousPosition = nodeAndSize.node.position
            nodeAndSize.node.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - nodeAndSize.size.width) / 2.0), y: verticalOrigin + itemHeight * CGFloat(displayIndex) + floor((itemHeight - nodeAndSize.size.height) / 2.0)), size: nodeAndSize.size)
            if animate {
                transition.animatePosition(node: nodeAndSize.node, from: previousPosition)
            }
            
            currentIndex += skipCount
            displayIndex += 1
        }
        
        while currentIndex < sections.count {
            if currentIndex == sections.count - 1 {
                addedLastTitle = true
            }
            addTitle(currentIndex)
        }
        
        if !addedLastTitle && sections.count > 0 {
            addTitle(sections.count - 1)
        }
        
        var removeTitles: [String] = []
        for title in self.titleNodes.keys {
            if !validTitles.contains(title) {
                removeTitles.append(title)
            }
        }
        
        for title in removeTitles {
            self.titleNodes.removeValue(forKey: title)?.node.removeFromSupernode()
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.isUserInteractionEnabled, self.bounds.insetBy(dx: -5.0, dy: 0.0).contains(point) {
            return self.view
        } else {
            return nil
        }
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        var locationTitleAndPosition: (String, CGFloat)?
        let location = recognizer.location(in: self.view)
        for (title, nodeAndSize) in self.titleNodes {
            let nodeFrame = nodeAndSize.node.frame
            if location.y >= nodeFrame.minY - 5.0 && location.y <= nodeFrame.maxY + 5.0 {
                if let currentTitleAndPosition = locationTitleAndPosition {
                    let distance = abs(nodeFrame.midY - location.y)
                    let previousDistance = abs(currentTitleAndPosition.1 - location.y)
                    if distance < previousDistance {
                        locationTitleAndPosition = (title, nodeFrame.midY)
                    }
                } else {
                    locationTitleAndPosition = (title, nodeFrame.midY)
                }
            }
        }
        let locationTitle = locationTitleAndPosition?.0
        switch recognizer.state {
            case .began:
                self.currentSelectedIndex = locationTitle
                if let locationTitle = locationTitle {
                    self.indexSelected?(locationTitle)
                }
            case .changed:
                if locationTitle != self.currentSelectedIndex {
                    self.currentSelectedIndex = locationTitle
                    if let locationTitle = locationTitle {
                        self.indexSelected?(locationTitle)
                        
                        if self.scrollFeedback == nil {
                            self.scrollFeedback = HapticFeedback()
                        }
                        self.scrollFeedback?.tap()
                    }
                }
            case .cancelled, .ended:
                self.currentSelectedIndex = nil
            default:
                break
        }
    }
}
