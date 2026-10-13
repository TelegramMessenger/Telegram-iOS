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
import ResizableSheetComponent
import MultilineTextComponent
import BalancedTextComponent
import GlassBarButtonComponent
import ButtonComponent
import TableComponent
import PresentationDataUtils
import BundleIconComponent
import LottieAnimationComponent
import ListSectionComponent
import ListActionItemComponent
import AvatarComponent
import TelegramStringFormatting
import Markdown
import AppBundle
import TextFormat
import ChatbotSetupScreen

private func botRecipientsCategoryCount(_ categories: TelegramBusinessRecipients.Categories) -> Int {
    var count = 0
    if categories.contains(.existingChats) {
        count += 1
    }
    if categories.contains(.newChats) {
        count += 1
    }
    if categories.contains(.contacts) {
        count += 1
    }
    if categories.contains(.nonContacts) {
        count += 1
    }
    return count
}

private let recentSessionCheckIcon: UIImage = {
    return generateImage(CGSize(width: 12.0, height: 10.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.98)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.translateBy(x: 1.0, y: 1.0)
        
        let _ = try? drawSvgPath(context, path: "M0.215053763,4.36080467 L3.31621263,7.70466293 L3.31621263,7.70466293 C3.35339229,7.74475231 3.41603123,7.74711109 3.45612061,7.70993143 C3.45920681,7.70706923 3.46210733,7.70401312 3.46480451,7.70078171 L9.89247312,0 S ")
    })!.withRenderingMode(.alwaysTemplate)
}()

