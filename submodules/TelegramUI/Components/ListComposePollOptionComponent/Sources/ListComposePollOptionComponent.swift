import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramCore
import CheckNode
import ListSectionComponent
import ComponentFlow
import TextFieldComponent
import AccountContext
import MultilineTextComponent
import PresentationDataUtils
import LottieComponent
import PlainButtonComponent
import BundleIconComponent
import SwiftSignalKit
import PhotoResources
import LocationResources
import RadialStatusNode
import EmojiTextAttachmentView
import TextFormat

public final class ListComposePollOptionComponent: Component {
    public enum Style {
        case glass
        case legacy
    }
    
    public final class ResetText: Equatable {
        public let value: NSAttributedString
        
        public init(value: NSAttributedString) {
            self.value = value
        }
        
        public static func ==(lhs: ResetText, rhs: ResetText) -> Bool {
            return lhs === rhs
        }
    }
    
    public final class Selection: Equatable {
        public let isSelected: Bool
        public let isMultiSelection: Bool
        public let isQuiz: Bool
        public let toggle: () -> Void
        
        public init(isSelected: Bool, isMultiSelection: Bool = false, isQuiz: Bool = false, toggle: @escaping () -> Void) {
            self.isSelected = isSelected
            self.isMultiSelection = isMultiSelection
            self.isQuiz = isQuiz
            self.toggle = toggle
        }
        
        public static func ==(lhs: Selection, rhs: Selection) -> Bool {
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            if lhs.isMultiSelection != rhs.isMultiSelection {
                return false
            }
            if lhs.isQuiz != rhs.isQuiz {
                return false
            }
            return true
        }
    }
    
    public final class Attachment: Equatable {
        public let media: AnyMediaReference?
        public let progress: CGFloat?
        public let alwaysDisplayAttachButton: Bool
        
        public init(media: AnyMediaReference?, progress: CGFloat?, alwaysDisplayAttachButton: Bool) {
            self.media = media
            self.progress = progress
            self.alwaysDisplayAttachButton = alwaysDisplayAttachButton
        }
        
        public static func ==(lhs: Attachment, rhs: Attachment) -> Bool {
            if lhs.media != rhs.media {
                return false
            }
            if lhs.progress != rhs.progress {
                return false
            }
            if lhs.alwaysDisplayAttachButton != rhs.alwaysDisplayAttachButton {
                return false
            }
            return true
        }
    }
    
    public enum InputMode {
        case keyboard
        case emoji
    }
    
    public final class EmojiSuggestion {
        public struct Position: Equatable {
            public var range: NSRange
            public var value: String
        }
        
        public var localPosition: CGPoint
        public var position: Position
        public var disposable: Disposable?
        public var value: Any?
        
        init(localPosition: CGPoint, position: Position) {
            self.localPosition = localPosition
            self.position = position
            self.disposable = nil
            self.value = nil
        }
    }
    
    public let externalState: TextFieldComponent.ExternalState?
    public let context: AccountContext
    public let style: Style
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let placeholder: NSAttributedString?
    public let isEnabled: Bool
    public let resetText: ResetText?
    public let assumeIsEditing: Bool
    public let characterLimit: Int?
    public let hasLeftInset: Bool
    public let enableInlineAnimations: Bool
    public let canReorder: Bool
    public let canAdd: Bool
    public let attachment: Attachment?
    public let emptyLineHandling: TextFieldComponent.EmptyLineHandling
    public let returnKeyType: UIReturnKeyType
    public let returnKeyAction: (() -> Void)?
    public let backspaceKeyAction: (() -> Void)?
    public let selection: Selection?
    public let inputMode: InputMode?
    public let alwaysDisplayInputModeSelector: Bool
    public let toggleInputMode: (() -> Void)?
    public let attachAction: (() -> Void)?
    public let deleteAction: (() -> Void)?
    public let paste: ((TextFieldComponent.PasteData) -> Void)?
    public let tag: AnyObject?
    
    public init(
        externalState: TextFieldComponent.ExternalState?,
        context: AccountContext,
        style: Style = .legacy,
        theme: PresentationTheme,
        strings: PresentationStrings,
        placeholder: NSAttributedString? = nil,
        isEnabled: Bool = true,
        resetText: ResetText? = nil,
        assumeIsEditing: Bool = false,
        characterLimit: Int,
        enableInlineAnimations: Bool = true,
        hasLeftInset: Bool = false,
        canReorder: Bool = false,
        canAdd: Bool = false,
        attachment: Attachment? = nil,
        emptyLineHandling: TextFieldComponent.EmptyLineHandling,
        returnKeyType: UIReturnKeyType = .next,
        returnKeyAction: (() -> Void)? = nil,
        backspaceKeyAction: (() -> Void)?,
        selection: Selection?,
        inputMode: InputMode?,
        alwaysDisplayInputModeSelector: Bool = false,
        toggleInputMode: (() -> Void)?,
        attachAction: (() -> Void)? = nil,
        deleteAction: (() -> Void)? = nil,
        paste: ((TextFieldComponent.PasteData) -> Void)? = nil,
        tag: AnyObject? = nil
    ) {
        self.externalState = externalState
        self.context = context
        self.style = style
        self.theme = theme
        self.strings = strings
        self.placeholder = placeholder
        self.isEnabled = isEnabled
        self.resetText = resetText
        self.assumeIsEditing = assumeIsEditing
        self.characterLimit = characterLimit
        self.enableInlineAnimations = enableInlineAnimations
        self.hasLeftInset = hasLeftInset
        self.canReorder = canReorder
        self.canAdd = canAdd
        self.attachment = attachment
        self.emptyLineHandling = emptyLineHandling
        self.returnKeyType = returnKeyType
        self.returnKeyAction = returnKeyAction
        self.backspaceKeyAction = backspaceKeyAction
        self.selection = selection
        self.inputMode = inputMode
        self.alwaysDisplayInputModeSelector = alwaysDisplayInputModeSelector
        self.toggleInputMode = toggleInputMode
        self.attachAction = attachAction
        self.deleteAction = deleteAction
        self.paste = paste
        self.tag = tag
    }
    
