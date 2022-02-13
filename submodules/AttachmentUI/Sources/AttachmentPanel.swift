import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AttachmentTextInputPanelNode
import ChatPresentationInterfaceState
import ChatSendMessageActionUI
import ChatTextLinkEditUI

let panelButtonSize = CGSize(width: 80.0, height: 72.0)
let smallPanelButtonSize = CGSize(width: 60.0, height: 49.0)

private let iconSize = CGSize(width: 54.0, height: 42.0)
private let normalSideInset: CGFloat = 3.0
private let smallSideInset: CGFloat = 0.0

private enum AttachmentButtonTransition {
    case transitionIn
    case selection
}

private func generateBackgroundImage(colors: [UIColor]) -> UIImage? {
    return generateImage(iconSize, rotatedContext: { size, context in
        var locations: [CGFloat]
        if colors.count == 3 {
            locations = [1.0, 0.5, 0.0]
        } else {
            locations = [1.0, 0.0]
        }
        let colors: [CGColor] = colors.map { $0.cgColor }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        if colors.count == 2 {
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: .drawsAfterEndLocation)
        } else if colors.count == 3 {
            context.drawLinearGradient(gradient, start:  CGPoint(x: 0.0, y: size.height), end: CGPoint(x: size.width, y: 0.0), options: .drawsAfterEndLocation)
        }
//        let center = CGPoint(x: 10.0, y: 10.0)
//        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width, options: .drawsAfterEndLocation)
    })
}

private let buttonGlowImage: UIImage? = {
    let inset: CGFloat = 6.0
    return generateImage(CGSize(width: iconSize.width + inset * 2.0, height: iconSize.height + inset * 2.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 21.0).cgPath
        context.addRect(bounds)
        context.addPath(path)
        context.clip(using: .evenOdd)
        
        context.addPath(path)
        context.setShadow(offset: CGSize(), blur: 14.0, color: UIColor(rgb: 0xffffff, alpha: 0.8).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
    })?.withRenderingMode(.alwaysTemplate)
}()

private let buttonSelectionMaskImage: UIImage? = {
    let inset: CGFloat = 3.0
    return generateImage(CGSize(width: iconSize.width + inset * 2.0, height: iconSize.height + inset * 2.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 23.0).cgPath
        context.addPath(path)
        context.setFillColor(UIColor(rgb: 0xffffff).cgColor)
        context.fillPath()
    })?.withRenderingMode(.alwaysTemplate)
}()

private final class AttachButtonComponent: CombinedComponent {
    let context: AccountContext
    let type: AttachmentButtonType
    let isSelected: Bool
    let isCollapsed: Bool
    let transitionFraction: CGFloat
    let strings: PresentationStrings
    let theme: PresentationTheme
    let action: () -> Void
    