private final class RecentSessionSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: RecentSessionScreen.Subject
    let cancel: (Bool) -> Void
    
    init(
        context: AccountContext,
        subject: RecentSessionScreen.Subject,
        cancel: @escaping  (Bool) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.cancel = cancel
    }
    
    static func ==(lhs: RecentSessionSheetContent, rhs: RecentSessionSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        fileprivate struct ConnectedBotRecipientsState {
            var categories: TelegramBusinessRecipients.Categories
            var peers: [BusinessRecipientListScreen.ResolvedPeer]
            var excludePeers: [BusinessRecipientListScreen.ResolvedPeer]
            var excludeByDefault: Bool
        }
        
        private let context: AccountContext
        private let subject: RecentSessionScreen.Subject
        private let botPeerDisposable = MetaDisposable()
        
        var allowSecretChats: Bool?
        var allowIncomingCalls: Bool?
        var botPeer: EnginePeer?
        fileprivate var connectedBotRecipients: ConnectedBotRecipientsState?
        
        weak var controller: RecentSessionScreen?
        
        init(context: AccountContext, subject: RecentSessionScreen.Subject) {
            self.context = context
            self.subject = subject
            
            super.init()
            
            switch subject {
            case let .session(session):
                if !session.flags.contains(.passwordPending) && session.apiId != 22 {
                    self.allowIncomingCalls = session.flags.contains(.acceptsIncomingCalls)
                    
                    if ![2040, 2496].contains(session.apiId) {
                        self.allowSecretChats = session.flags.contains(.acceptsSecretChats)
                    }
                }
            case .website:
                break
            case let .connectedBot(connectedBot):
                var additionalPeerIds = Set<EnginePeer.Id>()
                additionalPeerIds.formUnion(connectedBot.recipients.additionalPeers)
                additionalPeerIds.formUnion(connectedBot.recipients.excludePeers)
                
                self.botPeerDisposable.set((
                    context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: connectedBot.id),
                        EngineDataMap(additionalPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))),
                        EngineDataMap(additionalPeerIds.map(TelegramEngine.EngineData.Item.Peer.IsContact.init(id:)))
                    )
                    |> deliverOnMainQueue
                ).start(next: { [weak self] peer, peers, isContacts in
                    guard let self else {
                        return
                    }
                    self.botPeer = peer
                    
                    var additionalPeers: [BusinessRecipientListScreen.ResolvedPeer] = []
                    for peerId in connectedBot.recipients.additionalPeers.sorted() {
                        guard let maybePeer = peers[peerId], let peer = maybePeer else {
                            continue
                        }
                        additionalPeers.append(BusinessRecipientListScreen.ResolvedPeer(
                            peer: peer,
                            isContact: isContacts[peerId] ?? false
                        ))
                    }
                    
                    var excludePeers: [BusinessRecipientListScreen.ResolvedPeer] = []
                    for peerId in connectedBot.recipients.excludePeers.sorted() {
                        guard let maybePeer = peers[peerId], let peer = maybePeer else {
                            continue
                        }
                        excludePeers.append(BusinessRecipientListScreen.ResolvedPeer(
                            peer: peer,
                            isContact: isContacts[peerId] ?? false
                        ))
                    }
                    
                    self.connectedBotRecipients = ConnectedBotRecipientsState(
                        categories: connectedBot.recipients.categories,
                        peers: additionalPeers,
                        excludePeers: excludePeers,
                        excludeByDefault: connectedBot.recipients.exclude
                    )
                    self.updated()
                }))
            }
        }
        
        deinit {
            self.botPeerDisposable.dispose()
        }
        
        func toggleAllowSecretChats() {
            guard let controller = self.controller else {
                return
            }
            
            if let allowSecretChats = self.allowSecretChats {
                let newValue = !allowSecretChats
                self.allowSecretChats = newValue
                controller.updateAcceptSecretChats(newValue)
            }
            
            self.updated()
        }
        
        func toggleAllowIncomingCalls() {
            guard let controller = self.controller else {
                return
            }
            
            if let allowIncomingCalls = self.allowIncomingCalls {
                let newValue = !allowIncomingCalls
                self.allowIncomingCalls = newValue
                controller.updateAcceptIncomingCalls(newValue)
            }
            
            self.updated()
        }
        
        func terminate() {
            guard let controller = self.controller else {
                return
            }
            self.updated()
            controller.terminate()
        }
        
        private func applyConnectedBotRecipientsUpdate() {
            guard case let .connectedBot(connectedBot) = self.subject, let connectedBotRecipients = self.connectedBotRecipients else {
                return
            }
            
            let recipients = TelegramBusinessRecipients(
                categories: connectedBotRecipients.categories,
                additionalPeers: Set(connectedBotRecipients.peers.map(\.peer.id)),
                excludePeers: Set(connectedBotRecipients.excludePeers.map(\.peer.id)),
                exclude: connectedBotRecipients.excludeByDefault
            )
            let _ = self.context.engine.accountData.setAccountConnectedBot(bot: TelegramAccountConnectedBot(
                id: connectedBot.id,
                recipients: recipients,
                rights: connectedBot.rights,
                device: connectedBot.device,
                date: connectedBot.date,
                location: connectedBot.location
            )).startStandalone()
        }
        
        func setConnectedBotAccessMode(excludeByDefault: Bool) {
            guard var connectedBotRecipients = self.connectedBotRecipients else {
                return
            }
            guard connectedBotRecipients.excludeByDefault != excludeByDefault else {
                return
            }
            connectedBotRecipients.excludeByDefault = excludeByDefault
            connectedBotRecipients.categories = [] //removeAll()
            connectedBotRecipients.peers.removeAll()
            self.connectedBotRecipients = connectedBotRecipients
            self.applyConnectedBotRecipientsUpdate()
            self.updated()
        }
        
        func openConnectedBotRecipients(isExclude: Bool) {
            guard let controller = self.controller, let connectedBotRecipients = self.connectedBotRecipients else {
                return
            }
            
            BusinessRecipientListScreen.openSetupFlow(
                context: self.context,
                from: controller,
                state: BusinessRecipientListScreen.PeerListState(
                    categories: connectedBotRecipients.categories,
                    peers: connectedBotRecipients.peers,
                    excludePeers: connectedBotRecipients.excludePeers,
                    excludeByDefault: connectedBotRecipients.excludeByDefault
                ),
                isExclude: isExclude,
                update: { [weak self] updatedState in
                    guard let self else {
                        return
                    }
                    self.connectedBotRecipients = ConnectedBotRecipientsState(
                        categories: updatedState.categories,
                        peers: updatedState.peers,
                        excludePeers: updatedState.excludePeers,
                        excludeByDefault: updatedState.excludeByDefault
                    )
                    self.applyConnectedBotRecipientsUpdate()
                    self.updated()
                }
            )
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
    
    static var body: Body {
        let icon = Child(ZStack<Empty>.self)
        let avatar = Child(AvatarComponent.self)
        let title = Child(BalancedTextComponent.self)
        let description = Child(MultilineTextComponent.self)
        let recipientsModeSection = Child(ListSectionComponent.self)
        let recipientsSummarySection = Child(ListSectionComponent.self)
        let recipientsExcludedSection = Child(ListSectionComponent.self)
        let clientSection = Child(ListSectionComponent.self)
        let optionsSection = Child(ListSectionComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let state = context.state
            if state.controller == nil {
                state.controller = environment.controller() as? RecentSessionScreen
            }
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var contentHeight: CGFloat = 32.0
            switch component.subject {
            case let .session(session):
                let (image, backgroundColor, animationName, colorsArray) = iconForSession(session)
                
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: "background",
                        component: AnyComponent(
                            FilledRoundedRectangleComponent(
                                color: backgroundColor ?? .clear,
                                cornerRadius: .value(20.0),
                                smoothCorners: true
                            )
                        )
                    )
                )
                if let animationName {
                    var colors: [String: UIColor] = [:]
                    if let colorsArray {
                        for color in colorsArray {
                            colors[color] = backgroundColor
                        }
                    }
                    items.append(
                        AnyComponentWithIdentity(
                            id: "animation",
                            component: AnyComponent(
                                LottieAnimationComponent(
                                    animation: .init(name: animationName, mode: .animating(loop: false)),
                                    colors: colors,
                                    size: CGSize(width: 92.0, height: 92.0)
                                )
                            )
                        )
                    )
                } else if let image {
                    items.append(
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(
                                Image(image: image)
                            )
                        )
                    )
                }
                
                let icon = icon.update(
                    component: ZStack(items),
                    availableSize: CGSize(width: 92.0, height: 92.0),
                    transition: .immediate
                )
                context.add(icon
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + icon.size.height / 2.0))
                )
                contentHeight += icon.size.height
                contentHeight += 18.0
            case let .website(_, peer):
                if let peer {
                    let avatar = avatar.update(
                        component: AvatarComponent(
                            context: component.context,
                            theme: theme,
                            peer: peer,
                            clipStyle: .roundedRect
                        ),
                        availableSize: CGSize(width: 92.0, height: 92.0),
                        transition: .immediate
                    )
                    context.add(avatar
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + avatar.size.height / 2.0))
                    )
                    contentHeight += avatar.size.height
                    contentHeight += 18.0
                }
            case .connectedBot:
                if let peer = state.botPeer {
                    let avatar = avatar.update(
                        component: AvatarComponent(
                            context: component.context,
                            theme: theme,
                            peer: peer,
                            clipStyle: .roundedRect
                        ),
                        availableSize: CGSize(width: 92.0, height: 92.0),
                        transition: .immediate
                    )
                    context.add(avatar
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + avatar.size.height / 2.0))
                    )
                    contentHeight += avatar.size.height
                    contentHeight += 18.0
                }
            }
            
            let titleString: String
            let subtitleText: MultilineTextComponent.TextContent
            let subtitleHighlightAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)?
            let subtitleTapAction: (([NSAttributedString.Key: Any], Int) -> Void)?
            let applicationTitle: String
            let applicationString: String
            let ipString: String?
            let dateString: String?
            let locationString: String
            let buttonString: String?
            let clientSectionHeader: String?
            let clientSectionFooter: String?
            let connectedBot: TelegramAccountConnectedBot?
            
            let openBotProfile: () -> Void = {
                guard let botPeer = state.botPeer, let navigationController = environment.controller()?.navigationController as? NavigationController, let peerInfoController = component.context.sharedContext.makePeerInfoController(context: component.context, updatedPresentationData: nil, peer: botPeer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) else {
                    return
                }
                navigationController.pushViewController(peerInfoController)
            }
            
            switch component.subject {
            case let .session(session):
                titleString = session.deviceModel
                if session.isCurrent {
                    subtitleText = .plain(NSAttributedString(string: strings.Presence_online, font: Font.regular(15.0), textColor: theme.actionSheet.controlAccentColor))
                } else {
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    subtitleText = .plain(NSAttributedString(string: stringForRelativeActivityTimestamp(strings: strings, dateTimeFormat: presentationData.dateTimeFormat, relativeTimestamp: session.activityDate, relativeTo: timestamp), font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor))
                }
                subtitleHighlightAction = nil
                subtitleTapAction = nil
                var appVersion = session.appVersion
                appVersion = appVersion.replacingOccurrences(of: "APPSTORE", with: "").replacingOccurrences(of: "BETA", with: "Beta").trimmingTrailingSpaces()
                applicationTitle = strings.AuthSessions_View_Application
                applicationString =  "\(session.appName) \(appVersion)"
                ipString = nil
                dateString = nil
                locationString = session.country
                
                buttonString = !session.isCurrent ? strings.AuthSessions_View_TerminateSession : nil
                clientSectionHeader = nil
                clientSectionFooter = strings.AuthSessions_View_LocationInfo
                connectedBot = nil
            case let .website(website, peer):
                titleString = peer?.compactDisplayTitle ?? ""
                subtitleText = .plain(NSAttributedString(string: website.domain, font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor))
                subtitleHighlightAction = nil
                subtitleTapAction = nil
                
                var deviceString = ""
                if !website.browser.isEmpty {
                    deviceString += website.browser
                }
                if !website.platform.isEmpty {
                    if !deviceString.isEmpty {
                        deviceString += ", "
                    }
                    deviceString += website.platform
                }
                applicationTitle = strings.AuthSessions_View_Browser
                applicationString = deviceString
                ipString = website.ip
                dateString = nil
                locationString = website.region
                
                buttonString = strings.AuthSessions_View_Logout
                clientSectionHeader = nil
                clientSectionFooter = strings.AuthSessions_View_LocationInfo
                connectedBot = nil
            case let .connectedBot(subjectConnectedBot):
                let botUsername = state.botPeer?.addressName.flatMap { addressName -> String? in
                    if addressName.isEmpty {
                        return nil
                    } else {
                        return "@\(addressName)"
                    }
                } ?? ""
                titleString = state.botPeer?.compactDisplayTitle ?? "Bot"
                
                let subtitleString = strings.RecentSession_ConnectedBot_Subtitle
                if botUsername.isEmpty {
                    subtitleText = .plain(NSAttributedString(string: subtitleString, font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor))
                    subtitleHighlightAction = nil
                    subtitleTapAction = nil
                } else {
                    subtitleText = .markdown(
                        text: "\(subtitleString)\n[\(botUsername)](peer)",
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.actionSheet.controlAccentColor),
                            linkAttribute: { _ in
                                return (TelegramTextAttributes.URL, "peer")
                            }
                        )
                    )
                    subtitleHighlightAction = { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    }
                    subtitleTapAction = { attributes, _ in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                            openBotProfile()
                        }
                    }
                }
                
                applicationTitle = strings.RecentSession_ConnectedBot_Device
                applicationString = subjectConnectedBot.device ?? ""
                ipString = nil
                if let date = subjectConnectedBot.date {
                    dateString = humanReadableStringForTimestamp(strings: strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: date, alwaysShowTime: true, allowYesterday: true).string
                } else {
                    dateString = ""
                }
                locationString = subjectConnectedBot.location ?? ""
                
                buttonString = strings.AuthSessions_View_TerminateSession
                clientSectionHeader = strings.RecentSession_ConnectedBot_ConnectedFrom
                clientSectionFooter = nil
                connectedBot = subjectConnectedBot
            }
            
            let titleFont = Font.bold(24.0)
            let title = title.update(
                component: BalancedTextComponent(
                    text: .markdown(text: titleString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.controlAccentColor), link: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + title.size.height / 2.0))
            )
            contentHeight += title.size.height
            contentHeight += 2.0
            
            let description = description.update(
                component: MultilineTextComponent(
                    text: subtitleText,
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.2,
                    highlightColor: theme.actionSheet.controlAccentColor.withAlphaComponent(0.1),
                    highlightAction: subtitleHighlightAction,
                    tapAction: subtitleTapAction
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + description.size.height / 2.0))
            )
            contentHeight += description.size.height
            contentHeight += 22.0
            
            var clientSectionItems: [AnyComponentWithIdentity<Empty>] = []
            clientSectionItems.append(
                AnyComponentWithIdentity(id: "application", component: AnyComponent(
                    ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: applicationTitle,
                                font: Font.regular(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        accessory: .custom(ListActionItemComponent.CustomAccessory(
                            component: AnyComponentWithIdentity(
                                id: "info",
                                component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: applicationString,
                                        font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                        textColor: theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                            isInteractive: true
                        )),
                        action: nil
                    )
                ))
            )
            
            if let ipString {
                clientSectionItems.append(
                    AnyComponentWithIdentity(id: "ip", component: AnyComponent(
                        ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthSessions_View_IP,
                                    font: Font.regular(17.0),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )),
                            accessory: .custom(ListActionItemComponent.CustomAccessory(
                                component: AnyComponentWithIdentity(
                                    id: "info",
                                    component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: ipString,
                                            font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                            textColor: theme.list.itemSecondaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))
                                ),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                                isInteractive: true
                            )),
                            action: nil
                        )
                    ))
                )
            }
            
            clientSectionItems.append(
                AnyComponentWithIdentity(id: "region", component: AnyComponent(
                    ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AuthSessions_View_Location,
                                font: Font.regular(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        accessory: .custom(ListActionItemComponent.CustomAccessory(
                            component: AnyComponentWithIdentity(
                                id: "info",
                                component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: locationString,
                                        font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                        textColor: theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                            isInteractive: true
                        )),
                        action: nil
                    )
                ))
            )
            
            if let dateString {
                clientSectionItems.append(
                    AnyComponentWithIdentity(id: "date", component: AnyComponent(
                        ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.RecentSession_ConnectedBot_Date,
                                    font: Font.regular(17.0),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )),
                            accessory: .custom(ListActionItemComponent.CustomAccessory(
                                component: AnyComponentWithIdentity(
                                    id: "info",
                                    component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: dateString,
                                            font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                            textColor: theme.list.itemSecondaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))
                                ),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                                isInteractive: false
                            )),
                            action: nil
                        )
                    ))
                )
            }
            
            let clientSection = clientSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: clientSectionHeader.flatMap { header in
                        AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: header,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        ))
                    },
                    footer: clientSectionFooter.flatMap { footer in
                        AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: footer,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        ))
                    },
                    items: clientSectionItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(clientSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + clientSection.size.height / 2.0))
            )
            contentHeight += clientSection.size.height
            
            if let connectedBot {
                contentHeight += 32.0
                
                let recipientCategories = state.connectedBotRecipients?.categories ?? connectedBot.recipients.categories
                let hasAccessToAllChatsByDefault = state.connectedBotRecipients?.excludeByDefault ?? connectedBot.recipients.exclude
                let categoriesAndUsersItemCount = botRecipientsCategoryCount(recipientCategories) + (state.connectedBotRecipients?.peers.count ?? connectedBot.recipients.additionalPeers.count)
                let excludedSectionValue: String
                if categoriesAndUsersItemCount == 0 {
                    excludedSectionValue = strings.ChatbotSetup_RecipientSummary_ValueEmpty
                } else {
                    excludedSectionValue = strings.ChatbotSetup_RecipientSummary_ValueItems(Int32(categoriesAndUsersItemCount))
                }
                
                let excludedUsersItemCount = state.connectedBotRecipients?.excludePeers.count ?? connectedBot.recipients.excludePeers.count
                let excludedUsersValue: String
                if excludedUsersItemCount == 0 {
                    excludedUsersValue = strings.ChatbotSetup_RecipientSummary_ValueEmpty
                } else {
                    excludedUsersValue = strings.ChatbotSetup_RecipientSummary_ValueItems(Int32(excludedUsersItemCount))
                }
                
                let recipientsModeSection = recipientsModeSection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.ChatbotSetup_RecipientsSectionHeader,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: "allExcept", component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                style: .glass,
                                title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: strings.BusinessMessageSetup_RecipientsOptionAllExcept,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    )))
                                ], alignment: .left, spacing: 2.0)),
                                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(Image(
                                    image: recentSessionCheckIcon,
                                    tintColor: !hasAccessToAllChatsByDefault ? .clear : theme.list.itemAccentColor,
                                    contentMode: .center
                                ))), false),
                                accessory: nil,
                                action: { [weak state] _ in
                                    if !hasAccessToAllChatsByDefault {
                                        state?.setConnectedBotAccessMode(excludeByDefault: true)
                                    }
                                }
                            ))),
                            AnyComponentWithIdentity(id: "onlySelected", component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                style: .glass,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: strings.BusinessMessageSetup_RecipientsOptionOnly,
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    )))
                                ], alignment: .left, spacing: 2.0)),
                                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(Image(
                                    image: recentSessionCheckIcon,
                                    tintColor: hasAccessToAllChatsByDefault ? .clear : theme.list.itemAccentColor,
                                    contentMode: .center
                                ))), false),
                                accessory: nil,
                                action: { [weak state] _ in
                                    if hasAccessToAllChatsByDefault {
                                        state?.setConnectedBotAccessMode(excludeByDefault: false)
                                    }
                                }
                            )))
                        ]
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(recipientsModeSection
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + recipientsModeSection.size.height / 2.0))
                )
                contentHeight += recipientsModeSection.size.height
                contentHeight += 32.0
                
                let recipientsSummarySection = recipientsSummarySection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .markdown(
                                text: hasAccessToAllChatsByDefault ? strings.ChatbotSetup_Recipients_ExcludedSectionFooter : strings.ChatbotSetup_Recipients_IncludedSectionFooter,
                                attributes: MarkdownAttributes(
                                    body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                    bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                    link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.itemAccentColor),
                                    linkAttribute: { _ in
                                        return nil
                                    }
                                )
                            ),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: "summary", component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                style: .glass,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: hasAccessToAllChatsByDefault ? strings.ChatbotSetup_RecipientSummary_ExcludedChatsItem : strings.ChatbotSetup_RecipientSummary_IncludedChatsItem,
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    )))
                                ], alignment: .left, spacing: 2.0)),
                                leftIcon: nil,
                                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(
                                    id: "value",
                                    component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: excludedSectionValue,
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: theme.list.itemSecondaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))
                                )),
                                accessory: .arrow,
                                action: { [weak state] _ in
                                    state?.openConnectedBotRecipients(isExclude: false)
                                }
                            )))
                        ]
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(recipientsSummarySection
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + recipientsSummarySection.size.height / 2.0))
                )
                contentHeight += recipientsSummarySection.size.height
                contentHeight += 32.0
                
                if !hasAccessToAllChatsByDefault {
                    let recipientsExcludedSection = recipientsExcludedSection.update(
                        component: ListSectionComponent(
                            theme: theme,
                            style: .glass,
                            header: nil,
                            footer: AnyComponent(MultilineTextComponent(
                                text: .markdown(
                                    text: strings.ChatbotSetup_Recipients_ExcludedSectionFooter,
                                    attributes: MarkdownAttributes(
                                        body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                        bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                        link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.itemAccentColor),
                                        linkAttribute: { _ in
                                            return nil
                                        }
                                    )
                                ),
                                maximumNumberOfLines: 0
                            )),
                            items: [
                                AnyComponentWithIdentity(id: "excluded", component: AnyComponent(ListActionItemComponent(
                                    theme: theme,
                                    style: .glass,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: strings.ChatbotSetup_RecipientSummary_ExcludedChatsItem,
                                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                                textColor: theme.list.itemPrimaryTextColor
                                            )),
                                            maximumNumberOfLines: 1
                                        )))
                                    ], alignment: .left, spacing: 2.0)),
                                    leftIcon: nil,
                                    icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(
                                        id: "value",
                                        component: AnyComponent(MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: excludedUsersValue,
                                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                                textColor: theme.list.itemSecondaryTextColor
                                            )),
                                            maximumNumberOfLines: 1
                                        ))
                                    )),
                                    accessory: .arrow,
                                    action: { [weak state] _ in
                                        state?.openConnectedBotRecipients(isExclude: true)
                                    }
                                )))
                            ]
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                        transition: context.transition
                    )
                    context.add(recipientsExcludedSection
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + recipientsExcludedSection.size.height / 2.0))
                    )
                    contentHeight += recipientsExcludedSection.size.height
                    contentHeight += 32.0
                }
            }
            
            if state.allowSecretChats != nil || state.allowIncomingCalls != nil {
                contentHeight += 38.0
                
                var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
                
                if let allowSecretChats = state.allowSecretChats {
                    optionsSectionItems.append(AnyComponentWithIdentity(id: "allowSecretChats", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthSessions_View_AcceptSecretChats,
                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: allowSecretChats, action: { [weak state] _ in
                            guard let state else {
                                return
                            }
                            state.toggleAllowSecretChats()
                        })),
                        action: nil
                    ))))
                }
                if let allowIncomingCalls = state.allowIncomingCalls {
                    optionsSectionItems.append(AnyComponentWithIdentity(id: "allowIncomingCalls", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthSessions_View_AcceptIncomingCalls,
                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: allowIncomingCalls, action: { [weak state] _ in
                            guard let state else {
                                return
                            }
                            state.toggleAllowIncomingCalls()
                        })),
                        action: nil
                    ))))
                }
                let optionsSection = optionsSection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.AuthSessions_View_AcceptTitle.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: optionsSectionItems
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(optionsSection
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + optionsSection.size.height / 2.0))
                )
                contentHeight += optionsSection.size.height
            }
            contentHeight += 32.0
            
            if buttonString != nil {
                let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
                contentHeight += 52.0
                contentHeight += buttonInsets.bottom
            }
            
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class RecentSessionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: RecentSessionScreen.Subject
    
    init(
        context: AccountContext,
        subject: RecentSessionScreen.Subject
    ) {
        self.context = context
        self.subject = subject
    }
    
    static func ==(lhs: RecentSessionSheetComponent, rhs: RecentSessionSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else if let controller = controller() {
                    controller.dismiss(completion: nil)
                }
            }
            
            let buttonTitle: String?
            switch context.component.subject {
            case let .session(session):
                buttonTitle = !session.isCurrent ? environment.strings.AuthSessions_View_TerminateSession : nil
            case .website:
                buttonTitle = environment.strings.AuthSessions_View_Logout
            case .connectedBot:
                buttonTitle = environment.strings.AuthSessions_View_TerminateSession
            }
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(RecentSessionSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        cancel: { animate in
                            dismiss(animate)
                        }
                    )),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: environment.theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: environment.theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    hasTopEdgeEffect: false,
                    bottomItem: buttonTitle.flatMap { buttonTitle in
                        AnyComponent(
                            ButtonComponent(
                                background: ButtonComponent.Background(
                                    style: .glass,
                                    color: environment.theme.list.itemDestructiveColor,
                                    foreground: .white,
                                    pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                                ),
                                content: AnyComponentWithIdentity(
                                    id: AnyHashable(0),
                                    component: AnyComponent(
                                        MultilineTextComponent(
                                            text: .plain(NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))
                                        )
                                    )
                                ),
                                action: {
                                    (controller() as? RecentSessionScreen)?.terminate()
                                }
                            )
                        )
                    },
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    centeredSize: environment.metrics.widthClass == .regular ? CGSize(width: 414.0, height: 640.0) : nil,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: environment.theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: environment.inputHeight,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
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

