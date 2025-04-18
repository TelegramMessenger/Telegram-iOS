import Foundation
import UIKit
import AsyncDisplayKit
import AppBundle
import AsyncDisplayKit
import Display

private final class ArrowNode: HighlightTrackingButtonNode {
    private let isLeft: Bool
    
    private let iconView: UIImageView
    private let separatorLayer: SimpleLayer
    var action: (() -> Void)?
    
    init(isLeft: Bool, isDark: Bool) {
        self.isLeft = isLeft
        
        self.iconView = UIImageView()
        self.iconView.image = UIImage(bundleImageName: "Chat/Context Menu/Arrow")!.withRenderingMode(.alwaysTemplate)
        if isLeft {
            self.iconView.transform = CGAffineTransformMakeScale(-1.0, 1.0)
        }
        
        self.separatorLayer = SimpleLayer()
        
        super.init()
        
        self.layer.addSublayer(self.separatorLayer)
        self.view.addSubview(self.iconView)
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if isDark {
                self.backgroundColor = highlighted ? UIColor(rgb: 0x8c8e8e) : nil
            } else {
                self.backgroundColor = highlighted ? UIColor(rgb: 0xDCE3DC) : nil
            }
        }
    }
    
    @objc private func pressed() {
        self.action?()
    }
    
    func update(color: UIColor, separatorColor: UIColor, height: CGFloat) -> CGSize {
        let size = CGSize(width: 33.0, height: height)
        
        self.iconView.tintColor = color
        if let icon = self.iconView.image {
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - icon.size.width) * 0.5), y: floor((size.height - icon.size.height) * 0.5)), size: icon.size)
            self.iconView.center = CGPoint(x: iconFrame.midX, y: iconFrame.midY)
            self.iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
        }
        
        self.separatorLayer.backgroundColor = separatorColor.cgColor
        self.separatorLayer.frame = CGRect(origin: CGPoint(x: self.isLeft ? (size.width - UIScreenPixel) : 0.0, y: 0.0), size: CGSize(width: UIScreenPixel, height: size.height))
        
        return size
    }
}

final class ContextMenuNode: ASDisplayNode {
    private let blurred: Bool
    private let isDark: Bool
    
    private let actions: [ContextMenuAction]
    private let dismiss: () -> Void
    private let dismissOnTap: (UIView, CGPoint) -> Bool
    
    private let containerNode: ContextMenuContainerNode
    private let contentNode: ASDisplayNode
    private var separatorNodes: [ASDisplayNode] = []
    private let actionNodes: [ContextMenuActionNode]
    private let pageLeftNode: ArrowNode
    private let pageRightNode: ArrowNode
    
    private var currentPageIndex: Int = 0
    private var pageCount: Int = 0
    
    private var validLayout: ContainerViewLayout?
    
    var sourceRect: CGRect?
    var containerRect: CGRect?
    var arrowOnBottom: Bool = true
    var centerHorizontally: Bool = false
    
    private var dismissedByTouchOutside = false
    private let catchTapsOutside: Bool
    
    private let feedback: HapticFeedback?
    