    init(
        context: AccountContext,
        type: AttachmentButtonType,
        isSelected: Bool,
        isCollapsed: Bool,
        transitionFraction: CGFloat,
        strings: PresentationStrings,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.type = type
        self.isSelected = isSelected
        self.isCollapsed = isCollapsed
        self.transitionFraction = transitionFraction
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
        if lhs.isCollapsed != rhs.isCollapsed {
            return false
        }
        if lhs.transitionFraction != rhs.transitionFraction {
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
        let icon = Child(AttachButtonIconComponent.self)
        let title = Child(Text.self)

        return { context in
            let name: String
            let animationName: String?
            let imageName: String?
            let backgroundColors: [UIColor]
            let foregroundColor: UIColor = .white
            
            let isCollapsed = context.component.isCollapsed
            
            switch context.component.type {
            case .camera:
                name = context.component.strings.Attachment_Camera
                animationName = "anim_camera"
                imageName = "Chat/Attach Menu/Camera"
                backgroundColors = [UIColor(rgb: 0xba4aae), UIColor(rgb: 0xdd4e6f), UIColor(rgb: 0xf4b76c)]
            case .gallery:
                name = context.component.strings.Attachment_Gallery
                animationName = "anim_gallery"
                imageName = "Chat/Attach Menu/Gallery"
                backgroundColors = [UIColor(rgb: 0x2071f1), UIColor(rgb: 0x1bc9fa)]
            case .file:
                name = context.component.strings.Attachment_File
                animationName = "anim_file"
                imageName = "Chat/Attach Menu/File"
                backgroundColors = [UIColor(rgb: 0xed705d), UIColor(rgb: 0xffa14c)]
            case .location:
                name = context.component.strings.Attachment_Location
                animationName = "anim_location"
                imageName = "Chat/Attach Menu/Location"
                backgroundColors = [UIColor(rgb: 0x5fb84f), UIColor(rgb: 0x99de6f)]
            case .contact:
                name = context.component.strings.Attachment_Contact
                animationName = "anim_contact"
                imageName = "Chat/Attach Menu/Contact"
                backgroundColors = [UIColor(rgb: 0xaa47d6), UIColor(rgb: 0xd67cf4)]
            case .poll:
                name = context.component.strings.Attachment_Poll
                animationName = "anim_poll"
                imageName = "Chat/Attach Menu/Poll"
                backgroundColors = [UIColor(rgb: 0xe9484f), UIColor(rgb: 0xee707e)]
            case let .app(appName):
                name = appName
                animationName = nil
                imageName = nil
                backgroundColors = [UIColor(rgb: 0x000000), UIColor(rgb: 0x000000)]
            }
            
            let icon = icon.update(
                component: AttachButtonIconComponent(
                    animationName: animationName,
                    imageName: imageName,
                    isSelected: context.component.isSelected,
                    backgroundColors: backgroundColors,
                    foregroundColor: foregroundColor,
                    theme: context.component.theme,
                    context: context.component.context,
                    action: context.component.action
                ),
                availableSize: iconSize,
                transition: context.transition
            )

            let title = title.update(
                component: Text(
                    text: name,
                    font: Font.regular(11.0),
                    color: context.component.theme.actionSheet.primaryTextColor
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )

            let topInset: CGFloat = 8.0
            let spacing: CGFloat = 3.0 + UIScreenPixel

            let normalIconScale = isCollapsed ? 0.7 : 1.0
            let smallIconScale = isCollapsed ? 0.5 : 0.6
            
            let iconScale = normalIconScale - (normalIconScale - smallIconScale) * abs(context.component.transitionFraction)
            let iconOffset: CGFloat = (isCollapsed ? 10.0 : 20.0) * context.component.transitionFraction
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - icon.size.width) / 2.0) + iconOffset, y: isCollapsed ? 3.0 : topInset), size: icon.size)
            var titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - title.size.width) / 2.0) + iconOffset, y: iconFrame.midY + (iconFrame.height * 0.5 * iconScale) + spacing), size: title.size)
            if isCollapsed {
                titleFrame.origin.y = floorToScreenPixels(iconFrame.midY - title.size.height / 2.0)
            }
            
            context.add(title
                .position(CGPoint(x: titleFrame.midX, y: titleFrame.midY))
                .opacity(isCollapsed ? 0.0 : 1.0 - abs(context.component.transitionFraction))
            )

            context.add(icon
                .position(CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                .scale(iconScale)
            )
            
            return context.availableSize
        }
    }
}

private final class AttachButtonIconComponent: Component {
    let animationName: String?
    let imageName: String?
    let isSelected: Bool
    let backgroundColors: [UIColor]
    let foregroundColor: UIColor
    let theme: PresentationTheme
    let context: AccountContext
    
    let action: () -> Void

    init(
        animationName: String?,
        imageName: String?,
        isSelected: Bool,
        backgroundColors: [UIColor],
        foregroundColor: UIColor,
        theme: PresentationTheme,
        context: AccountContext,
        action: @escaping () -> Void
    ) {
        self.animationName = animationName
        self.imageName = imageName
        self.isSelected = isSelected
        self.backgroundColors = backgroundColors
        self.foregroundColor = foregroundColor
        self.theme = theme
        self.context = context
        self.action = action
    }

