import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import AsyncDisplayKit
import Display
import TelegramPresentationData

private func findScrollView(view: UIView?) -> UIScrollView? {
    if let view = view {
        if let view = view as? UIScrollView {
            return view
        }
        return findScrollView(view: view.superview)
    } else {
        return nil
    }
}

private func cancelScrollViewGestures(view: UIView?) {
    if let view = view {
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if let recognizer = recognizer as? UIPanGestureRecognizer {
                    switch recognizer.state {
                    case .began, .possible:
                        recognizer.state = .ended
                    default:
                        break
                    }
                }
            }
        }
        cancelScrollViewGestures(view: view.superview)
    }
}

private func generateKnobImage(color: UIColor, diameter: CGFloat, inverted: Bool = false) -> UIImage? {
    let f: (CGSize, CGContext) -> Void = { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(x: (size.width - 2.0) / 2.0, y: size.width / 2.0), size: CGSize(width: 2.0, height: size.height - size.width / 2.0 - 1.0)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: floor((size.width - diameter) / 2.0), y: floor((size.width - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: (size.width - 2.0) / 2.0, y: size.width + 2.0), size: CGSize(width: 2.0, height: 2.0)))
    }
    let size = CGSize(width: 12.0, height: 12.0 + 2.0 + 2.0)
    if inverted {
        return generateImage(size, contextGenerator: f)?.stretchableImage(withLeftCapWidth: Int(size.width / 2.0), topCapHeight: Int(size.height) - (Int(size.width) + 1))
    } else {
        return generateImage(size, rotatedContext: f)?.stretchableImage(withLeftCapWidth: Int(size.width / 2.0), topCapHeight: Int(size.width) + 1)
    }
}

public final class InstantPageTextSelectionTheme {
    public let selection: UIColor
    public let knob: UIColor
    public let knobDiameter: CGFloat
    
    public init(selection: UIColor, knob: UIColor, knobDiameter: CGFloat = 12.0) {
        self.selection = selection
        self.knob = knob
        self.knobDiameter = knobDiameter
    }
}

private enum Knob {
    case left
    case right
}