    init(actions: [ContextMenuAction], dismiss: @escaping () -> Void, dismissOnTap: @escaping (UIView, CGPoint) -> Bool, catchTapsOutside: Bool, hasHapticFeedback: Bool, blurred: Bool = false, isDark: Bool = true) {
        self.blurred = blurred
        self.isDark = isDark
        
        self.actions = actions
        self.dismiss = dismiss
        self.dismissOnTap = dismissOnTap
        self.catchTapsOutside = catchTapsOutside
        
        self.containerNode = ContextMenuContainerNode(isBlurred: blurred, isDark: isDark)
        self.contentNode = ASDisplayNode()
        self.contentNode.clipsToBounds = true
        
        self.actionNodes = actions.map { action in
            return ContextMenuActionNode(action: action, blurred: blurred, isDark: isDark)
        }
        
        self.pageLeftNode = ArrowNode(isLeft: true, isDark: isDark)
        self.pageRightNode = ArrowNode(isLeft: false, isDark: isDark)
        
        if hasHapticFeedback {
            self.feedback = HapticFeedback()
            self.feedback?.prepareImpact(.light)
        } else {
            self.feedback = nil
        }
        
        super.init()
        
        self.containerNode.containerNode.addSubnode(self.contentNode)
        
        self.addSubnode(self.containerNode)
        let dismissNode = {
            dismiss()
        }
        for actionNode in self.actionNodes {
            actionNode.dismiss = dismissNode
            self.contentNode.addSubnode(actionNode)
        }
        
        self.containerNode.containerNode.addSubnode(self.pageLeftNode)
        self.containerNode.containerNode.addSubnode(self.pageRightNode)
        
        let navigatePage: (Bool) -> Void = { [weak self] isLeft in
            guard let self else {
                return
            }
            var index = self.currentPageIndex
            if isLeft {
                index -= 1
            } else {
                index += 1
            }
            index = max(0, min(index, self.pageCount - 1))
            if self.currentPageIndex != index {
                self.currentPageIndex = index
                
                if let validLayout = self.validLayout {
                    self.containerLayoutUpdated(validLayout, transition: .animated(duration: 0.35, curve: .spring))
                }
            }
        }
        
        self.pageLeftNode.action = {
            navigatePage(true)
        }
        self.pageRightNode.action = {
            navigatePage(false)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        struct Page {
            var range: Range<Int>
            var width: CGFloat
            var offsetX: CGFloat
        }
        
        let separatorColor = self.isDark ? UIColor(rgb: 0x8c8e8e) : UIColor(rgb: 0xDCE3DC)
        
        var height: CGFloat = 54.0
        
        let handleWidth: CGFloat = 33.0
     
        let maxPageWidth = layout.size.width - 20.0 - handleWidth * 2.0
        var absoluteActionOffsetX: CGFloat = 0.0
        
        var pages: [Page] = []
        for i in 0 ..< self.actionNodes.count {
            if i != 0 {
                absoluteActionOffsetX += UIScreenPixel
            }
            let actionSize = self.actionNodes[i].measure(CGSize(width: layout.size.width, height: 100.0))
            height = max(height, actionSize.height)
            if pages.isEmpty || (pages[pages.count - 1].width + actionSize.width) > maxPageWidth {
                pages.append(Page(range: i ..< (i + 1), width: actionSize.width, offsetX: absoluteActionOffsetX))
            } else {
                pages[pages.count - 1].width += actionSize.width
            }
            let actionFrame = CGRect(origin: CGPoint(x: absoluteActionOffsetX, y: 0.0), size: actionSize)
            self.actionNodes[i].frame = actionFrame
            absoluteActionOffsetX += actionSize.width
            
            let separatorNode: ASDisplayNode
            if i < self.separatorNodes.count {
                separatorNode = self.separatorNodes[i]
            } else {
                separatorNode = ASDisplayNode()
                separatorNode.isUserInteractionEnabled = false
                self.separatorNodes.append(separatorNode)
                self.contentNode.insertSubnode(separatorNode, at: 0)
            }
            separatorNode.backgroundColor = separatorColor
            separatorNode.frame = CGRect(origin: CGPoint(x: actionFrame.maxX, y: 0.0), size: CGSize(width: UIScreenPixel, height: height))
            separatorNode.isHidden = i == self.actionNodes.count - 1
        }
        
        let pageLeftSize = self.pageLeftNode.update(color: self.isDark ? .white : .black, separatorColor: separatorColor, height: height)
        let pageRightSize = self.pageRightNode.update(color: self.isDark ? .white : .black, separatorColor: separatorColor, height: height)
        
        self.pageCount = pages.count
        
        if !pages.isEmpty {
            var leftInset: CGFloat = 0.0
            if self.currentPageIndex > 0 {
                leftInset = pageLeftSize.width
            }
            var rightInset: CGFloat = 0.0
            if self.currentPageIndex < pages.count - 1 {
                rightInset = pageLeftSize.width
            }
            
            let offsetX = -pages[self.currentPageIndex].offsetX
            
            let contentWidth = leftInset + rightInset + pages[self.currentPageIndex].width
            
            let contentNodeFrame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: pages[self.currentPageIndex].width, height: height))
            transition.updatePosition(node: self.contentNode, position: CGPoint(x: contentNodeFrame.midX, y: contentNodeFrame.midY))
            transition.updateBounds(node: self.contentNode, bounds: CGRect(origin: CGPoint(x: -offsetX, y: 0.0), size: contentNodeFrame.size))
            
            transition.updateFrame(node: self.pageLeftNode, frame: CGRect(origin: CGPoint(x: leftInset - pageLeftSize.width, y: 0.0), size: pageLeftSize))
            transition.updateFrame(node: self.pageRightNode, frame: CGRect(origin: CGPoint(x: contentWidth - rightInset, y: 0.0), size: pageRightSize))
            
            let sourceRect: CGRect = self.sourceRect ?? CGRect(origin: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0), size: CGSize())
            let containerRect: CGRect = self.containerRect ?? CGRect(origin: CGPoint(), size: layout.size)
            
