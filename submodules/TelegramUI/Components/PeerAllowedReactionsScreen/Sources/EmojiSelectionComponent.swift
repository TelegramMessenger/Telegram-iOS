import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import EntityKeyboard
import AccountContext
import PagerComponent

public final class EmojiSelectionComponent: Component {
    public typealias EnvironmentType = Empty
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let sideInset: CGFloat
    public let bottomInset: CGFloat
    public let deviceMetrics: DeviceMetrics
    public let emojiContent: EmojiPagerContentComponent
    public let backgroundIconColor: UIColor?
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        sideInset: CGFloat,
        bottomInset: CGFloat,
        deviceMetrics: DeviceMetrics,
        emojiContent: EmojiPagerContentComponent,
        backgroundIconColor: UIColor?,
        backgroundColor: UIColor,
        separatorColor: UIColor
    ) {
        self.theme = theme
        self.strings = strings
        self.sideInset = sideInset
        self.bottomInset = bottomInset
        self.deviceMetrics = deviceMetrics
        self.emojiContent = emojiContent
        self.backgroundIconColor = backgroundIconColor
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
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
        if lhs.backgroundIconColor != rhs.backgroundIconColor {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
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
        
        private var component: EmojiSelectionComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.keyboardView = ComponentView<Empty>()
            self.keyboardClippingView = UIView()
            self.panelHostView = PagerExternalTopPanelContainer()
            self.panelBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.panelSeparatorView = UIView()
            self.shadowView = UIImageView()
            self.cornersView = UIImageView()
            
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
        
        func update(component: EmojiSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.backgroundColor = component.backgroundColor
            let panelBackgroundColor = component.backgroundColor.withMultipliedAlpha(0.85)
            self.panelBackgroundView.updateColor(color: panelBackgroundColor, transition: .immediate)
            self.panelSeparatorView.backgroundColor = component.separatorColor
            
            self.component = component
            self.state = state
            
            self.cornersView.tintColor = component.theme.list.blocksBackgroundColor
            transition.setFrame(view: self.cornersView, frame: CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: CGSize(width: availableSize.width, height: 16.0)))
            
            transition.setFrame(view: self.shadowView, frame: CGRect(origin: CGPoint(x: 0.0, y: -8.0), size: CGSize(width: availableSize.width, height: 16.0)))
            
            let topPanelHeight: CGFloat = 42.0
            
            let keyboardSize = self.keyboardView.update(
                transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                component: AnyComponent(EntityKeyboardComponent(
                    theme: component.theme,
                    strings: component.strings,
                    isContentInFocus: false,
                    containerInsets: UIEdgeInsets(top: topPanelHeight - 34.0, left: component.sideInset, bottom: component.bottomInset, right: component.sideInset),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.emojiContent,
                    stickerContent: nil,
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
                    hideTopPanelUpdated: { _, _ in },
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
                containerSize: availableSize
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
                
                transition.setFrame(view: self.keyboardClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: availableSize.width, height: availableSize.height - topPanelHeight)))
                
                transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topPanelHeight), size: keyboardSize))
                transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - 34.0), size: CGSize(width: keyboardSize.width, height: 0.0)))
                
                transition.setFrame(view: self.panelBackgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: keyboardSize.width, height: topPanelHeight)))
                self.panelBackgroundView.update(size: self.panelBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
                
                transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: keyboardSize.width, height: UIScreenPixel)))
                transition.setAlpha(view: self.panelSeparatorView, alpha: 1.0)
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
