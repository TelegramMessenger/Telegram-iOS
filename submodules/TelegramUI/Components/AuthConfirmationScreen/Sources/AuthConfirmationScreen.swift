import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import GlassBarButtonComponent
import ButtonComponent
import PlainButtonComponent
import PresentationDataUtils
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import AvatarComponent
import Markdown
import PhoneNumberFormat
import ContextUI
import AccountUtils
import GlassBackgroundComponent
import AccountPeerContextItem
import ActivityIndicator
import LottieComponent
import LottieComponentResourceContent

private final class AuthConfirmationSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let requestSubject: MessageActionUrlSubject
    let subject: MessageActionUrlAuthResult
    let completion: (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void
    let cancel: (Bool) -> Void
    
    init(
        context: AccountContext,
        requestSubject: MessageActionUrlSubject,
        subject: MessageActionUrlAuthResult,
        completion: @escaping (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void,
        cancel: @escaping  (Bool) -> Void
    ) {
        self.context = context
        self.requestSubject = requestSubject
        self.subject = subject
        self.completion = completion
        self.cancel = cancel
    }
    
    static func ==(lhs: AuthConfirmationSheetContent, rhs: AuthConfirmationSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let requestSubject: MessageActionUrlSubject
        fileprivate var subject: MessageActionUrlAuthResult
        private let completion: (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void
        
        private let disposables = DisposableSet()
        private let accountInUseDisposable = MetaDisposable()
        
        var canSwitchAccount = false
        var forcedAccount: (AccountContext, EnginePeer)?
        var peer: EnginePeer?
        
        fileprivate var inProgress = false
        var allowWrite = true
        weak var controller: ViewController?
        
        var displayEmoji = false
        var matchCodes: [String]?
        var selectedMatchCode: String?
        
        init(context: AccountContext, requestSubject: MessageActionUrlSubject, subject: MessageActionUrlAuthResult, completion: @escaping (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void) {
            self.context = context
            self.requestSubject = requestSubject
            self.subject = subject
            self.completion = completion
                        
            super.init()
            
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                self.peer = peer
                self.updated()
            })
            
            if case let .request(_, _, _, flags, matchCodes, _) = self.subject, let matchCodes {
                if flags.contains(.showMatchCodesFirst) {
                    self.displayEmoji = true
                    self.matchCodes = matchCodes.shuffled()
                } else {
                    for code in matchCodes {
                        var file: TelegramMediaFile?
                        if let item = context.animatedEmojiStickersValue[code] {
                            file = item.first?.file._parse()
                        } else if let item = context.animatedEmojiStickersValue[code.strippedEmoji] {
                            file = item.first?.file._parse()
                        }
                        if let file {
                            self.disposables.add(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                        }
                    }
                }
            }
            
            if case let .request(_, _, _, _, _, userIdHint) = self.subject {
                let isTestEnvironment = context.account.testingEnvironment
                let _ = (activeAccountsAndPeers(context: self.context, includePrimary: true)
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] primary, other in
                    guard let self else {
                        return
                    }
                    
                    var accountCount = 0
                    for (accountContext, peer, _) in other {
                        if accountContext.account.testingEnvironment == isTestEnvironment {
                            accountCount += 1
                        }
                        if let userIdHint, userIdHint != context.account.peerId {
                            if peer.id == userIdHint {
                                self.forcedAccount = (accountContext, peer)
                                
                                self.accountInUseDisposable.set(self.context.sharedContext.setAccountUserInterfaceInUse(accountContext.account.id))
                                
                                let _ = (accountContext.engine.messages.requestMessageActionUrlAuth(subject: requestSubject)
                                |> deliverOnMainQueue).start(next: { [weak self] result in
                                    guard let self, case .request = result else {
                                        return
                                    }
                                    self.subject = result
                                    if case let .request(_, _, _, flags, _, _) = result, !flags.contains(.showMatchCodesFirst) {
                                        self.displayEmoji = false
                                        self.matchCodes = nil
                                    }
                                    self.updated()
                                })
                            }
                        }
                    }
                    self.canSwitchAccount = accountCount > 0
                    self.updated()
                })
            }
        }
        
        deinit {
            self.disposables.dispose()
            
            if !self.inProgress {
                self.accountInUseDisposable.dispose()
            }
        }
        
        func complete(matchCode: String?) {
            guard case let .request(_, _, _, flags, _, _) = self.subject else {
                return
            }
            
            var allowWrite = false
            if flags.contains(.requestWriteAccess) && self.allowWrite {
                allowWrite = true
            }
            
            let accountContext = self.forcedAccount?.0 ?? self.context
            guard let accountPeer = self.forcedAccount?.1 ?? self.peer else {
                return
            }
            
            if flags.contains(.requestPhoneNumber) {
                self.displayPhoneNumberConfirmation(commit: { sharePhoneNumber in
                    self.completion(accountContext, accountPeer, .accept(allowWriteAccess: allowWrite, sharePhoneNumber: sharePhoneNumber, matchCode: matchCode), self.accountInUseDisposable)
                    self.inProgress = true
                    self.selectedMatchCode = matchCode
                    self.updated()
                })
            } else {
                self.completion(accountContext, accountPeer, .accept(allowWriteAccess: allowWrite, sharePhoneNumber: false, matchCode: matchCode), self.accountInUseDisposable)
                self.inProgress = true
                self.selectedMatchCode = matchCode
                self.updated()
            }
        }
        
        func checkMatchCode(_ matchCode: String) {
            guard case let .url(url, _) = self.requestSubject else {
                return
            }
            self.selectedMatchCode = matchCode
            self.updated(transition: .easeInOut(duration: 0.2))
            
            let _ = (self.context.engine.messages.checkUrlAuthMatchCode(url: url, matchCode: matchCode)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                if result {
                    self.displayEmoji = false
                    self.updated(transition: .spring(duration: 0.4))
                } else {
                    let accountContext = self.forcedAccount?.0 ?? self.context
                    guard let accountPeer = self.forcedAccount?.1 ?? self.peer else {
                        return
                    }
                    
                    self.completion(accountContext, accountPeer, .failed, self.accountInUseDisposable)
                }
            })
        }
        
        func displayPhoneNumberConfirmation(commit: @escaping (Bool) -> Void) {
            guard case let .request(domain, _, clientData, _, _, _) = self.subject else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let sourceTitle: String
            if let clientData, clientData.isApp {
                if let appName = clientData.appName {
                    sourceTitle = appName
                } else {
                    sourceTitle = presentationData.strings.AuthConfirmation_UnverifiedApp
                }
            } else {
                sourceTitle = domain
            }
            
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, case let .user(user) = peer, let phone = user.phone else {
                    return
                }
                let phoneNumber = formatPhoneNumber(context: self.context, number: phone).replacingOccurrences(of: " ", with: "\u{00A0}")
                
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Title,
                    text: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Text(sourceTitle, phoneNumber).string,
                    actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Deny, action: {
                            commit(false)
                        }),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Allow, action: {
                            commit(true)
                        })
                    ]
                )
                self.controller?.present(alertController, in: .window(.root))
            })
        }
        
        func presentAccountSwitchMenu(sourceView: GlassContextExtractableContainer) {
            guard let controller = self.controller else {
                return
            }
            
            let context = self.context
            let isTestEnvironment = context.account.testingEnvironment
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let items: Signal<[ContextMenuItem], NoError> = activeAccountsAndPeers(context: self.context, includePrimary: true)
            |> take(1)
            |> map { primary, other -> [ContextMenuItem] in
                var items: [ContextMenuItem] = []
                var existingIds = Set<EnginePeer.Id>()
                if let (_, peer) = primary {
                    items.append(.custom(AccountPeerContextItem(context: context, account: context.account, peer: peer, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        
                        self.accountInUseDisposable.set(nil)
                        
                        self.forcedAccount = nil
                        self.updated()
                    }), true))
                    existingIds.insert(peer.id)
                }
                
                for (accountContext, peer, _) in other {
                    guard !existingIds.contains(peer.id), accountContext.account.testingEnvironment == isTestEnvironment else {
                        continue
                    }
                    items.append(.custom(AccountPeerContextItem(context: accountContext, account: accountContext.account, peer: peer, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        self.accountInUseDisposable.set(self.context.sharedContext.setAccountUserInterfaceInUse(accountContext.account.id))
                        
                        self.forcedAccount = (accountContext, peer)
                        self.updated()
                        
                        let _ = (accountContext.engine.messages.requestMessageActionUrlAuth(subject: self.requestSubject)
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let self, case .request = result else {
                                return
                            }
                            self.subject = result
                            self.updated()
                        })
                    }), true))
                }
                
                return items
            }

            let contextController = makeContextController(presentationData: presentationData, source: .reference(AuthConfirmationReferenceContentSource(controller: controller, sourceView: sourceView)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, requestSubject: self.requestSubject, subject: self.subject, completion: self.completion)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let accountButton = Child(AccountSwitchComponent.self)
        let avatar = Child(AvatarComponent.self)
        let title = Child(MultilineTextComponent.self)
        let description = Child(MultilineTextComponent.self)
        
        let emojiTitle = Child(MultilineTextComponent.self)
        let emojiDescription = Child(MultilineTextComponent.self)
        let emojis = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        
        let clientSection = Child(ListSectionComponent.self)
        let optionsSection = Child(ListSectionComponent.self)
        let cancelButton = Child(ButtonComponent.self)
        let doneButton = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let state = context.state
            if state.controller == nil {
                state.controller = environment.controller()
            }
            
            let presentationData = context.component.context.sharedContext.currentPresentationData.with { $0 }
            
            guard case let .request(domain, bot, clientData, flags, matchCodes, _) = state.subject else {
                fatalError()
            }
            
            let sourceTitle: String
            if let clientData, clientData.isApp {
                if let appName = clientData.appName {
                    sourceTitle = appName
                } else {
                    sourceTitle = strings.AuthConfirmation_UnverifiedApp
                }
            } else {
                sourceTitle = domain
            }

            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
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
                        component.cancel(true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            if let peer = state.peer {
                let accountButton = accountButton.update(
                    component: AccountSwitchComponent(
                        context: state.forcedAccount?.0 ?? component.context,
                        theme: environment.theme,
                        peer: state.forcedAccount?.1 ?? peer,
                        canSwitch: state.canSwitchAccount,
                        isVisible: true,
                        action: { [weak state] sourceView in
                            state?.presentAccountSwitchMenu(sourceView: sourceView)
                        }
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(accountButton
                    .position(CGPoint(x: context.availableSize.width - 16.0 - accountButton.size.width / 2.0, y: 16.0 + accountButton.size.height / 2.0))
                )
            }
            
            let titleFont = Font.bold(24.0)
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
        
            var contentHeight: CGFloat = 32.0
            
            if state.displayEmoji, let matchCodes = state.matchCodes {
                contentHeight += 36.0
                
                let emojiTitle = emojiTitle.update(
                    component: MultilineTextComponent(
                        text: .markdown(text: strings.AuthConfirmation_Emoji_Title, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.controlAccentColor), link: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(emojiTitle
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + emojiTitle.size.height / 2.0))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                contentHeight += emojiTitle.size.height
                contentHeight += 16.0
                
                let emojiDescriptionString: String
                if flags.contains(.showMatchCodesFirst) {
                    emojiDescriptionString = strings.AuthConfirmation_Emoji_DescriptionFirst(sourceTitle).string
                } else {
                    emojiDescriptionString = strings.AuthConfirmation_Emoji_Description
                }
                
                let emojiDescription = emojiDescription.update(
                    component: MultilineTextComponent(
                        text: .markdown(text: emojiDescriptionString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: theme.actionSheet.primaryTextColor), link: MarkdownAttributeSet(font: textFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(emojiDescription
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + emojiDescription.size.height / 2.0))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                contentHeight += emojiDescription.size.height
                contentHeight += 48.0
                
                var emojiDelay: Double = 0.0
                let emojiSize = CGSize(width: 64.0, height: 64.0)
                let emojiSpacing: CGFloat = 36.0
                let totalWidth = CGFloat(matchCodes.count) * emojiSize.width + CGFloat(matchCodes.count - 1) * emojiSpacing
                var emojiOriginX = context.availableSize.width / 2.0 - totalWidth / 2.0
                for code in matchCodes {
                    var items: [AnyComponentWithIdentity<Empty>] = []
                    items.append(
                        AnyComponentWithIdentity(id: "background", component: AnyComponent(
                            FilledRoundedRectangleComponent(color: theme.list.itemBlocksBackgroundColor, cornerRadius: .minEdge, smoothCorners: false)
                        ))
                    )
                    if state.selectedMatchCode == code {
                        items.append(
                            AnyComponentWithIdentity(id: "progress", component: AnyComponent(
                                ActivityIndicatorComponent(color: theme.list.itemAccentColor)
                            ))
                        )
                    }
                    
                    var file: TelegramMediaFile?
                    if let item = component.context.animatedEmojiStickersValue[code] {
                        file = item.first?.file._parse()
                    } else if let item = component.context.animatedEmojiStickersValue[code.strippedEmoji] {
                        file = item.first?.file._parse()
                    }
                    if let file {
                        items.append(
                            AnyComponentWithIdentity(id: "animatedIcon", component: AnyComponent(
                                LottieComponent(content: LottieComponent.ResourceContent(context: component.context, file: file, attemptSynchronously: true, providesPlaceholder: true), placeholderColor: theme.list.mediaPlaceholderColor, startingPosition: .begin, size: CGSize(width: 32.0, height: 32.0), loop: true, playOnce: nil)
                            ))
                        )
                    } else {
                        items.append(
                            AnyComponentWithIdentity(id: "staticIcon", component: AnyComponent(
                                Text(text: code, font: Font.regular(32.0), color: .black)
                            ))
                        )
                    }
                    
                    let subject = state.subject
                    let emoji = emojis[code].update(
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    ZStack(items)
                                ),
                                minSize: emojiSize,
                                action: { [weak state] in
                                    guard let state else {
                                        return
                                    }
                                    if case let .request(_, _, _, flags, _, _) = subject, flags.contains(.showMatchCodesFirst) {
                                        state.checkMatchCode(code)
                                    } else {
                                        state.complete(matchCode: code)
                                    }
                                },
                                isEnabled: state.selectedMatchCode == nil,
                                animateAlpha: false,
                                animateScale: true
                            )
                        ),
                        environment: {},
                        availableSize: emojiSize,
                        transition: context.transition
                    )
                    context.add(emoji
                        .position(CGPoint(x: emojiOriginX + emojiSize.width / 2.0, y: contentHeight + emojiSize.height / 2.0))
                        .opacity(state.selectedMatchCode != nil && state.selectedMatchCode != code ? 0.6 : 1.0)
                        .appear(ComponentTransition.Appear({ _, view, transition in
                            if !transition.animation.isImmediate {
                                transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: emojiDelay)
                                transition.animateScale(view: view, from: 0.01, to: 1.0, delay: emojiDelay)
                            }
                        }))
                        .disappear(.default(scale: true, alpha: true))
                    )
                    emojiOriginX += emojiSize.width + emojiSpacing
                    emojiDelay += 0.08
                }
                
                contentHeight += emojiSize.height
                contentHeight += 48.0
            } else {
                let avatar = avatar.update(
                    component: AvatarComponent(
                        context: component.context,
                        theme: environment.theme,
                        peer: EnginePeer(bot),
                        clipStyle: .roundedRect
                    ),
                    availableSize: CGSize(width: 92.0, height: 92.0),
                    transition: .immediate
                )
                context.add(avatar
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + avatar.size.height / 2.0))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                contentHeight += avatar.size.height
                contentHeight += 18.0
                                
                let title = title.update(
                    component: MultilineTextComponent(
                        text: .markdown(text: strings.AuthConfirmation_Title(sourceTitle).string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.controlAccentColor), link: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + title.size.height / 2.0))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                contentHeight += title.size.height
                contentHeight += 16.0
                
                let descriptionString: String
                if let clientData, clientData.isApp {
                    descriptionString = strings.AuthConfirmation_DescriptionApp
                } else {
                    descriptionString = strings.AuthConfirmation_Description
                }
                
                let description = description.update(
                    component: MultilineTextComponent(
                        text: .markdown(text: descriptionString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: theme.actionSheet.primaryTextColor), link: MarkdownAttributeSet(font: textFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(description
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + description.size.height / 2.0))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                contentHeight += description.size.height
                contentHeight += 16.0
                
                var clientSectionItems: [AnyComponentWithIdentity<Empty>] = []
                clientSectionItems.append(
                    AnyComponentWithIdentity(id: "device", component: AnyComponent(
                        ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthConfirmation_Device,
                                    font: Font.regular(17.0),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )),
                            contentInsets: UIEdgeInsets(top: 19.0, left: 0.0, bottom: 19.0, right: 0.0),
                            accessory: .custom(ListActionItemComponent.CustomAccessory(
                                component: AnyComponentWithIdentity(
                                    id: "info",
                                    component: AnyComponent(
                                        VStack([
                                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                                text: .plain(NSAttributedString(
                                                    string: clientData?.platform ?? "",
                                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                                    textColor: theme.list.itemPrimaryTextColor
                                                )),
                                                maximumNumberOfLines: 1
                                            ))),
                                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                                text: .plain(NSAttributedString(
                                                    string: clientData?.browser ?? "",
                                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 15.0),
                                                    textColor: theme.list.itemSecondaryTextColor
                                                )),
                                                horizontalAlignment: .left,
                                                truncationType: .middle,
                                                maximumNumberOfLines: 1
                                            )))
                                        ], alignment: .right, spacing: 3.0)
                                    )
                                ),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                                isInteractive: true
                            )),
                            action: nil
                        )
                    ))
                )
                
                clientSectionItems.append(
                    AnyComponentWithIdentity(id: "region", component: AnyComponent(
                        ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthConfirmation_IpAddress,
                                    font: Font.regular(17.0),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )),
                            contentInsets: UIEdgeInsets(top: 19.0, left: 0.0, bottom: 19.0, right: 0.0),
                            accessory: .custom(ListActionItemComponent.CustomAccessory(
                                component: AnyComponentWithIdentity(
                                    id: "info",
                                    component: AnyComponent(
                                        VStack([
                                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                                text: .plain(NSAttributedString(
                                                    string: clientData?.ip ?? "",
                                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                                    textColor: theme.list.itemPrimaryTextColor
                                                )),
                                                maximumNumberOfLines: 1
                                            ))),
                                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                                text: .plain(NSAttributedString(
                                                    string: clientData?.region ?? "",
                                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 15.0),
                                                    textColor: theme.list.itemSecondaryTextColor
                                                )),
                                                horizontalAlignment: .left,
                                                truncationType: .middle,
                                                maximumNumberOfLines: 1
                                            )))
                                        ], alignment: .right, spacing: 3.0)
                                    )
                                ),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                                isInteractive: true
                            )),
                            action: nil
                        )
                    ))
                )
                
                let clientSection = clientSection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AuthConfirmation_Info,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: clientSectionItems
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(clientSection
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + clientSection.size.height / 2.0))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
                contentHeight += clientSection.size.height
                
                if flags.contains(.requestWriteAccess) {
                    contentHeight += 38.0
                    
                    var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
                    optionsSectionItems.append(AnyComponentWithIdentity(id: "allowWrite", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthConfirmation_AllowMessages,
                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: state.allowWrite, action: { [weak state] _ in
                            guard let state else {
                                return
                            }
                            state.allowWrite = !state.allowWrite
                            state.updated()
                        })),
                        action: nil
                    ))))
                    let optionsSection = optionsSection.update(
                        component: ListSectionComponent(
                            theme: theme,
                            style: .glass,
                            header: nil,
                            footer: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthConfirmation_AllowMessagesInfo(EnginePeer(bot).compactDisplayTitle).string,
                                    font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                    textColor: environment.theme.list.freeTextColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            items: optionsSectionItems
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                        transition: context.transition
                    )
                    context.add(optionsSection
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + optionsSection.size.height / 2.0))
                        .appear(.default(scale: false, alpha: true))
                        .disappear(.default(scale: false, alpha: true))
                    )
                    contentHeight += optionsSection.size.height
                }
                contentHeight += 32.0
            }
    
            let buttonSpacing: CGFloat = 10.0
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            var buttonWidth = context.availableSize.width - buttonInsets.left - buttonInsets.right
            if !state.displayEmoji {
                buttonWidth = (buttonWidth - buttonSpacing) / 2.0
            }
            
            let cancelButton = cancelButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                        foreground: theme.list.itemPrimaryTextColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.AuthConfirmation_Cancel, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center))))
                    ),
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        let accountContext = state.forcedAccount?.0 ?? component.context
                        guard let accountPeer = state.forcedAccount?.1 ?? state.peer else {
                            return
                        }
                        component.completion(accountContext, accountPeer, .decline, EmptyDisposable)
                        component.cancel(true)
                    }
                ),
                availableSize: CGSize(width: buttonWidth, height: 52.0),
                transition: context.transition
            )
            context.add(cancelButton
                .position(CGPoint(x: state.displayEmoji ? context.availableSize.width / 2.0 : context.availableSize.width / 2.0 - buttonSpacing / 2.0 - cancelButton.size.width / 2.0, y: contentHeight + cancelButton.size.height / 2.0))
            )
            
            let doneButton = doneButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0,
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.AuthConfirmation_LogIn, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    displaysProgress: state.inProgress,
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        if !flags.contains(.showMatchCodesFirst), let matchCodes, !matchCodes.isEmpty {
                            state.displayEmoji = true
                            state.matchCodes = matchCodes.shuffled()
                            state.updated(transition: .spring(duration: 0.4))
                        } else {
                            state.complete(matchCode: state.selectedMatchCode)
                        }
                    }
                ),
                availableSize: CGSize(width: buttonWidth, height: 52.0),
                transition: context.transition
            )
            context.add(doneButton
                .position(CGPoint(x: context.availableSize.width / 2.0 + buttonSpacing / 2.0 + doneButton.size.width / 2.0, y: contentHeight + doneButton.size.height / 2.0))
                .opacity(state.displayEmoji ? 0.0 : 1.0)
                .scale(state.displayEmoji ? 0.01 : 1.0)
            )
            
            contentHeight += cancelButton.size.height
            contentHeight += buttonInsets.bottom
          
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class AuthConfirmationSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let requestSubject: MessageActionUrlSubject
    let subject: MessageActionUrlAuthResult
    let completion: (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void
    
    init(
        context: AccountContext,
        requestSubject: MessageActionUrlSubject,
        subject: MessageActionUrlAuthResult,
        completion: @escaping (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void
    ) {
        self.context = context
        self.requestSubject = requestSubject
        self.subject = subject
        self.completion = completion
    }
    
    static func ==(lhs: AuthConfirmationSheetComponent, rhs: AuthConfirmationSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(AuthConfirmationSheetContent(
                        context: context.component.context,
                        requestSubject: context.component.requestSubject,
                        subject: context.component.subject,
                        completion: context.component.completion,
                        cancel: { animate in
                            if animate {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else if let controller = controller() {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
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

public class AuthConfirmationScreen: ViewControllerComponentContainer {
    public enum Result {
        case accept(allowWriteAccess: Bool, sharePhoneNumber: Bool, matchCode: String?)
        case decline
        case failed
    }
    
    private let context: AccountContext
    private let requestSubject: MessageActionUrlSubject
    private let subject: MessageActionUrlAuthResult
    fileprivate let completion: (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void
    
    public init(
        context: AccountContext,
        requestSubject: MessageActionUrlSubject,
        subject: MessageActionUrlAuthResult,
        completion: @escaping (AccountContext, EnginePeer, AuthConfirmationScreen.Result, Disposable) -> Void
    ) {
        self.context = context
        self.requestSubject = requestSubject
        self.subject = subject
        self.completion = completion
        
        super.init(
            context: context,
            component: AuthConfirmationSheetComponent(
                context: context,
                requestSubject: requestSubject,
                subject: subject,
                completion: completion
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
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class AuthConfirmationReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    let forceDisplayBelowKeyboard = true
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ActivityIndicatorComponent: Component {
    let color: UIColor
    
    init(
        color: UIColor
    ) {
        self.color = color
    }

    static func ==(lhs: ActivityIndicatorComponent, rhs: ActivityIndicatorComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let background = UIView()
        private let activityIndicator: ActivityIndicator
        
        private var component: ActivityIndicatorComponent?
        
        override init(frame: CGRect) {
            self.activityIndicator = ActivityIndicator(type: .custom(.white, 64.0, 2.0, true))
            
            super.init(frame: frame)
            
            
            self.addSubview(self.background)
            self.addSubview(self.activityIndicator.view)
        }
        
        required public init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ActivityIndicatorComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let size = CGSize(width: 64.0, height: 64.0)
            
            self.background.backgroundColor = component.color.withMultipliedAlpha(0.1)
            self.background.layer.cornerRadius = 32.0
            self.background.clipsToBounds = true
            
            if self.component == nil {
                self.activityIndicator.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            self.component = component
            
            self.background.frame = CGRect(origin: .zero, size: size)
            self.activityIndicator.frame = CGRect(origin: .zero, size: size)
            self.activityIndicator.type = .custom(component.color, 64.0, 2.0, true)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
