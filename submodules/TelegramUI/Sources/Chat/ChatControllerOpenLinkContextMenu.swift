import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import Display
import ContextUI
import UndoUI
import AccountContext
import BrowserUI
import ChatMessageItemView
import ChatMessageItemCommon
import MessageUI
import ChatControllerInteraction
import TelegramUIPreferences
import UrlEscaping
import UrlWhitelist
import OpenInExternalAppUI
import SafariServices
import TelegramPresentationData

private struct ChatLinkOpenMode {
    let shouldOpenInApp: Bool
}

private enum ChatLinkReverseOpenTarget {
    case inApp
    case externalBrowser
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .inApp:
            return strings.WebBrowser_Exception_OpenInApp
        case .externalBrowser:
            return strings.WebBrowser_Exception_OpenInBrowser
        }
    }
    
    var openExternalBrowser: Bool {
        switch self {
        case .inApp:
            return false
        case .externalBrowser:
            return true
        }
    }
}

private func chatLinkContextMenuCanonicalUrl(from url: String) -> URL? {
    var urlWithScheme = url
    if !url.contains("://") && !url.hasPrefix("mailto:") {
        urlWithScheme = "http://" + url
    }
    if let parsed = URL(string: urlWithScheme) {
        return parsed
    } else if let encoded = (urlWithScheme as NSString).addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
        return URL(string: encoded)
    }
    return nil
}

private func chatLinkContextMenuOpenMode(context: AccountContext, url: String) -> Signal<ChatLinkOpenMode?, NoError> {
    let lowercasedUrl = url.lowercased()
    if lowercasedUrl.hasPrefix("mailto:") || lowercasedUrl.hasPrefix("tel:") || lowercasedUrl.hasPrefix("calshow:") {
        return .single(nil)
    }

    guard let parsedUrl = chatLinkContextMenuCanonicalUrl(from: url) else {
        return .single(nil)
    }

    let scheme = (parsedUrl.scheme ?? "").lowercased()
    guard scheme == "http" || scheme == "https" || scheme == "tonsite" else {
        return .single(nil)
    }

    let host = parsedUrl.host?.lowercased() ?? ""
    if host.isEmpty {
        return .single(nil)
    }
    if host == "t.me" || host == "telegram.me" || host == "telegram.dog" {
        return .single(nil)
    }
    if host.hasSuffix(".ton") || scheme.hasPrefix("tonsite") {
        return .single(nil)
    }

    return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.webBrowserSettings))
    |> take(1)
    |> map { accountSettingsEntry -> ChatLinkOpenMode? in
        let accountSettings = accountSettingsEntry?.get(AccountWebBrowserSettings.self) ?? AccountWebBrowserSettings.defaultSettings
        let normalizedHost = ".\(host)"
        let exceptions = accountSettings.openExternalBrowser ? accountSettings.inAppExceptions : accountSettings.externalExceptions
        var isExceptedDomain = false
        for exception in exceptions {
            if normalizedHost.hasSuffix(".\(exception.domain.lowercased())") {
                isExceptedDomain = true
                break
            }
        }

        let shouldOpenInApp: Bool
        if accountSettings.openExternalBrowser {
            shouldOpenInApp = isExceptedDomain
        } else {
            shouldOpenInApp = !isExceptedDomain
        }
        return ChatLinkOpenMode(shouldOpenInApp: shouldOpenInApp)
    }
}

