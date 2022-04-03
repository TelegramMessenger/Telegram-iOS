import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AttachmentTextInputPanelNode
import ChatPresentationInterfaceState
import ChatSendMessageActionUI
import ChatTextLinkEditUI
import PhotoResources
import AnimatedStickerComponent

private let buttonSize = CGSize(width: 88.0, height: 49.0)
private let smallButtonWidth: CGFloat = 69.0
private let iconSize = CGSize(width: 30.0, height: 30.0)
private let sideInset: CGFloat = 3.0

private final class IconComponent: Component {
    public let account: Account
    public let name: String
    public let file: TelegramMediaFile?
    public let animationName: String?
    public let tintColor: UIColor?
    
    public init(account: Account, name: String, file: TelegramMediaFile?, animationName: String?, tintColor: UIColor?) {
        self.account = account
        self.name = name
        self.file = file
        self.animationName = animationName
        self.tintColor = tintColor
    }
    
    public static func ==(lhs: IconComponent, rhs: IconComponent) -> Bool {
        if lhs.account !== rhs.account {
            return false
        }
        if lhs.name != rhs.name {
            return false
        }
        if lhs.file?.fileId != rhs.file?.fileId {
            return false
        }
        if lhs.animationName != rhs.animationName {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return false
    }
    
    public final class View: UIImageView {
        private var component: IconComponent?
        private var disposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func update(component: IconComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.component?.name != component.name || self.component?.file?.fileId != component.file?.fileId || self.component?.tintColor != component.tintColor {
                if let file = component.file {
                    let previousName = self.component?.name ?? ""
                    if !previousName.isEmpty {
                        self.image = nil
                    }
                    
                    self.disposable = (svgIconImageFile(account: component.account, fileReference: .standalone(media: file), fetched: true)
                    |> runOn(Queue.concurrentDefaultQueue())
                    |> deliverOnMainQueue).start(next: { [weak self] transform in
                        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: availableSize, boundingSize: availableSize, intrinsicInsets: UIEdgeInsets())
                        let drawingContext = transform(arguments)
                        let image = drawingContext?.generateImage()?.withRenderingMode(.alwaysTemplate)
                        if let tintColor = component.tintColor {
                            self?.image = generateTintedImage(image: image, color: tintColor, backgroundColor: nil)
                        } else {
                            self?.image = image
                        }
                    })
                } else {
                    if let tintColor = component.tintColor {
                        self.image = generateTintedImage(image: UIImage(bundleImageName: component.name), color: tintColor, backgroundColor: nil)
                    } else {
                        self.image = UIImage(bundleImageName: component.name)
                    }
                }
            }
            self.component = component
                        
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}


private final class AttachButtonComponent: CombinedComponent {
    let context: AccountContext
    let type: AttachmentButtonType
    let isSelected: Bool
    let strings: PresentationStrings
    let theme: PresentationTheme
    let action: () -> Void
    
    init(
        context: AccountContext,
        type: AttachmentButtonType,
        isSelected: Bool,
        strings: PresentationStrings,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.type = type
        self.isSelected = isSelected
        self.strings = strings
        self.theme = theme
        self.action = action
    }

    static func ==(lhs: AttachButtonComponent, rhs: AttachButtonComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    static var body: Body {
        let icon = Child(IconComponent.self)
        let animatedIcon = Child(AnimatedStickerComponent.self)
        let title = Child(Text.self)
        let button = Child(Rectangle.self)

        return { context in
            let name: String
            let imageName: String
            var imageFile: TelegramMediaFile?
            var animationFile: TelegramMediaFile?
            
            let component = context.component
            let strings = component.strings
            
            switch component.type {
            case .gallery:
                name = strings.Attachment_Gallery
                imageName = "Chat/Attach Menu/Gallery"
            case .file:
                name = strings.Attachment_File
                imageName = "Chat/Attach Menu/File"
            case .location:
                name = strings.Attachment_Location
                imageName = "Chat/Attach Menu/Location"
            case .contact:
                name = strings.Attachment_Contact
                imageName = "Chat/Attach Menu/Contact"
            case .poll:
                name = strings.Attachment_Poll
                imageName = "Chat/Attach Menu/Poll"
            case let .app(_, appName, appIcons):
                name = appName
                imageName = ""
                if let file = appIcons[.iOSAnimated] {
                    animationFile = file
                } else if let file = appIcons[.iOSStatic] {
                    imageFile = file
                } else if let file = appIcons[.default] {
                    imageFile = file
                }
            case .standalone:
                name = ""
                imageName = ""
                imageFile = nil
            }

            let tintColor = component.isSelected ? component.theme.rootController.tabBar.selectedIconColor : component.theme.rootController.tabBar.iconColor
            
            let iconSize = CGSize(width: 30.0, height: 30.0)
            let topInset: CGFloat = 4.0 + UIScreenPixel
            let spacing: CGFloat = 15.0 + UIScreenPixel
            
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - iconSize.width) / 2.0), y: topInset), size: iconSize)
            if let animationFile = animationFile {
                let icon = animatedIcon.update(
                    component: AnimatedStickerComponent(
                        account: component.context.account,
                        animation: AnimatedStickerComponent.Animation(
                            source: .file(media: animationFile),
                            loop: false,
                            tintColor: tintColor
                        ),
                        isAnimating: component.isSelected,
                        size: CGSize(width: iconSize.width, height: iconSize.height)
                    ),
                    availableSize: iconSize,
                    transition: context.transition
                )
                context.add(icon
                    .position(CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                )
            } else {
                let icon = icon.update(
                    component: IconComponent(
                        account: component.context.account,
                        name: imageName,
                        file: imageFile,
                        animationName: nil,
                        tintColor: tintColor
                    ),
                    availableSize: iconSize,
                    transition: context.transition
                )
                context.add(icon
                    .position(CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                )
            }

            let title = title.update(
                component: Text(
                    text: name,
                    font: Font.regular(10.0),
                    color: context.component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let button = button.update(
                component: Rectangle(
                    color: .clear,
                    width: context.availableSize.width,
                    height: context.availableSize.height
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )

            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - title.size.width) / 2.0), y: iconFrame.midY + spacing), size: title.size)
            
            context.add(title
                .position(CGPoint(x: titleFrame.midX, y: titleFrame.midY))
            )
            
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                .gesture(.tap {
                    component.action()
                })
            )
                        
            return context.availableSize
        }
    }
}

