import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import SwitchComponent
import EntityKeyboard
import AccountContext
import HierarchyTrackingLayer
import TelegramCore
import TextSelectionNode

private final class CaretIndicatorView: UIImageView {
    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    override init(frame: CGRect) {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            self?.restartAnimations(delayStart: false)
        }
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    func restartAnimations(delayStart: Bool) {
        self.layer.removeAnimation(forKey: "caret")
        
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1.0 as NSNumber, 0.0 as NSNumber, 1.0 as NSNumber, 1.0 as NSNumber]
        let firstDuration = 0.3
        let secondDuration = 0.25
        let restDuration = 0.35
        let duration = firstDuration + secondDuration + restDuration
        let keyTimes: [NSNumber] = [0.0 as NSNumber, (firstDuration / duration) as NSNumber, ((firstDuration + secondDuration) / duration) as NSNumber, ((firstDuration + secondDuration + restDuration) / duration) as NSNumber]
        
        animation.keyTimes = keyTimes
        animation.duration = duration
        animation.repeatCount = Float.greatestFiniteMagnitude
        animation.fillMode = .both
        if delayStart {
            animation.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.8 * UIView.animationDurationFactor()
        }
        self.layer.add(animation, forKey: "caret")
    }
}

/// What `TextSelectionNode` selects in the reaction field: one character per reaction, laid out on the field's grid,
/// so the field selects, extends and deletes reactions the way a text view does with characters.
private final class EmojiListTextSelectionAdapter: ASDisplayNode, TextNodeProtocol {
    struct Layout: Equatable {
        var itemFrames: [CGRect]
        var itemsPerRow: Int
        var itemSpacing: CGFloat
    }
    
    private(set) var layout = Layout(itemFrames: [], itemsPerRow: 1, itemSpacing: 0.0)
    private var text = NSAttributedString()
    
    override init() {
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    func update(layout: Layout) {
        self.layout = layout
        self.text = NSAttributedString(string: String(repeating: "\u{FFFC}", count: layout.itemFrames.count))
    }
    
    var currentText: NSAttributedString? {
        return self.text
    }
    
    // The cell of an item: its frame extended by half the spacing, so the cells of a row and of adjacent rows meet.
    private func cellFrame(at index: Int) -> CGRect {
        return self.layout.itemFrames[index].insetBy(dx: -floor(self.layout.itemSpacing * 0.5), dy: -floor(self.layout.itemSpacing * 0.5))
    }
    
    // Without `orNearest`, the item under the point; with it, the item boundary nearest to the point (where a knob
    // lands), on the nearest row.
    func attributesAtPoint(_ point: CGPoint, orNearest: Bool) -> (Int, [NSAttributedString.Key: Any])? {
        let itemFrames = self.layout.itemFrames
        if itemFrames.isEmpty {
            return nil
        }
        if !orNearest {
            for i in 0 ..< itemFrames.count {
                if self.cellFrame(at: i).contains(point) {
                    return (i, [:])
                }
            }
            return nil
        }
        
        let itemsPerRow = max(1, self.layout.itemsPerRow)
        let rowCount = (itemFrames.count + itemsPerRow - 1) / itemsPerRow
        var row = 0
        var rowDistance = CGFloat.greatestFiniteMagnitude
        for i in 0 ..< rowCount {
            let distance = abs(self.cellFrame(at: i * itemsPerRow).midY - point.y)
            if distance < rowDistance {
                rowDistance = distance
                row = i
            }
        }
        let rowStart = row * itemsPerRow
        let rowEnd = min(itemFrames.count, rowStart + itemsPerRow)
        var index = rowEnd
        for i in rowStart ..< rowEnd {
            if point.x < itemFrames[i].midX {
                index = i
                break
            }
        }
        return (index, [:])
    }
    
    func textRangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)? {
        let itemFrames = self.layout.itemFrames
        let lowerBound = max(0, range.location)
        let upperBound = min(itemFrames.count, range.location + range.length)
        if lowerBound >= upperBound {
            return nil
        }
        
        let itemsPerRow = max(1, self.layout.itemsPerRow)
        var rects: [CGRect] = []
        var index = lowerBound
        while index < upperBound {
            let rowEnd = min(upperBound, (index / itemsPerRow + 1) * itemsPerRow)
            rects.append(self.cellFrame(at: index).union(self.cellFrame(at: rowEnd - 1)))
            index = rowEnd
        }
        
        let first = rects[0]
        let last = rects[rects.count - 1]
        return (rects, TextRangeRectEdge(x: first.minX, y: first.minY, height: first.height), TextRangeRectEdge(x: last.maxX, y: last.minY, height: last.height))
    }
}

