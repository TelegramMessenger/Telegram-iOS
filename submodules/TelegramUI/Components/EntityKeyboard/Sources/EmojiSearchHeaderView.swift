import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import SwiftSignalKit

public final class EmojiSearchHeaderView: UIView, UITextFieldDelegate {
    private final class EmojiSearchTextField: UITextField {
        override func textRect(forBounds bounds: CGRect) -> CGRect {
            return bounds.integral
        }
    }
    
    private struct Params: Equatable {
        var context: AccountContext
        var theme: PresentationTheme
        var forceNeedsVibrancy: Bool
        var strings: PresentationStrings
        var text: String
        var useOpaqueTheme: Bool
        var isActive: Bool
        var hasPresetSearch: Bool
        var textInputState: EmojiSearchSearchBarComponent.TextInputState
        var searchState: EmojiPagerContentComponent.SearchState
        var size: CGSize
        var canFocus: Bool
        var searchCategories: EmojiSearchCategories?
        
        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.context !== rhs.context {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.forceNeedsVibrancy != rhs.forceNeedsVibrancy {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            if lhs.text != rhs.text {
                return false
            }
            if lhs.useOpaqueTheme != rhs.useOpaqueTheme {
                return false
            }
            if lhs.isActive != rhs.isActive {
                return false
            }
            if lhs.hasPresetSearch != rhs.hasPresetSearch {
                return false
            }
            if lhs.textInputState != rhs.textInputState {
                return false
            }
            if lhs.searchState != rhs.searchState {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            if lhs.canFocus != rhs.canFocus {
                return false
            }
            if lhs.searchCategories != rhs.searchCategories {
                return false
            }
            return true
        }
    }
    
    override public static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    private let activated: (Bool) -> Void
    private let deactivated: (Bool) -> Void
    private let updateQuery: (EmojiPagerContentComponent.SearchQuery?) -> Void
    
    let tintContainerView: UIView
    
    private let backgroundLayer: SimpleLayer
    private let tintBackgroundLayer: SimpleLayer
    
    private let statusIcon = ComponentView<Empty>()
    
    private let clearIconView: UIImageView
    private let clearIconTintView: UIImageView
    private let clearIconButton: HighlightTrackingButton
    
    private let cancelButtonTintTitle: ComponentView<Empty>
    private let cancelButtonTitle: ComponentView<Empty>
    private let cancelButton: HighlightTrackingButton
    
    private var placeholderContent = ComponentView<Empty>()
    
    private var textFrame: CGRect?
    private var textField: EmojiSearchTextField?
    
    private var tapRecognizer: UITapGestureRecognizer?
    private(set) var currentPresetSearchTerm: EmojiSearchCategories.Group?
    
    private var params: Params?
    
    public var wantsDisplayBelowKeyboard: Bool {
        return self.textField != nil
    }
    
    init(activated: @escaping (Bool) -> Void, deactivated: @escaping (Bool) -> Void, updateQuery: @escaping (EmojiPagerContentComponent.SearchQuery?) -> Void) {
        self.activated = activated
        self.deactivated = deactivated
        self.updateQuery = updateQuery
        
        self.tintContainerView = UIView()
        
        self.backgroundLayer = SimpleLayer()
        self.tintBackgroundLayer = SimpleLayer()
        
        self.clearIconView = UIImageView()
        self.clearIconTintView = UIImageView()
        self.clearIconButton = HighlightableButton()
        self.clearIconView.isHidden = true
        self.clearIconTintView.isHidden = true
        self.clearIconButton.isHidden = true
        
        self.cancelButtonTintTitle = ComponentView()
        self.cancelButtonTitle = ComponentView()
        self.cancelButton = HighlightTrackingButton()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.backgroundLayer)
        self.tintContainerView.layer.addSublayer(self.tintBackgroundLayer)
        
        self.addSubview(self.clearIconView)
        self.tintContainerView.addSubview(self.clearIconTintView)
        self.addSubview(self.clearIconButton)
        
        self.addSubview(self.cancelButton)
        self.clipsToBounds = true
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.tintContainerView.layer
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        self.addGestureRecognizer(tapRecognizer)
        
        self.cancelButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    if let cancelButtonTitleView = strongSelf.cancelButtonTitle.view {
                        cancelButtonTitleView.layer.removeAnimation(forKey: "opacity")
                        cancelButtonTitleView.alpha = 0.4
                    }
                    if let cancelButtonTintTitleView = strongSelf.cancelButtonTintTitle.view {
                        cancelButtonTintTitleView.layer.removeAnimation(forKey: "opacity")
                        cancelButtonTintTitleView.alpha = 0.4
                    }
                } else {
                    if let cancelButtonTitleView = strongSelf.cancelButtonTitle.view {
                        cancelButtonTitleView.alpha = 1.0
                        cancelButtonTitleView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                    if let cancelButtonTintTitleView = strongSelf.cancelButtonTintTitle.view {
                        cancelButtonTintTitleView.alpha = 1.0
                        cancelButtonTintTitleView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
        
        self.clearIconButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.clearIconView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconView.alpha = 0.4
                    strongSelf.clearIconTintView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconTintView.alpha = 0.4
                } else {
                    strongSelf.clearIconView.alpha = 1.0
                    strongSelf.clearIconView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.clearIconTintView.alpha = 1.0
                    strongSelf.clearIconTintView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.clearIconButton.addTarget(self, action: #selector(self.clearPressed), for: .touchUpInside)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let location = recognizer.location(in: self)
            if let view = self.statusIcon.view, view.frame.contains(location), self.currentPresetSearchTerm != nil {
                self.clearCategorySearch()
            } else {
                self.activateTextInput()
            }
        }
    }
    
    func clearCategorySearch() {
        if let placeholderContentView = self.placeholderContent.view as? EmojiSearchSearchBarComponent.View {
            placeholderContentView.clearSelection(dispatchEvent : true)
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let textField = self.textField, let text = textField.text, text.isEmpty {
            if self.bounds.contains(point), let placeholderContentView = self.placeholderContent.view as? EmojiSearchSearchBarComponent.View {
                let leftTextPosition = placeholderContentView.leftTextPosition()
                if point.x >= placeholderContentView.frame.minX + leftTextPosition {
                    if let result = placeholderContentView.hitTest(self.convert(point, to: placeholderContentView), with: event) {
                        return result
                    }
                }
            }
        }
        return super.hitTest(point, with: event)
    }
    
    private func activateTextInput() {
        guard let params = self.params else {
            return
        }
        if self.textField == nil, let textFrame = self.textFrame, params.canFocus == true {
            let backgroundFrame = self.backgroundLayer.frame
            let textFieldFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - textFrame.minX, height: backgroundFrame.height))
            
            let textField = EmojiSearchTextField(frame: textFieldFrame)
            textField.keyboardAppearance = params.theme.rootController.keyboardColor.keyboardAppearance
            textField.autocorrectionType = .no
            textField.returnKeyType = .search
            self.textField = textField
            if let placeholderContentView = self.placeholderContent.view {
                self.insertSubview(textField, belowSubview: placeholderContentView)
            } else {
                self.insertSubview(textField, belowSubview: self.clearIconView)
            }
            textField.delegate = self
            textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
        }
        
        if params.canFocus {
            self.currentPresetSearchTerm = nil
            if let placeholderContentView = self.placeholderContent.view as? EmojiSearchSearchBarComponent.View {
                placeholderContentView.clearSelection(dispatchEvent: false)
            }
        }
        
        self.activated(true)
        
        self.textField?.becomeFirstResponder()
    }
    
    @objc private func cancelPressed() {
        let textField = self.textField
        self.textField = nil
        
        self.currentPresetSearchTerm = nil
        self.updateQuery(nil)
        
        self.clearIconView.isHidden = true
        self.clearIconTintView.isHidden = true
        self.clearIconButton.isHidden = true
        
        self.deactivated(textField?.isFirstResponder ?? false)
        
        if let textField {
            textField.resignFirstResponder()
            textField.removeFromSuperview()
        }
    }
    
    @objc private func clearPressed() {
        self.currentPresetSearchTerm = nil
        self.updateQuery(nil)
        self.textField?.text = ""
        
        self.clearIconView.isHidden = true
        self.clearIconTintView.isHidden = true
        self.clearIconButton.isHidden = true
        
        /*self.tintTextView.view?.isHidden = false
        self.textView.view?.isHidden = false*/
    }
    
    var isActive: Bool {
        return self.textField?.isFirstResponder ?? false
    }
    
    func deactivate() {
        if let text = self.textField?.text, !text.isEmpty {
            self.textField?.endEditing(true)
        } else {
            self.cancelPressed()
        }
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return false
    }
    
    @objc private func textFieldChanged(_ textField: UITextField) {
        self.update(transition: .immediate)
        
        let text = textField.text ?? ""
        
        var inputLanguage = textField.textInputMode?.primaryLanguage ?? "en"
        if let range = inputLanguage.range(of: "-") {
            inputLanguage = String(inputLanguage[inputLanguage.startIndex ..< range.lowerBound])
        }
        if let range = inputLanguage.range(of: "_") {
            inputLanguage = String(inputLanguage[inputLanguage.startIndex ..< range.lowerBound])
        }
        
        self.clearIconView.isHidden = text.isEmpty
        self.clearIconTintView.isHidden = text.isEmpty
        self.clearIconButton.isHidden = text.isEmpty
        
        self.currentPresetSearchTerm = nil
        self.updateQuery(.text(value: text, language: inputLanguage))
    }
    
    private func update(transition: ComponentTransition) {
        guard let params = self.params else {
            return
        }
        self.params = nil
        self.update(context: params.context, theme: params.theme, forceNeedsVibrancy: params.forceNeedsVibrancy, strings: params.strings, text: params.text, useOpaqueTheme: params.useOpaqueTheme, isActive: params.isActive, size: params.size, canFocus: params.canFocus, searchCategories: params.searchCategories, searchState: params.searchState, transition: transition)
    }
    
    public func update(context: AccountContext, theme: PresentationTheme, forceNeedsVibrancy: Bool, strings: PresentationStrings, text: String, useOpaqueTheme: Bool, isActive: Bool, size: CGSize, canFocus: Bool, searchCategories: EmojiSearchCategories?, searchState: EmojiPagerContentComponent.SearchState, transition: ComponentTransition) {
        let textInputState: EmojiSearchSearchBarComponent.TextInputState
        if let textField = self.textField {
            textInputState = .active(hasText: !(textField.text ?? "").isEmpty)
        } else {
            textInputState = .inactive
        }
        
        let params = Params(
            context: context,
            theme: theme,
            forceNeedsVibrancy: forceNeedsVibrancy,
            strings: strings,
            text: text,
            useOpaqueTheme: useOpaqueTheme,
            isActive: isActive,
            hasPresetSearch: self.currentPresetSearchTerm == nil,
            textInputState: textInputState,
            searchState: searchState,
            size: size,
            canFocus: canFocus,
            searchCategories: searchCategories
        )
        
        if self.params == params {
            return
        }
        
        let isActiveWithText = isActive && self.currentPresetSearchTerm == nil
        
        if self.params?.theme !== theme {
            /*self.searchIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Loupe"), color: .white)?.withRenderingMode(.alwaysTemplate)
            self.searchIconView.tintColor = useOpaqueTheme ? theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayColor : theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
            
            self.searchIconTintView.image = generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Loupe"), color: .white)
            
            self.backIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: .white)?.withRenderingMode(.alwaysTemplate)
            self.backIconView.tintColor = useOpaqueTheme ? theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayColor : theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
            
            self.backIconTintView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: .white)*/
            
            self.clearIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: .white)?.withRenderingMode(.alwaysTemplate)
            self.clearIconView.tintColor = useOpaqueTheme ? theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayColor : theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
            
            self.clearIconTintView.image = generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: .black)
        }
        