private final class LoadingProgressNode: ASDisplayNode {
    var color: UIColor {
        didSet {
            self.foregroundNode.backgroundColor = self.color
        }
    }
    
    private let foregroundNode: ASDisplayNode
    
    init(color: UIColor) {
        self.color = color
        
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.backgroundColor = color
        
        super.init()
        
        self.addSubnode(self.foregroundNode)
    }
        
    private var _progress: CGFloat = 0.0
    func updateProgress(_ progress: CGFloat, animated: Bool = false) {
        if self._progress == progress && animated {
            return
        }
        
        var animated = animated
        if (progress < self._progress && animated) {
            animated = false
        }
        
        let size = self.bounds.size
        
        self._progress = progress
        
        let transition: ContainedViewLayoutTransition
        if animated && progress > 0.0 {
            transition = .animated(duration: 0.7, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let alpaTransition: ContainedViewLayoutTransition
        if animated {
            alpaTransition = .animated(duration: 0.3, curve: .easeInOut)
        } else {
            alpaTransition = .immediate
        }
        
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(x: -2.0, y: 0.0, width: (size.width + 4.0) * progress, height: size.height))
        
        let alpha: CGFloat = progress < 0.001 || progress > 0.999 ? 0.0 : 1.0
        alpaTransition.updateAlpha(node: self.foregroundNode, alpha: alpha)
    }
    
    override func layout() {
        super.layout()
        
        self.foregroundNode.cornerRadius = self.frame.height / 2.0
    }
}

public struct AttachmentMainButtonState {
    let text: String?
    let backgroundColor: UIColor
    let textColor: UIColor
    let isEnabled: Bool
    let isVisible: Bool
    
    public init(
        text: String?,
        backgroundColor: UIColor,
        textColor: UIColor,
        isEnabled: Bool,
        isVisible: Bool
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.isEnabled = isEnabled
        self.isVisible = isVisible
    }
    
    static var initial: AttachmentMainButtonState {
        return AttachmentMainButtonState(text: nil, backgroundColor: .clear, textColor: .clear, isEnabled: false, isVisible: false)
    }
}

private final class MainButtonNode: HighlightTrackingButtonNode {
    private var state: AttachmentMainButtonState
    