    public static func ==(lhs: ListComposePollOptionComponent, rhs: ListComposePollOptionComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.style != rhs.style {
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
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.resetText != rhs.resetText {
            return false
        }
        if lhs.assumeIsEditing != rhs.assumeIsEditing {
            return false
        }
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.enableInlineAnimations != rhs.enableInlineAnimations {
            return false
        }
        if lhs.hasLeftInset != rhs.hasLeftInset {
            return false
        }
        if lhs.canReorder != rhs.canReorder {
            return false
        }
        if lhs.canAdd != rhs.canAdd {
            return false
        }
        if lhs.attachment != rhs.attachment {
            return false
        }
        if lhs.emptyLineHandling != rhs.emptyLineHandling {
            return false
        }
        if lhs.returnKeyType != rhs.returnKeyType {
            return false
        }
        if lhs.selection != rhs.selection {
            return false
        }
        if lhs.inputMode != rhs.inputMode {
            return false
        }
        if lhs.alwaysDisplayInputModeSelector != rhs.alwaysDisplayInputModeSelector {
            return false
        }
        if (lhs.deleteAction == nil) != (rhs.deleteAction == nil) {
            return false
        }
        return true
    }
    
    private final class CheckView: HighlightTrackingButton {
        private var checkLayer: CheckLayer?
        private var theme: PresentationTheme?
        private var isRectangle = false
        private var isQuiz = false
        
        var action: (() -> Void)?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let animateScale = true
                    
                    let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                    
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.layer.removeAnimation(forKey: "transform.scale")
                        
                        if animateScale {
                            let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                            transition.setScale(layer: self.layer, scale: topScale)
                        }
                    } else {
                        if animateScale {
                            let transition = ComponentTransition(animation: .none)
                            transition.setScale(layer: self.layer, scale: 1.0)
                            
                            self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                            })
                        }
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.action?()
        }
        
        func update(size: CGSize, isRectangle: Bool, isQuiz: Bool, theme: PresentationTheme, isSelected: Bool, transition: ComponentTransition) {
            let checkLayer: CheckLayer
            if let current = self.checkLayer {
                checkLayer = current
            } else {
                checkLayer = CheckLayer(theme: CheckNodeTheme(theme: theme, style: .plain), content: .check(isRectangle: isRectangle))
                self.checkLayer = checkLayer
                self.layer.addSublayer(checkLayer)
            }
                        
            if self.theme !== theme || self.isQuiz != isQuiz {
                self.theme = theme
                self.isQuiz = isQuiz
                
                let checkTheme: CheckNodeTheme
                if isQuiz {
                    checkTheme = CheckNodeTheme(backgroundColor: theme.chat.message.incoming.polls.barPositive, strokeColor: theme.list.itemCheckColors.foregroundColor, borderColor: theme.list.itemCheckColors.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false)
                } else {
                    checkTheme = CheckNodeTheme(theme: theme, style: .plain)
                }
                checkLayer.theme = checkTheme
            }
            
            if self.isRectangle != isRectangle {
                self.isRectangle = isRectangle
                checkLayer.content = .check(isRectangle: isRectangle)
            }
            
            checkLayer.frame = CGRect(origin: CGPoint(), size: size)
            checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
        }
    }
    
    private final class DeleteRevealView: UIView {
        private let backgroundView: UIView
        
        private let _title: String
        private let title = ComponentView<Empty>()
        
        private var revealOffset: CGFloat = 0.0
                
        var currentSize = CGSize()
        
        var tapped: (Bool) -> Void = { _ in }
        
        init(title: String, color: UIColor) {
            self._title = title
            
            self.backgroundView = UIView()
            self.backgroundView.backgroundColor = color
            self.backgroundView.isUserInteractionEnabled = false
                
            super.init(frame: .zero)
                        
            self.clipsToBounds = true
            
            self.addSubview(self.backgroundView)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            self.addGestureRecognizer(tapRecognizer)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func handleTap(_ gestureRecignizer: UITapGestureRecognizer) {
            let location = gestureRecignizer.location(in: self)
            if self.backgroundView.frame.contains(location) {
                self.tapped(true)
            } else {
                self.tapped(false)
            }
        }
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if abs(self.revealOffset) < .ulpOfOne {
                return false
            }
            return super.point(inside: point, with: event)
        }
        
        func updateLayout(availableSize: CGSize, revealOffset: CGFloat, transition: ComponentTransition) -> CGSize {
            let previousRevealOffset = self.revealOffset
            self.revealOffset = revealOffset
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: self._title,
                                font: Font.regular(17.0),
                                textColor: .white
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let size = CGSize(width: max(74.0, titleSize.width + 20.0), height: availableSize.height)
            let previousRevealFactor = abs(previousRevealOffset) / size.width
            let revealFactor = abs(revealOffset) / size.width
            let backgroundWidth = size.width * max(1.0, abs(revealFactor))
            
            let previousIsExtended = previousRevealFactor >= 2.0
            let isExtended = revealFactor >= 2.0
            var titleTransition = transition
            if isExtended != previousIsExtended {
                titleTransition = .spring(duration: 0.3)
            }
                                                  
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.backgroundView.addSubview(titleView)
                }
                let titleFrame = CGRect(
                    origin: CGPoint(
                        x: revealFactor > 2.0 ? 10.0 : max(10.0, backgroundWidth - titleSize.width - 10.0),
                        y: floor((size.height - titleSize.height) / 2.0)
                    ),
                    size: titleSize
                )
                
                if titleTransition.animation.isImmediate && titleView.layer.animation(forKey: "position") != nil {   
                } else {
                    titleTransition.setFrame(view: titleView, frame: titleFrame)
                }
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: availableSize.width + revealOffset, y: 0.0), size: CGSize(width: backgroundWidth, height: size.height))
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            
            self.currentSize = size
            
            return size
        }
    }
    
    public final class View: UIView, ListSectionComponent.ChildView, ComponentTaggedView, UIGestureRecognizerDelegate {
        private let textField = ComponentView<Empty>()
        
        private var modeSelector: ComponentView<Empty>?
        private var reorderIconView: UIImageView?
        private var addIconView: UIImageView?
        
        private var attachButton: ComponentView<Empty>?
        private var imageNode: TransformImageNode?
        private var statusNode: RadialStatusNode?
        private var animationLayer: InlineStickerItemLayer?
        private var videoIconView: UIImageView?
        private let imageButton = HighlightTrackingButton()
        
        private var checkView: CheckView?
        
        private var deleteRevealView: DeleteRevealView?
        private var revealOffset: CGFloat = 0.0
        public private(set) var isRevealed: Bool = false
        
        private var recognizer: RevealOptionsGestureRecognizer?
        
        private var customPlaceholder: ComponentView<Empty>?
        
        private var appliedMedia: AnyMediaReference?
        
        private var component: ListComposePollOptionComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        public var currentText: String {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.inputState.inputText.string
            } else {
                return ""
            }
        }
        
        public var currentAttributedText: NSAttributedString {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.inputState.inputText
            } else {
                return NSAttributedString(string: "")
            }
        }
        
        public var textFieldView: TextFieldComponent.View? {
            return self.textField.view as? TextFieldComponent.View
        }
        
        public var currentTag: AnyObject? {
            return self.component?.tag
        }
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var enumerateSiblings: (((UIView) -> Void) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
                
        public override init(frame: CGRect) {
            super.init(frame: CGRect())
            
            self.imageButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.imageNode?.layer.removeAnimation(forKey: "opacity")
                    self.imageNode?.alpha = 0.4
                    
                    self.animationLayer?.removeAnimation(forKey: "opacity")
                    self.animationLayer?.opacity = 0.4
                } else {
                    self.imageNode?.alpha = 1.0
                    self.imageNode?.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    self.animationLayer?.opacity = 1.0
                    self.animationLayer?.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        public func activateInput() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.activateInput()
            }
        }
        
        public func insertText(text: NSAttributedString) {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.insertText(text)
            }
        }
        
        public func backwardsDeleteText() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.deleteBackward()
            }
        }
        
        override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let recognizer = self.recognizer, gestureRecognizer == self.recognizer, recognizer.numberOfTouches == 0 {
                let translation = recognizer.velocity(in: recognizer.view)
                if abs(translation.y) > 4.0 && abs(translation.y) > abs(translation.x) * 2.5 {
                    return false
                }
            }
            return true
        }
        
        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component, component.deleteAction != nil else {
                return
            }
            
            let translation = gestureRecognizer.translation(in: self)
            let velocity = gestureRecognizer.velocity(in: self)
            let revealWidth: CGFloat = self.deleteRevealView?.currentSize.width ?? 74.0
            
            switch gestureRecognizer.state {
            case .began:
                self.window?.endEditing(true)
                
                if self.isRevealed {
                    let location = gestureRecognizer.location(in: self)
                    if location.x > self.bounds.width - revealWidth {
                        gestureRecognizer.isEnabled = false
                        gestureRecognizer.isEnabled = true
                        return
                    }
                }
                
            case .changed:
                var offset = self.revealOffset + translation.x
                offset = max(-revealWidth * 6.0, min(0, offset))
                
                self.revealOffset = offset
                self.state?.updated()
                gestureRecognizer.setTranslation(CGPoint(), in: self)
                
            case .ended, .cancelled:
                var shouldReveal = false
                
                if abs(velocity.x) >= 100.0 {
                    shouldReveal = velocity.x < 0
                } else {
                    if self.revealOffset.isZero && self.revealOffset < 0 {
                        shouldReveal = self.revealOffset < -revealWidth * 0.5
                    } else if self.isRevealed {
                        shouldReveal = self.revealOffset < -revealWidth * 0.3
                    } else {
                        shouldReveal = self.revealOffset < -revealWidth * 0.5
                    }
                }
                
                let isExtendedSwipe = self.revealOffset < -revealWidth * 2.0

                if isExtendedSwipe && shouldReveal {
                    component.deleteAction?()
                    
                    self.isRevealed = false
                    let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                    self.revealOffset = 0.0
                    self.state?.updated(transition: transition)
                } else {
                    let targetOffset: CGFloat = shouldReveal ? -revealWidth : 0.0
                    self.isRevealed = shouldReveal
                    
                    let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                    self.revealOffset = targetOffset
                    self.state?.updated(transition: transition)
                }
            default:
                break
            }
        }
        
        @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard self.isRevealed else {
                return
            }
            
            let location = gestureRecognizer.location(in: self)
            if location.x >= self.bounds.width + self.revealOffset {
                self.component?.deleteAction?()
            }
        }
        
        @objc private func imageButtonPressed() {
            guard let component = self.component else {
                return
            }
            component.attachAction?()
        }
                
        func update(component: ListComposePollOptionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            var verticalInset: CGFloat = 12.0
            if case .glass = component.style {
                verticalInset = 16.0
            }
            var leftInset: CGFloat = 16.0
            var rightInset: CGFloat = 16.0
            let modeSelectorSize = CGSize(width: 32.0, height: 32.0)
            
            if component.hasLeftInset {
                leftInset += 46.0
            }
            
            if component.selection != nil {
                leftInset += 34.0
            }
            
            if component.inputMode != nil {
                rightInset += 34.0
            }
            
            if component.attachment != nil {
                rightInset += 28.0
            }
            
            let textFieldSize = self.textField.update(
                transition: transition,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    externalState: component.externalState ?? TextFieldComponent.ExternalState(),
                    fontSize: 17.0,
                    textColor: component.theme.list.itemPrimaryTextColor,
                    accentColor: component.theme.list.itemPrimaryTextColor,
                    insets: UIEdgeInsets(top: verticalInset, left: 8.0, bottom: verticalInset, right: 8.0),
                    hideKeyboard: component.inputMode == .emoji,
                    customInputView: nil,
                    placeholder: component.placeholder,
                    resetText: component.resetText.flatMap { resetText in
                        let result = NSMutableAttributedString(attributedString: resetText.value)
                        result.addAttributes([
                            .font: Font.regular(17.0),
                            .foregroundColor: component.theme.list.itemPrimaryTextColor
                        ], range: NSRange(location: 0, length: result.length))
                        return result
                    },
                    isOneLineWhenUnfocused: false,
                    characterLimit: component.characterLimit,
                    enableInlineAnimations: component.enableInlineAnimations,
                    emptyLineHandling: component.emptyLineHandling,
                    externalHandlingForMultilinePaste: true,
                    formatMenuAvailability: .none,
                    returnKeyType: component.returnKeyType,
                    lockedFormatAction: {
                    },
                    present: { _ in
                    },
                    paste: { [weak self] data in
                        guard let self, let component = self.component else {
                            return
                        }
                        if let paste = component.paste, case .text = data {
                            paste(data)
                        }
                    },
                    returnKeyAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.returnKeyAction?()
                    },
                    backspaceKeyAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.backspaceKeyAction?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset + 8.0 * 2.0, height: availableSize.height)
            )
            
            let size = CGSize(width: availableSize.width, height: textFieldSize.height - 1.0)
            
            var hasReorderIcon = false
            if component.canReorder, let externalState = component.externalState, externalState.hasText {
                var reorderIconTransition = transition
                let reorderIconView: UIImageView
                if let current = self.reorderIconView {
                    reorderIconView = current
                } else {
                    reorderIconTransition = reorderIconTransition.withAnimation(.none)
                    reorderIconView = UIImageView()
                    self.reorderIconView = reorderIconView
                    self.addSubview(reorderIconView)
                    
                    if !transition.animation.isImmediate {
                        transition.animateAlpha(view: reorderIconView, from: 0.0, to: 1.0)
                        transition.animateScale(view: reorderIconView, from: 0.001, to: 1.0)
                    }
                }
                reorderIconView.image = PresentationResourcesItemList.itemListReorderIndicatorIcon(component.theme)
                
                var reorderIconSize = CGSize()
                if let icon = reorderIconView.image {
                    reorderIconSize = icon.size
                }
                
                let reorderIconFrame = CGRect(origin: CGPoint(x: 22.0 + self.revealOffset, y: floor((size.height - reorderIconSize.height) * 0.5)), size: reorderIconSize)
                reorderIconTransition.setPosition(view: reorderIconView, position: reorderIconFrame.center)
                reorderIconTransition.setBounds(view: reorderIconView, bounds: CGRect(origin: CGPoint(), size: reorderIconFrame.size))
                
                hasReorderIcon = true
            } else if let reorderIconView = self.reorderIconView {
                self.reorderIconView = nil
                if !transition.animation.isImmediate {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    alphaTransition.setAlpha(view: reorderIconView, alpha: 0.0, completion: { [weak reorderIconView] _ in
                        reorderIconView?.removeFromSuperview()
                    })
                    alphaTransition.setScale(view: reorderIconView, scale: 0.001)
                } else {
                    reorderIconView.removeFromSuperview()
                }
            }
            
            if component.canAdd, !hasReorderIcon {
                var addIconTransition = transition
                let addIconView: UIImageView
                if let current = self.addIconView {
                    addIconView = current
                } else {
                    addIconTransition = addIconTransition.withAnimation(.none)
                    addIconView = UIImageView()
                    self.addIconView = addIconView
                    self.addSubview(addIconView)
                    
                    if !transition.animation.isImmediate {
                        transition.animateAlpha(view: addIconView, from: 0.0, to: 1.0)
                        transition.animateScale(view: addIconView, from: 0.001, to: 1.0)
                    }
                }
                addIconView.image = PresentationResourcesItemList.itemListAddIndicatorIcon(component.theme)
                
                var addIconSize = CGSize()
                if let icon = addIconView.image {
                    addIconSize = icon.size
                }
                
                let addIconFrame = CGRect(origin: CGPoint(x: 22.0 + self.revealOffset, y: floor((size.height - addIconSize.height) * 0.5)), size: addIconSize)
                addIconTransition.setPosition(view: addIconView, position: addIconFrame.center)
                addIconTransition.setBounds(view: addIconView, bounds: CGRect(origin: CGPoint(), size: addIconFrame.size))
            } else if let addIconView = self.addIconView {
                self.addIconView = nil
                if !transition.animation.isImmediate {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    alphaTransition.setAlpha(view: addIconView, alpha: 0.0, completion: { [weak addIconView] _ in
                        addIconView?.removeFromSuperview()
                    })
                    alphaTransition.setScale(view: addIconView, scale: 0.001)
                } else {
                    addIconView.removeFromSuperview()
                }
            }
            
            let textFieldFrame = CGRect(origin: CGPoint(x: leftInset - 16.0 + self.revealOffset, y: 0.0), size: textFieldSize)
            if let textFieldView = self.textField.view {
                if textFieldView.superview == nil {
                    self.addSubview(textFieldView)
                    self.textField.parentState = state
                }
                transition.setFrame(view: textFieldView, frame: textFieldFrame)
                
                transition.setAlpha(view: textFieldView, alpha: component.isEnabled ? 1.0 : 0.3)
                textFieldView.isUserInteractionEnabled = component.isEnabled
            }
            
            if let selection = component.selection {
                var checkTransition = transition
                let checkView: CheckView
                var animateIn = false
                if let current = self.checkView {
                    checkView = current
                } else {
                    checkTransition = .immediate
                    animateIn = true
                    checkView = CheckView()
                    self.checkView = checkView
                    self.addSubview(checkView)
                    
                    checkView.action = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.selection?.toggle()
                    }
                }
                let checkSize = CGSize(width: 22.0, height: 22.0)
                let checkFrame = CGRect(origin: CGPoint(x: leftInset - checkSize.width - 20.0 + self.revealOffset, y: floor((size.height - checkSize.height) * 0.5)), size: checkSize)
                
                checkTransition.setPosition(view: checkView, position: checkFrame.center)
                checkTransition.setBounds(view: checkView, bounds: CGRect(origin: CGPoint(), size: checkFrame.size))
                
                checkView.update(size: checkFrame.size, isRectangle: selection.isMultiSelection, isQuiz: selection.isQuiz, theme: component.theme, isSelected: selection.isSelected, transition: .immediate)
                
                if animateIn {
                    transition.animateAlpha(view: checkView, from: 0.0, to: 1.0)
                    transition.animateScale(view: checkView, from: 0.01, to: 1.0)
                }
            } else if let checkView = self.checkView {
                self.checkView = nil
                
                transition.setAlpha(view: checkView, alpha: 0.0, completion: { [weak checkView] _ in
                    checkView?.removeFromSuperview()
                })
                transition.setScale(view: checkView, scale: 0.01)
            }
                
            var rightIconsInset: CGFloat = 16.0
            let minHeight: CGFloat = 52.0
            
            if let attachment = component.attachment, attachment.alwaysDisplayAttachButton || component.externalState?.hasText == true {
                var attachButtonTransition = transition
                let attachButton: ComponentView<Empty>
                if let current = self.attachButton {
                    attachButton = current
                } else {
                    attachButtonTransition = attachButtonTransition.withAnimation(.none)
                    attachButton = ComponentView()
                    self.attachButton = attachButton
                }
               
                let attachButtonSize = attachButton.update(
                    transition: attachButtonTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(BundleIconComponent(
                            name: "Item List/AttachIcon",
                            tintColor: component.theme.chat.inputPanel.inputControlColor.blitOver(component.theme.list.itemBlocksBackgroundColor, alpha: 1.0)
                        )),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.attachAction?()
                        },
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let attachButtonFrame = CGRect(origin: CGPoint(x: size.width - rightIconsInset - 7.0 - attachButtonSize.width + self.revealOffset, y: size.height - minHeight + floor((minHeight - attachButtonSize.height) * 0.5)), size: attachButtonSize)
                if let attachButtonView = attachButton.view as? PlainButtonComponent.View {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    
                    if attachButtonView.superview == nil {
                        self.addSubview(attachButtonView)
                        ComponentTransition.immediate.setAlpha(view: attachButtonView, alpha: 0.0)
                        ComponentTransition.immediate.setScale(view: attachButtonView, scale: 0.001)
                    }
                    
                    attachButtonTransition.setPosition(view: attachButtonView, position: attachButtonFrame.center)
                    attachButtonTransition.setBounds(view: attachButtonView, bounds: CGRect(origin: CGPoint(), size: attachButtonFrame.size))
                    
                    let displaySelector = attachment.media == nil
                    alphaTransition.setAlpha(view: attachButtonView, alpha: displaySelector ? 1.0 : 0.0)
                    alphaTransition.setScale(view: attachButtonView, scale: displaySelector ? 1.0 : 0.001)
                }
                
                rightIconsInset += 42.0
            } else if let attachButton = self.attachButton {
                self.attachButton = nil
                if let attachButtonView = attachButton.view {
                    if !transition.animation.isImmediate {
                            let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        alphaTransition.setAlpha(view: attachButtonView, alpha: 0.0, completion: { [weak attachButtonView] _ in
                            attachButtonView?.removeFromSuperview()
                        })
                        alphaTransition.setScale(view: attachButtonView, scale: 0.001)
                    } else {
                        attachButtonView.removeFromSuperview()
                    }
                }
            }
            
            let imageNodeSize = CGSize(width: 40.0, height: 40.0)
            let imageNodeFrame = CGRect(origin: CGPoint(x: size.width - 16.0 - imageNodeSize.width + self.revealOffset, y: size.height - minHeight + floor((minHeight - imageNodeSize.height) * 0.5)), size: imageNodeSize)
            
            var isSticker = false
            if let attachment = component.attachment, let file = attachment.media?.media as? TelegramMediaFile, file.isSticker || file.isCustomEmoji {
                isSticker = true
                
                var updateMedia = false
                if self.appliedMedia != attachment.media {
                    self.appliedMedia = attachment.media
                    updateMedia = true
                }
                
                
                var animationSize = CGSize(width: 40.0, height: 40.0)
                if let dimensions = file.dimensions {
                    animationSize = dimensions.cgSize.aspectFitted(animationSize)
                }
                let animationLayer: InlineStickerItemLayer
                if let current = self.animationLayer, !updateMedia {
                    animationLayer = current
                } else {
                    if let animationLayer = self.animationLayer {
                        self.animationLayer = nil
                        animationLayer.removeFromSuperlayer()
                    }
                    animationLayer = InlineStickerItemLayer(
                        context: component.context,
                        userLocation: .other,
                        attemptSynchronousLoad: true,
                        emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file, custom: nil, enableAnimation: true),
                        file: file,
                        cache: component.context.animationCache,
                        renderer: component.context.animationRenderer,
                        unique: false,
                        placeholderColor: component.theme.list.mediaPlaceholderColor,
                        pointSize: CGSize(width: animationSize.width * 2.0, height: animationSize.height * 2.0),
                        dynamicColor: nil,
                        loopCount: nil
                    )
                    animationLayer.isVisibleForAnimations = true
                    self.animationLayer = animationLayer
                    self.layer.addSublayer(animationLayer)
                }
                animationLayer.frame = CGRect(origin: CGPoint(x: imageNodeFrame.midX - animationSize.width * 0.5, y: imageNodeFrame.midY - animationSize.height * 0.5), size: animationSize)
                
                if self.imageButton.superview == nil {
                    self.imageButton.addTarget(self, action: #selector(self.imageButtonPressed), for: .touchUpInside)
                    self.addSubview(self.imageButton)
                }
                self.imageButton.frame = imageNodeFrame
            } else if let animationLayer = self.animationLayer {
                self.animationLayer = nil
                if !transition.animation.isImmediate {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    alphaTransition.setAlpha(layer: animationLayer, alpha: 0.0, completion: { [weak animationLayer] _ in
                        animationLayer?.removeFromSuperlayer()
                    })
                    alphaTransition.setScale(layer: animationLayer, scale: 0.001)
                } else {
                    animationLayer.removeFromSuperlayer()
                }
                self.imageButton.removeFromSuperview()
            }
            
            if let attachment = component.attachment, let media = attachment.media, !isSticker {
                var imageNodeTransition = transition
                let imageNode: TransformImageNode
                if let current = self.imageNode {
                    imageNode = current
                } else {
                    imageNodeTransition = imageNodeTransition.withAnimation(.none)
                    imageNode = TransformImageNode()
                    imageNode.isUserInteractionEnabled = false
                    self.imageNode = imageNode
                    self.addSubview(imageNode.view)
                }
                
                imageNodeTransition.setPosition(view: imageNode.view, position: imageNodeFrame.center)
                imageNodeTransition.setBounds(view: imageNode.view, bounds: CGRect(origin: CGPoint(), size: imageNodeFrame.size))
                
                var imageSize = imageNodeSize
                var updateMedia = false
                if self.appliedMedia != media {
                    self.appliedMedia = media
                    updateMedia = true
                }
                
                var isVideo = false
                if let image = media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations), let photoReference = media.concrete(TelegramMediaImage.self) {
                    imageSize = largest.dimensions.cgSize.aspectFilled(imageNodeSize)
                    
                    if updateMedia {
                        imageNode.setSignal(chatMessagePhoto(postbox: component.context.account.postbox, userLocation: .other, photoReference: photoReference))
                    }
                } else if let file = media.media as? TelegramMediaFile, let fileReference = media.concrete(TelegramMediaFile.self) {
                    if let dimensions = file.dimensions {
                        imageSize = dimensions.cgSize.aspectFilled(imageNodeSize)
                    }
                    if file.isVideo {
                        if updateMedia {
                            imageNode.setSignal(chatMessageVideo(postbox: component.context.account.postbox, userLocation: .other, videoReference: fileReference))
                        }
                        isVideo = true
                    } else if file.mimeType.hasPrefix("image/") || !file.previewRepresentations.isEmpty {
                        if updateMedia {
                            imageNode.setSignal(chatMessageImageFile(account: component.context.account, userLocation: .other, fileReference: fileReference, thumbnail: true))
                        }
                    } else {
                        let fileName: String = file.fileName ?? "File"
                        var fileExtension: String?
                        if let range = fileName.range(of: ".", options: [.backwards]) {
                            fileExtension = fileName[range.upperBound...].lowercased()
                        }
                        
                        imageNode.setSignal(.single({ arguments in
                            let size = arguments.imageSize
                            let context = DrawingContext(size: size)!
                            context.withFlippedContext { context in
                                context.clear(CGRect(origin: .zero, size: size))
                                if let image = extensionImage(fileExtension: fileExtension), let cgImage = image.cgImage {
                                    context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                                }
                            }
                            return context
                        }))
                    }
                } else if let map = media.media as? TelegramMediaMap {
                    imageSize = CGSize(width: 40.0, height: 40.0)
                    if updateMedia {
                        let resource = MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: Int32(imageSize.width), height: Int32(imageSize.height))
                        imageNode.setSignal(chatMapSnapshotImage(engine: component.context.engine, resource: resource))
                    }
                }
                
                let cornerRadius: CGFloat = 10.0
                let makeLayout = imageNode.asyncLayout()
                Queue.concurrentDefaultQueue().async {
                    let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: cornerRadius), imageSize: imageSize, boundingSize: imageNodeSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))
                    Queue.mainQueue().async {
                        apply()
                    }
                }
                
                if self.imageButton.superview == nil {
                    self.imageButton.addTarget(self, action: #selector(self.imageButtonPressed), for: .touchUpInside)
                    self.addSubview(self.imageButton)
                }
                self.imageButton.frame = imageNodeFrame
                
                if let progress = attachment.progress {
                    let statusNode: RadialStatusNode
                    if let current = self.statusNode {
                        statusNode = current
                    } else {
                        statusNode = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.5))
                        self.statusNode = statusNode
                        self.addSubview(statusNode.view)
                    }
                    
                    let progressFrame = imageNodeFrame.insetBy(dx: 4.0, dy: 4.0)
                    statusNode.frame = progressFrame
                    statusNode.transitionToState(.progress(color: .white, lineWidth: 2.0 - UIScreenPixel, value: max(0.027, min(1.0, progress)), cancelEnabled: true, animateRotation: true))
                    
                    isVideo = false
                } else if let statusNode = self.statusNode {
                    self.statusNode = nil
                    if !transition.animation.isImmediate {
                        let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        alphaTransition.setAlpha(view: statusNode.view, alpha: 0.0, completion: { [weak statusNode] _ in
                            statusNode?.view.removeFromSuperview()
                        })
                        alphaTransition.setScale(view: statusNode.view, scale: 0.001)
                    } else {
                        statusNode.view.removeFromSuperview()
                    }
                }
                
                if isVideo {
                    let videoIconView: UIImageView
                    if let current = self.videoIconView {
                        videoIconView = current
                    } else  {
                        videoIconView = UIImageView(image: UIImage(bundleImageName: "Media Gallery/PlayButton")?.withRenderingMode(.alwaysTemplate))
                        videoIconView.tintColor = .white
                        self.addSubview(videoIconView)
                        self.videoIconView = videoIconView
                        
                        if !transition.animation.isImmediate {
                            let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                            alphaTransition.animateAlpha(view: videoIconView, from: 0.0, to: 1.0)
                            alphaTransition.animateScale(view: videoIconView, from: 0.01, to: 1.0)
                        }
                    }
                    let videoIconFrame = CGRect(origin: CGPoint(x: imageNodeFrame.center.x - 15.0, y: imageNodeFrame.center.y - 15.0), size: CGSize(width: 30.0, height: 30.0))
                    videoIconView.frame = videoIconFrame
                } else if let videoIconView = self.videoIconView {
                    self.videoIconView = nil
                    if !transition.animation.isImmediate {
                        let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        alphaTransition.setAlpha(view: videoIconView, alpha: 0.0, completion: { [weak videoIconView] _ in
                            videoIconView?.removeFromSuperview()
                        })
                        alphaTransition.setScale(view: videoIconView, scale: 0.001)
                    } else {
                        videoIconView.removeFromSuperview()
                    }
                }
            } else if let imageNode = self.imageNode {
                self.imageNode = nil
                if !transition.animation.isImmediate {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    alphaTransition.setAlpha(view: imageNode.view, alpha: 0.0, completion: { [weak imageNode] _ in
                        imageNode?.view.removeFromSuperview()
                    })
                    alphaTransition.setScale(view: imageNode.view, scale: 0.001)
                } else {
                    imageNode.view.removeFromSuperview()
                }
                self.imageButton.removeFromSuperview()
                
                if let videoIconView = self.videoIconView {
                    self.videoIconView = nil
                    if !transition.animation.isImmediate {
                        let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        alphaTransition.setAlpha(view: videoIconView, alpha: 0.0, completion: { [weak videoIconView] _ in
                            videoIconView?.removeFromSuperview()
                        })
                        alphaTransition.setScale(view: videoIconView, scale: 0.001)
                    } else {
                        videoIconView.removeFromSuperview()
                    }
                }
                
                if let statusNode = self.statusNode {
                    self.statusNode = nil
                    if !transition.animation.isImmediate {
                        let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        alphaTransition.setAlpha(view: statusNode.view, alpha: 0.0, completion: { [weak statusNode] _ in
                            statusNode?.view.removeFromSuperview()
                        })
                        alphaTransition.setScale(view: statusNode.view, scale: 0.001)
                    } else {
                        statusNode.view.removeFromSuperview()
                    }
                }
            }
            
            if let inputMode = component.inputMode {
                var modeSelectorTransition = transition
                let modeSelector: ComponentView<Empty>
                if let current = self.modeSelector {
                    modeSelector = current
                } else {
                    modeSelectorTransition = modeSelectorTransition.withAnimation(.none)
                    modeSelector = ComponentView()
                    self.modeSelector = modeSelector
                }
                let animationName: String
                var playAnimation = false
                if let previousComponent, let previousInputMode = previousComponent.inputMode {
                    if previousInputMode != inputMode {
                        playAnimation = true
                    }
                }
                switch inputMode {
                case .keyboard:
                    animationName = "input_anim_keyToSmile"
                case .emoji:
                    animationName = "input_anim_smileToKey"
                }
                
                let _ = modeSelector.update(
                    transition: modeSelectorTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(
                                name: animationName
                            ),
                            color: component.theme.chat.inputPanel.inputControlColor.blitOver(component.theme.list.itemBlocksBackgroundColor, alpha: 1.0),
                            size: modeSelectorSize
                        )),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.toggleInputMode?()
                        },
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: modeSelectorSize
                )
                let modeSelectorFrame = CGRect(origin: CGPoint(x: size.width - rightIconsInset - 4.0 - modeSelectorSize.width + self.revealOffset, y: size.height - minHeight + floor((minHeight - modeSelectorSize.height) * 0.5)), size: modeSelectorSize)
                if let modeSelectorView = modeSelector.view as? PlainButtonComponent.View {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    
                    if modeSelectorView.superview == nil {
                        self.addSubview(modeSelectorView)
                        ComponentTransition.immediate.setAlpha(view: modeSelectorView, alpha: 0.0)
                        ComponentTransition.immediate.setScale(view: modeSelectorView, scale: 0.001)
                    }
                    
                    if let animationView = modeSelectorView.contentView as? LottieComponent.View {
                        if playAnimation {
                            animationView.playOnce()
                        }
                    }
                    
                    modeSelectorTransition.setPosition(view: modeSelectorView, position: modeSelectorFrame.center)
                    modeSelectorTransition.setBounds(view: modeSelectorView, bounds: CGRect(origin: CGPoint(), size: modeSelectorFrame.size))
                    
                    if let externalState = component.externalState {
                        let displaySelector = externalState.isEditing || component.alwaysDisplayInputModeSelector
                        
                        alphaTransition.setAlpha(view: modeSelectorView, alpha: displaySelector ? 1.0 : 0.0)
                        alphaTransition.setScale(view: modeSelectorView, scale: displaySelector ? 1.0 : 0.001)
                    }
                }
            } else if let modeSelector = self.modeSelector {
                self.modeSelector = nil
                if let modeSelectorView = modeSelector.view {
                    if !transition.animation.isImmediate {
                        let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        alphaTransition.setAlpha(view: modeSelectorView, alpha: 0.0, completion: { [weak modeSelectorView] _ in
                            modeSelectorView?.removeFromSuperview()
                        })
                        alphaTransition.setScale(view: modeSelectorView, scale: 0.001)
                    } else {
                        modeSelectorView.removeFromSuperview()
                    }
                }
            }
            
            if let deleteAction = component.deleteAction {
                var deleteRevealViewTransition = transition
                let deleteRevealView: DeleteRevealView
                if let current = self.deleteRevealView {
                    deleteRevealView = current
                } else {
                    deleteRevealViewTransition = .immediate
                    deleteRevealView = DeleteRevealView(title: component.strings.Common_Delete, color: component.theme.list.itemDisclosureActions.destructive.fillColor)
                    deleteRevealView.tapped = { [weak self] action in
                        guard let self else {
                            return
                        }
                        if action {
                            deleteAction()
                        } else {
                            self.revealOffset = 0.0
                            self.isRevealed = false
                            self.state?.updated(transition: .spring(duration: 0.3))
                        }
                    }
                    self.deleteRevealView = deleteRevealView
                    self.addSubview(deleteRevealView)
                    
                    if self.recognizer == nil {
                        let recognizer = RevealOptionsGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
                        recognizer.delegate = self
                        self.addGestureRecognizer(recognizer)
                        self.recognizer = recognizer
                    }
                }
                
                let _ = deleteRevealView.updateLayout(availableSize: size, revealOffset: self.revealOffset, transition: deleteRevealViewTransition)
                deleteRevealView.frame = CGRect(origin: .zero, size: size)
            } else {
                if let deleteRevealView = self.deleteRevealView {
                    self.deleteRevealView = nil
                    deleteRevealView.removeFromSuperview()
                }
                
                if let panGestureRecognizer = self.recognizer {
                    self.recognizer = nil
                    self.removeGestureRecognizer(panGestureRecognizer)
                }
                
                self.isRevealed = false
                self.revealOffset = 0.0
            }
            
            self.separatorInset = leftInset
            
            return size
        }
        
        public func updateCustomPlaceholder(value: String, size: CGSize, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            
            var verticalInset: CGFloat = 12.0
            if case .glass = component.style {
                verticalInset = 16.0
            }
            var leftInset: CGFloat = 16.0
            let rightInset: CGFloat = 16.0
            
            if component.hasLeftInset {
                leftInset += 46.0
            }
            
            if component.selection != nil {
                leftInset += 34.0
            }
            
            if !value.isEmpty {
                let customPlaceholder: ComponentView<Empty>
                var customPlaceholderTransition = transition
                if let current = self.customPlaceholder {
                    customPlaceholder = current
                } else {
                    customPlaceholderTransition = customPlaceholderTransition.withAnimation(.none)
                    customPlaceholder = ComponentView()
                    self.customPlaceholder = customPlaceholder
                }
                
                let placeholderSize = customPlaceholder.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: value.isEmpty ? " " : value, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: size.width - leftInset - rightInset, height: 100.0)
                )
                let placeholderFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: placeholderSize)
                if let placeholderView = customPlaceholder.view {
                    if placeholderView.superview == nil {
                        placeholderView.layer.anchorPoint = CGPoint()
                        placeholderView.isUserInteractionEnabled = false
                        self.insertSubview(placeholderView, at: 0)
                    }
                    transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                    placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                    
                    if let externalState = component.externalState {
                        placeholderView.isHidden = externalState.hasText
                    }
                }
            } else if let customPlaceholder = self.customPlaceholder {
                self.customPlaceholder = nil
                customPlaceholder.view?.removeFromSuperview()
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class RevealOptionsGestureRecognizer: UIPanGestureRecognizer {
    var validatedGesture = false
    var firstLocation: CGPoint = CGPoint()
    
    var allowAnyDirection = false
    var lastVelocity: CGPoint = CGPoint()
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        if #available(iOS 13.4, *) {
            self.allowedScrollTypesMask = .continuous
        }
        
        self.maximumNumberOfTouches = 1
    }
    
    override public func reset() {
        super.reset()
        
        self.validatedGesture = false
    }
    
    func becomeCancelled() {
        self.state = .cancelled
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let touch = touches.first!
        self.firstLocation = touch.location(in: self.view)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
        
        if !self.validatedGesture {
            if !self.allowAnyDirection && translation.x > 0.0 {
                self.state = .failed
            } else if abs(translation.y) > 4.0 && abs(translation.y) > abs(translation.x) * 2.5 {
                self.state = .failed
            } else if abs(translation.x) > 4.0 && abs(translation.y) * 2.5 < abs(translation.x) {
                self.validatedGesture = true
            }
        }
        
        if self.validatedGesture {
            self.lastVelocity = self.velocity(in: self.view)
            super.touchesMoved(touches, with: event)
        }
    }
}