        self.params = params
        
        let sideInset: CGFloat = 12.0
        let topInset: CGFloat = 8.0
        let inputHeight: CGFloat = 36.0
        
        let sideTextInset: CGFloat = sideInset + 4.0 + 24.0
        
        if theme.overallDarkAppearance && forceNeedsVibrancy {
            self.backgroundLayer.backgroundColor = theme.chat.inputMediaPanel.panelContentControlVibrantSelectionColor.withMultipliedAlpha(0.3).cgColor
            self.tintBackgroundLayer.backgroundColor = UIColor(white: 0.0, alpha: 0.2).cgColor
        } else if useOpaqueTheme {
            self.backgroundLayer.backgroundColor = theme.chat.inputMediaPanel.panelContentControlOpaqueSelectionColor.cgColor
            self.tintBackgroundLayer.backgroundColor = UIColor.black.cgColor
        } else {
            self.backgroundLayer.backgroundColor = theme.chat.inputMediaPanel.panelContentControlVibrantSelectionColor.cgColor
            self.tintBackgroundLayer.backgroundColor = UIColor(white: 0.0, alpha: 0.2).cgColor
        }
        
        self.backgroundLayer.cornerRadius = inputHeight * 0.5
        self.tintBackgroundLayer.cornerRadius = inputHeight * 0.5
        