    private let backgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
        
    override init(pointerStyle: PointerStyle? = nil) {
        self.state = AttachmentMainButtonState.initial
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.allowsGroupOpacity = true
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.textAlignment = .center
        
        super.init(pointerStyle: pointerStyle)
        
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self, strongSelf.state.isEnabled {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.65
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, state: AttachmentMainButtonState, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.state = state
        
        self.isUserInteractionEnabled = state.isVisible
        self.isEnabled = state.isEnabled
        transition.updateAlpha(node: self, alpha: state.isEnabled ? 1.0 : 0.4)
        
        let buttonHeight = 50.0
        if let text = state.text {
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.semibold(16.0), textColor: state.textColor)
            
            let textSize = self.textNode.updateLayout(layout.size)
            self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - textSize.width) / 2.0), y: floorToScreenPixels((buttonHeight - textSize.height) / 2.0)), size: textSize)
            
            self.backgroundNode.backgroundColor = state.backgroundColor
        }
        
        let totalButtonHeight = buttonHeight + layout.intrinsicInsets.bottom
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: totalButtonHeight)))
        transition.updateSublayerTransformOffset(layer: self.layer, offset: CGPoint(x: 0.0, y: state.isVisible ? 0.0 : totalButtonHeight))
        
        return totalButtonHeight
    }
}

