import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import ViewControllerComponent
import ResizableSheetComponent
import GlassBarButtonComponent
import BundleIconComponent
import MultilineTextComponent
import ComponentDisplayAdapters
import ShareController
import AnimatedTextComponent
import UndoUI
import SaveToCameraRoll
import AsyncDisplayKit
import AuthConfirmationScreen
import AccountPeerContextItem
import ContextUI
import GlassBackgroundComponent
import SegmentControlComponent
import UIKitRuntimeUtils

public struct ShareScreenSegmentedValue {
    public let title: String
    public let subject: ShareScreenSubject
    public let actionTitle: String

    public init(title: String, subject: ShareScreenSubject, actionTitle: String) {
        self.title = title
        self.subject = subject
        self.actionTitle = actionTitle
    }
}

private func shareScreenTimestampText(_ value: Int32) -> String {
    let hours = value / 3600
    let minutes = (value % 3600) / 60
    let seconds = value % 60
    if hours == 0 {
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
    return "\(hours):\(minutes < 10 ? "0" : "")\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
}

private func shareScreenTimestampLinkSuffix(_ value: Int32) -> String {
    let hours = value / 3600
    let minutes = value / 60 % 60
    let seconds = value % 60
    var result = ""
    if hours == 0 && minutes == 0 {
        result = "\(value)"
    } else {
        if hours != 0 { result += "\(hours)h" }
        if minutes != 0 { result += "\(minutes)m" }
        if seconds != 0 { result += "\(seconds)s" }
    }
    return "?t=\(result)"
}

public final class ShareScreenHostController: ViewController {
    private let navigation: NavigationController
    private let screen: ShareScreen

    public init(screen: ShareScreen, theme: PresentationTheme) {
        self.screen = screen
        let navigationTheme = NavigationControllerTheme(presentationTheme: theme)
        self.navigation = NavigationController(mode: .single, theme: NavigationControllerTheme(statusBar: navigationTheme.statusBar, navigationBar: navigationTheme.navigationBar, emptyAreaColor: .clear, separatorColor: navigationTheme.separatorColor, opaqueBackgroundColor: navigationTheme.opaqueBackgroundColor))
        self.navigation.isOpaqueWhenInOverlay = false
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .default
        screen.navigationPresentation = .default
        self.navigation.setViewControllers([screen], animated: false)
        screen.host = self
        self.hostReady.set(screen.contentReady.get()
        |> filter { $0 }
        |> take(1)
        |> timeout(1.0, queue: Queue.mainQueue(), alternate: .single(true)))
    }

    required public init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private let hostReady = Promise<Bool>()

    override public var ready: Promise<Bool> {
        return self.hostReady
    }

    override public func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()
        self.navigation.setIgnoreAppearanceMethodInvocations(true)
        self.displayNode.view.addSubview(self.navigation.view)
        self.navigation.setIgnoreAppearanceMethodInvocations(false)
    }

    private var currentLayout: ContainerViewLayout?
    private var isAppearing = false

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.currentLayout = layout
        guard self.isAppearing else { return }
        transition.updateFrame(view: self.navigation.view, frame: CGRect(origin: .zero, size: layout.size))
        self.navigation.containerLayoutUpdated(layout, transition: transition)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !self.isAppearing {
            self.isAppearing = true
            if let layout = self.currentLayout {
                self.navigation.view.frame = CGRect(origin: .zero, size: layout.size)
                self.navigation.containerLayoutUpdated(layout, transition: .immediate)
            }
        }
        self.navigation.viewWillAppear(animated)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigation.viewDidAppear(animated)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigation.viewWillDisappear(animated)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigation.viewDidDisappear(animated)
    }
}

private final class ShareScreenHeaderComponent: Component {
    let title: String
    let subtitle: [AnimatedTextComponent.Item]
    let theme: PresentationTheme
    let isHidden: Bool

    init(title: String, subtitle: [AnimatedTextComponent.Item], theme: PresentationTheme, isHidden: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.isHidden = isHidden
    }

    static func ==(lhs: ShareScreenHeaderComponent, rhs: ShareScreenHeaderComponent) -> Bool {
        return lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.theme === rhs.theme && lhs.isHidden == rhs.isHidden
    }