final class EmojiListInputComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let placeholder: String
    let reactionItems: [EmojiComponentReactionItem]
    let isInputActive: Bool
    let caretPosition: Int
    let selectedRange: NSRange?
    let activateInput: () -> Void
    let setCaretPosition: (Int) -> Void
    let updateSelectedRange: (NSRange?) -> Void
    let deleteRange: (NSRange) -> Void
    let present: (ViewController, Any?) -> Void
    let rootView: () -> UIView?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        placeholder: String,
        reactionItems: [EmojiComponentReactionItem],
        isInputActive: Bool,
        caretPosition: Int,
        selectedRange: NSRange?,
        activateInput: @escaping () -> Void,
        setCaretPosition: @escaping (Int) -> Void,
        updateSelectedRange: @escaping (NSRange?) -> Void,
        deleteRange: @escaping (NSRange) -> Void,
        present: @escaping (ViewController, Any?) -> Void,
        rootView: @escaping () -> UIView?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.placeholder = placeholder
        self.reactionItems = reactionItems
        self.isInputActive = isInputActive
        self.caretPosition = caretPosition
        self.selectedRange = selectedRange
        self.activateInput = activateInput
        self.setCaretPosition = setCaretPosition
        self.updateSelectedRange = updateSelectedRange
        self.deleteRange = deleteRange
        self.present = present
        self.rootView = rootView
    }
    
    static func ==(lhs: EmojiListInputComponent, rhs: EmojiListInputComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.reactionItems != rhs.reactionItems {
            return false
        }
        if lhs.isInputActive != rhs.isInputActive {
            return false
        }
        if lhs.caretPosition != rhs.caretPosition {
            return false
        }
        if lhs.selectedRange != rhs.selectedRange {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        private var component: EmojiListInputComponent?
        private weak var state: EmptyComponentState?
        
        private var itemLayers: [Int64: EmojiKeyboardItemLayer] = [:]
        private let trailingPlaceholder = ComponentView<Empty>()
        private let caretIndicator: CaretIndicatorView
        
        private let textSelectionAdapter: EmojiListTextSelectionAdapter
        private var textSelectionNode: TextSelectionNode?
        private var textSelectionTheme: PresentationTheme?
        // Set when the current touch began or changed the selection (a long press, a knob drag): its touch-up is
        // not a tap.
        private var selectionChangedDuringTouch: Bool = false
        
        override init(frame: CGRect) {
            self.caretIndicator = CaretIndicatorView(frame: CGRect())
            self.caretIndicator.image = generateImage(CGSize(width: 2.0, height: 4.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: size.width * 0.5).cgPath)
                context.fillPath()
            })?.stretchableImage(withLeftCapWidth: 1, topCapHeight: 2).withRenderingMode(.alwaysTemplate)
            
            self.textSelectionAdapter = EmojiListTextSelectionAdapter()
            
            super.init(frame: frame)
            
            self.addSubview(self.textSelectionAdapter.view)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            tapRecognizer.delegate = self
            self.addGestureRecognizer(tapRecognizer)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            self.selectionChangedDuringTouch = false
            return true
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return !self.selectionChangedDuringTouch
        }
        
        // A tap both places the caret and ends the selection (the selection recognizer's own tap); a touch that
        // drags a knob is the selection's alone.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if otherGestureRecognizer is TextSelectionGestureRecognizer {
                switch otherGestureRecognizer.state {
                case .began, .changed:
                    return false
                default:
                    return true
                }
            }
            return false
        }
        
        // The knobs reach past the field's top and bottom edges.
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let textSelectionNode = self.textSelectionNode, !self.bounds.contains(point), let result = textSelectionNode.view.hitTest(self.convert(point, to: textSelectionNode.view), with: event) {
                return result
            }
            return super.hitTest(point, with: event)
        }
        
        private func updateTextSelection(component: EmojiListInputComponent) {
            if self.textSelectionTheme !== component.theme, let textSelectionNode = self.textSelectionNode {
                textSelectionNode.cancelSelection()
                self.textSelectionNode = nil
                textSelectionNode.highlightAreaNode.view.removeFromSuperview()
                textSelectionNode.view.removeFromSuperview()
            }
            
            let textSelectionNode: TextSelectionNode
            if let current = self.textSelectionNode {
                textSelectionNode = current
            } else {
                textSelectionNode = TextSelectionNode(
                    theme: TextSelectionTheme(selection: component.theme.list.itemAccentColor.withMultipliedAlpha(0.2), knob: component.theme.list.itemAccentColor, isDark: component.theme.overallDarkAppearance),
                    strings: component.strings,
                    textNodeOrView: .node(self.textSelectionAdapter),
                    updateIsActive: { _ in },
                    present: { [weak self] c, a in
                        self?.component?.present(c, a)
                    },
                    rootView: { [weak self] in
                        return self?.component?.rootView()
                    },
                    performAction: { _, _ in }
                )
                textSelectionNode.enableCopy = false
                textSelectionNode.enableLookup = false
                textSelectionNode.enableTranslate = false
                textSelectionNode.enableShare = false
                textSelectionNode.canBeginSelection = { [weak self] point in
                    guard let self, let textSelectionNode = self.textSelectionNode else {
                        return false
                    }
                    return self.textSelectionAdapter.attributesAtPoint(textSelectionNode.view.convert(point, to: self.textSelectionAdapter.view), orNearest: false) != nil
                }
                textSelectionNode.updateRange = { [weak self] range in
                    guard let self else {
                        return
                    }
                    if range != nil {
                        self.selectionChangedDuringTouch = true
                    }
                    self.component?.updateSelectedRange(range)
                }
                textSelectionNode.performDelete = { [weak self] range in
                    self?.component?.deleteRange(range)
                }
                self.textSelectionNode = textSelectionNode
                self.textSelectionTheme = component.theme
                
                self.insertSubview(textSelectionNode.highlightAreaNode.view, at: 0)
                self.addSubview(textSelectionNode.view)
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            
            if case .ended = recognizer.state {
                let point = recognizer.location(in: self)
                
                var tapOnItem = false
                for (itemId, itemLayer) in self.itemLayers {
                    if itemLayer.frame.insetBy(dx: -6.0, dy: -6.0).contains(point) {
                        if let itemIndex = component.reactionItems.firstIndex(where: { $0.file.fileId.id == itemId }) {
                            var caretPosition = point.x >= itemLayer.frame.midX ? (itemIndex + 1) : itemIndex
                            caretPosition = max(0, min(component.reactionItems.count, caretPosition))
                            component.setCaretPosition(caretPosition)
                            component.activateInput()
                        }
                        tapOnItem = true
                        break
                    }
                }
                
                if !tapOnItem {
                    component.setCaretPosition(component.reactionItems.count)
                    component.activateInput()
                }
            }
        }
        
        // VoiceOver: the field is one element. It reads the reactions it shows (each as its emoji) and, empty, its
        // placeholder; activation opens the emoji input with the caret at the end, as a tap past the last item does.
        // The reactions are layers and were not read at all; the placeholder text was read on its own.
        override var isAccessibilityElement: Bool {
            get {
                return self.component != nil
            } set(value) {
            }
        }
        
        override var accessibilityLabel: String? {
            get {
                return self.component?.placeholder
            } set(value) {
            }
        }
        
        override var accessibilityValue: String? {
            get {
                guard let component = self.component else {
                    return nil
                }
                let emojis: [String] = component.reactionItems.compactMap { item -> String? in
                    if case let .builtin(value) = item.reaction {
                        return value
                    }
                    if let alt = item.file.customEmojiAlt, !alt.isEmpty {
                        return alt
                    }
                    return nil
                }
                return emojis.isEmpty ? nil : emojis.joined(separator: " ")
            } set(value) {
            }
        }
        
        override var accessibilityTraits: UIAccessibilityTraits {
            get {
                return .button
            } set(value) {
            }
        }
        
        override func accessibilityActivate() -> Bool {
            guard let component = self.component else {
                return false
            }
            component.setCaretPosition(component.reactionItems.count)
            component.activateInput()
            return true
        }
        
        func caretRect() -> CGRect? {
            if !self.caretIndicator.isHidden {
                return self.caretIndicator.frame
            } else {
                return nil
            }
        }
        
        func update(component: EmojiListInputComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let verticalInset: CGFloat = 12.0
            let placeholderSpacing: CGFloat = 6.0
            
            let minItemSize: CGFloat = 24.0
            let itemSpacingFactor: CGFloat = 0.15
            let minSideInset: CGFloat = 12.0
            
            self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            self.layer.cornerRadius = 26.0
            
            let maxItemsWidth = availableSize.width - minSideInset * 2.0
            let itemsPerRow = Int(floor((maxItemsWidth + minItemSize * itemSpacingFactor) / (minItemSize + minItemSize * itemSpacingFactor)))
            let itemSizePlusSpacing = maxItemsWidth / CGFloat(itemsPerRow)
            let itemSize = floor(itemSizePlusSpacing * (1.0 - itemSpacingFactor))
            let itemSpacing = floor(itemSizePlusSpacing * itemSpacingFactor)
            let sideInset = floor((availableSize.width - (itemSize * CGFloat(itemsPerRow) + itemSpacing * CGFloat(itemsPerRow - 1))) * 0.5)
            
            var rowCount = (component.reactionItems.count + (itemsPerRow - 1)) / itemsPerRow
            rowCount = max(1, rowCount)
            
            if let previousComponent = self.component, (previousComponent.reactionItems.count != component.reactionItems.count || previousComponent.isInputActive != component.isInputActive) {
                self.caretIndicator.restartAnimations(delayStart: true)
            }
            
            self.component = component
            self.state = state
            
            let trailingPlaceholderSize = self.trailingPlaceholder.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.placeholder, font: Font.regular(17.0), color: component.theme.list.itemPlaceholderTextColor)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            
            var lastRowItemCount = component.reactionItems.count % itemsPerRow
            if lastRowItemCount == 0 && !component.reactionItems.isEmpty {
                lastRowItemCount = itemsPerRow
            }
            let trailingLineWidth = sideInset + CGFloat(lastRowItemCount) * (itemSize + itemSpacing) + placeholderSpacing
            
            var contentHeight: CGFloat = verticalInset * 2.0 + CGFloat(rowCount) * itemSize + CGFloat(max(0, rowCount - 1)) * itemSpacing
            let trailingPlaceholderFrame: CGRect
            if availableSize.width - sideInset - trailingLineWidth < trailingPlaceholderSize.width {
                contentHeight += itemSize + itemSpacing
                trailingPlaceholderFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset + CGFloat(rowCount) * (itemSize + itemSpacing) + floor((itemSize - trailingPlaceholderSize.height) * 0.5)), size: trailingPlaceholderSize)
            } else {
                trailingPlaceholderFrame = CGRect(origin: CGPoint(x: trailingLineWidth, y: verticalInset + CGFloat(rowCount - 1) * (itemSize + itemSpacing) + floor((itemSize - trailingPlaceholderSize.height) * 0.5)), size: trailingPlaceholderSize)
            }
            
            if let trailingPlaceholderView = self.trailingPlaceholder.view {
                if trailingPlaceholderView.superview == nil {
                    trailingPlaceholderView.layer.anchorPoint = CGPoint()
                    self.addSubview(trailingPlaceholderView)
                    self.addSubview(self.caretIndicator)
                }
                transition.setPosition(view: trailingPlaceholderView, position: trailingPlaceholderFrame.origin)
                trailingPlaceholderView.bounds = CGRect(origin: CGPoint(), size: trailingPlaceholderFrame.size)
            }
            
            self.caretIndicator.tintColor = component.theme.list.itemAccentColor
            self.caretIndicator.isHidden = !component.isInputActive || component.selectedRange.flatMap({ $0.length != 0 }) == true
            
            var caretFrame = CGRect(origin: CGPoint(x: trailingPlaceholderFrame.minX, y: trailingPlaceholderFrame.minY + floorToScreenPixels((trailingPlaceholderFrame.height - 22.0) * 0.5)), size: CGSize(width: 2.0, height: 22.0))
            
            var itemFrames: [CGRect] = []
            var validIds: [Int64] = []
            for i in 0 ..< component.reactionItems.count {
                let item = component.reactionItems[i]
                let itemKey = item.file.fileId.id
                validIds.append(itemKey)
                
                let itemFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i % itemsPerRow) * (itemSize + itemSpacing), y: verticalInset + CGFloat(i / itemsPerRow) * (itemSize + itemSpacing)), size: CGSize(width: itemSize, height: itemSize))
                itemFrames.append(itemFrame)
                
                var itemTransition = transition
                var animateIn = false
                let itemLayer: EmojiKeyboardItemLayer
                if let current = self.itemLayers[itemKey] {
                    itemLayer = current
                } else {
                    itemTransition = .immediate
                    animateIn = true
                    
                    let animationData = EntityKeyboardAnimationData(
                        file: item.file
                    )
                    itemLayer = EmojiKeyboardItemLayer(
                        item: EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: item.file,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: item.file.isCustomTemplateEmoji ? .primary : .none
                        ),
                        context: component.context,
                        attemptSynchronousLoad: false,
                        content: EmojiPagerContentComponent.ItemContent.animation(animationData),
                        cache: component.context.animationCache,
                        renderer: component.context.animationRenderer,
                        placeholderColor: component.theme.list.mediaPlaceholderColor,
                        blurredBadgeColor: .clear,
                        accentIconColor: component.theme.list.itemPrimaryTextColor,
                        pointSize: CGSize(width: 32.0, height: 32.0),
                        onUpdateDisplayPlaceholder: { _, _ in
                        }
                    )
                    self.itemLayers[itemKey] = itemLayer
                    if let textSelectionNode = self.textSelectionNode {
                        self.layer.insertSublayer(itemLayer, below: textSelectionNode.view.layer)
                    } else {
                        self.layer.addSublayer(itemLayer)
                    }
                }
                itemLayer.isVisibleForAnimations = true
                
                switch itemLayer.item.tintMode {
                case .none:
                    itemLayer.layerTintColor = nil
                case .accent, .primary, .custom:
                    itemLayer.layerTintColor = component.theme.list.itemPrimaryTextColor.cgColor
                }
                
                itemTransition.setFrame(layer: itemLayer, frame: itemFrame)
                
                if component.caretPosition == i {
                    caretFrame = CGRect(origin: CGPoint(x: itemFrame.minX - 2.0, y: itemFrame.minY + floorToScreenPixels((itemFrame.height - 22.0) * 0.5)), size: CGSize(width: 2.0, height: 22.0))
                } else if i == component.reactionItems.count - 1 && component.caretPosition == i + 1 {
                    caretFrame = CGRect(origin: CGPoint(x: itemFrame.maxX + itemSpacing, y: itemFrame.minY + floorToScreenPixels((itemFrame.height - 22.0) * 0.5)), size: CGSize(width: 2.0, height: 22.0))
                }
                
                if animateIn, !transition.animation.isImmediate {
                    itemLayer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                    itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            
            var removedIds: [Int64] = []
            for (key, itemLayer) in self.itemLayers {
                if !validIds.contains(key) {
                    removedIds.append(key)
                    
                    if !transition.animation.isImmediate {
                        itemLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemLayer] _ in
                            itemLayer?.removeFromSuperlayer()
                        })
                        itemLayer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                    } else {
                        itemLayer.removeFromSuperlayer()
                    }
                }
            }
            for key in removedIds {
                self.itemLayers.removeValue(forKey: key)
            }
            
            let size = CGSize(width: availableSize.width, height: contentHeight)
            
            self.updateTextSelection(component: component)
            if let textSelectionNode = self.textSelectionNode {
                let selectionLayout = EmojiListTextSelectionAdapter.Layout(itemFrames: itemFrames, itemsPerRow: itemsPerRow, itemSpacing: itemSpacing)
                let layoutUpdated = self.textSelectionAdapter.layout != selectionLayout || self.textSelectionAdapter.frame.size != size
                self.textSelectionAdapter.update(layout: selectionLayout)
                self.textSelectionAdapter.frame = CGRect(origin: CGPoint(), size: size)
                textSelectionNode.frame = CGRect(origin: CGPoint(), size: size)
                textSelectionNode.highlightAreaNode.frame = CGRect(origin: CGPoint(), size: size)
                
                if component.selectedRange == nil {
                    if textSelectionNode.getSelection() != nil {
                        textSelectionNode.cancelSelection()
                    }
                } else if layoutUpdated {
                    textSelectionNode.updateLayout()
                }
            }
            
            if !transition.animation.isImmediate && abs(caretFrame.midY - self.caretIndicator.center.y) > 2.0 {
                if let caretSnapshot = self.caretIndicator.snapshotView(afterScreenUpdates: false) {
                    caretSnapshot.frame = self.caretIndicator.frame
                    self.insertSubview(caretSnapshot, aboveSubview: self.caretIndicator)
                    caretSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak caretSnapshot] _ in
                        caretSnapshot?.removeFromSuperview()
                    })
                    caretSnapshot.layer.animateScale(from: 1.0, to: 0.001, duration: 0.15, removeOnCompletion: false)
                }
                self.caretIndicator.frame = caretFrame
                self.caretIndicator.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                self.caretIndicator.layer.animateScale(from: 0.001, to: 1.0, duration: 0.15)
            } else {
                transition.setFrame(view: self.caretIndicator, frame: caretFrame)
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