public class RecentSessionScreen: ViewControllerComponentContainer {
    public enum Subject {
        case session(RecentAccountSession)
        case website(WebAuthorization, EnginePeer?)
        case connectedBot(TelegramAccountConnectedBot)
    }
    
    private let context: AccountContext
    private let subject: Subject
    fileprivate let updateAcceptSecretChats: (Bool) -> Void
    fileprivate let updateAcceptIncomingCalls: (Bool) -> Void
    fileprivate let remove: (@escaping () -> Void) -> Void
    
    public init(
        context: AccountContext,
        subject: RecentSessionScreen.Subject,
        updateAcceptSecretChats: @escaping (Bool) -> Void,
        updateAcceptIncomingCalls: @escaping (Bool) -> Void,
        remove: @escaping (@escaping () -> Void) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.updateAcceptSecretChats = updateAcceptSecretChats
        self.updateAcceptIncomingCalls = updateAcceptIncomingCalls
        self.remove = remove
        
        super.init(
            context: context,
            component: RecentSessionSheetComponent(
                context: context,
                subject: subject
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
    
    fileprivate func terminate() {
        switch self.subject {
        case .session, .website:
            self.remove({ [weak self] in
                self?.dismissAnimated()
            })
        case .connectedBot:
            let _ = (self.context.engine.accountData.setAccountConnectedBot(bot: nil)
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                self?.dismissAnimated()
            })
        }
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
