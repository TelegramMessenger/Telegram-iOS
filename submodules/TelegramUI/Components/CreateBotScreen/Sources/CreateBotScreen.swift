import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import ButtonComponent
import BundleIconComponent
import TelegramCore
import PresentationDataUtils
import ResizableSheetComponent
import GlassBarButtonComponent
import ListSectionComponent
import AvatarComponent
import ListMultilineTextFieldItemComponent
import Markdown

final class CreateBotContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    final class ExternalState {
        var name: String = ""
        var username: String = ""
        var usernameIsChecked: Bool = false
        
        init() {
        }
    }

    let externalState: ExternalState
    let context: AccountContext
    let parentPeer: EnginePeer
    let initialUsername: String?
    let initialTitle: String?

    init(
        externalState: ExternalState,
        context: AccountContext,
        parentPeer: EnginePeer,
        initialUsername: String?,
        initialTitle: String?
    ) {
        self.externalState = externalState
        self.context = context
        self.parentPeer = parentPeer
        self.initialUsername = initialUsername
        self.initialTitle = initialTitle
    }

    static func ==(lhs: CreateBotContentComponent, rhs: CreateBotContentComponent) -> Bool {
        return true
    }
    
    private enum UsernameCheckingStatus {
        case checking
        case valid
        case invalid
        case taken
    }

    final class View: UIView {
        private var component: CreateBotContentComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let nameSection = ComponentView<Empty>()
        private let usernameSection = ComponentView<Empty>()
        
        private let usernameInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let usernameInputTag = ListMultilineTextFieldItemComponent.Tag()
        private let nameInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let nameInputTag = ListMultilineTextFieldItemComponent.Tag()
        
        private var usernameCheckingStatus: (username: String, status: UsernameCheckingStatus)? {
            didSet {
                guard let component = self.component else {
                    return
                }
                component.externalState.usernameIsChecked = self.usernameCheckingStatus?.status == .valid
            }
        }
        private var usernameCheckingDisposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.usernameInputState.updated = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                component.externalState.username = self.usernameInputState.text.string
                
                self.inputUsernameUpdated()
                if !self.isUpdating {
                    self.state?.updated(transition: .immediate)
                }
            }
            self.nameInputState.updated = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                component.externalState.name = self.nameInputState.text.string
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.usernameCheckingDisposable?.dispose()
        }
        
        private func inputUsernameUpdated() {
            guard let component = self.component else {
                return
            }
            let username = self.usernameInputState.text.string.lowercased() + "bot"
            if let usernameCheckingStatus = self.usernameCheckingStatus, usernameCheckingStatus.username == username {
                return
            }
            self.usernameCheckingDisposable?.dispose()
            self.usernameCheckingDisposable = nil
            
            guard case .success = CreateBotSheetComponent.View.validatedUsername(inputUsername: username) else {
                self.usernameCheckingStatus = (username, .invalid)
                return
            }
            
            self.usernameCheckingStatus = (username, .checking)
            self.usernameCheckingDisposable = (component.context.engine.peers.addressNameAvailability(domain: .bot(component.parentPeer.id), name: username) |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case .available:
                    self.usernameCheckingStatus = (username, .valid)
                case .invalid:
                    self.usernameCheckingStatus = (username, .invalid)
                case .purchaseAvailable:
                    self.usernameCheckingStatus = (username, .invalid)
                case .taken:
                    self.usernameCheckingStatus = (username, .taken)
                }
                if !self.isUpdating {
                    self.state?.updated(transition: .immediate)
                }
            })
        }

        func update(component: CreateBotContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            let _ = alphaTransition
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            let isFirstTime = self.component == nil
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0

            var contentHeight: CGFloat = 0.0
            contentHeight += 32.0
            
            let avatarSize = self.avatar.update(
                transition: transition,
                component: AnyComponent(AvatarComponent(
                    context: component.context,
                    theme: environment.theme,
                    peer: component.parentPeer
                )),
                environment: {},
                containerSize: CGSize(width: 92.0, height: 92.0)
            )
            let avatarFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - avatarSize.width) * 0.5), y: contentHeight), size: avatarSize)
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                transition.setPosition(view: avatarView, position: avatarFrame.center)
                avatarView.bounds = CGRect(origin: CGPoint(), size: avatarFrame.size)
            }
            contentHeight += avatarSize.height
            contentHeight += 16.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.CreateBot_Title, font: Font.bold(24.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.12
                )),
                environment: {},
                containerSize: CGSize(width: min(280.0, availableSize.width - sideInset * 2.0), height: 1000.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            contentHeight += titleSize.height
            contentHeight += 10.0
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = environment.theme.actionSheet.primaryTextColor
            let linkColor = environment.theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor), linkAttribute: { contents in
                return ("URL", contents)
            })
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .markdown(text: environment.strings.CreateBot_Text(component.parentPeer.debugDisplayTitle).string, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.12
                )),
                environment: {},
                containerSize: CGSize(width: min(280.0, availableSize.width - sideInset * 2.0), height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
            }
            contentHeight += subtitleSize.height
            contentHeight += 24.0
            
            let nameSectionSize = self.nameSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreateBot_SectionName,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListMultilineTextFieldItemComponent(
                            externalState: self.nameInputState,
                            style: .glass,
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            initialText: "",
                            resetText: isFirstTime ? ListMultilineTextFieldItemComponent.ResetText(value: component.initialTitle ?? "") : nil,
                            placeholder: environment.strings.CreateBot_NamePlaceholder,
                            autocapitalizationType: .words,
                            autocorrectionType: .no,
                            characterLimit: 64,
                            rightAccessory: ListMultilineTextFieldItemComponent.RightAccessory(component: AnyComponentWithIdentity(
                                id: 0,
                                component: AnyComponent(EditLabelComponent(
                                    theme: environment.theme,
                                    strings: environment.strings,
                                    action: { [weak self] in
                                        guard let self, let itemView = self.nameSection.findTaggedView(tag: self.nameInputTag) as? ListMultilineTextFieldItemComponent.View else {
                                            return
                                        }
                                        itemView.activateInput()
                                    }
                                ))),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 0.0)
                            ),
                            emptyLineHandling: .notAllowed,
                            updated: { _ in },
                            textUpdateTransition: .immediate,
                            tag: self.nameInputTag
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let nameSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: nameSectionSize)
            self.nameSection.parentState = state
            if let nameSectionView = self.nameSection.view {
                if nameSectionView.superview == nil {
                    self.addSubview(nameSectionView)
                }
                transition.setFrame(view: nameSectionView, frame: nameSectionFrame)
            }
            contentHeight += nameSectionSize.height + 22.0
            
            var initialUsername = ""
            var botSuffix = "bot"
            if let value = component.initialUsername {
                if value.lowercased().hasSuffix("bot") {
                    botSuffix = String(value[value.index(value.endIndex, offsetBy: -3)...])
                    initialUsername = String(value[value.startIndex ..< value.index(value.endIndex, offsetBy: -3)])
                } else {
                    initialUsername = value
                }
            }
            
            let usernameFooterString: NSAttributedString
            switch CreateBotSheetComponent.View.validatedUsername(inputUsername: "\(self.usernameInputState.text.string)" + botSuffix) {
            case let .success(value):
                switch self.usernameCheckingStatus?.status ?? .valid {
                case .checking:
                    usernameFooterString = NSAttributedString(
                        string: environment.strings.CreateBot_UsernameStatus_Checking,
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.freeTextColor
                    )
                case .invalid:
                    let errorText = environment.strings.CreateBot_UsernameStatus_Invalid
                    usernameFooterString = parseMarkdownIntoAttributedString(errorText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemDestructiveColor), bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemDestructiveColor), link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemDestructiveColor), linkAttribute: { contents in
                        return ("URL", contents)
                    }))
                case .taken:
                    let errorText = environment.strings.CreateBot_UsernameStatus_Taken
                    usernameFooterString = parseMarkdownIntoAttributedString(errorText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemDestructiveColor), bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemDestructiveColor), link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemDestructiveColor), linkAttribute: { contents in
                        return ("URL", contents)
                    }))
                case .valid:
                    usernameFooterString = NSAttributedString(
                        string: environment.strings.CreateBot_UsernameStatus_Link(value).string,
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.freeTextColor
                    )
                }
            case let .failure(error):
                let errorText: String
                switch error {
                case .insufficientLength:
                    errorText = environment.strings.CreateBot_UsernameStatus_Short
                case .startsWithNumber:
                    errorText = environment.strings.CreateBot_UsernameStatus_Number
                case .unsupportedCharacters:
                    errorText = environment.strings.CreateBot_UsernameStatus_Invalid
                }
                usernameFooterString = parseMarkdownIntoAttributedString(errorText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemDestructiveColor), bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemDestructiveColor), link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemDestructiveColor), linkAttribute: { contents in
                    return ("URL", contents)
                }))
            }
            
            let usernameSectionSize = self.usernameSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.CreateBot_SectionUsername,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(usernameFooterString),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListMultilineTextFieldItemComponent(
                            externalState: usernameInputState,
                            style: .glass,
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            initialText: "",
                            resetText: isFirstTime ? ListMultilineTextFieldItemComponent.ResetText(value: initialUsername) : nil,
                            placeholder: "",
                            autocapitalizationType: .none,
                            autocorrectionType: .no,
                            keyboardType: .asciiCapable,
                            characterLimit: 32,
                            prefix: NSAttributedString(string: "@", font: Font.regular(17.0), textColor: environment.theme.list.itemPrimaryTextColor),
                            suffix: NSAttributedString(string: botSuffix, font: Font.regular(17.0), textColor: environment.theme.list.itemSecondaryTextColor),
                            rightAccessory: ListMultilineTextFieldItemComponent.RightAccessory(component: AnyComponentWithIdentity(
                                id: 0,
                                component: AnyComponent(EditLabelComponent(
                                    theme: environment.theme,
                                    strings: environment.strings,
                                    action: { [weak self] in
                                        guard let self, let itemView = self.usernameSection.findTaggedView(tag: self.usernameInputTag) as? ListMultilineTextFieldItemComponent.View else {
                                            return
                                        }
                                        itemView.activateInput()
                                    }
                                ))),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 0.0)
                            ),
                            emptyLineHandling: .notAllowed,
                            updated: { _ in },
                            textUpdateTransition: .immediate,
                            tag: self.usernameInputTag,
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let usernameSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: usernameSectionSize)
            self.usernameSection.parentState = state
            if let usernameSectionView = self.usernameSection.view {
                if usernameSectionView.superview == nil {
                    self.addSubview(usernameSectionView)
                }
                transition.setFrame(view: usernameSectionView, frame: usernameSectionFrame)
            }
            contentHeight += usernameSectionSize.height + 18.0
            
            contentHeight += 106.0
            contentHeight += environment.inputHeight
            
            component.externalState.name = self.nameInputState.text.string
            component.externalState.username = self.usernameInputState.text.string
            component.externalState.usernameIsChecked = self.usernameCheckingStatus?.status == .valid

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class CreateBotSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let parentPeer: EnginePeer
    let initialUsername: String?
    let initialTitle: String?
    let openAutomatically: Bool
    let completion: (EnginePeer.Id?) -> Void

    init(
        context: AccountContext,
        parentPeer: EnginePeer,
        initialUsername: String?,
        initialTitle: String?,
        openAutomatically: Bool,
        completion: @escaping (EnginePeer.Id?) -> Void
    ) {
        self.context = context
        self.parentPeer = parentPeer
        self.initialUsername = initialUsername
        self.initialTitle = initialTitle
        self.openAutomatically = openAutomatically
        self.completion = completion
    }

    static func ==(lhs: CreateBotSheetComponent, rhs: CreateBotSheetComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()
        private let contentExternalState = CreateBotContentComponent.ExternalState()

        private var component: CreateBotSheetComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?
        
        private var isCreating: Bool = false
        private var actionDisposable: Disposable?
        private var isCompleted: Bool = false

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.actionDisposable?.dispose()
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component else {
                return true
            }
            if self.isCreating {
                return false
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let _ = presentationData
            let alertController = textAlertController(
                context: component.context,
                title: presentationData.strings.CreateBot_UnsavedAlert_Title,
                text: presentationData.strings.CreateBot_UnsavedAlert_Text,
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    }),
                    TextAlertAction(type: .destructiveAction, title: presentationData.strings.CreateBot_UnsavedAlert_Discard, action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        if !self.isCompleted {
                            self.isCompleted = true
                            component.completion(nil)
                        }
                        let controller = self.environment?.controller
                        self.animateOut.invoke(Action { _ in
                            if let controller = controller?() {
                                controller.dismiss(completion: nil)
                            }
                        })
                    })
                ]
            )
            self.environment?.controller()?.present(alertController, in: .window(.root))
            
            return false
        }
        
        enum UsernameValidationError: Error {
            case insufficientLength
            case unsupportedCharacters
            case startsWithNumber
        }
        
        static func validatedUsername(inputUsername: String) -> Result<String, UsernameValidationError> {
            var isUsernameValid = true
            var usernameCharacters = CharacterSet(charactersIn: "a".unicodeScalars.first! ... "z".unicodeScalars.first!)
            usernameCharacters.insert(charactersIn: "A".unicodeScalars.first! ... "Z".unicodeScalars.first!)
            usernameCharacters.insert(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
            usernameCharacters.insert("_")
            for c in inputUsername.unicodeScalars {
                if !usernameCharacters.contains(c) {
                    isUsernameValid = false
                    break
                }
            }
            if !isUsernameValid {
                return .failure(.unsupportedCharacters)
            }
            if let first = inputUsername.unicodeScalars.first {
                if CharacterSet.decimalDigits.contains(first) {
                    return .failure(.startsWithNumber)
                }
            }
            if inputUsername.count < 5 {
                return .failure(.insufficientLength)
            }
            return .success(inputUsername)
        }
        
        static func validatedParams(inputName: String, inputUsername: String) -> (name: String, username: String)? {
            if inputName.isEmpty {
                return nil
            }
            guard case let .success(username) = validatedUsername(inputUsername: inputUsername) else {
                return nil
            }
            return (inputName, username)
        }
        
        private func validatedParams() -> (name: String, username: String)? {
            if !self.contentExternalState.usernameIsChecked {
                return nil
            }
            return CreateBotSheetComponent.View.validatedParams(inputName: contentExternalState.name, inputUsername: self.contentExternalState.username)
        }
        
        private func performCreateBot() {
            guard let component = self.component else {
                return
            }
            
            if self.isCreating {
                return
            }
            guard let params = self.validatedParams() else {
                return
            }
            
            self.isCreating = true
            self.state?.updated(transition: .immediate)
            
            self.actionDisposable?.dispose()
            self.actionDisposable = (component.context.engine.peers.createBot(
                name: params.name,
                username: params.username + "bot",
                managerPeerId: component.parentPeer.id,
                viaDeeplink: true
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] botPeer in
                guard let self, let component = self.component, let controller = self.environment?.controller(), let navigationController = controller.navigationController as? NavigationController else {
                    return
                }
                let context = component.context
                self.isCompleted = true
                self.animateOut.invoke(Action { [weak controller, weak navigationController] _ in
                    if let controller, let navigationController {
                        controller.dismiss(completion: { [weak navigationController] in
                            if component.openAutomatically, let navigationController {
                                component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                    navigationController: navigationController,
                                    context: context,
                                    chatLocation: .peer(botPeer)
                                ))
                            }
                            component.completion(botPeer.id)
                        })
                    }
                })
            }, error: { [weak self] error in
                Task { @MainActor in
                    guard let self, let environment = self.environment, let component = self.component else {
                        return
                    }
                    
                    self.isCreating = false
                    self.state?.updated(transition: .immediate)
                    
                    let text: String
                    switch error {
                    case .generic:
                        text = environment.strings.Login_UnknownError
                    case .occupied:
                        text = environment.strings.CreateBot_UsernameStatus_Taken
                    case .limitExceeded:
                        let isPremium = (await component.context.engine.data.get(
                            TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
                        ).get())?.isPremium ?? false
                        let limits = await component.context.engine.data.get(
                            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: isPremium)
                        ).get()
                        text = environment.strings.CreateBot_UsernameStatus_LimitExceeded(Int32(limits.maxBotsCreated))
                    }
                    
                    let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                    self.environment?.controller()?.push(textAlertController(
                        context: component.context,
                        title: nil,
                        text: text,
                        actions: [
                            .init(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                        ]
                    ))
                }
            })
        }

        func update(component: CreateBotSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let environmentValue = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environmentValue
            let controller = environmentValue.controller
            let theme = environmentValue.theme

            let dismiss: (Bool) -> Void = { [weak self] animated in
                guard let self, let component = self.component else {
                    return
                }
                if !self.isCompleted {
                    self.isCompleted = true
                    component.completion(nil)
                }
                if animated {
                    self.animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else {
                    if let controller = controller() {
                        controller.dismiss(completion: nil)
                    }
                }
            }

            let performMainAction: () -> Void = { [weak self] in
                guard let self else {
                    return
                }
                self.performCreateBot()
            }

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(CreateBotContentComponent(
                        externalState: self.contentExternalState,
                        context: component.context,
                        parentPeer: component.parentPeer,
                        initialUsername: component.initialUsername,
                        initialTitle: component.initialTitle
                    )),
                    titleItem: nil,
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(
                        ActionButtonsComponent(
                            theme: environmentValue.theme,
                            strings: environmentValue.strings,
                            isActionEnabled: !self.isCreating && self.validatedParams() != nil,
                            cancelAction: {
                                dismiss(true)
                            },
                            action: {
                                performMainAction()
                            }
                        )
                    ),
                    backgroundColor: .color(theme.list.blocksBackgroundColor),
                    animateOut: self.animateOut
                )),
                environment: {
                    environmentValue
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environmentValue.statusBarHeight,
                        safeInsets: environmentValue.safeInsets,
                        inputHeight: environmentValue.inputHeight,
                        metrics: environmentValue.metrics,
                        deviceMetrics: environmentValue.deviceMetrics,
                        isDisplaying: environmentValue.isVisible,
                        isCentered: environmentValue.metrics.widthClass == .regular,
                        screenSize: availableSize,
                        regularMetricsSize: nil,
                        dismiss: { [weak self] animated in
                            guard let self else {
                                return
                            }
                            if animated {
                                if !self.attemptNavigation(complete: {
                                    dismiss(animated)
                                }) {
                                    return
                                }
                            }
                            dismiss(animated)
                        }
                    )
                },
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class CreateBotScreen: ViewControllerComponentContainer {
    private let context: AccountContext

    public init?(
        context: AccountContext,
        parentBot: EnginePeer.Id,
        initialUsername: String?,
        initialTitle: String?,
        openAutomatically: Bool,
        completion: @escaping (EnginePeer.Id?) -> Void
    ) async {
        self.context = context
        
        guard let parentPeer = await context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: parentBot)
        ).get() else {
            return nil
        }
        
        super.init(
            context: context,
            component: CreateBotSheetComponent(
                context: context,
                parentPeer: parentPeer,
                initialUsername: initialUsername,
                initialTitle: initialTitle,
                openAutomatically: openAutomatically,
                completion: completion
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? CreateBotSheetComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class ActionButtonsComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let isActionEnabled: Bool
    let cancelAction: () -> Void
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        isActionEnabled: Bool,
        cancelAction: @escaping () -> Void,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.isActionEnabled = isActionEnabled
        self.cancelAction = cancelAction
        self.action = action
    }
    
    static func ==(lhs: ActionButtonsComponent, rhs: ActionButtonsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isActionEnabled != rhs.isActionEnabled {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let cancelButton = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private var component: ActionButtonsComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ActionButtonsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let spacing: CGFloat = 10.0
            let buttonWidth = floor((availableSize.width - spacing) * 0.5)
            
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1).blitOver(component.theme.list.blocksBackgroundColor, alpha: 1.0),
                        foreground: component.theme.actionSheet.primaryTextColor,
                        pressedColor: component.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1).withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: component.strings.Common_Cancel,
                            badge: 0,
                            textColor: component.theme.actionSheet.primaryTextColor,
                            badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: component.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.cancelAction()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: availableSize.height)
            )
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: component.strings.CreateBot_ActionButton,
                            badge: 0,
                            textColor: component.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: component.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: component.isActionEnabled,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.action()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - spacing - buttonWidth, height: availableSize.height)
            )
            
            let cancelButtonFrame = CGRect(origin: CGPoint(), size: cancelButtonSize)
            let actionButtonFrame = CGRect(origin: CGPoint(x: cancelButtonFrame.maxX + spacing, y: cancelButtonFrame.minY), size: actionButtonSize)
            
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }

            return CGSize(width: availableSize.width, height: max(cancelButtonSize.height, actionButtonSize.height))
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class EditLabelComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.action = action
    }
    
    static func ==(lhs: EditLabelComponent, rhs: EditLabelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let background = ComponentView<Empty>()
        
        private var component: EditLabelComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                component.action()
            }
        }
        
        func update(component: EditLabelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 7.0
            let verticalInset: CGFloat = 4.0
            let rightInset: CGFloat = 16.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.CreateBot_InputBadge, font: Font.regular(11.0), textColor: component.theme.list.itemAccentColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let backgroundSize = CGSize(width: titleSize.width + sideInset * 2.0, height: titleSize.height + verticalInset * 2.0)
            let size = CGSize(width: backgroundSize.width + rightInset, height: backgroundSize.height)
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - backgroundSize.height) * 0.5)), size: backgroundSize)
            let titleFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floorToScreenPixels((backgroundSize.width - titleSize.width) * 0.5), y: backgroundFrame.minY + floorToScreenPixels((backgroundSize.height - titleSize.height) * 0.5) - UIScreenPixel), size: titleSize)
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                    cornerRadius: .minEdge,
                    smoothCorners: false
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    backgroundView.isUserInteractionEnabled = false
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
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