    final class View: UIView {
        private var title = ComponentView<Empty>()
        private var titleText: String?
        private var subtitle = ComponentView<Empty>()
        private let subtitleContainer = UIView()
        private var subtitleIds: Set<AnyHashable> = []

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.subtitleContainer.clipsToBounds = true
            self.addSubview(self.subtitleContainer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: ShareScreenHeaderComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.isUserInteractionEnabled = !component.isHidden
            transition.setAlpha(view: self, alpha: component.isHidden ? 0.0 : 1.0)
            transition.setBlur(layer: self.layer, radius: component.isHidden ? 8.0 : 0.0)
            // Keep the sheet's title slot independent of the subtitle's measured width.
            let size = CGSize(width: availableSize.width, height: 38.0)
            var replacedTitle = false
            if !transition.animation.isImmediate, let previousText = self.titleText, previousText != component.title, let previousView = self.title.view {
                transition.setAlpha(view: previousView, alpha: 0.0, completion: { [weak previousView] _ in
                    previousView?.removeFromSuperview()
                })
                transition.setBlur(layer: previousView.layer, radius: 4.0)
                self.title = ComponentView<Empty>()
                replacedTitle = true
            }
            self.titleText = component.title
            let titleSize = self.title.update(transition: .immediate, component: AnyComponent(Text(
                text: component.title, font: Font.semibold(17.0), color: component.theme.list.itemPrimaryTextColor
            )), environment: {}, containerSize: CGSize(width: size.width, height: 22.0))
            if let view = self.title.view {
                if view.superview == nil {
                    self.addSubview(view)
                    if replacedTitle {
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        ComponentTransition.immediate.setBlur(layer: view.layer, radius: 4.0)
                        transition.setBlur(layer: view.layer, radius: 0.0)
                    }
                }
                view.frame = CGRect(x: floorToScreenPixels((size.width - titleSize.width) * 0.5), y: 0.0, width: titleSize.width, height: titleSize.height)
            }
            let subtitleFont = Font.regular(12.0)
            var subtitleItems: [AnimatedTextComponent.Item] = []
            var remainingWidth = size.width
            for (index, item) in component.subtitle.enumerated() {
                guard case let .text(text) = item.content else { continue }
                let textWidth = ceil((text as NSString).size(withAttributes: [.font: subtitleFont]).width)
                let ellipsisWidth = ceil(("…" as NSString).size(withAttributes: [.font: subtitleFont]).width)
                let reservedWidth = index == component.subtitle.count - 1 ? 0.0 : ellipsisWidth
                if textWidth + reservedWidth <= remainingWidth {
                    subtitleItems.append(item)
                    remainingWidth -= textWidth
                } else {
                    var truncated = text
                    while !truncated.isEmpty && ceil(((truncated + "…") as NSString).size(withAttributes: [.font: subtitleFont]).width) > remainingWidth {
                        truncated.removeLast()
                    }
                    subtitleItems.append(AnimatedTextComponent.Item(id: item.id, isUnbreakable: true, content: .text(truncated + "…")))
                    break
                }
            }
            let ids = Set(subtitleItems.map(\.id))
            var subtitleTransition = transition
            var replacedSubtitle = false
            if !transition.animation.isImmediate, !self.subtitleIds.isEmpty, self.subtitleIds.isDisjoint(with: ids), let previousView = self.subtitle.view {
                transition.setAlpha(view: previousView, alpha: 0.0, completion: { [weak previousView] _ in
                    previousView?.removeFromSuperview()
                })
                transition.setBlur(layer: previousView.layer, radius: 4.0)
                self.subtitle = ComponentView<Empty>()
                subtitleTransition = .immediate
                replacedSubtitle = true
            }
            self.subtitleIds = ids
            let subtitleSize = self.subtitle.update(transition: subtitleTransition, component: AnyComponent(AnimatedTextComponent(
                font: subtitleFont,
                color: component.theme.list.itemSecondaryTextColor,
                items: subtitleItems,
                noDelay: true,
                animateScale: false,
                animateSlide: true,
                useTransitionAnimation: true
            )), environment: {}, containerSize: CGSize(width: size.width, height: 16.0))
            // Clip vertically without shortening the outgoing text to the new
            // subtitle width while AnimatedTextComponent is removing it.
            self.subtitleContainer.frame = CGRect(x: 0.0, y: 23.0, width: size.width, height: 16.0)
            if let view = self.subtitle.view {
                let isNew = view.superview == nil
                let frameTransition: ComponentTransition = isNew ? .immediate : subtitleTransition
                if isNew {
                    self.subtitleContainer.addSubview(view)
                    if replacedSubtitle {
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        ComponentTransition.immediate.setBlur(layer: view.layer, radius: 4.0)
                        transition.setBlur(layer: view.layer, radius: 0.0)
                    }
                }
                frameTransition.setFrame(view: view, frame: CGRect(x: floorToScreenPixels((size.width - subtitleSize.width) * 0.5), y: 0.0, width: subtitleSize.width, height: subtitleSize.height))
            }
            return size
        }
    }

    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

public final class ShareScreen: ViewControllerComponentContainer {
    public typealias Subject = ShareScreenSubject

    public var enqueued: (([EnginePeer.Id], [Int64]) -> Void)?
    public var actionCompleted: (() -> Void)?
    public var linkCopied: ((Int32?) -> Void)?
    public var dismissed: (() -> Void)?

    private var context: AccountContext
    private var model: ShareScreenState
    private var sender: ShareScreenSendCoordinator
    private var subject: Subject
    fileprivate weak var host: ShareScreenHostController?
    private let mediaParameters: ShareControllerSubject.MediaParameters?
    fileprivate let segmentedValues: [ShareScreenSegmentedValue]?
    fileprivate private(set) var selectedSegment = 0
    fileprivate let collectibleItemInfo: TelegramCollectibleItemInfo?
    private let forcedActionTitle: String?
    fileprivate private(set) var startAtTimestampEnabled = false
    private let peerDisposable = MetaDisposable()
    private let showSenderNames = ValuePromise<Bool>(true)
    fileprivate let contentReady = Promise<Bool>(false)
    public var shareStory: (() -> Void)? {
        didSet { self.refreshComponent() }
    }
    public var canSendInHighQuality = false
    fileprivate let externalConfiguration: ShareScreenExternalConfiguration?
    fileprivate var loadingNode: ASDisplayNode?
    fileprivate var captureCaption: (() -> NSAttributedString)?
    private let accountInUse = MetaDisposable()
    private let completionDisposable = MetaDisposable()
    private var uploadCompleted = false
    private let preferredAction: ShareControllerPreferredAction
    fileprivate let externalShareSubject: ShareControllerSubject?
    private let shareAsLink: Bool
    private let saveDisposable = MetaDisposable()
    fileprivate var isSaving = false {
        didSet { if self.isSaving != oldValue { self.model.changed() } }
    }
    private let linkDisposable = MetaDisposable()
    private let groupDisposable = MetaDisposable()
    private var didNotifyDismiss = false
    private var isClosing = false
    private var copyText: String?
    private var copyIsLink = false
    private var linkPending = false
    private var copyWhenLinkReady = false
    private let animateOut = ActionSlot<Action<()>>()
    fileprivate var caption = NSAttributedString(string: "")

