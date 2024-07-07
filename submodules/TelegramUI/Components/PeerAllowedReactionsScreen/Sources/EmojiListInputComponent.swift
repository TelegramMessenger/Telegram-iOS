import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import SwitchComponent
import EntityKeyboard
import AccountContext
import HierarchyTrackingLayer

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

final class EmojiListInputComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let placeholder: String
    let reactionItems: [EmojiComponentReactionItem]
    let isInputActive: Bool
    let caretPosition: Int
    let activateInput: () -> Void
    let setCaretPosition: (Int) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        placeholder: String,
        reactionItems: [EmojiComponentReactionItem],
        isInputActive: Bool,
        caretPosition: Int,
        activateInput: @escaping () -> Void,
        setCaretPosition: @escaping (Int) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.placeholder = placeholder
        self.reactionItems = reactionItems
        self.isInputActive = isInputActive
        self.caretPosition = caretPosition
        self.activateInput = activateInput
        self.setCaretPosition = setCaretPosition
    }
    
    static func ==(lhs: EmojiListInputComponent, rhs: EmojiListInputComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
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
        return true
    }
    
    final class View: UIView {
        private var component: EmojiListInputComponent?
        private weak var state: EmptyComponentState?
        
        private var itemLayers: [Int64: EmojiKeyboardItemLayer] = [:]
        private let trailingPlaceholder = ComponentView<Empty>()
        private let caretIndicator: CaretIndicatorView
        
        override init(frame: CGRect) {
            self.caretIndicator = CaretIndicatorView(frame: CGRect())
            self.caretIndicator.image = generateImage(CGSize(width: 2.0, height: 4.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: size.width * 0.5).cgPath)
                context.fillPath()
            })?.stretchableImage(withLeftCapWidth: 1, topCapHeight: 2).withRenderingMode(.alwaysTemplate)
            
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
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
            self.layer.cornerRadius = 12.0
            
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
            self.caretIndicator.isHidden = !component.isInputActive
            
            var caretFrame = CGRect(origin: CGPoint(x: trailingPlaceholderFrame.minX, y: trailingPlaceholderFrame.minY + floorToScreenPixels((trailingPlaceholderFrame.height - 22.0) * 0.5)), size: CGSize(width: 2.0, height: 22.0))
            
            var validIds: [Int64] = []
            for i in 0 ..< component.reactionItems.count {
                let item = component.reactionItems[i]
                let itemKey = item.file.fileId.id
                validIds.append(itemKey)
                
                let itemFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i % itemsPerRow) * (itemSize + itemSpacing), y: verticalInset + CGFloat(i / itemsPerRow) * (itemSize + itemSpacing)), size: CGSize(width: itemSize, height: itemSize))
                
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
                    self.layer.addSublayer(itemLayer)
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
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
