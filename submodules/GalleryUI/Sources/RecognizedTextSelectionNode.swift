import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ImageContentAnalysis

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

private func generateSelectionsImage(size: CGSize, rects: [RecognizedContent.Rect], color: UIColor) -> UIImage? {
    return generateImage(size, opaque: false, rotatedContext: { size, c in
        let bounds = CGRect(origin: CGPoint(), size: size)
        c.clear(bounds)
        
        c.setFillColor(color.cgColor)
        for rect in rects {
            let path = UIBezierPath(rect: rect, radius: 2.5)
            c.addPath(path.cgPath)
            c.fillPath()
        }
    })
}

public final class RecognizedTextSelectionTheme {
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

private final class RecognizedTextSelectionGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
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

public final class RecognizedTextSelectionNodeView: UIView {
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.hitTestImpl?(point, event)
    }
}

public enum RecognizedTextSelectionAction {
    case copy
    case share
    case lookup
    case speak
    case translate
}

public final class RecognizedTextSelectionNode: ASDisplayNode {
    private let size: CGSize
    private let theme: RecognizedTextSelectionTheme
    private let strings: PresentationStrings
    private let recognitions: [(string: String, rect: RecognizedContent.Rect)]
    private let updateIsActive: (Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    private weak var rootNode: ASDisplayNode?
    private let performAction: (String, RecognizedTextSelectionAction) -> Void
    private var highlightOverlay: ASImageNode?
    private let leftKnob: ASImageNode
    private let rightKnob: ASImageNode
    
    private var selectedIndices: Set<Int>?
    private var currentRects: [RecognizedContent.Rect]?
    private var currentTopLeft: CGPoint?
    private var currentBottomRight: CGPoint?
    
    public let highlightAreaNode: ASDisplayNode
    
    private var recognizer: RecognizedTextSelectionGestureRecognizer?
    
    public init(size: CGSize, theme: RecognizedTextSelectionTheme, strings: PresentationStrings, recognitions: [RecognizedContent], updateIsActive: @escaping (Bool) -> Void, present: @escaping (ViewController, Any?) -> Void, rootNode: ASDisplayNode, performAction: @escaping (String, RecognizedTextSelectionAction) -> Void) {
        self.size = size
        self.theme = theme
        self.strings = strings
        
        let sortedRecognitions = recognitions.sorted(by: { lhs, rhs in
            if abs(lhs.rect.leftMidPoint.y - rhs.rect.rightMidPoint.y) < min(lhs.rect.leftHeight, rhs.rect.leftHeight) / 2.0  {
                return lhs.rect.leftMidPoint.x < rhs.rect.leftMidPoint.x
            } else {
                return lhs.rect.leftMidPoint.y > rhs.rect.leftMidPoint.y
            }
        })
        var textRecognitions: [(String, RecognizedContent.Rect)] = []
        for recognition in sortedRecognitions {
            if case let .text(string, _) = recognition.content {
                textRecognitions.append((string, recognition.rect))
//                for word in words {
//                    textRecognitions.append((String(string[word.0]), word.1))
//                }
            }
        }
        self.recognitions = textRecognitions

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
            return RecognizedTextSelectionNodeView()
        })
        
        self.addSubnode(self.leftKnob)
        self.addSubnode(self.rightKnob)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        (self.view as? RecognizedTextSelectionNodeView)?.hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
       