    public init(context: AccountContext, subject: Subject, externalShare: Bool = true, presetText: String? = nil, shareStory: (() -> Void)? = nil, preferredAction: ShareControllerPreferredAction = .default, externalShareSubject: ShareControllerSubject? = nil, shareAsLink: Bool = false, forceTheme: PresentationTheme? = nil, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, externalConfiguration: ShareScreenExternalConfiguration? = nil, mediaParameters: ShareControllerSubject.MediaParameters? = nil, segmentedValues: [ShareScreenSegmentedValue]? = nil, collectibleItemInfo: TelegramCollectibleItemInfo? = nil, forcedActionTitle: String? = nil, showInChat: ((EngineRawMessage) -> Void)? = nil, immediatePeerId: EnginePeer.Id? = nil) {
        self.externalConfiguration = externalConfiguration
        self.context = context
        var subject = subject
        if let segmentedValues, let first = segmentedValues.first {
            subject = first.subject
        }
        self.subject = subject
        self.mediaParameters = mediaParameters
        self.segmentedValues = segmentedValues.flatMap { $0.isEmpty ? nil : $0 }
        self.collectibleItemInfo = collectibleItemInfo
        self.forcedActionTitle = forcedActionTitle
        self.shareStory = shareStory
        var preferredAction = preferredAction
        if case .default = preferredAction, let showInChat, case let .messages(messages) = subject, messages.count == 1, let message = messages.first {
            let title = (updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }).strings.SharedMedia_ViewInChat
            preferredAction = .custom(action: ShareControllerAction(title: title, action: {
                showInChat(message)
            }))
        }
        self.preferredAction = preferredAction
        self.externalShareSubject = externalShareSubject
        self.shareAsLink = shareAsLink
        self.model = ShareScreenState(context: context)
        self.model.defersItemsUntilFirstLoad = externalConfiguration != nil
        self.sender = ShareScreenSendCoordinator(context: context, subject: subject)
        let contentReady = self.contentReady
        self.model.firstLoadCompleted = {
            contentReady.set(.single(true))
        }
        self.caption = NSAttributedString(string: presetText ?? "")
        super.init(context: context, component: ShareScreenComponent(model: self.model, sender: self.sender, externalShare: externalShare, initialCaption: self.caption, hasStory: shareStory != nil, animateOut: self.animateOut), navigationBarAppearance: .none, statusBarStyle: .ignore, theme: forceTheme.map { .custom($0) } ?? .default, updatedPresentationData: updatedPresentationData)
        self.navigationPresentation = .flatModal
        self.configureSender()
        if let externalConfiguration {
            self.accountInUse.set(externalConfiguration.environment.setAccountUserInterfaceInUse(id: context.account.id))
        }
        if let peerId = externalConfiguration?.immediatePeerId ?? immediatePeerId {
            self.peerDisposable.set((context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else { return }
                self.select(peer)
            }))
        }
        self.configureCopy()
    }

    private func configureCopy() {
        let context = self.context
        self.linkDisposable.set(nil)
        self.copyText = nil
        self.copyIsLink = false
        self.linkPending = false
        self.copyWhenLinkReady = false
        switch self.subject {
        case .image, .fromExternal, .quote:
            break
        case let .mapMedia(media):
            let latLong = "\(media.latitude),\(media.longitude)"
            self.copyText = "https://maps.apple.com/maps?ll=\(latLong)&q=\(latLong)&t=m"
            self.copyIsLink = true
        case let .media(reference):
            if let publicLinkPrefix = self.mediaParameters?.publicLinkPrefix {
                self.copyText = publicLinkPrefix.actualString
                self.copyIsLink = true
            } else if case let .message(message, _) = reference, let id = message.id, id.namespace == Namespaces.Message.Cloud, id.peerId.namespace == Namespaces.Peer.CloudChannel {
                self.linkPending = true
                self.copyIsLink = true
                self.linkDisposable.set((context.engine.messages.exportMessageLink(peerId: id.peerId, messageId: id) |> deliverOnMainQueue).start(next: { [weak self] link in
                    self?.linkExported(link, fallbackText: nil)
                }))
            }
        case let .url(url): self.copyText = url; self.copyIsLink = true
        case let .text(text): self.copyText = text.isEmpty ? nil : text
        case let .messages(messages):
            if let message = messages.first, messages.allSatisfy({ !$0.isCopyProtected() }) {
                let text = messages.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n\n")
                let fallbackText = text.isEmpty ? nil : text
                let sameGroup = message.groupingKey != nil && messages.allSatisfy { $0.groupingKey == message.groupingKey }
                if message.id.namespace == Namespaces.Message.Cloud, message.peers[message.id.peerId] is TelegramChannel, messages.count == 1 || sameGroup {
                    self.linkPending = true
                    self.copyIsLink = true
                    self.linkDisposable.set((context.engine.messages.exportMessageLink(peerId: message.id.peerId, messageId: message.id) |> deliverOnMainQueue).start(next: { [weak self] link in
                        self?.linkExported(link, fallbackText: fallbackText)
                    }))
                } else {
                    self.copyText = fallbackText
                }
            }
        }
    }

    private var effectiveCopyText: String? {
        guard let text = self.copyText else { return nil }
        if self.mediaParameters?.publicLinkPrefix != nil, let timestamp = self.effectiveStartTimestamp {
            return text + shareScreenTimestampLinkSuffix(timestamp)
        }
        return text
    }

    private var effectiveStartTimestamp: Int32? {
        guard self.startAtTimestampEnabled else { return nil }
        return self.mediaParameters?.startAtTimestamp
    }

    fileprivate var startAtTitle: String? {
        guard let timestamp = self.mediaParameters?.startAtTimestamp else { return nil }
        return self.context.sharedContext.currentPresentationData.with { $0 }.strings.Share_VideoStartAt(shareScreenTimestampText(timestamp)).string
    }

    fileprivate func toggleStartAt() {
        guard !self.sender.isSending else { return }
        self.startAtTimestampEnabled = !self.startAtTimestampEnabled
        self.sender.mediaStartTimestamp = self.effectiveStartTimestamp
        self.model.changed(animated: true)
    }

    fileprivate func selectSegment(_ index: Int) {
        guard let values = self.segmentedValues, index != self.selectedSegment, index >= 0, index < values.count, !self.sender.isSending else { return }
        self.selectedSegment = index
        self.subject = values[index].subject
        self.sender = ShareScreenSendCoordinator(context: self.context, subject: self.subject)
        self.configureSender()
        self.configureCopy()
        self.refreshComponent()
        self.model.changed(animated: true)
    }

    private func linkExported(_ link: String?, fallbackText: String?) {
        self.linkPending = false
        self.copyText = link ?? fallbackText
        self.copyIsLink = link != nil
        self.model.changed()
        if self.copyWhenLinkReady {
            self.copyWhenLinkReady = false
            self.action(caption: self.caption)
        }
    }

    private func configureSender() {
        self.sender.updated = { [weak self] in
            guard let self else { return }
            if !self.sender.isSending { self.loadingNode = nil }
            self.model.changed()
        }
        self.sender.present = { [weak self] controller in self?.present(controller, in: .window(.root)) }
        self.sender.premiumRequired = { [weak self] peer in self?.presentPremiumRequired(peer) }
        self.sender.navigationController = { [weak self] in self?.navigationController as? NavigationController }
        self.sender.willEnqueue = { [weak self] ids in
            guard let self else { return }
            let environment: ShareControllerEnvironment = self.externalConfiguration?.environment ?? ShareControllerAppEnvironment(sharedContext: self.context.sharedContext)
            environment.donateSendMessageIntent(account: ShareControllerAppAccountContext(context: self.context), peerIds: ids)
        }
        self.sender.enqueued = { [weak self] ids, correlations in
            guard let self else { return }
            let haptic = HapticFeedback()
            let hapticDelay = ids.count == 1 && ids.first == self.context.account.peerId ? 0.88 : 0.44
            Queue.mainQueue().after(hapticDelay) {
                haptic.success()
            }
            self.enqueued?(ids, correlations)
            self.close()
        }
        self.sender.externalStatusUpdated = { [weak self] status in self?.updateExternalStatus(status) }
        self.sender.mediaStartTimestamp = self.effectiveStartTimestamp
    }

    private func refreshComponent() {
        self.updateComponent(component: AnyComponent(ShareScreenComponent(model: self.model, sender: self.sender, externalShare: self.externalConfiguration == nil, initialCaption: self.caption, hasStory: self.shareStory != nil, animateOut: self.animateOut)), transition: .immediate)
    }

    fileprivate func presentAccountMenu(source: GlassContextExtractableContainer) {
        guard !self.sender.isSending, let configuration = self.externalConfiguration else { return }
        source.morphsIntoContextMenu = true
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        let items: [ContextMenuItem] = configuration.accounts.map { account in
            .custom(AccountPeerContextItem(context: account.context, account: account.context.account, peer: account.peer, action: { [weak self] _, dismiss in
                dismiss(.default)
                guard let self, self.context.account.id != account.context.account.id else { return }
                self.caption = self.captureCaption?() ?? self.caption
                self.view.endEditing(true)
                self.model.updated = nil
                self.context = account.context
                self.model = ShareScreenState(context: account.context)
                self.model.defersItemsUntilFirstLoad = true
                self.model.appearanceAnimationStart = CACurrentMediaTime()
                self.sender = ShareScreenSendCoordinator(context: account.context, subject: self.subject)
                self.configureSender()
                self.accountInUse.set(configuration.environment.setAccountUserInterfaceInUse(id: account.context.account.id))
                self.refreshComponent()
            }), true)
        }
        let menu = makeContextController(presentationData: data, source: .reference(ShareScreenAccountReferenceSource(sourceView: source)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        self.presentInGlobalOverlay(menu)
    }

    fileprivate func presentSendOptions(source: UIView) {
        guard !self.sender.isSending, !self.model.selection.peers.isEmpty else { return }
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        let isExternal = self.externalConfiguration != nil
        let showsSenderNameOptions = !isExternal && self.sender.sendsForwards
        let canSendInHighQuality = self.canSendInHighQuality
        let showNames = self.showSenderNames
        let items: Signal<ContextController.Items, NoError> = showNames.get()
        |> map { [weak self] showNamesValue -> ContextController.Items in
            func sendItem(_ title: String, icon: String, silently: Bool) -> ContextMenuItem {
                return .action(ContextMenuActionItem(text: title, icon: { theme in
                    generateTintedImage(image: UIImage(bundleImageName: icon), color: theme.contextMenu.primaryColor)
                }, action: { _, dismiss in
                    dismiss(.default)
                    guard let self else { return }
                    self.sender.hidesSenderNames = showsSenderNameOptions && !showNamesValue
                    self.sender.send(peers: self.model.selection.peers, topics: self.model.selection.topics, caption: self.captureCaption?() ?? self.caption, silently: silently)
                }))
            }
            func checkItem(_ title: String, isChecked: Bool, value: Bool) -> ContextMenuItem {
                return .action(ContextMenuActionItem(text: title, icon: { theme in
                    isChecked ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
                }, action: { _, _ in
                    showNames.set(value)
                }))
            }
            var items: [ContextMenuItem] = []
            if showsSenderNameOptions {
                items.append(checkItem(data.strings.Conversation_ForwardOptions_ShowSendersName, isChecked: showNamesValue, value: true))
                items.append(checkItem(data.strings.Conversation_ForwardOptions_HideSendersName, isChecked: !showNamesValue, value: false))
                items.append(.separator)
            }
            if isExternal && canSendInHighQuality {
                items.append(sendItem(data.strings.Attachment_SendInHd, icon: "Chat/Context Menu/QualityHd", silently: true))
            }
            items.append(sendItem(data.strings.Conversation_SendMessage_SendSilently, icon: "Chat/Input/Menu/SilentIcon", silently: true))
            items.append(sendItem(data.strings.Conversation_ForwardOptions_SendMessage, icon: "Chat/Context Menu/Resend", silently: false))
            return ContextController.Items(content: .list(items))
        }
        let controller = makeContextController(presentationData: data, source: .reference(ShareScreenAccountReferenceSource(sourceView: source, actionsPosition: .top)), items: items, gesture: nil)
        controller.immediateItemsTransitionAnimation = true
        self.presentInGlobalOverlay(controller)
    }

    private func updateExternalStatus(_ status: ShareControllerExternalStatus) {
        guard let configuration = self.externalConfiguration, !self.uploadCompleted else { return }
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        if self.loadingNode == nil { self.caption = self.captureCaption?() ?? self.caption }
        self.view.endEditing(true)
        let previousNode = self.loadingNode
        if case let .preparing(long) = status, long, !(self.loadingNode is ShareProlongedLoadingContainerNode) {
            self.loadingNode = ShareProlongedLoadingContainerNode(theme: data.theme, strings: data.strings, forceNativeAppearance: true, environment: configuration.environment)
        } else if self.loadingNode == nil {
            self.loadingNode = ShareLoadingContainerNode(theme: data.theme, forceNativeAppearance: true)
        }
        let loadingState: ShareLoadingState
        switch status {
        case .preparing: loadingState = .preparing
        case let .progress(value): loadingState = .progress(value)
        case .done: loadingState = .done
        }
        (self.loadingNode as? ShareLoadingContainerNode)?.state = loadingState
        (self.loadingNode as? ShareProlongedLoadingContainerNode)?.state = loadingState
        self.model.changed(animated: previousNode !== self.loadingNode)
        if case .done = status {
            self.uploadCompleted = true
            let completionDelay = (self.loadingNode as? ShareProlongedLoadingContainerNode)?.completionDuration ?? 0.9
            let hapticDelay = self.loadingNode is ShareProlongedLoadingContainerNode ? max(0.0, completionDelay - 1.5) : completionDelay
            let haptic = HapticFeedback()
            Queue.mainQueue().after(hapticDelay) {
                haptic.success()
            }
            self.completionDisposable.set((Signal<Never, NoError>.complete() |> delay(completionDelay, queue: Queue.mainQueue())).start(completed: { [weak self] in
                self?.actionCompleted?()
                self?.close()
            }))
        }
    }

    required public init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { self.accountInUse.dispose(); self.completionDisposable.dispose(); self.linkDisposable.dispose(); self.groupDisposable.dispose(); self.saveDisposable.dispose(); self.peerDisposable.dispose() }

    fileprivate var copyTitle: String? {
        let strings = self.context.sharedContext.currentPresentationData.with { $0.strings }
        switch self.preferredAction {
        case let .custom(action): return action.title
        case .saveToCameraRoll:
            switch self.subject {
            case .image: return strings.Gallery_SaveImage
            case let .media(reference): return (reference.media as? TelegramMediaFile)?.isVideo == true ? strings.Gallery_SaveVideo : strings.Gallery_SaveImage
            case .messages: return strings.Preview_SaveToCameraRoll
            default: break
            }
        case .default: break
        }
        guard self.copyText != nil || self.linkPending else { return nil }
        if let values = self.segmentedValues {
            return values[self.selectedSegment].actionTitle
        }
        if let forcedActionTitle = self.forcedActionTitle {
            return forcedActionTitle
        }
        return self.copyIsLink ? strings.ShareMenu_CopyShareLink : strings.Conversation_ContextMenuCopy
    }

    fileprivate func close(animated: Bool = true) {
        guard !self.sender.isEnqueuing, !self.isClosing else { return }
        self.isClosing = true
        self.sender.cancelPreparation(notify: false)
        if animated && self.externalConfiguration == nil {
            self.view.endEditing(true)
            self.animateOut.invoke(Action { [weak self] _ in self?.dismiss() })
        } else {
            // The sheet has already completed its interactive dismissal.
            self.dismiss()
        }
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.didNotifyDismiss {
            self.didNotifyDismiss = true
            self.dismissed?()
        }
        if self.externalConfiguration != nil {
            completion?()
            return
        }
        if let host = self.host, let navigation = self.navigationController as? NavigationController, navigation.viewControllers.first === self {
            host.dismiss(animated: false, completion: nil)
            completion?()
        } else if let navigation = self.navigationController as? NavigationController, navigation.viewControllers.first === self {
            navigation.dismiss(animated: false, completion: nil)
            completion?()
        } else {
            super.dismiss(completion: completion)
        }
    }

    fileprivate func action(caption: NSAttributedString) {
        guard !self.isSaving, !self.isClosing, !self.sender.isSending else { return }
        self.caption = caption
        if self.model.selection.peers.isEmpty {
            switch self.preferredAction {
            case let .custom(action):
                action.action()
                self.close()
                return
            case .saveToCameraRoll:
                self.saveMedia()
                return
            case .default: break
            }
            guard let text = self.effectiveCopyText else {
                if self.linkPending {
                    self.copyWhenLinkReady = true
                }
                return
            }
            UIPasteboard.general.string = text
            if self.copyIsLink, let linkCopied = self.linkCopied { linkCopied(self.effectiveStartTimestamp) } else { self.actionCompleted?() }
            self.close()
        } else {
            self.sender.send(peers: self.model.selection.peers, topics: self.model.selection.topics, caption: caption)
        }
    }

    private func saveMedia() {
        guard !self.isSaving else { return }
        var references: [(MediaResourceUserLocation, AnyMediaReference)] = []
        switch self.subject {
        case let .image(representations):
            let image = TelegramMediaImage(imageId: EngineMedia.Id(namespace: 0, id: 0), representations: representations.map { $0.representation }, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            references.append((.other, .standalone(media: image)))
        case let .media(reference):
            references.append((.other, reference))
        case let .messages(messages):
            for message in messages {
                if let media = message.effectiveMedia.first {
                    references.append((.peer(message.id.peerId), .message(message: MessageReference(message), media: media)))
                }
            }
        default: break
        }
        guard !references.isEmpty else { return }
        self.isSaving = true
        self.saveDisposable.set((combineLatest(references.map { location, reference in
            SaveToCameraRoll.saveToCameraRoll(context: self.context, userLocation: location, mediaReference: reference) |> takeLast
        }) |> filter { values in values.allSatisfy { $0 >= 1.0 } } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else { return }
            self.isSaving = false
            self.actionCompleted?()
            self.close()
        }, completed: { [weak self] in self?.isSaving = false }))
    }

    fileprivate func externalShare() {
        guard !self.sender.isSending else { return }
        if let subject = self.externalShareSubject {
            let controller = self.context.sharedContext.makeShareController(context: self.context, params: ShareControllerParams(subject: subject, externalShare: true, immediateExternalShare: true, shareAsLink: self.shareAsLink))
            self.present(controller, in: .window(.root))
        } else if let text = self.effectiveCopyText {
            presentExternalShare(context: self.context, text: text, parentController: self)
        }
    }

    fileprivate func repost() {
        guard !self.sender.isSending, let shareStory = self.shareStory else { return }
        if self.externalConfiguration != nil {
            self.dismiss(completion: shareStory)
            return
        }
        self.animateOut.invoke(Action { [weak self] _ in
            self?.dismiss(completion: shareStory)
        })
    }

    private func presentPremiumRequired(_ peer: EnginePeer) {
        self.forEachController { controller in
            if let controller = controller as? UndoOverlayController { controller.dismiss() }
            return true
        }
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        let hasAction = !PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 }).isPremiumDisabled
        self.present(UndoOverlayController(presentationData: data, content: .premiumPaywall(
            title: nil, text: data.strings.Chat_ToastMessagingRestrictedToPremium_Text(peer.compactDisplayTitle).string,
            customUndoText: hasAction ? data.strings.Chat_ToastMessagingRestrictedToPremium_Action : nil,
            timeout: nil, linkAction: { _ in }
        ), elevatedLayout: false, animateInAsReplacement: false, action: { [weak self] action in
            guard let self else { return false }
            if case .undo = action, let navigation = self.navigationController as? NavigationController {
                self.view.endEditing(true)
                let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .settings, forceDark: false, dismissed: nil)
                controller.navigationPresentation = .modal
                navigation.pushViewController(controller)
            }
            return false
        }), in: .current)
    }

    fileprivate func select(_ peer: EnginePeer) {
        guard !self.sender.isSending else { return }
        if !self.model.selection.contains(peer.id), self.model.messagingRequirement(for: peer).requiresPremium {
            self.presentPremiumRequired(peer)
            return
        }
        if case .community = peer {
            self.view.endEditing(true)
            self.model.openCommunity(peer)
        } else if !self.model.selection.contains(peer.id), peer._asPeer().isForumOrMonoForum {
            self.view.endEditing(true)
            self.model.openForum(peer)
        } else if self.model.isSearching && !self.model.query.isEmpty {
            if !self.model.selection.contains(peer.id) {
                self.model.selection.toggle(peer)
            }
            self.model.noteSelectedInSearch(peer)
            self.view.endEditing(true)
            self.model.setSearching(false)
        } else {
            self.model.selection.toggle(peer)
            self.model.noteSelectedInSearch(peer)
            self.model.changed(animated: true)
        }
    }

    fileprivate func createGroup(caption: NSAttributedString) {
        guard !self.sender.isSending else { return }
        self.caption = caption
        self.view.endEditing(true)
        let users = self.model.selection.peers.filter { peer in
            if case let .user(user) = peer { return user.botInfo == nil && user.id != self.context.account.peerId }
            return false
        }
        guard let navigation = self.navigationController as? NavigationController else { return }
        if users.isEmpty {
            let selector = self.context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: self.context, mode: .groupCreation(isCall: false), onlyWriteable: true))
            self.groupDisposable.set((selector.result |> deliverOnMainQueue).start(next: { [weak self, weak selector] result in
                guard let self, let selector, case let .result(ids, _) = result else { return }
                let peerIds = ids.compactMap { id -> EnginePeer.Id? in
                    if case let .peer(id) = id { return id }
                    return nil
                }
                guard !peerIds.isEmpty else { return }
                self.presentGroupCreation(peerIds: peerIds, navigation: selector.navigationController as? NavigationController)
            }))
            selector.navigationPresentation = .modal
            navigation.pushViewController(selector)
        } else {
            self.presentGroupCreation(peerIds: users.map(\.id), navigation: navigation)
        }
    }

    private func presentGroupCreation(peerIds: [EnginePeer.Id], navigation: NavigationController?) {
        guard let navigation else { return }
        let controller = self.context.sharedContext.makeCreateGroupController(context: self.context, peerIds: peerIds, initialTitle: nil, mode: .generic, completion: { [weak self, weak navigation] id, _ in
            guard let self else { return }
            self.groupDisposable.set((self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: id)) |> deliverOnMainQueue).start(next: { [weak self, weak navigation] peer in
                guard let self, let peer else { return }
                self.model.selectCreatedGroup(peer)
                navigation?.setViewControllers([self], animated: true)
            }))
        })
        controller.navigationPresentation = .modal
        navigation.pushViewController(controller)
    }

}