        let cancelColor: UIColor
        if theme.overallDarkAppearance && forceNeedsVibrancy {
            cancelColor = theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor.withMultipliedAlpha(0.3)
        } else {
            cancelColor = useOpaqueTheme ? theme.list.itemAccentColor : theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
        }
        
        let cancelTextSize = self.cancelButtonTitle.update(
            transition: .immediate,
            component: AnyComponent(Text(
                text: strings.Common_Cancel,
                font: Font.regular(17.0),
                color: cancelColor
            )),
            environment: {},
            containerSize: CGSize(width: size.width - 32.0, height: 100.0)
        )
        let _ = self.cancelButtonTintTitle.update(
            transition: .immediate,
            component: AnyComponent(Text(
                text: strings.Common_Cancel,
                font: Font.regular(17.0),
                color: .black
            )),
            environment: {},
            containerSize: CGSize(width: size.width - 32.0, height: 100.0)
        )
        
        let cancelButtonSpacing: CGFloat = 8.0
        
        var backgroundFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: CGSize(width: size.width - sideInset * 2.0, height: inputHeight))
        if isActiveWithText {
            backgroundFrame.size.width -= cancelTextSize.width + cancelButtonSpacing
        }
        transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
        transition.setFrame(layer: self.tintBackgroundLayer, frame: backgroundFrame)
        