            let insets = layout.insets(options: [.statusBar, .input])
            
            let verticalOrigin: CGFloat
            var arrowOnBottom = true
            if sourceRect.minY - height > containerRect.minY + insets.top {
                verticalOrigin = sourceRect.minY - height
            } else {
                verticalOrigin = min(containerRect.maxY - insets.bottom - height, sourceRect.maxY)
                arrowOnBottom = false
            }
            self.arrowOnBottom = arrowOnBottom
                    
            let horizontalOrigin: CGFloat = floor(max(8.0, min(self.centerHorizontally ? sourceRect.midX - contentWidth / 2.0 : max(sourceRect.minX + 8.0, sourceRect.midX - contentWidth / 2.0), layout.size.width - contentWidth - 8.0)))
            
            let containerFrame = CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin), size: CGSize(width: contentWidth, height: height))
            transition.updateFrame(node: self.containerNode, frame: containerFrame)
            self.containerNode.relativeArrowPosition = (sourceRect.midX - horizontalOrigin, arrowOnBottom)
            self.containerNode.updateLayout(transition: transition)
        }
    }
    
    func animateIn(bounce: Bool) {
        if bounce {
            self.containerNode.layer.animateSpring(from: NSNumber(value: Float(0.2)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.4)
            let containerPosition = self.containerNode.layer.position
            self.containerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: containerPosition.x, y: containerPosition.y + (self.arrowOnBottom ? 1.0 : -1.0) * self.containerNode.bounds.size.height / 2.0)), to: NSValue(cgPoint: containerPosition), keyPath: "position", duration: 0.4)
        }
        
        if !(self.blurred && self.isDark) {
            self.allowsGroupOpacity = true
            self.layer.rasterizationScale = UIScreen.main.scale
            self.layer.shouldRasterize = true
        }
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { [weak self] _ in
            self?.allowsGroupOpacity = false
            self?.layer.shouldRasterize = false
        })
        
        if let feedback = self.feedback {
            feedback.impact(.light)
        }
    }
    
    func animateOut(bounce: Bool, completion: @escaping () -> Void) {
        if !(self.blurred && self.isDark) {
            self.allowsGroupOpacity = true
            self.layer.rasterizationScale = UIScreen.main.scale
            self.layer.shouldRasterize = true
        }
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?.allowsGroupOpacity = false
            self?.layer.shouldRasterize = false
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event = event {
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                if !self.containerNode.frame.contains(point) {
                    if self.dismissOnTap(self.view, point) {
                        self.dismiss()
                        if self.catchTapsOutside {
                            return self.view
                        } else {
                            return nil
                        }
                    }
                    if !self.dismissedByTouchOutside {
                        self.dismissedByTouchOutside = true
                        self.dismiss()
                    }
                    if self.catchTapsOutside {
                        return self.view
                    }
                    return nil
                }
            }
        }
        return super.hitTest(point, with: event)
    }
}