private func shareScreenFindContentView(in view: UIView) -> ShareScreenContentComponent.View? {
    if let view = view as? ShareScreenContentComponent.View {
        return view
    }
    for subview in view.subviews {
        if let result = shareScreenFindContentView(in: subview) {
            return result
        }
    }
    return nil
}

private func shareScreenParentScrollOffset(saved: CGFloat, nested: CGFloat?) -> CGFloat {
    guard saved < 0.0, let nested else { return saved }
    return max(saved, min(0.0, nested))
}

private final class ShareScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let model: ShareScreenState
    let sender: ShareScreenSendCoordinator
    let externalShare: Bool
    let initialCaption: NSAttributedString
    let hasStory: Bool
    let animateOut: ActionSlot<Action<()>>

    init(model: ShareScreenState, sender: ShareScreenSendCoordinator, externalShare: Bool, initialCaption: NSAttributedString, hasStory: Bool, animateOut: ActionSlot<Action<()>>) {
        self.model = model; self.sender = sender; self.externalShare = externalShare
        self.initialCaption = initialCaption; self.hasStory = hasStory; self.animateOut = animateOut
    }
    static func ==(lhs: ShareScreenComponent, rhs: ShareScreenComponent) -> Bool { return lhs === rhs }

    final class State: ComponentState {
        init(model: ShareScreenState) {
            super.init()
            self.bind(model: model)
        }
        func bind(model: ShareScreenState) {
            model.updated = { [weak self] animated in
                self?.updated(transition: animated ? .spring(duration: 0.35) : .immediate)
            }
        }
    }
    func makeState() -> State { return State(model: self.model) }

    final class View: UIView {
        private var sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
        private let externalState = ResizableSheetComponent<EnvironmentType>.ExternalState()
        private var panelState = ShareScreenPanelState()
        private var accountId: AccountRecordId?
        private let boundsUpdated = ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>()
        private let layoutApplied = ActionSlot<Void>()
        private var previousForumId: EnginePeer.Id?
        private var previousInputHeight: CGFloat = 0.0
        private var previousSearching = false
        private var previousFilter: Int32 = 0
        private var previousQuery = ""
        private var peersScrollOffset: CGFloat = 0.0
        private var previousCreatedGroupId: EnginePeer.Id?
        private var previousCommunityId: EnginePeer.Id?
        private var communityParentScrollOffset: CGFloat = 0.0
        private var preSearchExpansion: CGFloat = 0.0
        private var pendingSearchExitExpansion: CGFloat?
        private var initializedCaption = false
        private var animatesSheetAppearance = true
        private weak var accountSwitchOverlay: UIView?
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.accessibilityViewIsModal = true
        }

        func update(component: ShareScreenComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let model = component.model
            state.bind(model: model)
            if self.accountId != model.context.account.id {
                let isSwitch = self.accountId != nil
                self.accountId = model.context.account.id
                if isSwitch, let sheetView = self.sheet.view, let contentView = shareScreenFindContentView(in: sheetView) {
                    let overlay = UIView(frame: self.bounds)
                    overlay.isUserInteractionEnabled = false
                    self.addSubview(overlay)
                    contentView.makeAccountSwitchOutgoingItems(in: overlay)
                    self.accountSwitchOverlay = overlay
                    Queue.mainQueue().after(1.0) { [weak overlay] in overlay?.removeFromSuperview() }
                }
                self.animatesSheetAppearance = !isSwitch
                self.sheet.view?.removeFromSuperview()
                self.sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
                self.panelState = ShareScreenPanelState()
                self.initializedCaption = false
                self.previousForumId = nil
                self.previousCommunityId = nil
                self.previousSearching = false
                self.previousFilter = 0
                self.previousQuery = ""
            }
            let theme = environment.theme
            let strings = environment.strings
            let controller = environment.controller
            if !self.initializedCaption {
                self.initializedCaption = true
                self.panelState.initialCaption = component.initialCaption
            }
            (controller() as? ShareScreen)?.captureCaption = { [weak self] in self?.panelState.caption() ?? NSAttributedString(string: "") }
            let selected = model.selection.peers
            var subtitle: [AnimatedTextComponent.Item] = []
            if selected.isEmpty {
                subtitle.append(AnimatedTextComponent.Item(id: "placeholder", isUnbreakable: true, content: .text(strings.ShareMenu_SelectChats)))
            } else {
                for (index, peer) in selected.enumerated() {
                    if index != 0 {
                        subtitle.append(AnimatedTextComponent.Item(id: "separator-\(peer.id)", isUnbreakable: true, content: .text(", ")))
                    }
                    let name = peer.id == model.context.account.peerId ? strings.DialogList_SavedMessages : model.displayPeer(peer).compactDisplayTitle
                    subtitle.append(AnimatedTextComponent.Item(id: peer.id, isUnbreakable: true, content: .text(name)))
                }
            }
            let copyTitle = (controller() as? ShareScreen)?.copyTitle
            let isEmbedded = (controller() as? ShareScreen)?.externalConfiguration != nil
            let height = isEmbedded ? availableSize.height : max(0.0, availableSize.height - environment.statusBarHeight - 10.0)
            self.panelState.heightUpdated = { [weak state] in state?.updated(transition: transition) }
            let bottomHeight = self.panelState.height + (environment.inputHeight > 0.0 ? 16.0 : 26.0)
            let hostScreen = controller() as? ShareScreen
            var contentHeader: AnyComponentWithIdentity<Empty>?
            if let values = hostScreen?.segmentedValues {
                contentHeader = AnyComponentWithIdentity(id: "segments", component: AnyComponent(SegmentControlComponent(
                    theme: SegmentControlComponent.Theme(theme: theme),
                    items: values.enumerated().map { SegmentControlComponent.Item(id: $0.offset, title: $0.element.title) },
                    selectedId: hostScreen?.selectedSegment ?? 0,
                    fillWidth: true,
                    action: { id in
                        guard let index = id.base as? Int else { return }
                        (controller() as? ShareScreen)?.selectSegment(index)
                    }
                )))
            } else if let info = hostScreen?.collectibleItemInfo {
                let sharedContext = model.context.sharedContext
                contentHeader = AnyComponentWithIdentity(id: "collectible", component: AnyComponent(ShareScreenCollectibleInfoComponent(theme: theme, strings: strings, info: info, openUrl: { url in
                    sharedContext.applicationBindings.openUrl(url)
                })))
            }
            var bottomAccessory: AnyComponentWithIdentity<Empty>?
            if let startAtTitle = hostScreen?.startAtTitle {
                bottomAccessory = AnyComponentWithIdentity(id: "startAt", component: AnyComponent(ShareScreenCheckOptionComponent(theme: theme, title: startAtTitle, isSelected: hostScreen?.startAtTimestampEnabled ?? false, action: {
                    (controller() as? ShareScreen)?.toggleStartAt()
                })))
            }
            let content = ShareScreenContentComponent(model: model, height: height, bottomInset: bottomHeight + environment.safeInsets.bottom, isLoading: (controller() as? ShareScreen)?.loadingNode != nil, header: contentHeader, select: { peer in
                (controller() as? ShareScreen)?.select(peer)
            }, story: component.hasStory ? { (controller() as? ShareScreen)?.repost() } : nil, createGroup: { [weak self] in
                (controller() as? ShareScreen)?.createGroup(caption: self?.panelState.caption() ?? NSAttributedString(string: ""))
            }, boundsUpdated: self.boundsUpdated, layoutApplied: self.layoutApplied)
            let bottom: AnyComponent<Empty> = AnyComponent(BottomPanelComponent(context: model.context, theme: theme, strings: strings, actionTitle: copyTitle, actionBadge: selected.isEmpty ? nil : selected.count, panelState: self.panelState, showsActionButton: !model.isSearching, hiddenActionOffset: environment.inputHeight + environment.safeInsets.bottom + 100.0, inlineSendButton: model.isSearching, sheetSideInset: ResizableSheetComponent<EnvironmentType>.bottomItemSideInset(inputHeight: environment.inputHeight), metrics: environment.metrics, deviceMetrics: environment.deviceMetrics, isSending: component.sender.isSending || (controller() as? ShareScreen)?.isSaving == true, showsProgress: (controller() as? ShareScreen)?.isSaving == true, present: { c in controller()?.present(c, in: .window(.root)) }, accessory: bottomAccessory, actionOptions: { source in (controller() as? ShareScreen)?.presentSendOptions(source: source) }, action: { [weak self] in
                (controller() as? ShareScreen)?.action(caption: self?.panelState.caption() ?? NSAttributedString(string: ""))
            }))
            let communityChanged = self.previousCommunityId != model.communityPeer?.id
            let nestedPeer = (controller() as? ShareScreen)?.loadingNode == nil ? (model.forumPeer ?? model.communityPeer) : nil
            let forumChanged = self.previousForumId != model.forumPeer?.id
            if communityChanged && model.communityPeer != nil, let view = self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View {
                self.communityParentScrollOffset = view.contentScrollOffset
            }
            let searchModeChanged = self.previousSearching != model.isSearching
            let searchChanged = searchModeChanged || self.previousFilter != model.filterId || self.previousQuery != model.query
            if forumChanged && model.forumPeer != nil, let view = self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View {
                self.peersScrollOffset = view.contentScrollOffset
            }
            let inputHeightChanged = self.previousInputHeight != environment.inputHeight
            let previousContentOffset = (self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View)?.contentScrollOffset
            if searchModeChanged && model.isSearching, let view = self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View {
                self.preSearchExpansion = view.expansionFraction
            }
            let screen = controller() as? ShareScreen
            let loadingNode = screen?.loadingNode
            if loadingNode != nil { self.panelState.initialCaption = screen?.caption ?? component.initialCaption }
            var rightItem: AnyComponent<Empty> = AnyComponent(ShareScreenBarButtonComponent(theme: theme, title: strings.ShareMenu_ShareTo, icon: "Navigation/Share", isVisible: nestedPeer == nil && !model.isSearching && component.externalShare && (copyTitle != nil || screen?.externalShareSubject != nil), action: {
                (controller() as? ShareScreen)?.externalShare()
            }))
            if let configuration = screen?.externalConfiguration, let account = configuration.accounts.first(where: { $0.context.account.id == model.context.account.id }) {
                rightItem = AnyComponent(ShareScreenFadeComponent(content: AnyComponent(AccountSwitchComponent(context: account.context, theme: theme, peer: account.peer, canSwitch: configuration.accounts.count > 1, isVisible: true, action: { source in
                    (controller() as? ShareScreen)?.presentAccountMenu(source: source)
                })), isVisible: nestedPeer == nil && !model.isSearching && loadingNode == nil))
            }
            self.sheet.parentState = state
            let sheetDefaultHeight: CGFloat = loadingNode == nil ? min(540.0, height) : (loadingNode is ShareProlongedLoadingContainerNode ? 420.0 : 260.0)
            let size = self.sheet.update(transition: transition, component: AnyComponent(ResizableSheetComponent<EnvironmentType>(
                content: AnyComponent(ShareScreenBodyComponent(content: AnyComponent(content), loadingNode: loadingNode, loadingHeight: isEmbedded ? height : sheetDefaultHeight)),
                titleItem: AnyComponent(ShareScreenHeaderComponent(title: nestedPeer.map { model.displayPeer($0).compactDisplayTitle } ?? strings.ShareScreen_Title, subtitle: model.forumPeer == nil ? subtitle : [AnimatedTextComponent.Item(id: "topic", isUnbreakable: true, content: .text(model.forumPeer?._asPeer().isMonoForum == true ? strings.ShareMenu_SelectChats : strings.ShareMenu_SelectTopic))], theme: theme, isHidden: loadingNode == nil && model.isSearching && nestedPeer == nil)),
                leftItem: AnyComponent(ShareScreenBarButtonComponent(theme: theme, title: nestedPeer == nil ? strings.Common_Close : strings.Common_Back, icon: nestedPeer == nil ? "Navigation/Close" : "Navigation/Back", isVisible: loadingNode != nil || !model.isSearching || nestedPeer != nil, action: {
                    if loadingNode != nil { (controller() as? ShareScreen)?.close() } else if model.forumPeer != nil { model.closeForum() } else if model.communityPeer != nil { model.closeCommunity() } else { (controller() as? ShareScreen)?.close() }
                })),
                rightItem: rightItem,
                hasTopEdgeEffect: loadingNode == nil && nestedPeer != nil,
                hasBottomEdgeEffect: loadingNode == nil && (!selected.isEmpty || (!model.isSearching && (copyTitle != nil || bottomAccessory != nil))),
                bottomEdgeEffectColor: isEmbedded && selected.isEmpty && copyTitle == nil ? .clear : nil,
                bottomItem: loadingNode == nil ? bottom : nil,
                bottomEdgeEffectExtension: loadingNode == nil && !model.isSearching && hostScreen?.startAtTitle != nil ? 60.0 : 0.0,
                backgroundColor: .color(theme.list.modalPlainBackgroundColor), clipsContent: true, delaysContentTouches: false,
                isEmbedded: isEmbedded,
                allowsExpansion: loadingNode == nil,
                locksExpansion: loadingNode == nil && model.isSearching,
                slidesOutBottomItem: isEmbedded,
                animatesAppearance: self.animatesSheetAppearance,
                scrollsContentWhenCentered: true,
                centeredSize: environment.metrics.widthClass == .regular ? CGSize(width: min(414.0, availableSize.width - 20.0), height: min(670.0, availableSize.height - 88.0)) : nil,
                defaultHeight: sheetDefaultHeight, externalState: self.externalState, animateOut: component.animateOut
            )), environment: {
                environment
                ResizableSheetComponentEnvironment(theme: theme, statusBarHeight: environment.statusBarHeight, safeInsets: environment.safeInsets, inputHeight: environment.inputHeight, metrics: environment.metrics, deviceMetrics: environment.deviceMetrics, isDisplaying: environment.isVisible, isCentered: environment.presentsFloatingPanels, screenSize: availableSize, regularMetricsSize: CGSize(width: 430.0, height: 900.0), dismiss: { animated in (controller() as? ShareScreen)?.close(animated: animated) }, boundsUpdated: self.boundsUpdated)
            }, containerSize: availableSize)
            if let view = self.sheet.view {
                if view.superview == nil {
                    self.addSubview(view)
                    if let overlay = self.accountSwitchOverlay {
                        self.bringSubviewToFront(overlay)
                    }
                }
                transition.setFrame(view: view, frame: CGRect(origin: .zero, size: size))
            }
            if let view = self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View {
                if self.previousCreatedGroupId != model.createdGroup?.id {
                    view.setContentScrollOffset(0.0, transition: .immediate)
                } else if forumChanged {
                    if model.forumPeer == nil {
                        view.setContentScrollOffset(shareScreenParentScrollOffset(saved: self.peersScrollOffset, nested: previousContentOffset), transition: (previousContentOffset ?? 0.0) < -0.5 ? transition : .immediate)
                    } else {
                        view.setContentScrollOffset(min(0.0, self.peersScrollOffset), transition: .immediate)
                    }
                } else if communityChanged {
                    if model.communityPeer == nil {
                        view.setContentScrollOffset(shareScreenParentScrollOffset(saved: self.communityParentScrollOffset, nested: previousContentOffset), transition: (previousContentOffset ?? 0.0) < -0.5 ? transition : .immediate)
                    } else {
                        view.setContentScrollOffset(min(0.0, self.communityParentScrollOffset), transition: .immediate)
                    }
                } else if searchChanged {
                    view.setExpansionFraction(model.isSearching ? 1.0 : self.preSearchExpansion, transition: searchModeChanged ? transition : .immediate)
                    self.pendingSearchExitExpansion = searchModeChanged && !model.isSearching && environment.inputHeight > 0.0 ? self.preSearchExpansion : nil
                } else if !model.isSearching && inputHeightChanged, let expansion = self.pendingSearchExitExpansion {
                    self.pendingSearchExitExpansion = nil
                    view.setExpansionFraction(expansion, transition: transition)
                } else if model.isSearching && inputHeightChanged, let previousContentOffset {
                    // Keyboard changes alter the sheet's collapsed inset. Keep
                    // the list at the same offset relative to the expanded sheet.
                    view.setContentScrollOffset(max(0.0, previousContentOffset), transition: transition)
                }
            }
            self.previousCreatedGroupId = model.createdGroup?.id
            self.previousCommunityId = model.communityPeer?.id
            self.previousForumId = model.forumPeer?.id
            self.previousInputHeight = environment.inputHeight
            self.previousSearching = model.isSearching
            self.previousFilter = model.filterId
            self.previousQuery = model.query
            self.layoutApplied.invoke(Void())
            return availableSize
        }
    }
    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