private final class InstantPageTextSelectionGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var longTapTimer: Timer?
    private var movingKnob: (Knob, CGPoint, CGPoint)?
    private var currentLocation: CGPoint?
    
    var beginSelection: ((CGPoint) -> Void)?
    var knobAtPoint: ((CGPoint) -> (Knob, CGPoint)?)?
    var moveKnob: ((Knob, CGPoint) -> Void)?
    var finishedMovingKnob: (() -> Void)?
    var clearSelection: (() -> Void)?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: nil, action: nil)
        
        self.delegate = self
    }
    
    override public func reset() {
        super.reset()
        
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        
        self.movingKnob = nil
        self.currentLocation = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let currentLocation = touches.first?.location(in: self.view)
        self.currentLocation = currentLocation
        
        if let currentLocation = currentLocation {
            if let (knob, knobPosition) = self.knobAtPoint?(currentLocation) {
                self.movingKnob = (knob, knobPosition, currentLocation)
                cancelScrollViewGestures(view: self.view?.superview)
                self.state = .began
            } else if self.longTapTimer == nil {
                final class TimerTarget: NSObject {
                    let f: () -> Void
                    
                    init(_ f: @escaping () -> Void) {
                        self.f = f
                    }
                    
                    @objc func event() {
                        self.f()
                    }
                }
                let longTapTimer = Timer(timeInterval: 0.3, target: TimerTarget({ [weak self] in
                    self?.longTapEvent()
                }), selector: #selector(TimerTarget.event), userInfo: nil, repeats: false)
                self.longTapTimer = longTapTimer
                RunLoop.main.add(longTapTimer, forMode: .common)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        let currentLocation = touches.first?.location(in: self.view)
        self.currentLocation = currentLocation
        
        if let (knob, initialKnobPosition, initialGesturePosition) = self.movingKnob, let currentLocation = currentLocation {
            self.moveKnob?(knob, CGPoint(x: initialKnobPosition.x + currentLocation.x - initialGesturePosition.x, y: initialKnobPosition.y + currentLocation.y - initialGesturePosition.y))
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let longTapTimer = self.longTapTimer {
            self.longTapTimer = nil
            longTapTimer.invalidate()
            self.clearSelection?()
        } else {
            if let _ = self.currentLocation, let _ = self.movingKnob {
                self.finishedMovingKnob?()
            }
        }
        self.state = .ended
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    private func longTapEvent() {
        if let currentLocation = self.currentLocation {
            self.beginSelection?(currentLocation)
            self.state = .ended
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }
    
    @available(iOS 9.0, *)
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        return true
    }
}

public final class InstantPageTextSelectionNodeView: UIView {
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.hitTestImpl?(point, event)
    }
}

public enum InstantPageTextSelectionAction {
    case copy
    case share
    case lookup
}

public struct InstantPageTextSelectionItem {
    let item: InstantPageTextItem
    let start: Int
    let end: Int
    
    var range: NSRange {
        return NSRange(location: self.start, length: self.end - self.start)
    }
}

public struct InstantPageTextSelection {
    let items: [InstantPageTextSelectionItem]
}

final class InstantPageTextSelectionNode: ASDisplayNode {
    private let theme: InstantPageTextSelectionTheme
    private let strings: PresentationStrings
    private let textItemAtLocation: (CGPoint) -> (InstantPageTextItem, CGPoint)?
    private let updateIsActive: (Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    private weak var rootNode: ASDisplayNode?
    private let performAction: (String, InstantPageTextSelectionAction) -> Void
    private var highlightOverlay: LinkHighlightingNode?
    private let leftKnob: ASImageNode
    private let rightKnob: ASImageNode
    
    private var currentSelection: InstantPageTextSelection?
    private var currentRects: [CGRect]?
    
    public let highlightAreaNode: ASDisplayNode
    
    private var recognizer: InstantPageTextSelectionGestureRecognizer?
    private var displayLinkAnimator: DisplayLinkAnimator?
    
    public init(theme: InstantPageTextSelectionTheme, strings: PresentationStrings, textItemAtLocation: @escaping (CGPoint) -> (InstantPageTextItem, CGPoint)?, updateIsActive: @escaping (Bool) -> Void, present: @escaping (ViewController, Any?) -> Void, rootNode: ASDisplayNode, performAction: @escaping (String, InstantPageTextSelectionAction) -> Void) {
        self.theme = theme
        self.strings = strings
        self.textItemAtLocation = textItemAtLocation
        self.updateIsActive = updateIsActive
        self.present = present
        self.rootNode = rootNode
        self.performAction = performAction
        self.leftKnob = ASImageNode()
        self.leftKnob.isUserInteractionEnabled = false
        self.leftKnob.image = generateKnobImage(color: theme.knob, diameter: theme.knobDiameter)
        self.leftKnob.displaysAsynchronously = false
        self.leftKnob.displayWithoutProcessing = true
        self.leftKnob.alpha = 0.0
        self.rightKnob = ASImageNode()
        self.rightKnob.isUserInteractionEnabled = false
        self.rightKnob.image = generateKnobImage(color: theme.knob, diameter: theme.knobDiameter, inverted: true)
        self.rightKnob.displaysAsynchronously = false
        self.rightKnob.displayWithoutProcessing = true
        self.rightKnob.alpha = 0.0
        
        self.highlightAreaNode = ASDisplayNode()
        
        super.init()
        
        self.setViewBlock({
            return InstantPageTextSelectionNodeView()
        })
        
        self.addSubnode(self.leftKnob)
        self.addSubnode(self.rightKnob)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        (self.view as? InstantPageTextSelectionNodeView)?.hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
       
        let recognizer = InstantPageTextSelectionGestureRecognizer(target: nil, action: nil)
        recognizer.knobAtPoint = { [weak self] point in
            return self?.knobAtPoint(point)
        }
        recognizer.moveKnob = { [weak self] knob, point in
            guard let strongSelf = self, let currentSelection = strongSelf.currentSelection, let currentItem = currentSelection.items.first else {
                return
            }
            
            if let (item, parentOffset) = strongSelf.textItemAtLocation(point) {
                let mappedPoint = point.offsetBy(dx: -item.frame.minX - parentOffset.x, dy: -item.frame.minY - parentOffset.y)
                if let stringIndex = item.attributesAtPoint(mappedPoint)?.0 {
                    var updatedLeft = currentItem.start
                    var updatedRight = currentItem.end
                    switch knob {
                        case .left:
                            updatedLeft = stringIndex
                        case .right:
                            updatedRight = stringIndex
                    }
                    if currentItem.start != updatedLeft || currentItem.end != updatedRight {
                        strongSelf.currentSelection = InstantPageTextSelection(items: [InstantPageTextSelectionItem(item: item, start: updatedLeft, end: updatedRight)])
                        strongSelf.updateSelection(selection: strongSelf.currentSelection, animateIn: false)
                    }
                    
                    if let scrollView = findScrollView(view: strongSelf.view) {
                        let scrollPoint = strongSelf.view.convert(point, to: scrollView)
                        scrollView.scrollRectToVisible(CGRect(origin: CGPoint(x: scrollPoint.x, y: scrollPoint.y - 30.0), size: CGSize(width: 1.0, height: 60.0)), animated: false)
                    }
                }
            }
        }
        recognizer.finishedMovingKnob = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.displayMenu()
        }
        recognizer.beginSelection = { [weak self] point in
            guard let strongSelf = self else {
                return
            }

            strongSelf.dismissSelection()

            if let (item, parentOffset) = strongSelf.textItemAtLocation(point) {
                let mappedPoint = point.offsetBy(dx: -item.frame.minX - parentOffset.x, dy: -item.frame.minY - parentOffset.y)
                var resultRange: NSRange?
                if let stringIndex = item.attributesAtPoint(mappedPoint)?.0 {
                    let string = item.attributedString.string as NSString
                    
                    let inputRange = CFRangeMake(0, string.length)
                    let flag = UInt(kCFStringTokenizerUnitWord)
                    let locale = CFLocaleCopyCurrent()
                    let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, string as CFString, inputRange, flag, locale)
                    var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
   
                    while !tokenType.isEmpty {
                        let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
                        if currentTokenRange.location <= stringIndex && currentTokenRange.location + currentTokenRange.length > stringIndex {
                            resultRange = NSRange(location: currentTokenRange.location, length: currentTokenRange.length)
                            break
                        }
                        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
                    }
                    
                    if resultRange == nil {
                        resultRange = NSRange(location: stringIndex, length: 1)
                    }
                }
                
                strongSelf.currentSelection = resultRange.flatMap {
                    InstantPageTextSelection(items: [InstantPageTextSelectionItem(item: item, start: $0.lowerBound, end: $0.upperBound)])
                }
            }
            strongSelf.updateSelection(selection: strongSelf.currentSelection, animateIn: true)
            strongSelf.displayMenu()
            strongSelf.updateIsActive(true)
        }
        recognizer.clearSelection = { [weak self] in
            self?.dismissSelection()
            self?.updateIsActive(false)
        }
        self.recognizer = recognizer
        self.view.addGestureRecognizer(recognizer)
    }
    
    public func updateLayout() {
        if let currentSelection = self.currentSelection {
            self.updateSelection(selection: currentSelection, animateIn: false)
        }
    }
        
    private func updateSelection(selection: InstantPageTextSelection?, animateIn: Bool) {
        var rects: (rects: [CGRect], start: InstantPageTextRangeRectEdge, end: InstantPageTextRangeRectEdge)?
        
        if let selection = selection, selection.items.count > 0 {
            var selectionRects: [CGRect] = []
            var start: InstantPageTextRangeRectEdge?
            var end: InstantPageTextRangeRectEdge?
            
            for i in 0 ..< selection.items.count {
                let item = selection.items[i]
                if let (itemRects, itemStart, itemEnd) = item.item.rangeRects(in: item.range) {
                    for rect in itemRects {
                        var rect = rect
                        rect = rect.insetBy(dx: 0.0, dy: -1.0)
                        selectionRects.append(rect.offsetBy(dx: item.item.frame.minX, dy: item.item.frame.minY))
                    }
                    if let itemStart = itemStart, i == 0 {
                        start = InstantPageTextRangeRectEdge(x: itemStart.x + item.item.frame.minX, y: itemStart.y + item.item.frame.minY, height: itemStart.height)
                    }
                    if let itemEnd = itemEnd, i == selection.items.count - 1 {
                        end = InstantPageTextRangeRectEdge(x: itemEnd.x + item.item.frame.minX, y: itemEnd.y + item.item.frame.minY, height: itemEnd.height)
                    }
                }
            }
            
            if let start = start, let end = end {
                rects = (rects: selectionRects, start: start, end: end)
            }
        }
        
        self.currentRects = rects?.rects
        
        if let (rects, startEdge, endEdge) = rects, !rects.isEmpty {
            let highlightOverlay: LinkHighlightingNode
            if let current = self.highlightOverlay {
                highlightOverlay = current
            } else {
                highlightOverlay = LinkHighlightingNode(color: self.theme.selection)
                highlightOverlay.isUserInteractionEnabled = false
                highlightOverlay.innerRadius = 0.0
                highlightOverlay.outerRadius = 0.0
                highlightOverlay.inset = 1.0
                self.highlightOverlay = highlightOverlay
                self.highlightAreaNode.addSubnode(highlightOverlay)
            }
            highlightOverlay.frame = self.bounds
            highlightOverlay.updateRects(rects)
            if let image = self.leftKnob.image {
                self.leftKnob.frame = CGRect(origin: CGPoint(x: floor(startEdge.x - image.size.width / 2.0), y: startEdge.y + 1.0 - 12.0), size: CGSize(width: image.size.width, height: self.theme.knobDiameter + startEdge.height + 2.0))
                self.rightKnob.frame = CGRect(origin: CGPoint(x: floor(endEdge.x + 1.0 - image.size.width / 2.0), y: endEdge.y + endEdge.height + 3.0 - (endEdge.height + 2.0)), size: CGSize(width: image.size.width, height: self.theme.knobDiameter + endEdge.height + 2.0))
            }
            if self.leftKnob.alpha.isZero {
                highlightOverlay.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                self.leftKnob.alpha = 1.0
                self.leftKnob.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.14, delay: 0.19)
                self.rightKnob.alpha = 1.0
                self.rightKnob.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.14, delay: 0.19)
                self.leftKnob.layer.animateSpring(from: 0.5 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.2, delay: 0.25, initialVelocity: 0.0, damping: 80.0)
                self.rightKnob.layer.animateSpring(from: 0.5 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.2, delay: 0.25, initialVelocity: 0.0, damping: 80.0)
                
                if animateIn {
                    var result = CGRect()
                    for rect in rects {
                        if result.isEmpty {
                            result = rect
                        } else {
                            result = result.union(rect)
                        }
                    }
                    highlightOverlay.layer.animateScale(from: 2.0, to: 1.0, duration: 0.26)
                    let fromResult = CGRect(origin: CGPoint(x: result.minX - result.width / 2.0, y: result.minY - result.height / 2.0), size: CGSize(width: result.width * 2.0, height: result.height * 2.0))
                    highlightOverlay.layer.animatePosition(from: CGPoint(x: (-fromResult.midX + highlightOverlay.bounds.midX) / 1.0, y: (-fromResult.midY + highlightOverlay.bounds.midY) / 1.0), to: CGPoint(), duration: 0.26, additive: true)
                }
            }
        } else if let highlightOverlay = self.highlightOverlay {
            self.highlightOverlay = nil
            highlightOverlay.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak highlightOverlay] _ in
                highlightOverlay?.removeFromSupernode()
            })
            self.leftKnob.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
            self.leftKnob.alpha = 0.0
            self.leftKnob.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18)
            self.rightKnob.alpha = 0.0
            self.rightKnob.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18)
        }
    }
    
    private func knobAtPoint(_ point: CGPoint) -> (Knob, CGPoint)? {
        if !self.leftKnob.alpha.isZero, self.leftKnob.frame.insetBy(dx: -4.0, dy: -8.0).contains(point) {
            return (.left, self.leftKnob.frame.offsetBy(dx: 0.0, dy: self.leftKnob.frame.width / 2.0).center)
        }
        if !self.rightKnob.alpha.isZero, self.rightKnob.frame.insetBy(dx: -4.0, dy: -8.0).contains(point) {
            return (.right, self.rightKnob.frame.offsetBy(dx: 0.0, dy: -self.rightKnob.frame.width / 2.0).center)
        }
        if !self.leftKnob.alpha.isZero, self.leftKnob.frame.insetBy(dx: -14.0, dy: -14.0).contains(point) {
            return (.left, self.leftKnob.frame.offsetBy(dx: 0.0, dy: self.leftKnob.frame.width / 2.0).center)
        }
        if !self.rightKnob.alpha.isZero, self.rightKnob.frame.insetBy(dx: -14.0, dy: -14.0).contains(point) {
            return (.right, self.rightKnob.frame.offsetBy(dx: 0.0, dy: -self.rightKnob.frame.width / 2.0).center)
        }
        return nil
    }
    
    private func dismissSelection() {
        self.currentSelection = nil
        self.updateSelection(selection: nil, animateIn: false)
    }
    
    private func displayMenu() {
//        guard let currentRects = self.currentRects, !currentRects.isEmpty, let currentRange = self.currentRange, let cachedLayout = self.textNode.cachedLayout, let attributedString = cachedLayout.attributedString else {
//            return
//        }
//        let range = NSRange(location: min(currentRange.0, currentRange.1), length: max(currentRange.0, currentRange.1) - min(currentRange.0, currentRange.1))
//        var completeRect = currentRects[0]
//        for i in 0 ..< currentRects.count {
//            completeRect = completeRect.union(currentRects[i])
//        }
//        completeRect = completeRect.insetBy(dx: 0.0, dy: -12.0)
//        
//        let text = (attributedString.string as NSString).substring(with: range)

        guard let currentRects = self.currentRects, !currentRects.isEmpty else {
            return
        }
                
        var completeRect = currentRects[0]
        for i in 0 ..< currentRects.count {
            completeRect = completeRect.union(currentRects[i])
        }
        completeRect = completeRect.insetBy(dx: 0.0, dy: -12.0)
        
        let text = "Text"
        
        var actions: [ContextMenuAction] = []
        actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.strings.Conversation_ContextMenuCopy), action: { [weak self] in
            self?.performAction(text, .copy)
            self?.dismissSelection()
        }))
        actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuLookUp, accessibilityLabel: self.strings.Conversation_ContextMenuLookUp), action: { [weak self] in
            self?.performAction(text, .lookup)
            self?.dismissSelection()
        }))
        actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuShare, accessibilityLabel: self.strings.Conversation_ContextMenuShare), action: { [weak self] in
            self?.performAction(text, .share)
            self?.dismissSelection()
        }))
        self.present(ContextMenuController(actions: actions, catchTapsOutside: false, hasHapticFeedback: false), ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
            guard let strongSelf = self, let rootNode = strongSelf.rootNode else {
                return nil
            }
            return (strongSelf, completeRect, rootNode, rootNode.bounds)
        }, bounce: false))
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.knobAtPoint(point) != nil {
            return self.view
        }
        if self.bounds.contains(point) {
            return self.view
        }
        return nil
    }
}
