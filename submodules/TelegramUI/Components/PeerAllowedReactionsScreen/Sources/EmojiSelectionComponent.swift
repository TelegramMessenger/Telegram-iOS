import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import EntityKeyboard
import AccountContext
import PagerComponent
import AudioToolbox

public final class EmojiSelectionComponent: Component {
    public typealias EnvironmentType = Empty
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let sideInset: CGFloat
    public let bottomInset: CGFloat
    public let deviceMetrics: DeviceMetrics
    public let emojiContent: EmojiPagerContentComponent?
    public let stickerContent: EmojiPagerContentComponent?
    public let backgroundIconColor: UIColor?
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let backspace: (() -> Void)?
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        sideInset: CGFloat,
        bottomInset: CGFloat,
        deviceMetrics: DeviceMetrics,
        emojiContent: EmojiPagerContentComponent?,
        stickerContent: EmojiPagerContentComponent?,
        backgroundIconColor: UIColor?,
        backgroundColor: UIColor,
        separatorColor: UIColor,
        backspace: (() -> Void)?
    ) {
        self.theme = theme
        self.strings = strings
        self.sideInset = sideInset
        self.bottomInset = bottomInset
        self.deviceMetrics = deviceMetrics
        self.emojiContent = emojiContent
        self.stickerContent = stickerContent
        self.backgroundIconColor = backgroundIconColor
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.backspace = backspace
    }
    
    public static func ==(lhs: EmojiSelectionComponent, rhs: EmojiSelectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings != rhs.strings {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.emojiContent != rhs.emojiContent {
            return false
        }
        if lhs.stickerContent != rhs.stickerContent {
            return false
        }
        if lhs.backgroundIconColor != rhs.backgroundIconColor {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        if (lhs.backspace == nil) != (rhs.backspace == nil) {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let keyboardView: ComponentView<Empty>
        private let keyboardClippingView: UIView
        private let panelHostView: PagerExternalTopPanelContainer
        private let panelBackgroundView: BlurredBackgroundView
        private let panelSeparatorView: UIView
        private let shadowView: UIImageView
        private let cornersView: UIImageView
        
        private let backspaceButton = ComponentView<Empty>()
        private let backspaceBackgroundView: UIImageView
        
        private var component: EmojiSelectionComponent?
        private weak var state: EmptyComponentState?
        
        private var isSearchActive: Bool = false
        
        override init(frame: CGRect) {
            self.keyboardView = ComponentView<Empty>()
            self.keyboardClippingView = UIView()
            self.panelHostView = PagerExternalTopPanelContainer()
            self.panelBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.panelSeparatorView = UIView()
            self.shadowView = UIImageView()
            self.cornersView = UIImageView()
            
            self.backspaceBackgroundView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.keyboardClippingView)
            self.addSubview(self.panelBackgroundView)
            self.addSubview(self.panelSeparatorView)
            self.addSubview(self.panelHostView)
            self.addSubview(self.cornersView)
            self.addSubview(self.shadowView)
            
            self.shadowView.image = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setShadow(offset: CGSize(), blur: 40.0, color: UIColor(white: 0.0, alpha: 0.05).cgColor)
                context.setFillColor(UIColor.black.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: size))
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: size).insetBy(dx: -0.5, dy: -0.5))
            })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 16)
            
            self.cornersView.image = generateImage(CGSize(width: 16.0 + 1.0, height: 16.0), rotatedContext: { size, context in
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: size), cornerRadius: 8.0).cgPath)
                context.fillPath()
                context.clear(CGRect(origin: CGPoint(x: 8.0, y: 0.0), size: CGSize(width: 1.0, height: size.height)))
            })?.withRenderingMode(.alwaysTemplate).stretchableImage(withLeftCapWidth: 8, topCapHeight: 16)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        public func internalRequestUpdate(transition: ComponentTransition) {
            if let keyboardComponentView = self.keyboardView.view as? EntityKeyboardComponent.View {
                keyboardComponentView.state?.updated(transition: transition)
            }
        }
        
        func update(component: EmojiSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.backgroundColor = component.backgroundColor
            let panelBackgroundColor = component.backgroundColor.withMultipliedAlpha(0.85)
            self.panelBackgroundView.updateColor(color: panelBackgroundColor, transition: .immediate)
            self.panelSeparatorView.backgroundColor = component.separatorColor
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            var resolvedHeight: CGFloat = min(340.0, max(50.0, availableSize.height - 200.0))
            if self.isSearchActive {
                resolvedHeight = min(availableSize.height, resolvedHeight + 200.0)
            }
            
            self.cornersView.tintColor = component.theme.list.blocksBackgroundColor
            transition.setFrame(view: self.cornersView, frame: CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: CGSize(width: availableSize.width, height: 16.0)))
            
            transition.setFrame(view: self.shadowView, frame: CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: CGSize(width: availableSize.width, height: 16.0)))
            
            let topPanelHeight: CGFloat = 42.0
            
            let backspaceButtonInset = UIEdgeInsets(top: 9.0, left: 0.0, bottom: 36.0, right: 9.0)
            let backspaceButtonSize = CGSize(width: 36.0, height: 36.0)
            
            let _ = self.backspaceButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(HStack([], spacing: 0.0)),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.backspace?()
                        AudioServicesPlaySystemSound(1155)
                    }
                ).withHoldAction({ [weak self] _ in
                    guard let self, let component = self.component else {
                        return
                    }
                    AudioServicesPlaySystemSound(1155)
                    component.backspace?()
                })),
                environment: {},
                containerSize: backspaceButtonSize
            )
            
            if previousComponent?.theme !== component.theme {
                self.backspaceBackgroundView.image = generateImage(CGSize(width: backspaceButtonSize.width + 12.0 * 2.0, height: backspaceButtonSize.height + 12.0 * 2.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setShadow(offset: CGSize(), blur: 40.0, color: UIColor(white: 0.0, alpha: 0.15).cgColor)
                    context.setFillColor(component.theme.list.plainBackgroundColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: backspaceButtonSize))
                    
                    context.setShadow(offset: CGSize(), blur: 0.0, color: nil)
                    if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputClearIcon"), color: component.theme.chat.inputMediaPanel.panelIconColor) {
                        let imageSize = image.size
                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: 12.0 + floor((backspaceButtonSize.width - imageSize.width) * 0.5) - 1.0, y: 12.0 + floor((backspaceButtonSize.height - imageSize.height) * 0.5)), size: imageSize))
                    }
                })
            }
            self.backspaceBackgroundView.frame = CGRect(origin: CGPoint(), size: backspaceButtonSize).insetBy(dx: -12.0, dy: -12.0)
            let backspaceButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - component.sideInset - backspaceButtonInset.right - backspaceButtonSize.width, y: resolvedHeight - component.bottomInset - backspaceButtonInset.bottom), size: backspaceButtonSize)
            
            if let backspaceButtonView = self.backspaceButton.view {
                if backspaceButtonView.superview == nil {
                    backspaceButtonView.addSubview(self.backspaceBackgroundView)
                    self.addSubview(backspaceButtonView)
                }
                transition.setPosition(view: backspaceButtonView, position: backspaceButtonFrame.center)
                transition.setBounds(view: backspaceButtonView, bounds: CGRect(origin: CGPoint(), size: backspaceButtonFrame.size))
                
                if component.backspace != nil {
                    transition.setAlpha(view: backspaceButtonView, alpha: 1.0)
                    transition.setScale(view: backspaceButtonView, scale: 1.0)
                } else {
                    transition.setAlpha(view: backspaceButtonView, alpha: 0.0)
                    transition.setScale(view: backspaceButtonView, scale: 0.001)
                }
            }
            
            self.keyboardView.parentState = state
            let keyboardSize = self.keyboardView.update(
                transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                component: AnyComponent(EntityKeyboardComponent(
                    theme: component.theme,
                    strings: component.strings,
                    isContentInFocus: true,
                    containerInsets: UIEdgeInsets(top: topPanelHeight - 34.0, left: component.sideInset, bottom: component.bottomInset + 16.0, right: component.sideInset),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.emojiContent?.withCustomTintColor(component.theme.list.itemPrimaryTextColor),
                    stickerContent: component.stickerContent?.withCustomTintColor(component.theme.list.itemPrimaryTextColor),
                    maskContent: nil,
                    gifContent: nil,
                    hasRecentGifs: false,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: true,
                    externalTopPanelContainer: self.panelHostView,
                    externalBottomPanelContainer: nil,
                    displayTopPanelBackground: .blur,
                    topPanelExtensionUpdated: { _, _ in },
                    topPanelScrollingOffset: { _, _ in },
                    hideInputUpdated: { _, _, _ in },
                    hideTopPanelUpdated: { [weak self] hideTopPanel, transition in
                        guard let self else {
                            return
                        }
                        if self.isSearchActive != hideTopPanel {
                            self.isSearchActive = hideTopPanel
                            self.state?.updated(transition: transition)
                        }
                    },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    reorderItems: { _, _ in },
                    makeSearchContainerNode: { _ in return nil },
                    contentIdUpdated: { _ in },
                    deviceMetrics: component.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    inputHeight: 0.0,
                    displayBottomPanel: false,
                    isExpanded: true,
                    clipContentToTopPanel: false,
                    useExternalSearchContainer: false,
                    customTintColor: component.backgroundIconColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: resolvedHeight)
            )
            if let keyboardComponentView = self.keyboardView.view {
                if keyboardComponentView.superview == nil {
                    self.keyboardClippingView.addSubview(keyboardComponentView)
                }
                
                if panelBackgroundColor.alpha < 0.01 {
                    self.keyboardClippingView.clipsToBounds = true
                } else {
                    self.keyboardClippingView.clipsToBounds = false
                }
                
                transition.setFrame(view: self.keyboardClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: availableSize.width, height: resolvedHeight - topPanelHeight)))
                
                transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topPanelHeight), size: keyboardSize))
                transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - 34.0), size: CGSize(width: keyboardSize.width, height: 0.0)))
                
                transition.setFrame(view: self.panelBackgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: keyboardSize.width, height: topPanelHeight)))
                self.panelBackgroundView.update(size: self.panelBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
                
                transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: keyboardSize.width, height: UIScreenPixel)))
                transition.setAlpha(view: self.panelSeparatorView, alpha: 1.0)
            }
            
            return CGSize(width: availableSize.width, height: resolvedHeight)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