    static func ==(lhs: AttachButtonIconComponent, rhs: AttachButtonIconComponent) -> Bool {
        if lhs.animationName != rhs.animationName {
            return false
        }
        if lhs.imageName != rhs.imageName {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.backgroundColors != rhs.backgroundColors {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let containerView: UIView
        private let glowView: UIImageView
        private let selectionView: UIImageView
        private let backgroundView: UIView
        private let iconView: UIImageView
        private let highlightView: UIView
    
        private var action: (() -> Void)?
        
        private var currentColors: [UIColor] = []
        private var currentImageName: String?
        private var currentIsSelected: Bool?
        
        private let hapticFeedback = HapticFeedback()
            
        init() {
            self.containerView = UIView()
            self.containerView.isUserInteractionEnabled = false
            
            self.glowView = UIImageView()
            self.glowView.image = buttonGlowImage
            self.glowView.isUserInteractionEnabled = false
            
            self.selectionView = UIImageView()
            self.selectionView.image = buttonSelectionMaskImage
            self.selectionView.isUserInteractionEnabled = false
            
            self.backgroundView = UIView()
            self.backgroundView.clipsToBounds = true
            self.backgroundView.isUserInteractionEnabled = false
            self.backgroundView.layer.cornerRadius = 21.0
            
            self.iconView = UIImageView()
            
            self.highlightView = UIView()
            self.highlightView.alpha = 0.0
            self.highlightView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.1)
            self.highlightView.isUserInteractionEnabled = false
    
            super.init(frame: CGRect())
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.glowView)
            self.containerView.addSubview(self.selectionView)
            self.containerView.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.iconView)
            self.backgroundView.addSubview(self.highlightView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.containerView.layer.animateScale(from: 1.0, to: 0.9, duration: 0.3, removeOnCompletion: false)
                        
                        strongSelf.highlightView.layer.removeAnimation(forKey: "opacity")
                        strongSelf.highlightView.alpha = 1.0
                        
                        strongSelf.hapticFeedback.impact(.click05)
                    } else {
                        if let presentationLayer = strongSelf.containerView.layer.presentation() {
                            strongSelf.containerView.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.2, removeOnCompletion: false)
                        }
                        
                        strongSelf.highlightView.alpha = 0.0
                        strongSelf.highlightView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                        
                        strongSelf.hapticFeedback.impact(.click06)
                    }
                }
            }
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        @objc private func pressed() {
            self.action?()
        }

        func update(component: AttachButtonIconComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.action = component.action
            
            if self.currentColors != component.backgroundColors {
                self.currentColors = component.backgroundColors
                self.backgroundView.layer.contents = generateBackgroundImage(colors: component.backgroundColors)?.cgImage
                
                if let color = component.backgroundColors.last {
                    self.glowView.tintColor = color
                    self.selectionView.tintColor = color.withAlphaComponent(0.2)
                }
            }
            
            if self.currentImageName != component.imageName {
                self.currentImageName = component.imageName
                if let imageName = component.imageName, let image = UIImage(bundleImageName: imageName) {
                    self.iconView.image = image
                    
                    let scale: CGFloat = 0.875
                    let iconSize = CGSize(width: floorToScreenPixels(image.size.width * scale), height: floorToScreenPixels(image.size.height * scale))
                    self.iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - iconSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - iconSize.height) / 2.0)), size: iconSize)
                }
            }
            
            if self.currentIsSelected != component.isSelected {
                self.currentIsSelected = component.isSelected

                transition.setScale(view: self.selectionView, scale: component.isSelected ? 1.0 : 0.8)
            }
            
            let contentFrame = CGRect(origin: CGPoint(), size: availableSize)
            self.containerView.frame = contentFrame
            self.backgroundView.frame = contentFrame
            self.highlightView.frame = contentFrame
            
            self.glowView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: contentFrame.width + 12.0, height: contentFrame.height + 12.0))
            self.glowView.center = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            
            self.selectionView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: contentFrame.width + 6.0, height: contentFrame.height + 6.0))
            self.selectionView.center = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class AttachmentPanel: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var presentationInterfaceState: ChatPresentationInterfaceState
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let containerNode: ASDisplayNode
    private var effectView: UIVisualEffectView?
    private let scrollNode: ASScrollNode
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private var buttonViews: [Int: ComponentHostView<Empty>] = [:]
    
    private var textInputPanelNode: AttachmentTextInputPanelNode?
    
    private var buttons: [AttachmentButtonType] = []
    private var selectedIndex: Int = 1
    private(set) var isCollapsed: Bool = false
    private(set) var isSelecting: Bool = false
    
    private var validLayout: ContainerViewLayout?
    private var scrollLayout: (width: CGFloat, contentSize: CGSize)?
    
    var selectionChanged: (AttachmentButtonType, Bool) -> Void = { _, _ in }
    var beganTextEditing: () -> Void = {}
    var textUpdated: (NSAttributedString) -> Void = { _ in }
    var sendMessagePressed: (AttachmentTextInputPanelSendMode) -> Void = { _ in }
    var requestLayout: () -> Void = {}
    var present: (ViewController) -> Void = { _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: .builtin(WallpaperSettings()), theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: self.context.account.peerId, mode: .standard(previewing: false), chatLocation: .peer(PeerId(0)), subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil)
        
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        
        self.scrollNode = ASScrollNode()
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        super.init()
                        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.separatorNode)
        self.containerNode.addSubnode(self.scrollNode)
        
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
            let controller = ChatSendMessageActionSheetController(context: strongSelf.context, interfaceState: strongSelf.presentationInterfaceState, gesture: gesture, sourceSendButton: node, textInputNode: textInputNode, completion: {
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
        }, statuses: nil)
    }
    
    override func didLoad() {
        super.didLoad()
        if #available(iOS 13.0, *) {
            self.containerNode.layer.cornerCurve = .continuous
        }
    
        self.scrollNode.view.delegate = self
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        let effect: UIVisualEffect
        switch self.presentationData.theme.actionSheet.backgroundType {
        case .light:
            effect = UIBlurEffect(style: .light)
        case .dark:
            effect = UIBlurEffect(style: .dark)
        }
        let effectView = UIVisualEffectView(effect: effect)
        self.effectView = effectView
        self.containerNode.view.insertSubview(effectView, at: 0)
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
    
    func updateViews(transition: Transition) {
        guard let layout = self.validLayout else {
            return
        }
        
        let visibleRect = self.scrollNode.bounds.insetBy(dx: -180.0, dy: 0.0)
        let actualVisibleRect = self.scrollNode.bounds
        var validButtons = Set<Int>()
        
        let buttonSize = self.isCollapsed ? smallPanelButtonSize : panelButtonSize
        var sideInset = self.isCollapsed ? smallSideInset : normalSideInset
        
        let buttonsWidth = sideInset * 2.0 + buttonSize.width * CGFloat(self.buttons.count)
        if buttonsWidth < layout.size.width {
            sideInset = floorToScreenPixels((layout.size.width - buttonsWidth) / 2.0)
        }
        
        for i in 0 ..< self.buttons.count {
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset + buttonSize.width * CGFloat(i), y: 0.0), size: buttonSize)
            if !visibleRect.intersects(buttonFrame) {
                continue
            }
            validButtons.insert(i)
            
            let edge = buttonSize.width * 0.75
            let leftEdge = max(-edge, min(0.0, buttonFrame.minX - actualVisibleRect.minX)) / -edge
            let rightEdge = min(edge, max(0.0, buttonFrame.maxX - actualVisibleRect.maxX)) / edge
            
            let transitionFraction: CGFloat
            if leftEdge > rightEdge {
                transitionFraction = leftEdge
            } else {
                transitionFraction = -rightEdge
            }
            
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
            let _ = buttonView.update(
                transition: buttonTransition,
                component: AnyComponent(AttachButtonComponent(
                    context: self.context,
                    type: type,
                    isSelected: i == self.selectedIndex,
                    isCollapsed: self.isCollapsed,
                    transitionFraction: transitionFraction,
                    strings: self.presentationData.strings,
                    theme: self.presentationData.theme,
                    action: { [weak self] in
                        if let strongSelf = self {
                            let ascending = i > strongSelf.selectedIndex
                            strongSelf.selectedIndex = i
                            strongSelf.selectionChanged(type, ascending)
                            strongSelf.updateViews(transition: .init(animation: .curve(duration: 0.2, curve: .spring)))
                        }
                    })
                ),
                environment: {},
                containerSize: buttonSize
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

        let buttonSize = self.isCollapsed ? smallPanelButtonSize : panelButtonSize
        let contentSize = CGSize(width: (self.isCollapsed ? smallSideInset : normalSideInset) * 2.0 + CGFloat(self.buttons.count) * buttonSize.width, height: buttonSize.height)
        self.scrollLayout = (layout.size.width, contentSize)

        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isSelecting ? -panelButtonSize.height : 0.0), size: CGSize(width: layout.size.width, height: panelButtonSize.height)))
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
    
    func update(layout: ContainerViewLayout, buttons: [AttachmentButtonType], isCollapsed: Bool, isSelecting: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        self.buttons = buttons
        
        let isCollapsedUpdated = self.isCollapsed != isCollapsed
        self.isCollapsed = isCollapsed
                
        let isSelectingUpdated = self.isSelecting != isSelecting
        self.isSelecting = isSelecting
        
        self.scrollNode.isUserInteractionEnabled = !isSelecting
        
        var insets = layout.insets(options: [])
        if let inputHeight = layout.inputHeight, inputHeight > 0.0 && isSelecting {
            insets.bottom = inputHeight
        } else if layout.intrinsicInsets.bottom > 0.0 {
            insets.bottom = layout.intrinsicInsets.bottom
        }
        
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
            let panelHeight = textInputPanelNode.updateLayout(width: layout.size.width, leftInset: insets.left, rightInset: insets.right, additionalSideInsets: UIEdgeInsets(), maxHeight: layout.size.height / 2.0, isSecondary: false, transition: panelTransition, interfaceState: self.presentationInterfaceState, metrics: layout.metrics)
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
        
        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: panelButtonSize.height + insets.bottom))
        let containerTransition: ContainedViewLayoutTransition
        let containerFrame: CGRect
        if isSelecting {
            containerFrame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: textPanelHeight + insets.bottom))
        } else if isCollapsed {
            containerFrame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: smallPanelButtonSize.height + insets.bottom))
        } else {
            containerFrame = bounds
        }
        let containerBounds = CGRect(origin: CGPoint(), size: containerFrame.size)
        if isCollapsedUpdated || isSelectingUpdated {
            containerTransition = .animated(duration: 0.25, curve: .easeInOut)
        } else {
            containerTransition = transition
        }
        containerTransition.updateAlpha(node: self.scrollNode, alpha: isSelecting ? 0.0 : 1.0)
        
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
        containerTransition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: UIScreenPixel)))
        if let effectView = self.effectView {
            containerTransition.updateFrame(view: effectView, frame: bounds)
        }
                
        let _ = self.updateScrollLayoutIfNeeded(force: isCollapsedUpdated || isSelectingUpdated, transition: containerTransition)

        var buttonTransition: Transition = .immediate
        if isCollapsedUpdated {
            buttonTransition = .easeInOut(duration: 0.25)
        }
        self.updateViews(transition: buttonTransition)
        
        return containerFrame.height
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateViews(transition: .immediate)
    }
}