private let extensionFont = Font.with(size: 15.0, design: .round, weight: .bold)
private let mediumExtensionFont = Font.with(size: 14.0, design: .round, weight: .bold)
private let smallExtensionFont = Font.with(size: 12.0, design: .round, weight: .bold)

private let redColors: (UInt32, UInt32) = (0xff875f, 0xff5069)
private let greenColors: (UInt32, UInt32) = (0x99de6f, 0x5fb84f)
private let blueColors: (UInt32, UInt32) = (0x72d5fd, 0x2a9ef1)
private let yellowColors: (UInt32, UInt32) = (0xffa24b, 0xed705c)

private let extensionColorsMap: [String: (UInt32, UInt32)] = [
    "ppt": redColors,
    "pptx": redColors,
    "pdf": redColors,
    "key": redColors,
    
    "xls": greenColors,
    "xlsx": greenColors,
    "csv": greenColors,
    
    "zip": yellowColors,
    "rar": yellowColors,
    "gzip": yellowColors,
    "ai": yellowColors
]

private func generateExtensionImage(colors: (UInt32, UInt32), fileExtension: String) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.saveGState()
        context.beginPath()
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 ")
        context.clip()
        
        let gradientColors = [UIColor(rgb: colors.0).cgColor, UIColor(rgb: colors.1).cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.restoreGState()
        
        context.saveGState()
        let rounded = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 13).cgPath
        let full = UIBezierPath(rect: CGRect(origin: .zero, size: size)).cgPath
        context.addPath(full)
        context.addPath(rounded)
        context.setBlendMode(.destinationOut)
        context.drawPath(using: .eoFill)
        context.setBlendMode(.normal)
        context.restoreGState()
        
        context.saveGState()
        
        context.beginPath()
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 ")
        context.clip()

        context.setBlendMode(.overlay)
        context.setFillColor(UIColor(rgb: 0xffffff, alpha: 0.5).cgColor)
        context.translateBy(x: 40.0 - 14.0, y: 0.0)
        let _ = try? drawSvgPath(context, path: "M-1,0 L14,0 L14,15 L14,14 C14,12.8954305 13.1045695,12 12,12 L4,12 C2.8954305,12 2,11.1045695 2,10 L2,2 C2,0.8954305 1.1045695,-2.02906125e-16 0,0 L-1,0 L-1,0 Z ")
        
        context.restoreGState()
        
        UIGraphicsPushContext(context)
        let extensionText = NSAttributedString(string: fileExtension, font: fileExtension.count > 3 ? mediumExtensionFont : extensionFont, textColor: .white, paragraphAlignment: .center)
        extensionText.draw(in: CGRect(origin: CGPoint(x: 0.0, y: 15.0), size: size))
        UIGraphicsPopContext()
    })
}

private func extensionImage(fileExtension: String?) -> UIImage? {
    let colors: (UInt32, UInt32)
    if let fileExtension = fileExtension {
        if let extensionColors = extensionColorsMap[fileExtension] {
            colors = extensionColors
        } else {
            colors = blueColors
        }
    } else {
        colors = blueColors
    }
    return generateExtensionImage(colors: colors, fileExtension: fileExtension ?? "")
}