final class AttachmentPanel: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var iconDisposables: [MediaId: Disposable] = [:]
    
    private var presentationInterfaceState: ChatPresentationInterfaceState
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let containerNode: ASDisplayNode
    private let backgroundNode: NavigationBackgroundNode
    private let scrollNode: ASScrollNode
    private let separatorNode: ASDisplayNode
    private var buttonViews: [Int: ComponentHostView<Empty>] = [:]
    
    private var textInputPanelNode: AttachmentTextInputPanelNode?
    private var progressNode: LoadingProgressNode?
    private var mainButtonNode: MainButtonNode
    
    private var loadingProgress: CGFloat?
    private var mainButtonState: AttachmentMainButtonState = .initial
    
    private var buttons: [AttachmentButtonType] = []
    private var selectedIndex: Int = 0
    private(set) var isSelecting: Bool = false
    private(set) var isButtonVisible: Bool = false
        
    private var validLayout: ContainerViewLayout?
    private var scrollLayout: (width: CGFloat, contentSize: CGSize)?
    
    var selectionChanged: (AttachmentButtonType) -> Bool = { _ in return false }
    var beganTextEditing: () -> Void = {}
    var textUpdated: (NSAttributedString) -> Void = { _ in }
    var sendMessagePressed: (AttachmentTextInputPanelSendMode) -> Void = { _ in }
    var requestLayout: () -> Void = {}
    var present: (ViewController) -> Void = { _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    
    var mainButtonPressed: () -> Void = { }
    
    init(context: AccountContext, chatLocation: ChatLocation, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: .builtin(WallpaperSettings()), theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: self.context.account.peerId, mode: .standard(previewing: false), chatLocation: chatLocation, subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil)
        
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        
        self.scrollNode = ASScrollNode()
        
        self.backgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.tabBar.separatorColor
        
        self.mainButtonNode = MainButtonNode()
        
        super.init()
                        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.separatorNode)
        self.containerNode.addSubnode(self.scrollNode)
        
        self.addSubnode(self.mainButtonNode)
        
        self.mainButtonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, deleteSelectedMessages: {
        }, reportSelectedMessages: {
        }, reportMessages: { _, _ in
        }, blockMessageAuthor: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, updateForwardOptionsState: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardOptionsState($0.forwardOptionsState) }) })
            }
        }, presentForwardOptions: { _ in
        }, shareSelectedMessages: {
        }, updateTextInputStateAndMode: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                    let (updatedState, updatedMode) = f(state.interfaceState.effectiveInputState, state.inputMode)
                    return state.updatedInterfaceState { interfaceState in
                        return interfaceState.withUpdatedEffectiveInputState(updatedState)
                    }.updatedInputMode({ _ in updatedMode })
                })
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    return $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({
                        $0.withUpdatedMessageActionsState({ value in
                            var value = value
                            value.closedButtonKeyboardMessageId = updatedClosedButtonKeyboardMessageId
                            return value
                        })
                    })
                })
            }
        }, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, openSearchResults: {
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _, _, _, _ in
        }, navigateToChat: { _ in
        }, navigateToProfile: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _, _, _ in
            return false
        }, sendBotCommand: { _, _ in
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: { _ in
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _, _ in
            return false
        }, unblockPeer: {
        }, pinMessage: { _, _ in
        }, unpinMessage: { _, _, _ in
        }, unpinAllMessages: {
        }, openPinnedList: { _ in
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: { _ in
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, getNavigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, requestUnvoteInMessage: { _ in
        }, requestStopPollInMessage: { _ in
        }, updateInputLanguage: { _ in
        }, unarchiveChat: {
        }, openLinkEditing: { [weak self] in
            if let strongSelf = self {
                var selectionRange: Range<Int>?
                var text: String?
                var inputMode: ChatInputMode?

                strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                    selectionRange = state.interfaceState.effectiveInputState.selectionRange
                    if let selectionRange = selectionRange {
                        text = state.interfaceState.effectiveInputState.inputText.attributedSubstring(from: NSRange(location: selectionRange.startIndex, length: selectionRange.count)).string
                    }
                    inputMode = state.inputMode
                    return state
                })

                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let controller = chatTextLinkEditController(sharedContext: strongSelf.context.sharedContext, updatedPresentationData: (presentationData, .never()), account: strongSelf.context.account, text: text ?? "", link: nil, apply: { [weak self] link in
                    if let strongSelf = self, let inputMode = inputMode, let selectionRange = selectionRange {
                        if let link = link {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                                return state.updatedInterfaceState({
                                    $0.withUpdatedEffectiveInputState(chatTextInputAddLinkAttribute($0.effectiveInputState, selectionRange: selectionRange, url: link))
                                })
                            })
                        }
                        if let textInputPanelNode = strongSelf.textInputPanelNode {
                            textInputPanelNode.ensureFocused()
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                            return state.updatedInputMode({ _ in return inputMode }).updatedInterfaceState({
                                $0.withUpdatedEffectiveInputState(ChatTextInputState(inputText: $0.effectiveInputState.inputText, selectionRange: selectionRange.endIndex ..< selectionRange.endIndex))
                            })
                        })
                    }
                })
                strongSelf.present(controller)
            }
        }, reportPeerIrrelevantGeoLocation: {
        }, displaySlowmodeTooltip: { _, _ in
        }, displaySendMessageOptions: { [weak self] node, gesture in
            guard let strongSelf = self, let textInputPanelNode = strongSelf.textInputPanelNode else {
                return
            }
            textInputPanelNode.loadTextInputNodeIfNeeded()
            guard let textInputNode = textInputPanelNode.textInputNode else {
                return
            }
            let controller = ChatSendMessageActionSheetController(context: strongSelf.context, interfaceState: strongSelf.presentationInterfaceState, gesture: gesture, sourceSendButton: node, textInputNode: textInputNode, attachment: true, completion: {
            }, sendMessage: { [weak textInputPanelNode] silently in
                textInputPanelNode?.sendMessage(silently ? .silent : .generic)
            }, schedule: { [weak textInputPanelNode] in
                textInputPanelNode?.sendMessage(.schedule)
            })
            strongSelf.presentInGlobalOverlay(controller)
        }, openScheduledMessages: {
        }, openPeersNearby: {
        }, displaySearchResultsTooltip: { _, _ in
        }, unarchivePeer: {
        }, scrollToTop: {
        }, viewReplies: { _, _ in
        }, activatePinnedListPreview: { _, _ in
        }, joinGroupCall: { _ in
        }, presentInviteMembers: {
        }, presentGigagroupHelp: {
        }, editMessageMedia: { _, _ in
        }, updateShowCommands: { _ in
        }, updateShowSendAsPeers: { _ in
        }, openInviteRequests: {
        }, openSendAsPeer: { _, _ in
        }, presentChatRequestAdminInfo: {
        }, displayCopyProtectionTip: { _, _ in
        }, chatController: {
            return nil
        }, statuses: nil)
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                
                strongSelf.backgroundNode.updateColor(color: presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
                strongSelf.separatorNode.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
                
                strongSelf.updateChatPresentationInterfaceState({ $0.updatedTheme(presentationData.theme) })
            
                if let layout = strongSelf.validLayout {
                    let _ = strongSelf.update(layout: layout, buttons: strongSelf.buttons, isSelecting: strongSelf.isSelecting, transition: .immediate)
                }
            }
        })
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        for (_, disposable) in self.iconDisposables {
            disposable.dispose()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        if #available(iOS 13.0, *) {
            self.containerNode.layer.cornerCurve = .continuous
        }
    
        self.scrollNode.view.delegate = self
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
    }
    
    @objc private func buttonPressed() {
        self.mainButtonPressed()
    }
    
    func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.separatorNode, alpha: alpha)
        transition.updateAlpha(node: self.backgroundNode, alpha: alpha)
    }
    
    func updateCaption(_ caption: NSAttributedString) {
        if !caption.string.isEmpty {
            self.loadTextNodeIfNeeded()
        }
        self.updateChatPresentationInterfaceState(animated: false, { $0.updatedInterfaceState { $0.withUpdatedComposeInputState(ChatTextInputState(inputText: caption))} })
    }

    private func updateChatPresentationInterfaceState(animated: Bool = true, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        self.updateChatPresentationInterfaceState(transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, f, completion: completion)
    }
    
    private func updateChatPresentationInterfaceState(transition: ContainedViewLayoutTransition, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion externalCompletion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        let presentationInterfaceState = f(self.presentationInterfaceState)
        let updateInputTextState = self.presentationInterfaceState.interfaceState.effectiveInputState != presentationInterfaceState.interfaceState.effectiveInputState
        
        self.presentationInterfaceState = presentationInterfaceState
        
        if let textInputPanelNode = self.textInputPanelNode, updateInputTextState {
            textInputPanelNode.updateInputTextState(presentationInterfaceState.interfaceState.effectiveInputState, animated: transition.isAnimated)

            self.textUpdated(presentationInterfaceState.interfaceState.effectiveInputState.inputText)
        }
    }
    
    func updateSelectedIndex(_ index: Int) {
        self.selectedIndex = index
        self.updateViews(transition: .init(animation: .curve(duration: 0.2, curve: .spring)))
    }
    
    func updateViews(transition: Transition) {
        guard let layout = self.validLayout else {
            return
        }
        
        let visibleRect = self.scrollNode.bounds.insetBy(dx: -180.0, dy: 0.0)
        var validButtons = Set<Int>()
        
        var distanceBetweenNodes = layout.size.width / CGFloat(self.buttons.count)
        let internalWidth = distanceBetweenNodes * CGFloat(self.buttons.count - 1)
        var leftNodeOriginX = (layout.size.width - internalWidth) / 2.0
        
        var buttonWidth = buttonSize.width
        if self.buttons.count > 6 {
            buttonWidth = smallButtonWidth
            distanceBetweenNodes = buttonWidth
            leftNodeOriginX = sideInset + buttonWidth / 2.0
        }
        
        for i in 0 ..< self.buttons.count {
            let originX = floor(leftNodeOriginX + CGFloat(i) * distanceBetweenNodes - buttonWidth / 2.0)
            let buttonFrame = CGRect(origin: CGPoint(x: originX, y: 0.0), size: CGSize(width: buttonWidth, height: buttonSize.height))
            if !visibleRect.intersects(buttonFrame) {
                continue
            }
            validButtons.insert(i)
            
            var buttonTransition = transition
            let buttonView: ComponentHostView<Empty>
            if let current = self.buttonViews[i] {
                buttonView = current
            } else {
                buttonTransition = .immediate
                buttonView = ComponentHostView<Empty>()
                self.buttonViews[i] = buttonView
                self.scrollNode.view.addSubview(buttonView)
            }
            
            let type = self.buttons[i]
            if case let .app(_, _, iconFiles) = type {
                for (name, file) in iconFiles {
                    if [.default, .iOSAnimated].contains(name) {
                        if self.iconDisposables[file.fileId] == nil {
                            self.iconDisposables[file.fileId] = freeMediaFileInteractiveFetched(account: self.context.account, fileReference: .standalone(media: file)).start()
                        }
                    }
                }
            }
            let _ = buttonView.update(
                transition: buttonTransition,
                component: AnyComponent(AttachButtonComponent(
                    context: self.context,
                    type: type,
                    isSelected: i == self.selectedIndex,
                    strings: self.presentationData.strings,
                    theme: self.presentationData.theme,
                    action: { [weak self] in
                        if let strongSelf = self {
                            if strongSelf.selectionChanged(type) {
                                strongSelf.selectedIndex = i
                                strongSelf.updateViews(transition: .init(animation: .curve(duration: 0.2, curve: .spring)))
                                
                                if strongSelf.buttons.count > 6, let button = strongSelf.buttonViews[i] {
                                    strongSelf.scrollNode.view.scrollRectToVisible(button.frame.insetBy(dx: -35.0, dy: 0.0), animated: true)
                                }
                            }
                        }
                    })
                ),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonSize.height)
            )
            buttonTransition.setFrame(view: buttonView, frame: buttonFrame)
        }
    }
    
    private func updateScrollLayoutIfNeeded(force: Bool, transition: ContainedViewLayoutTransition) -> Bool {
        guard let layout = self.validLayout else {
            return false
        }
        if self.scrollLayout?.width == layout.size.width && !force {
            return false
        }
        
        var contentSize = CGSize(width: layout.size.width, height: buttonSize.height)
        var buttonWidth = buttonSize.width
        if self.buttons.count > 6 {
            buttonWidth = smallButtonWidth
            contentSize = CGSize(width: sideInset * 2.0 + CGFloat(self.buttons.count) * buttonWidth, height: buttonSize.height)
        }
        self.scrollLayout = (layout.size.width, contentSize)

        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isSelecting || self.isButtonVisible ? -buttonSize.height : 0.0), size: CGSize(width: layout.size.width, height: buttonSize.height)))
        self.scrollNode.view.contentSize = contentSize

        return true
    }
    
    private func loadTextNodeIfNeeded() {
        if let _ = self.textInputPanelNode {
        } else {
            let textInputPanelNode = AttachmentTextInputPanelNode(context: self.context, presentationInterfaceState: self.presentationInterfaceState, isAttachment: true, presentController: { [weak self] c in
                if let strongSelf = self {
                    strongSelf.present(c)
                }
            })
            textInputPanelNode.interfaceInteraction = self.interfaceInteraction
            textInputPanelNode.sendMessage = { [weak self] mode in
                if let strongSelf = self {
                    strongSelf.sendMessagePressed(mode)
                }
            }
            textInputPanelNode.focusUpdated = { [weak self] focus in
                if let strongSelf = self, focus {
                    strongSelf.beganTextEditing()
                }
            }
            textInputPanelNode.updateHeight = { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.requestLayout()
                }
            }
            self.addSubnode(textInputPanelNode)
            self.textInputPanelNode = textInputPanelNode
            
            textInputPanelNode.alpha = self.isSelecting ? 1.0 : 0.0
            textInputPanelNode.isUserInteractionEnabled = self.isSelecting
        }
    }
    
    func updateLoadingProgress(_ progress: CGFloat?) {
        self.loadingProgress = progress
    }
    
    func updateMainButtonState(_ mainButtonState: AttachmentMainButtonState?) {
        var currentButtonState = self.mainButtonState
        if mainButtonState == nil {
            currentButtonState = AttachmentMainButtonState(text: currentButtonState.text, backgroundColor: currentButtonState.backgroundColor, textColor: currentButtonState.textColor, isEnabled: currentButtonState.isEnabled, isVisible: false)
        }
        self.mainButtonState = mainButtonState ?? currentButtonState
    }
    
    func update(layout: ContainerViewLayout, buttons: [AttachmentButtonType], isSelecting: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        self.buttons = buttons
                
        let isButtonVisibleUpdated = self.isButtonVisible != self.mainButtonState.isVisible
        self.isButtonVisible = self.mainButtonState.isVisible
        
        let isSelectingUpdated = self.isSelecting != isSelecting
        self.isSelecting = isSelecting
        
        self.scrollNode.isUserInteractionEnabled = !isSelecting
        
        var insets = layout.insets(options: [])
        if let inputHeight = layout.inputHeight, inputHeight > 0.0 && isSelecting {
            insets.bottom = inputHeight
        } else if layout.intrinsicInsets.bottom > 0.0 {
            insets.bottom = layout.intrinsicInsets.bottom
        }
        
        let isButtonVisible = self.mainButtonState.isVisible
        
        if isSelecting {
            self.loadTextNodeIfNeeded()
        } else {
            self.textInputPanelNode?.ensureUnfocused()
        }
        var textPanelHeight: CGFloat = 0.0
        if let textInputPanelNode = self.textInputPanelNode {
            textInputPanelNode.isUserInteractionEnabled = isSelecting
            
            var panelTransition = transition
            if textInputPanelNode.frame.width.isZero {
                panelTransition = .immediate
            }
            let panelHeight = textInputPanelNode.updateLayout(width: layout.size.width, leftInset: insets.left + layout.safeInsets.left, rightInset: insets.right + layout.safeInsets.right, additionalSideInsets: UIEdgeInsets(), maxHeight: layout.size.height / 2.0, isSecondary: false, transition: panelTransition, interfaceState: self.presentationInterfaceState, metrics: layout.metrics)
            let panelFrame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: panelHeight)
            if textInputPanelNode.frame.width.isZero {
                textInputPanelNode.frame = panelFrame
            }
            transition.updateFrame(node: textInputPanelNode, frame: panelFrame)
            if panelFrame.height > 0.0 {
                textPanelHeight = panelFrame.height
            } else {
                textPanelHeight = 45.0
            }
        }
        
        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: buttonSize.height + insets.bottom))
        let containerTransition: ContainedViewLayoutTransition
        let containerFrame: CGRect
        if isSelecting {
            containerFrame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: textPanelHeight + insets.bottom))
        } else {
            containerFrame = bounds
        }
        let containerBounds = CGRect(origin: CGPoint(), size: containerFrame.size)
        if isSelectingUpdated || isButtonVisibleUpdated {
            containerTransition = .animated(duration: 0.25, curve: .easeInOut)
        } else {
            containerTransition = transition
        }
        containerTransition.updateAlpha(node: self.scrollNode, alpha: isSelecting || isButtonVisible ? 0.0 : 1.0)
        
        if isSelectingUpdated {
            if isSelecting {
                self.loadTextNodeIfNeeded()
                if let textInputPanelNode = self.textInputPanelNode {
                    textInputPanelNode.alpha = 1.0
                    textInputPanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    textInputPanelNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: CGPoint(), duration: 0.25, additive: true)
                }
            } else {
                if let textInputPanelNode = self.textInputPanelNode {
                    textInputPanelNode.alpha = 0.0
                    textInputPanelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                    textInputPanelNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 44.0), duration: 0.25, additive: true)
                }
            }
        }

        
        containerTransition.updateFrame(node: self.containerNode, frame: containerFrame)
        containerTransition.updateFrame(node: self.backgroundNode, frame: containerBounds)
        self.backgroundNode.update(size: containerBounds.size, transition: transition)
        containerTransition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: UIScreenPixel)))
                
        let _ = self.updateScrollLayoutIfNeeded(force: isSelectingUpdated || isButtonVisibleUpdated, transition: containerTransition)

        self.updateViews(transition: .immediate)
        
        if let progress = self.loadingProgress {
            let loadingProgressNode: LoadingProgressNode
            if let current = self.progressNode {
                loadingProgressNode = current
            } else {
                loadingProgressNode = LoadingProgressNode(color: self.presentationData.theme.rootController.tabBar.selectedIconColor)
                self.addSubnode(loadingProgressNode)
                self.progressNode = loadingProgressNode
            }
            let loadingProgressHeight: CGFloat = 2.0
            transition.updateFrame(node: loadingProgressNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: loadingProgressHeight)))
            
            loadingProgressNode.updateProgress(progress, animated: true)
        } else if let progressNode = self.progressNode {
            self.progressNode = nil
            progressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak progressNode] _ in
                progressNode?.removeFromSupernode()
            })
        }
        
        let mainButtonHeight = self.mainButtonNode.updateLayout(layout: layout, state: self.mainButtonState, transition: transition)
        transition.updateFrame(node: self.mainButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: mainButtonHeight)))
        
        return containerFrame.height
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateViews(transition: .immediate)
    }
}