extension ChatControllerImpl {
    private func presentOpenLinkConfirmation(_ url: String, target: ChatLinkReverseOpenTarget) {
        var exceptionAdded = false
        let disposable = self.context.sharedContext.openUserGeneratedUrl(
            context: self.context,
            peerId: self.contentData?.state.peerView?.peerId,
            url: url,
            webpage: nil,
            concealed: false,
            forceConcealed: true,
            skipUrlAuth: false,
            skipConcealedAlert: false,
            forceDark: false,
            present: { [weak self] c in
                self?.present(c, in: .window(.root))
            },
            openResolved: { [weak self] result in
                guard let self else {
                    return
                }
                switch target {
                case .inApp:
                    if case let .externalUrl(resolvedUrl) = result, let navigationController = self.effectiveNavigationController {
                        self.chatDisplayNode.dismissInput()
                        let controller = BrowserScreen(context: self.context, subject: .webPage(url: resolvedUrl))
                        navigationController.pushViewController(controller)
                        
                        if exceptionAdded {
                            Queue.mainQueue().after(0.5) {
                                let tooltipScreen = UndoOverlayController(
                                    presentationData: self.presentationData,
                                    content: .actionSucceeded(title: self.presentationData.strings.WebBrowser_ExceptionAdded_Title, text: self.presentationData.strings.WebBrowser_ExceptionAdded_Text, cancel: "", destructive: false),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    action: { _ in
                                        return false
                                    }
                                )
                                controller.present(tooltipScreen, in: .current)
                            }
                        }
                    } else {
                        self.openResolved(result: result, sourceMessageId: nil, forceExternal: false, concealed: true)
                    }
                case .externalBrowser:
                    if case .externalUrl = result {
                        let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings])
                        |> take(1)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] sharedData in
                            guard let self else {
                                return
                            }
                            self.chatDisplayNode.dismissInput()

                            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) ?? WebBrowserSettings.defaultSettings
                            var defaultWebBrowser = settings.defaultWebBrowser
                            if defaultWebBrowser == nil || defaultWebBrowser == "inApp" || defaultWebBrowser == "inAppSafari" {
                                defaultWebBrowser = "safari"
                            }

                            let targetUrl = chatLinkContextMenuCanonicalUrl(from: url)?.absoluteString ?? url
                            let openInOptions = availableOpenInOptions(context: self.context, item: .url(url: targetUrl))
                            if let option = openInOptions.first(where: { $0.identifier == defaultWebBrowser }) {
                                if case let .openUrl(openInUrl) = option.action() {
                                    self.context.sharedContext.applicationBindings.openUrl(openInUrl)
                                } else {
                                    self.context.sharedContext.applicationBindings.openUrl(targetUrl)
                                }
                            } else {
                                self.context.sharedContext.applicationBindings.openUrl(targetUrl)
                            }
                        })
                    } else {
                        self.openResolved(result: result, sourceMessageId: nil, forceExternal: true, concealed: false)
                    }
                }
            },
            progress: nil,
            alertDisplayUpdated: nil,
            concealedAlertOption: OpenUserGeneratedUrlConcealedAlertOption(title: target.title(strings: self.presentationData.strings), action: { [weak self] in
                guard let self else {
                    return
                }
                let _ = toggleWebBrowserSettingsException(
                    postbox: self.context.account.postbox,
                    network: self.context.account.network,
                    openExternalBrowser: target.openExternalBrowser,
                    delete: false,
                    url: url
                ).startStandalone()
                
                exceptionAdded = true
            })
        )
        self.navigationActionDisposable.set(disposable)
    }

    func openLinkContextMenu(url: String, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let contentNode = params.contentNode else {
            var (cleanUrl, _) = parseUrl(url: url, wasConcealed: false)
            var canAddToReadingList = true
            let mailtoString = "mailto:"
            let telString = "tel:"
            var openText = self.presentationData.strings.Conversation_LinkDialogOpen
            var phoneNumber: String?

            var isPhoneNumber = false
            var isEmail = false
            var hasOpenAction = true

            if cleanUrl.hasPrefix(mailtoString) {
                canAddToReadingList = false
                cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
                isEmail = true
            } else if cleanUrl.hasPrefix(telString) {
                canAddToReadingList = false
                phoneNumber = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
                cleanUrl = phoneNumber!
                openText = self.presentationData.strings.UserInfo_PhoneCall
                isPhoneNumber = true

                if cleanUrl.hasPrefix("+888") {
                    hasOpenAction = false
                }
            }

            let _ = (chatLinkContextMenuOpenMode(context: self.context, url: url)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] openMode in
                guard let self else {
                    return
                }

                let actionSheet = ActionSheetController(presentationData: self.presentationData)
                var items: [ActionSheetItem] = []
                items.append(ActionSheetTextItem(title: displayUrlRevealingLoginPart(url) ?? cleanUrl))
                if hasOpenAction {
                    items.append(ActionSheetButtonItem(title: openText, color: .accent, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.openUrl(url, concealed: false)
                    }))

                    if let openMode {
                        let reverseText = openMode.shouldOpenInApp ? self.presentationData.strings.Chat_ContextMenu_OpenInBrowser : self.presentationData.strings.Chat_ContextMenu_OpenInApp
                        items.append(ActionSheetButtonItem(title: reverseText, color: .accent, action: { [weak self, weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            guard let self else {
                                return
                            }
                            if openMode.shouldOpenInApp {
                                self.presentOpenLinkConfirmation(url, target: .externalBrowser)
                            } else {
                                self.presentOpenLinkConfirmation(url, target: .inApp)
                            }
                        }))
                    }
                }
                if let phoneNumber = phoneNumber {
                    items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_AddContact, color: .accent, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            strongSelf.controllerInteraction?.addContact(phoneNumber)
                        }
                    }))
                }
                items.append(ActionSheetButtonItem(title: canAddToReadingList ? self.presentationData.strings.ShareMenu_CopyShareLink : self.presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet, weak self] in
                    actionSheet?.dismissAnimated()
                    guard let self else {
                        return
                    }
                    UIPasteboard.general.string = cleanUrl

                    let content: UndoOverlayContent
                    if isPhoneNumber {
                        content = .copy(text: self.presentationData.strings.Conversation_PhoneCopied)
                    } else if isEmail {
                        content = .copy(text: self.presentationData.strings.Conversation_EmailCopied)
                    } else if canAddToReadingList {
                        content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
                    } else {
                        content = .copy(text: self.presentationData.strings.Conversation_TextCopied)
                    }
                    self.present(UndoOverlayController(presentationData: self.presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }))
                if canAddToReadingList {
                    items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let link = URL(string: url) {
                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                        }
                    }))
                }
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                self.chatDisplayNode.dismissInput()
                self.present(actionSheet, in: .window(.root))
            })

            return
        }

        guard let messages = self.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) else {
            return
        }

        var updatedMessages = messages
        for i in 0 ..< updatedMessages.count {
            if updatedMessages[i].id == message.id {
                let message = updatedMessages.remove(at: i)
                updatedMessages.insert(message, at: 0)
                break
            }
        }

        var (cleanUrl, _) = parseUrl(url: url, wasConcealed: false)
        var canAddToReadingList = true

        var isEmail = false
        let mailtoString = "mailto:"
        let openText = self.presentationData.strings.Conversation_LinkDialogOpen
        var copyText = self.presentationData.strings.Conversation_ContextMenuCopyLink
        if cleanUrl.hasPrefix(mailtoString) {
            canAddToReadingList = false
            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
            copyText = self.presentationData.strings.Conversation_ContextMenuCopyEmail
            isEmail = true
        }

        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = params.gesture
        let gesture: ContextGesture? = nil

        let source: ContextContentSource = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))

        let itemsSignal = chatLinkContextMenuOpenMode(context: self.context, url: url)
        |> deliverOnMainQueue
        |> map { [weak self] openMode -> ContextController.Items in
            guard let self else {
                return ContextController.Items(content: .list([]))
            }

            var items: [ContextMenuItem] = []

            items.append(
                .action(ContextMenuActionItem(text: openText, icon: { theme in return generateTintedImage(image: openMode?.shouldOpenInApp == true ? UIImage(bundleImageName: "Chat/Context Menu/Browser") : UIImage(bundleImageName: "Chat/Context Menu/Globe"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                    f(.default)

                    guard let self else {
                        return
                    }
                    self.openUrl(url, concealed: false)
                }))
            )

            if let openMode {
                let reverseText = openMode.shouldOpenInApp ? self.presentationData.strings.Chat_ContextMenu_OpenInBrowser : self.presentationData.strings.Chat_ContextMenu_OpenInApp
                items.append(
                    .action(ContextMenuActionItem(text: reverseText, icon: { theme in return generateTintedImage(image: openMode.shouldOpenInApp ? UIImage(bundleImageName: "Chat/Context Menu/Globe") : UIImage(bundleImageName: "Chat/Context Menu/Browser"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                        f(.default)

                        guard let self else {
                            return
                        }
                        if openMode.shouldOpenInApp {
                            self.presentOpenLinkConfirmation(url, target: .externalBrowser)
                        } else {
                            self.presentOpenLinkConfirmation(url, target: .inApp)
                        }
                    }))
                )
            }

            items.append(
                .action(ContextMenuActionItem(text: copyText, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                    f(.default)

                    guard let self else {
                        return
                    }

                    UIPasteboard.general.string = cleanUrl

                    self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: isEmail ? presentationData.strings.Conversation_EmailCopied : presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }))
            )

            if canAddToReadingList {
                items.append(
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_AddToReadingList, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReadingList"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                        f(.default)

                        if let link = URL(string: url) {
                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                        }
                    }))
                )
            }

            return ContextController.Items(content: .list(items))
        }

        self.canReadHistory.set(false)

        let controller = makeContextController(presentationData: self.presentationData, source: source, items: itemsSignal, recognizer: recognizer, gesture: gesture, disableScreenshots: false)
        controller.dismissed = { [weak self] in
            self?.canReadHistory.set(true)
        }

        self.window?.presentInGlobalOverlay(controller)
    }
}