        transition.setFrame(view: self.cancelButton, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX, y: 0.0), size: CGSize(width: cancelButtonSpacing + cancelTextSize.width, height: size.height)))
        
        let textX: CGFloat = backgroundFrame.minX + sideTextInset
        let textFrame = CGRect(origin: CGPoint(x: textX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - textX, height: backgroundFrame.height))
        self.textFrame = textFrame
        
        let statusContent: EmojiSearchStatusComponent.Content
        switch searchState {
        case .empty:
            statusContent = .search
        case .searching:
            statusContent = .progress
        case .active:
            statusContent = .results
        }
        
        let statusSize = CGSize(width: 24.0, height: 24.0)
        let _ = self.statusIcon.update(
            transition: transition,
            component: AnyComponent(EmojiSearchStatusComponent(
                theme: theme,
                forceNeedsVibrancy: forceNeedsVibrancy,
                strings: strings,
                useOpaqueTheme: useOpaqueTheme,
                content: statusContent
            )),
            environment: {},
            containerSize: statusSize
        )
        let iconFrame = CGRect(origin: CGPoint(x: textFrame.minX - statusSize.width - 4.0, y: backgroundFrame.minY + floor((backgroundFrame.height - statusSize.height) / 2.0)), size: statusSize)
        if let statusIconView = self.statusIcon.view as? EmojiSearchStatusComponent.View {
            if statusIconView.superview == nil {
                self.addSubview(statusIconView)
                self.tintContainerView.addSubview(statusIconView.tintContainerView)
            }
            
            transition.setFrame(view: statusIconView, frame: iconFrame)
            transition.setFrame(view: statusIconView.tintContainerView, frame: iconFrame)
        }
        
        let placeholderContentFrame = CGRect(origin: CGPoint(x: textFrame.minX - 6.0, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - (textFrame.minX - 6.0), height: backgroundFrame.height))
        let _ = self.placeholderContent.update(
            transition: transition,
            component: AnyComponent(EmojiSearchSearchBarComponent(
                context: context,
                theme: theme,
                forceNeedsVibrancy: forceNeedsVibrancy,
                strings: strings,
                useOpaqueTheme: useOpaqueTheme,
                textInputState: textInputState,
                categories: searchCategories,
                searchTermUpdated: { [weak self] term in
                    guard let self else {
                        return
                    }
                    var shouldChangeActivation = false
                    if (self.currentPresetSearchTerm == nil) != (term == nil) {
                        shouldChangeActivation = true
                    }
                    self.currentPresetSearchTerm = term
                    
                    if shouldChangeActivation {
                        if let term {
                            self.update(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            
                            let textField = self.textField
                            self.textField = nil
                            
                            self.clearIconView.isHidden = true
                            self.clearIconTintView.isHidden = true
                            self.clearIconButton.isHidden = true
                            
                            self.updateQuery(.category(value: term))
                            self.activated(false)
                            
                            if let textField {
                                textField.resignFirstResponder()
                                textField.removeFromSuperview()
                            }
                        } else {
                            self.deactivated(self.textField?.isFirstResponder ?? false)
                            self.updateQuery(nil)
                        }
                    } else {
                        if let term {
                            self.updateQuery(.category(value: term))
                        } else {
                            self.updateQuery(nil)
                        }
                    }
                },
                activateTextInput: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.activateTextInput()
                }
            )),
            environment: {},
            containerSize: placeholderContentFrame.size
        )
        if let placeholderContentView = self.placeholderContent.view as? EmojiSearchSearchBarComponent.View {
            if placeholderContentView.superview == nil {
                self.addSubview(placeholderContentView)
                self.tintContainerView.addSubview(placeholderContentView.tintContainerView)
            }
            transition.setFrame(view: placeholderContentView, frame: placeholderContentFrame)
            transition.setFrame(view: placeholderContentView.tintContainerView, frame: placeholderContentFrame)
        }
        
        /*if let searchCategories {
            let suggestedItemsView: ComponentView<Empty>
            var suggestedItemsTransition = transition
            if let current = self.suggestedItemsView {
                suggestedItemsView = current
            } else {
                suggestedItemsTransition = .immediate
                suggestedItemsView = ComponentView()
                self.suggestedItemsView = suggestedItemsView
            }
            
            let itemsX: CGFloat = textFrame.maxX + 8.0
            let suggestedItemsFrame = CGRect(origin: CGPoint(x: itemsX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - itemsX, height: backgroundFrame.height))
            
            if let suggestedItemsComponentView = suggestedItemsView.view {
                if suggestedItemsComponentView.superview == nil {
                    self.addSubview(suggestedItemsComponentView)
                }
                suggestedItemsTransition.setFrame(view: suggestedItemsComponentView, frame: suggestedItemsFrame)
                suggestedItemsTransition.setAlpha(view: suggestedItemsComponentView, alpha: isActiveWithText ? 0.0 : 1.0)
            }
        } else {
            if let suggestedItemsView = self.suggestedItemsView {
                self.suggestedItemsView = nil
                if let suggestedItemsComponentView = suggestedItemsView.view {
                    transition.setAlpha(view: suggestedItemsComponentView, alpha: 0.0, completion: { [weak suggestedItemsComponentView] _ in
                        suggestedItemsComponentView?.removeFromSuperview()
                    })
                }
            }
        }*/
        
        if let image = self.clearIconView.image {
            let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - image.size.width - 4.0, y: backgroundFrame.minY + floor((backgroundFrame.height - image.size.height) / 2.0)), size: image.size)
            transition.setFrame(view: self.clearIconView, frame: iconFrame)
            transition.setFrame(view: self.clearIconTintView, frame: iconFrame)
            transition.setFrame(view: self.clearIconButton, frame: iconFrame.insetBy(dx: -8.0, dy: -10.0))
        }
        
        if let cancelButtonTitleComponentView = self.cancelButtonTitle.view {
            if cancelButtonTitleComponentView.superview == nil {
                self.addSubview(cancelButtonTitleComponentView)
                cancelButtonTitleComponentView.isUserInteractionEnabled = false
            }
            transition.setFrame(view: cancelButtonTitleComponentView, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX + cancelButtonSpacing, y: floor((size.height - cancelTextSize.height) / 2.0)), size: cancelTextSize))
            transition.setAlpha(view: cancelButtonTitleComponentView, alpha: isActiveWithText ? 1.0 : 0.0)
        }
        if let cancelButtonTintTitleComponentView = self.cancelButtonTintTitle.view {
            if cancelButtonTintTitleComponentView.superview == nil {
                self.tintContainerView.addSubview(cancelButtonTintTitleComponentView)
                cancelButtonTintTitleComponentView.isUserInteractionEnabled = false
            }
            transition.setFrame(view: cancelButtonTintTitleComponentView, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX + cancelButtonSpacing, y: floor((size.height - cancelTextSize.height) / 2.0)), size: cancelTextSize))
            transition.setAlpha(view: cancelButtonTintTitleComponentView, alpha: isActiveWithText ? 1.0 : 0.0)
        }
        
        var hasText = false
        if let textField = self.textField {
            textField.textColor = theme.contextMenu.primaryColor
            transition.setFrame(view: textField, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + sideTextInset, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.width - sideTextInset - 32.0, height: backgroundFrame.height)))
            
            if let text = textField.text, !text.isEmpty {
                hasText = true
            }
        }
        let _ = hasText
        
        
    }
}
