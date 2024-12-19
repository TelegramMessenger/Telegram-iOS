import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import AccountContext
import PresentationDataUtils
import PremiumPeerShortcutComponent
import GiftAnimationComponent

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let botName: String
    let accountPeer: EnginePeer
    let file: TelegramMediaFile
    let duration: Int32?
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        botName: String,
        accountPeer: EnginePeer,
        file: TelegramMediaFile,
        duration: Int32?,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.botName = botName
        self.accountPeer = accountPeer
        self.file = file
        self.duration = duration
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.botName != rhs.botName {
            return false
        }
        if lhs.file != rhs.file {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedCloseImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }
        
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let animation = Child(GiftAnimationComponent.self)
        let closeButton = Child(Button.self)
        let title = Child(Text.self)
        let text = Child(BalancedTextComponent.self)
        
        let peerShortcut = Child(PremiumPeerShortcutComponent.self)
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme
            let strings = presentationData.strings
                        
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.actionSheet.opaqueItemBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )

            let animation = animation.update(
                component: GiftAnimationComponent(
                    context: component.context,
                    theme: environment.theme,
                    file: component.file
                ),
                availableSize: CGSize(width: 128.0, height: 128.0),
                transition: .immediate
            )
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: animation.size.height / 2.0 + 12.0))
            )
            
            let closeImage: UIImage
            if let (image, cacheTheme) = state.cachedCloseImage, theme === cacheTheme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - closeButton.size.width, y: 28.0))
            )
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            contentSize.height += 128.0
            
            let title = title.update(
                component: Text(text: strings.WebApp_Emoji_Title, font: Font.bold(24.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 13.0
                          
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            var textString: String
            if let duration = component.duration {
                let durationString = scheduledTimeIntervalString(strings: strings, value: duration)
                textString = strings.WebApp_Emoji_DurationText(component.botName, durationString).string
            } else {
                textString = strings.WebApp_Emoji_Text(component.botName).string
            }
                        
            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: textString,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += 15.0
            
            let peerShortcut = peerShortcut.update(
                component: PremiumPeerShortcutComponent(
                    context: component.context,
                    theme: theme,
                    peer: component.accountPeer,
                    icon: component.file
                ),
                availableSize: CGSize(width: context.availableSize.width - 32.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(peerShortcut
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + peerShortcut.size.height / 2.0))
            )
            contentSize.height += peerShortcut.size.height
            contentSize.height += 32.0
            
            let controller = environment.controller() as? WebAppSetEmojiStatusScreen
                        
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.WebApp_Emoji_Confirm, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak controller] in
                        controller?.complete(result: true)
                        controller?.dismissAnimated()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 16.0 * 2.0, height: 50),
                transition: .immediate
            )
            context.add(button
                .clipsToBounds(true)
                .cornerRadius(10.0)
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
 
            contentSize.height += 48.0
            
            return contentSize
        }
    }
}

private final class WebAppSetEmojiStatusSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let botName: String
    private let accountPeer: EnginePeer
    private let file: TelegramMediaFile
    private let duration: Int32?
    
    init(
        context: AccountContext,
        botName: String,
        accountPeer: EnginePeer,
        file: TelegramMediaFile,
        duration: Int32?
    ) {
        self.context = context
        self.botName = botName
        self.accountPeer = accountPeer
        self.file = file
        self.duration = duration
    }
    
    static func ==(lhs: WebAppSetEmojiStatusSheetComponent, rhs: WebAppSetEmojiStatusSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.botName != rhs.botName {
            return false
        }
        if lhs.accountPeer != rhs.accountPeer {
            return false
        }
        if lhs.duration != rhs.duration {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        botName: context.component.botName,
                        accountPeer: context.component.accountPeer,
                        file: context.component.file,
                        duration: context.component.duration,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() as? WebAppSetEmojiStatusScreen {
                                    controller.complete(result: false)
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() as? WebAppSetEmojiStatusScreen {
                                        controller.complete(result: false)
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() as? WebAppSetEmojiStatusScreen {
                                    controller.complete(result: false)
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class WebAppSetEmojiStatusScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let completion: (Bool) -> Void
        
    public init(
        context: AccountContext,
        botName: String,
        accountPeer: EnginePeer,
        file: TelegramMediaFile,
        duration: Int32?,
        completion: @escaping (Bool) -> Void
    ) {
        self.context = context
        self.completion = completion
                
        super.init(
            context: context,
            component: WebAppSetEmojiStatusSheetComponent(
                context: context,
                botName: botName,
                accountPeer: accountPeer,
                file: file,
                duration: duration
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var didComplete = false
    fileprivate func complete(result: Bool) {
        guard !self.didComplete else {
            return
        }
        self.didComplete = true
        self.completion(result)
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}