        let recognizer = RecognizedTextSelectionGestureRecognizer(target: nil, action: nil)
        recognizer.knobAtPoint = { [weak self] point in
            return self?.knobAtPoint(point)
        }
        recognizer.moveKnob = { [weak self] knob, point in
            guard let strongSelf = self, let _ = strongSelf.selectedIndices, let currentTopLeft = strongSelf.currentTopLeft, let currentBottomRight = strongSelf.currentBottomRight else {
                return
            }
            
            let topLeftPoint: CGPoint
            let bottomRightPoint: CGPoint
            switch knob {
                case .left:
                    topLeftPoint = point
                    bottomRightPoint = currentBottomRight
                case .right:
                    topLeftPoint = currentTopLeft
                    bottomRightPoint = point
            }
            
            let selectionRect = CGRect(x: min(topLeftPoint.x, bottomRightPoint.x), y: min(topLeftPoint.y, bottomRightPoint.y), width: max(bottomRightPoint.x, topLeftPoint.x) - min(bottomRightPoint.x, topLeftPoint.x), height: max(bottomRightPoint.y, topLeftPoint.y) - min(bottomRightPoint.y, topLeftPoint.y))
            
            var i = 0
            var selectedIndices: Set<Int>?
            for recognition in strongSelf.recognitions {
                let rect = recognition.rect.convertTo(size: strongSelf.size, insets: UIEdgeInsets(top: -4.0, left: -2.0, bottom: -4.0, right: -2.0))
                if selectionRect.intersects(rect.boundingFrame) {
                    if selectedIndices == nil {
                        selectedIndices = Set()
                    }
                    selectedIndices?.insert(i)
                }
                i += 1
            }
            
            strongSelf.selectedIndices = selectedIndices
            strongSelf.updateSelection(range: selectedIndices, animateIn: false)
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
            
            let _ = strongSelf.dismissSelection()
            
            var i = 0
            var selectedIndices: Set<Int>?
            var topLeft: CGPoint?
            var bottomRight: CGPoint?
            for recognition in strongSelf.recognitions {
                let rect = recognition.rect.convertTo(size: strongSelf.size, insets: UIEdgeInsets(top: -4.0, left: -2.0, bottom: -4.0, right: -2.0))
                if rect.boundingFrame.contains(point) {
                    topLeft = rect.topLeft
                    bottomRight = rect.bottomRight
                    selectedIndices = Set([i])
                    break
                }
                i += 1
            }
            strongSelf.selectedIndices = selectedIndices
            strongSelf.currentTopLeft = topLeft
            strongSelf.currentBottomRight = bottomRight
            strongSelf.updateSelection(range: selectedIndices, animateIn: true)

            strongSelf.displayMenu()
            strongSelf.updateIsActive(true)
        }
        recognizer.clearSelection = { [weak self] in
            let _ = self?.dismissSelection()
            self?.updateIsActive(false)
        }
        self.recognizer = recognizer
        self.view.addGestureRecognizer(recognizer)
    }
    
    public func updateLayout() {
        if let selectedIndices = self.selectedIndices {
            self.updateSelection(range: selectedIndices, animateIn: false)
        }
    }
    
    private func updateSelection(range: Set<Int>?, animateIn: Bool) {
        var rects: [RecognizedContent.Rect]? = nil
        var startEdge: (position: CGPoint, height: CGFloat)?
        var endEdge: (position: CGPoint, height: CGFloat)?
        
        if let range = range {
            var i = 0
            rects = []
            for recognition in self.recognitions {
                let rect = recognition.rect.convertTo(size: self.size)
                if range.contains(i) {
                    if startEdge == nil {
                        startEdge = (rect.leftMidPoint, rect.leftHeight)
                    }
                    rects?.append(rect)
                }
                i += 1
            }
            
            if let rect = rects?.last {
                endEdge = (rect.rightMidPoint, rect.rightHeight)
            }
        }

        self.currentRects = rects

        if let rects = rects, let startEdge = startEdge, let endEdge = endEdge, !rects.isEmpty {
            let highlightOverlay: ASImageNode
            if let current = self.highlightOverlay {
                highlightOverlay = current
            } else {
                highlightOverlay = ASImageNode()
                self.highlightOverlay = highlightOverlay
                self.highlightAreaNode.addSubnode(highlightOverlay)
            }
            highlightOverlay.frame = self.bounds
            highlightOverlay.image = generateSelectionsImage(size: self.size, rects: rects, color: self.theme.selection.withAlphaComponent(1.0))
            highlightOverlay.alpha = self.theme.selection.alpha
            
            if let image = self.leftKnob.image {
                self.leftKnob.frame = CGRect(origin: CGPoint(x: floor(startEdge.position.x - image.size.width / 2.0), y: startEdge.position.y - floorToScreenPixels(startEdge.height / 2.0) - self.theme.knobDiameter), size: CGSize(width: image.size.width, height: self.theme.knobDiameter + startEdge.height + 2.0))
                self.rightKnob.frame = CGRect(origin: CGPoint(x: floor(endEdge.position.x + 1.0 - image.size.width / 2.0), y: endEdge.position.y - floorToScreenPixels(endEdge.height / 2.0)), size: CGSize(width: image.size.width, height: self.theme.knobDiameter + endEdge.height + 2.0))
            }
            if self.leftKnob.alpha.isZero {
                highlightOverlay.layer.animateAlpha(from: 0.0, to: highlightOverlay.alpha, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
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
                            result = rect.boundingFrame
                        } else {
                            result = result.union(rect.boundingFrame)
                        }
                    }
                    highlightOverlay.layer.animateScale(from: 2.0, to: 1.0, duration: 0.26)
                    let fromResult = CGRect(origin: CGPoint(x: result.minX - result.width / 2.0, y: result.minY - result.height / 2.0), size: CGSize(width: result.width * 2.0, height: result.height * 2.0))
                    highlightOverlay.layer.animatePosition(from: CGPoint(x: (-fromResult.midX + highlightOverlay.bounds.midX) / 1.0, y: (-fromResult.midY + highlightOverlay.bounds.midY) / 1.0), to: CGPoint(), duration: 0.26, additive: true)
                }
            }
        } else if let highlightOverlay = self.highlightOverlay {
            self.highlightOverlay = nil
            highlightOverlay.layer.animateAlpha(from: highlightOverlay.alpha, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak highlightOverlay] _ in
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
    
    public func dismissSelection() -> Bool {
        if let _ = self.selectedIndices {
            self.selectedIndices = nil
            self.updateSelection(range: nil, animateIn: false)
            return true
        } else {
            return false
        }
    }
    
    private func displayMenu() {
        guard let currentRects = self.currentRects, !currentRects.isEmpty, let selectedIndices = self.selectedIndices else {
            return
        }
        
        var completeRect = currentRects[0].boundingFrame
        for i in 0 ..< currentRects.count {
            completeRect = completeRect.union(currentRects[i].boundingFrame)
        }
        completeRect = completeRect.insetBy(dx: 0.0, dy: -12.0)
        
        var selectedText = ""
        for i in 0 ..< self.recognitions.count {
            if selectedIndices.contains(i) {
                let (string, _) = self.recognitions[i]
                if !selectedText.isEmpty {
                    selectedText += "\n"
                }
                selectedText.append(contentsOf: string.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        var actions: [ContextMenuAction] = []
        actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.strings.Conversation_ContextMenuCopy), action: { [weak self] in
            self?.performAction(selectedText, .copy)
            let _ = self?.dismissSelection()
        }))
        actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuLookUp, accessibilityLabel: self.strings.Conversation_ContextMenuLookUp), action: { [weak self] in
            self?.performAction(selectedText, .lookup)
            let _ = self?.dismissSelection()
        }))
        if #available(iOS 15.0, *) {
            actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuTranslate, accessibilityLabel: self.strings.Conversation_ContextMenuTranslate), action: { [weak self] in
                self?.performAction(selectedText, .translate)
                let _ = self?.dismissSelection()
            }))
        }
//        if isSpeakSelectionEnabled() {
//            actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuSpeak, accessibilityLabel: self.strings.Conversation_ContextMenuSpeak), action: { [weak self] in
//                self?.performAction(selectedText, .speak)
//                let _ = self?.dismissSelection()
//            }))
//        }
        actions.append(ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuShare, accessibilityLabel: self.strings.Conversation_ContextMenuShare), action: { [weak self] in
            self?.performAction(selectedText, .share)
            let _ = self?.dismissSelection()
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
            for recognition in self.recognitions {
                let mappedRect = recognition.rect.convertTo(size: self.bounds.size)
                if mappedRect.boundingFrame.insetBy(dx: -20.0, dy: -20.0).contains(point) {
                    return self.view
                }
            }
            return nil
        }
        return nil
    }
}
