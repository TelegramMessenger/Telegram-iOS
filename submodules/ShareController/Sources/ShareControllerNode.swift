import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import TelegramIntents
import ContextUI
import ComponentFlow
import MultilineTextComponent
import TelegramStringFormatting
import BundleIconComponent
import LottieComponent
import CheckNode
import ChatMessagePaymentAlertController

enum ShareState {
    case preparing(Bool)
    case progress(Float)
    case done([Int64])
}

enum ShareExternalState {
    case preparing
    case done
}

private final class ShareContentInfoView: UIView {
    private struct Params: Equatable {
        var environment: ShareControllerEnvironment
        var theme: PresentationTheme
        var strings: PresentationStrings
        var collectibleItemInfo: TelegramCollectibleItemInfo
        var availableSize: CGSize
        
        init(environment: ShareControllerEnvironment, theme: PresentationTheme, strings: PresentationStrings, collectibleItemInfo: TelegramCollectibleItemInfo, availableSize: CGSize) {
            self.environment = environment
            self.theme = theme
            self.strings = strings
            self.collectibleItemInfo = collectibleItemInfo
            self.availableSize = availableSize
        }
        
        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.environment !== rhs.environment {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            if lhs.collectibleItemInfo != rhs.collectibleItemInfo {
                return false
            }
            if lhs.availableSize != rhs.availableSize {
                return false
            }
            return true
        }
    }
    
    private struct Layout {
        var params: Params
        var size: CGSize
        
        init(params: Params, size: CGSize) {
            self.params = params
            self.size = size
        }
    }
    
    private let icon = ComponentView<Empty>()
    private let text = ComponentView<Empty>()
    private var currencySymbolIcon: UIImage?
    private var arrowIcon: UIImage?
    private let backgroundView: BlurredBackgroundView
    
    private var currentLayout: Layout?
    
    override init(frame: CGRect) {
        self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(environment: ShareControllerEnvironment, presentationData: PresentationData, collectibleItemInfo: TelegramCollectibleItemInfo, availableSize: CGSize) -> CGSize {
        let params = Params(
            environment: environment,
            theme: presentationData.theme,
            strings: presentationData.strings,
            collectibleItemInfo: collectibleItemInfo,
            availableSize: availableSize
        )
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        let size = self.updateInternal(params: params)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
    
    private func updateInternal(params: Params) -> CGSize {
        var username: String = ""
        if case let .username(value) = params.collectibleItemInfo.subject {
            username = value
        }
        
        let textText = NSMutableAttributedString()
        
        let dateText = stringForDate(timestamp: params.collectibleItemInfo.purchaseDate, strings: params.strings)
        
        let (rawCryptoCurrencyText, cryptoCurrencySign, _) = formatCurrencyAmountCustom(params.collectibleItemInfo.cryptoCurrencyAmount, currency: params.collectibleItemInfo.cryptoCurrency, customFormat: CurrencyFormatterEntry(
            symbol: "~",
            thousandsSeparator: ",",
            decimalSeparator: ".",
            symbolOnLeft: true,
            spaceBetweenAmountAndSymbol: false,
            decimalDigits: 9
        ))
        var cryptoCurrencyText = rawCryptoCurrencyText
        while cryptoCurrencyText.hasSuffix("0") {
            cryptoCurrencyText = String(cryptoCurrencyText[cryptoCurrencyText.startIndex ..< cryptoCurrencyText.index(before: cryptoCurrencyText.endIndex)])
        }
        if cryptoCurrencyText.hasSuffix(".") {
            cryptoCurrencyText = String(cryptoCurrencyText[cryptoCurrencyText.startIndex ..< cryptoCurrencyText.index(before: cryptoCurrencyText.endIndex)])
        }
        
        let (currencyText, currencySign, _) = formatCurrencyAmountCustom(params.collectibleItemInfo.currencyAmount, currency: params.collectibleItemInfo.currency)
        
        let rawTextString = params.strings.CollectibleItemInfo_UsernameText("@\(username)", params.strings.CollectibleItemInfo_StoreName, dateText, "\(cryptoCurrencySign)\(cryptoCurrencyText)", "\(currencySign)\(currencyText)")
        textText.append(NSAttributedString(string: rawTextString.string, font: Font.regular(14.0), textColor: .white))
        for range in rawTextString.ranges {
            switch range.index {
            case 0:
                textText.addAttribute(.font, value: Font.semibold(14.0), range: range.range)
            case 1:
                textText.addAttribute(.font, value: Font.semibold(14.0), range: range.range)
            case 3:
                textText.addAttribute(.font, value: Font.semibold(14.0), range: range.range)
            default:
                break
            }
        }
        
        let currencySymbolRange = (textText.string as NSString).range(of: "~")
        
        if self.currencySymbolIcon == nil {
            if let templateImage = UIImage(bundleImageName: "Peer Info/CollectibleTonSymbolInline") {
                self.currencySymbolIcon = generateImage(CGSize(width: templateImage.size.width, height: templateImage.size.height + 2.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    if let cgImage = templateImage.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(x: 0.0, y: 4.0), size: CGSize(width: templateImage.size.width - 2.0, height: templateImage.size.height - 2.0)))
                    }
                })?.withRenderingMode(.alwaysTemplate)
            }
        }
        
        if currencySymbolRange.location != NSNotFound, let currencySymbolIcon = self.currencySymbolIcon {
            textText.replaceCharacters(in: currencySymbolRange, with: "$")
            textText.addAttribute(.attachment, value: currencySymbolIcon, range: currencySymbolRange)
            
            final class RunDelegateData {
                let ascent: CGFloat
                let descent: CGFloat
                let width: CGFloat
                
                init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
                    self.ascent = ascent
                    self.descent = descent
                    self.width = width
                }
            }
            let font = Font.semibold(14.0)
            let runDelegateData = RunDelegateData(
                ascent: font.ascender,
                descent: font.descender,
                width: currencySymbolIcon.size.width + 4.0
            )
            var callbacks = CTRunDelegateCallbacks(
                version: kCTRunDelegateCurrentVersion,
                dealloc: { dataRef in
                    Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                },
                getAscent: { dataRef in
                    let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                    return data.takeUnretainedValue().ascent
                },
                getDescent: { dataRef in
                    let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                    return data.takeUnretainedValue().descent
                },
                getWidth: { dataRef in
                    let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                    return data.takeUnretainedValue().width
                }
            )
            
            if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
                textText.addAttribute(NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String), value: runDelegate, range: currencySymbolRange)
            }
        }
        
        let accentColor = params.theme.list.itemAccentColor.withMultiplied(hue: 0.933, saturation: 0.61, brightness: 1.0)
        if self.arrowIcon == nil {
            if let templateImage = UIImage(bundleImageName: "Settings/TextArrowRight") {
                let scaleFactor: CGFloat = 0.8
                let imageSize = CGSize(width: floor(templateImage.size.width * scaleFactor), height: floor(templateImage.size.height * scaleFactor))
                self.arrowIcon = generateImage(imageSize, contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    if let cgImage = templateImage.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                    }
                })?.withRenderingMode(.alwaysTemplate)
            }
        }
        
        textText.append(NSAttributedString(string: " \(params.strings.CollectibleItemInfo_ShareInlineText_LearnMore)", attributes: [
            .font: Font.medium(14.0),
            .foregroundColor: accentColor,
            NSAttributedString.Key(rawValue: "URL"): ""
        ]))
        if let range = textText.string.range(of: ">"), let arrowIcon = self.arrowIcon {
            textText.addAttribute(.attachment, value: arrowIcon, range: NSRange(range, in: textText.string))
        }
        
        let textInsets = UIEdgeInsets(top: 8.0, left: 50.0, bottom: 8.0, right: 10.0)
        
        let textSize = self.text.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(textText),
                maximumNumberOfLines: 0,
                lineSpacing: 0.185,
                highlightColor: accentColor.withMultipliedAlpha(0.1),
                highlightAction: { attributes in
                    if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                        return NSAttributedString.Key(rawValue: "URL")
                    } else {
                        return nil
                    }
                },
                tapAction: { [weak self] _, _ in
                    guard let self, let params = self.currentLayout?.params else {
                        return
                    }
                    if let environment = params.environment as? ShareControllerAppEnvironment {
                        environment.sharedContext.applicationBindings.openUrl(params.collectibleItemInfo.url)
                    }
                }
            )),
            environment: {},
            containerSize: CGSize(width: params.availableSize.width - textInsets.left - textInsets.right, height: 1000.0)
        )
        let textFrame = CGRect(origin: CGPoint(x: textInsets.left, y: textInsets.top), size: textSize)
        if let textView = self.text.view {
            if textView.superview == nil {
                self.addSubview(textView)
            }
            textView.frame = textFrame
        }
        
        let size = CGSize(width: params.availableSize.width, height: textInsets.top + textSize.height + textInsets.bottom)
        
        let iconSize = self.icon.update(
            transition: .immediate,
            component: AnyComponent(LottieComponent(
                content: LottieComponent.AppBundleContent(name: "ToastCollectibleUsernameEmoji"),
                loop: false
            )),
            environment: {},
            containerSize: CGSize(width: 30.0, height: 30.0)
        )
        let iconFrame = CGRect(origin: CGPoint(x: floor((textInsets.left - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
        if let iconView = self.icon.view as? LottieComponent.View {
            if iconView.superview == nil {
                self.addSubview(iconView)
                iconView.playOnce(delay: 0.1)
            }
            iconView.frame = iconFrame
        }
        
        self.backgroundView.updateColor(color: UIColor(rgb: 0x1C2023), transition: .immediate)
        self.backgroundView.update(size: size, cornerRadius: 16.0, transition: .immediate)
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        
        return size
    }
}

private func textForTimeout(value: Int32) -> String {
    if value < 3600 {
        let minutes = value / 60
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(minutes):\(secondsPadding)\(seconds)"
    } else {
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let minutesPadding = minutes < 10 ? "0" : ""
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(hours):\(minutesPadding)\(minutes):\(secondsPadding)\(seconds)"
    }
}

final class ShareControllerNode: ViewControllerTracingNode, ASScrollViewDelegate {
    private weak var controller: ShareController?
    private let environment: ShareControllerEnvironment
    private var context: ShareControllerAccountContext?
    private var presentationData: PresentationData
    private let forceTheme: PresentationTheme?
    private let externalShare: Bool
    private let immediateExternalShare: Bool
    private var immediatePeerId: PeerId?
    private let fromForeignApp: Bool
    private let fromPublicChannel: Bool
    private let segmentedValues: [ShareControllerSegmentedValue]?
    private let collectibleItemInfo: TelegramCollectibleItemInfo?
    private let mediaParameters: ShareControllerSubject.MediaParameters?
    private let messageCount: Int
    
    var selectedSegmentedIndex: Int = 0
    
    private let defaultAction: ShareControllerAction?
    private let requestLayout: (ContainedViewLayoutTransition) -> Void
    private let presentError: (String?, String) -> Void
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    private let dimNode: ASDisplayNode
    
    private let wrappingScrollNode: ASScrollNode
    private let cancelButtonNode: ASButtonNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentBackgroundNode: ASImageNode
    private var contentInfoView: ShareContentInfoView?
    
    private var contentNode: (ASDisplayNode & ShareContentContainerNode)?
    private var previousContentNode: (ASDisplayNode & ShareContentContainerNode)?
    private var animateContentNodeOffsetFromBackgroundOffset: CGFloat?
    
    private let actionsBackgroundNode: ASImageNode
    private let actionButtonNode: ShareActionButtonNode
    let startAtTimestampNode: ShareStartAtTimestampNode?
    private let inputFieldNode: ShareInputFieldNode
    private let actionSeparatorNode: ASDisplayNode
    
    var dismiss: ((Bool) -> Void)?
    var cancel: (() -> Void)?
    var tryShare: ((String, [EnginePeer]) -> Bool)?
    var share: ((String, [PeerId], [PeerId: Int64], Bool, Bool) -> Signal<ShareState, ShareControllerError>)?
    var shareExternal: ((Bool) -> Signal<ShareExternalState, NoError>)?
    var switchToAnotherAccount: (() -> Void)?
    var debugAction: (() -> Void)?
    var openStats: (() -> Void)?
    var completed: (([PeerId]) -> Void)?
    var enqueued: (([PeerId], [Int64]) -> Void)?
    var present: ((ViewController) -> Void)?
    var disabledPeerSelected: ((EnginePeer) -> Void)?
    var onMediaTimestampLinkCopied: ((Int32?) -> Void)?
    
    let ready = Promise<Bool>()
    
    private var controllerInteraction: ShareControllerInteraction?
    
    private var peersContentNode: SharePeersContainerNode?
    private var topicsContentNode: ShareTopicsContainerNode?
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private let shareDisposable = MetaDisposable()
    
    private var hapticFeedback: HapticFeedback?
    
    private let presetText: String?
    
    private let showNames = ValuePromise<Bool>(true)
    
    init(controller: ShareController, environment: ShareControllerEnvironment, presentationData: PresentationData, presetText: String?, defaultAction: ShareControllerAction?, mediaParameters: ShareControllerSubject.MediaParameters?, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void, presentError: @escaping (String?, String) -> Void, externalShare: Bool, immediateExternalShare: Bool, immediatePeerId: PeerId?, fromForeignApp: Bool, forceTheme: PresentationTheme?, fromPublicChannel: Bool, segmentedValues: [ShareControllerSegmentedValue]?, shareStory: (() -> Void)?, collectibleItemInfo: TelegramCollectibleItemInfo?, messageCount: Int) {
        self.controller = controller
        self.environment = environment
        self.presentationData = presentationData
        self.forceTheme = forceTheme
        self.externalShare = externalShare
        self.immediateExternalShare = immediateExternalShare
        self.immediatePeerId = immediatePeerId
        self.fromForeignApp = fromForeignApp
        self.presentError = presentError
        self.fromPublicChannel = fromPublicChannel
        self.segmentedValues = segmentedValues
        self.collectibleItemInfo = collectibleItemInfo
        self.mediaParameters = mediaParameters
        self.messageCount = messageCount
        
        self.presetText = presetText
        
        self.defaultAction = defaultAction
        self.requestLayout = requestLayout
        
        if let forceTheme = self.forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        
        let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        let highlightedRoundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor)
        
        let theme = self.presentationData.theme
        let halfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        let highlightedHalfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemHighlightedBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        if self.fromForeignApp {
            self.dimNode.backgroundColor = .clear
        } else {
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        }
        
        self.cancelButtonNode = ASButtonNode()
        self.cancelButtonNode.displaysAsynchronously = false
        self.cancelButtonNode.setBackgroundImage(roundedBackground, for: .normal)
        self.cancelButtonNode.setBackgroundImage(highlightedRoundedBackground, for: .highlighted)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        self.contentContainerNode.clipsToBounds = true
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        self.contentBackgroundNode.image = roundedBackground
        
        self.contentInfoView = ShareContentInfoView(frame: CGRect())
        
        self.actionsBackgroundNode = ASImageNode()
        self.actionsBackgroundNode.isLayerBacked = true
        self.actionsBackgroundNode.displayWithoutProcessing = true
        self.actionsBackgroundNode.displaysAsynchronously = false
        self.actionsBackgroundNode.image = halfRoundedBackground
        
        self.actionButtonNode = ShareActionButtonNode(badgeBackgroundColor: self.presentationData.theme.actionSheet.controlAccentColor, badgeTextColor: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        self.actionButtonNode.displaysAsynchronously = false
        self.actionButtonNode.titleNode.displaysAsynchronously = false
        self.actionButtonNode.setBackgroundImage(highlightedHalfRoundedBackground, for: .highlighted)
        
        if let startAtTimestamp = mediaParameters?.startAtTimestamp {
            self.startAtTimestampNode = ShareStartAtTimestampNode(titleText: self.presentationData.strings.Share_VideoStartAt(textForTimeout(value: startAtTimestamp)).string, titleTextColor: self.presentationData.theme.actionSheet.secondaryTextColor, checkNodeTheme: CheckNodeTheme(backgroundColor: presentationData.theme.list.itemCheckColors.fillColor, strokeColor: presentationData.theme.list.itemCheckColors.foregroundColor, borderColor: presentationData.theme.list.itemCheckColors.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false))
        } else {
            self.startAtTimestampNode = nil
        }
        
        self.inputFieldNode = ShareInputFieldNode(theme: ShareInputFieldNodeTheme(presentationTheme: self.presentationData.theme), strings: self.presentationData.strings, placeholder: self.presentationData.strings.ShareMenu_Comment)
        self.inputFieldNode.text = presetText ?? ""
        self.inputFieldNode.preselectText()
        self.inputFieldNode.alpha = 0.0
        
        self.actionSeparatorNode = ASDisplayNode()
        self.actionSeparatorNode.isLayerBacked = true
        self.actionSeparatorNode.displaysAsynchronously = false
        self.actionSeparatorNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemSeparatorColor
        
        if self.defaultAction == nil {
            self.actionButtonNode.alpha = 0.0
            self.actionsBackgroundNode.alpha = 0.0
            self.actionSeparatorNode.alpha = 0.0
        }
        
        super.init()
        
        self.isHidden = true
        
        self.startAtTimestampNode?.updated = { [weak self] in
            guard let self else {
                return
            }
            if let (layout, navigationBarHeight, _) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
                
        self.actionButtonNode.shouldBegin = { [weak self] in
            if let strongSelf = self {
                return !strongSelf.controllerInteraction!.selectedPeers.isEmpty
            } else {
                return false
            }
        }
        self.actionButtonNode.contextAction = { [weak self] node, gesture in
            if let strongSelf = self, let node = node as? ContextReferenceContentNode {
                let presentationData = strongSelf.presentationData
                let fromForeignApp = strongSelf.fromForeignApp
                let items: Signal<ContextController.Items, NoError> =
                strongSelf.showNames.get()
                |> map { showNamesValue in
                    var items: [ContextMenuItem] = []
                    if !fromForeignApp {
                        items.append(contentsOf: [
                            .action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_ShowSendersName, icon: { theme in
                                if showNamesValue {
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                } else {
                                    return nil
                                }
                            }, action: { _, _ in
                                self?.showNames.set(true)
                            })),
                            .action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_HideSendersName, icon: { theme in
                                if !showNamesValue {
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                } else {
                                    return nil
                                }
                            }, action: { _, _ in
                                self?.showNames.set(false)
                            })),
                            .separator,
                        ])
                    }
                    items.append(contentsOf: [
                        .action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_SendSilently, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                            f(.default)
                            if let strongSelf = self {
                                strongSelf.send(showNames: showNamesValue, silently: true)
                            }
                        })),
                        .action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_SendMessage, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                            f(.default)
                            if let strongSelf = self {
                                strongSelf.send(showNames: showNamesValue, silently: false)
                            }
                        }))
                    ])
                    return ContextController.Items(content: .list(items), animationCache: nil)
                }
                let contextController = ContextController(presentationData: presentationData, source: .reference(ShareContextReferenceContentSource(sourceNode: node, customPosition: CGPoint(x: 0.0, y: fromForeignApp ? -116.0 : 0.0))), items: items, gesture: gesture)
                contextController.immediateItemsTransitionAnimation = true
                strongSelf.present?(contextController)
            }
        }
                
        self.controllerInteraction = ShareControllerInteraction(togglePeer: { [weak self] peer, search in
            if let strongSelf = self {
                var added = false
                var openedTopicList = false
                if strongSelf.controllerInteraction!.selectedPeerIds.contains(peer.peerId) {
                    strongSelf.controllerInteraction!.selectedTopics[peer.peerId] = nil
                    strongSelf.peersContentNode?.update()
                    strongSelf.controllerInteraction!.selectedPeerIds.remove(peer.peerId)
                    strongSelf.controllerInteraction!.selectedPeers = strongSelf.controllerInteraction!.selectedPeers.filter({ $0.peerId != peer.peerId })
                } else {
                    if case let .channel(channel) = peer.peer, channel.isForumOrMonoForum {
                        if strongSelf.controllerInteraction!.selectedTopics[peer.peerId] != nil {
                            strongSelf.controllerInteraction!.selectedTopics[peer.peerId] = nil
                            strongSelf.peersContentNode?.update()
                        } else {
                            strongSelf.transitionToPeerTopics(peer)
                            openedTopicList = true
                        }
                    } else {
                        strongSelf.controllerInteraction!.selectedPeerIds.insert(peer.peerId)
                        strongSelf.controllerInteraction!.selectedPeers.append(peer)
                        added = true
                    }
                    
                    if openedTopicList {
                        Queue.mainQueue().after(0.4) {
                            strongSelf.contentNode?.setEnsurePeerVisibleOnLayout(peer.peerId)
                        }
                    } else {
                        strongSelf.contentNode?.setEnsurePeerVisibleOnLayout(peer.peerId)
                    }
                }
                
                if search && added {
                    strongSelf.controllerInteraction!.foundPeers = strongSelf.controllerInteraction!.foundPeers.filter { otherPeer in
                        return peer.peerId != otherPeer.peer.peerId
                    }
                    strongSelf.controllerInteraction!.foundPeers.append((peer, false))
                    strongSelf.peersContentNode?.updateFoundPeers()
                }
                
                if !openedTopicList {
                    strongSelf.setActionNodesHidden(strongSelf.controllerInteraction!.selectedPeers.isEmpty && strongSelf.presetText == nil && strongSelf.mediaParameters?.publicLinkPrefix == nil, inputField: true, actions: strongSelf.defaultAction == nil)
                    
                    strongSelf.updateButton()
                    
                    strongSelf.peersContentNode?.updateSelectedPeers(animated: true)
                    strongSelf.contentNode?.updateSelectedPeers(animated: true)
                }
                
                if let (layout, navigationBarHeight, _) = strongSelf.containerLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                }
                
                if added, strongSelf.contentNode is ShareSearchContainerNode {
                    if let peersContentNode = strongSelf.peersContentNode {
                        strongSelf.transitionToContentNode(peersContentNode)
                    }
                }
            }
        }, selectTopic: { [weak self] peer, threadId, threadData in
            if let strongSelf = self {
                strongSelf.controllerInteraction?.selectedPeers.append(peer)
                strongSelf.controllerInteraction?.selectedPeerIds.insert(peer.peerId)
                strongSelf.controllerInteraction?.selectedTopics[peer.peerId] = (threadId, threadData)
                strongSelf.peersContentNode?.update()
                
                strongSelf.setActionNodesHidden(strongSelf.controllerInteraction!.selectedPeers.isEmpty && strongSelf.presetText == nil, inputField: true, actions: strongSelf.defaultAction == nil)
                
                strongSelf.peersContentNode?.updateSelectedPeers(animated: false)
                strongSelf.updateButton()
                
                if let peersContentNode = strongSelf.peersContentNode, strongSelf.contentNode !== peersContentNode {
                    strongSelf.transitionToContentNode(peersContentNode, animated: true)
                    peersContentNode.prepareForAnimateIn()
                }
                                
                Queue.mainQueue().after(0.01, {
                    strongSelf.closePeerTopics(peer.peerId, selected: true)
                })
            }
        }, shareStory: shareStory.flatMap { shareStory in
            return { [weak self] in
                self?.animateOut(shared: false, completion: { [weak self] in
                    self?.dismiss?(false)
                })
                shareStory()
            }
        }, disabledPeerSelected: { [weak self] peer in
            guard let self else {
                return
            }
            if let peer = peer.peer {
                self.disabledPeerSelected?(peer)
            }
        })
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.addSubnode(self.wrappingScrollNode)
        
        self.cancelButtonNode.setTitle(self.presentationData.strings.Common_Cancel, with: Font.medium(20.0), with: self.presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
        
        self.wrappingScrollNode.addSubnode(self.cancelButtonNode)
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        
        self.actionButtonNode.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        
        self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
        
        if let contentInfoView = self.contentInfoView {
            self.wrappingScrollNode.view.addSubview(contentInfoView)
        }
        
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.actionSeparatorNode)
        self.contentContainerNode.addSubnode(self.actionsBackgroundNode)
        self.contentContainerNode.addSubnode(self.inputFieldNode)
        self.contentContainerNode.addSubnode(self.actionButtonNode)
        if let startAtTimestampNode = self.startAtTimestampNode {
            self.contentContainerNode.addSubnode(startAtTimestampNode)
        }
        
        self.inputFieldNode.updateHeight = { [weak self] in
            if let strongSelf = self {
                if let (layout, navigationBarHeight, _) = strongSelf.containerLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.15, curve: .spring))
                }
            }
        }
        self.inputFieldNode.onInputCopyText = { [weak self] in
            guard let self else {
                return
            }
            if let publicLinkPrefix = self.mediaParameters?.publicLinkPrefix {
                var timestampSuffix = ""
                var effectiveStartTimestamp: Int32?
                if let startAtTimestamp = self.mediaParameters?.startAtTimestamp, let startAtTimestampNode = self.startAtTimestampNode, startAtTimestampNode.value {
                    var startAtTimestampString = ""
                    let hours = startAtTimestamp / 3600
                    let minutes = startAtTimestamp / 60 % 60
                    let seconds = startAtTimestamp % 60
                    if hours == 0 && minutes == 0 {
                        startAtTimestampString = "\(startAtTimestamp)"
                    } else {
                        if hours != 0 {
                            startAtTimestampString += "\(hours)h"
                        }
                        if minutes != 0 {
                            startAtTimestampString += "\(minutes)m"
                        }
                        if seconds != 0 {
                            startAtTimestampString += "\(seconds)s"
                        }
                    }
                    timestampSuffix = "?t=\(startAtTimestampString)"
                    effectiveStartTimestamp = startAtTimestamp
                }
                let inputCopyText = "\(publicLinkPrefix.actualString)\(timestampSuffix)"
                UIPasteboard.general.string = inputCopyText
                self.onMediaTimestampLinkCopied?(effectiveStartTimestamp)
            }
            self.cancel?()
        }
        
        self.updateButton()
        
        if self.presetText != nil || self.mediaParameters?.publicLinkPrefix != nil {
            self.setActionNodesHidden(false, inputField: true, actions: true, animated: false)
        }
    }
    
    deinit {
        self.shareDisposable.dispose()
    }
        
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    func transitionToPeerTopics(_ peer: EngineRenderedPeer) {
        guard let context = self.context, let mainPeer = peer.chatMainPeer, let controllerInteraction = self.controllerInteraction else {
            return
        }
        
        var isMonoforum = false
        if case let .channel(channel) = mainPeer {
            isMonoforum = channel.isMonoForum
        }
        
        var didPresent = false
        var presentImpl: (() -> Void)?
        let threads = threadList(accountPeerId: context.accountPeerId, postbox: context.stateManager.postbox, peerId: mainPeer.id, isMonoforum: isMonoforum)
        |> deliverOnMainQueue
        |> beforeNext { _ in
            if !didPresent {
                didPresent = true
                presentImpl?()
            }
        }
        
        let topicsContentNode = ShareTopicsContainerNode(
            environment: self.environment,
            context: context,
            theme: self.presentationData.theme,
            strings: self.presentationData.strings,
            peer: mainPeer,
            topics: threads,
            controllerInteraction: controllerInteraction
        )
        topicsContentNode.backPressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.closePeerTopics(peer.peerId, selected: false)
            }
        }
        self.topicsContentNode = topicsContentNode
        
        presentImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.contentNode?.supernode?.addSubnode(topicsContentNode)
                        
            if let (layout, navigationBarHeight, _) = strongSelf.containerLayout {
                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
            
            if let searchContentNode = strongSelf.contentNode as? ShareSearchContainerNode {
                searchContentNode.setDidBeginDragging(nil)
                searchContentNode.setContentOffsetUpdated(nil)
                let scrollDelta = topicsContentNode.contentGridNode.scrollView.contentOffset.y - searchContentNode.effectiveGridNode.scrollView.contentOffset.y
                if let sourceFrame = searchContentNode.animateOut(peerId: peer.peerId, scrollDelta: scrollDelta) {
                    topicsContentNode.animateIn(sourceFrame: sourceFrame, scrollDelta: scrollDelta)
                }
            } else if let peersContentNode = strongSelf.peersContentNode {
                peersContentNode.setDidBeginDragging(nil)
                peersContentNode.setContentOffsetUpdated(nil)
                let scrollDelta = topicsContentNode.contentGridNode.scrollView.contentOffset.y - peersContentNode.contentGridNode.scrollView.contentOffset.y
                if let sourceFrame = peersContentNode.animateOut(peerId: peer.peerId, scrollDelta: scrollDelta) {
                    topicsContentNode.animateIn(sourceFrame: sourceFrame, scrollDelta: scrollDelta)
                }
            }
            
            topicsContentNode.setDidBeginDragging({ [weak self] in
                self?.contentNodeDidBeginDragging()
            })
            topicsContentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
            })
            strongSelf.contentNodeOffsetUpdated(topicsContentNode.contentGridNode.scrollView.contentOffset.y, transition: .animated(duration: 0.4, curve: .spring))
            
            strongSelf.view.endEditing(true)
        }
    }
    
    func closePeerTopics(_ peerId: EnginePeer.Id, selected: Bool) {
        guard let topicsContentNode = self.topicsContentNode else {
            return
        }
        topicsContentNode.setDidBeginDragging(nil)
        topicsContentNode.setContentOffsetUpdated(nil)
                
        if let searchContentNode = self.contentNode as? ShareSearchContainerNode {
            topicsContentNode.supernode?.insertSubnode(topicsContentNode, belowSubnode: searchContentNode)
        } else if let peersContentNode = self.peersContentNode {
            topicsContentNode.supernode?.insertSubnode(topicsContentNode, belowSubnode: peersContentNode)
        }
                            
        if let (layout, navigationBarHeight, _) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
        }

        if let searchContentNode = self.contentNode as? ShareSearchContainerNode {
            searchContentNode.setDidBeginDragging({ [weak self] in
                self?.contentNodeDidBeginDragging()
            })
            searchContentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
            })
            self.contentNodeOffsetUpdated(searchContentNode.effectiveGridNode.scrollView.contentOffset.y, transition: .animated(duration: 0.4, curve: .spring))
            
            let scrollDelta = topicsContentNode.contentGridNode.scrollView.contentOffset.y - searchContentNode.effectiveGridNode.scrollView.contentOffset.y
            if let targetFrame = searchContentNode.animateIn(peerId: peerId, scrollDelta: scrollDelta) {
                topicsContentNode.animateOut(targetFrame: targetFrame, scrollDelta: scrollDelta, completion: { [weak self] in
                    if let topicsContentNode = self?.topicsContentNode {
                        topicsContentNode.removeFromSupernode()
                        self?.topicsContentNode = nil
                    }
                })
            }
        } else if let peersContentNode = self.peersContentNode {
            peersContentNode.setDidBeginDragging({ [weak self] in
                self?.contentNodeDidBeginDragging()
            })
            peersContentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
            })
            self.contentNodeOffsetUpdated(peersContentNode.contentGridNode.scrollView.contentOffset.y, transition: .animated(duration: 0.4, curve: .spring))
            
            let scrollDelta = topicsContentNode.contentGridNode.scrollView.contentOffset.y - peersContentNode.contentGridNode.scrollView.contentOffset.y
            if let targetFrame = peersContentNode.animateIn(peerId: peerId, scrollDelta: scrollDelta) {
                topicsContentNode.animateOut(targetFrame: targetFrame, scrollDelta: scrollDelta, completion: { [weak self] in
                    if let topicsContentNode = self?.topicsContentNode {
                        topicsContentNode.removeFromSupernode()
                        self?.topicsContentNode = nil
                    }
                })
            }
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        guard self.presentationData !== presentationData else {
            return
        }
        self.presentationData = presentationData
        if let forceTheme = self.forceTheme {
            self.presentationData = self.presentationData.withUpdated(theme: forceTheme)
        }
        
        let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        let highlightedRoundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor)
        
        let theme = self.presentationData.theme
        let halfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        let highlightedHalfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.actionSheet.opaqueItemHighlightedBackgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        self.cancelButtonNode.setBackgroundImage(roundedBackground, for: .normal)
        self.cancelButtonNode.setBackgroundImage(highlightedRoundedBackground, for: .highlighted)
        
        self.contentBackgroundNode.image = roundedBackground
        self.actionsBackgroundNode.image = halfRoundedBackground
        self.actionButtonNode.setBackgroundImage(highlightedHalfRoundedBackground, for: .highlighted)
        self.actionSeparatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor
        self.cancelButtonNode.setTitle(presentationData.strings.Common_Cancel, with: Font.medium(20.0), with: presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
        
        self.actionButtonNode.badgeBackgroundColor = presentationData.theme.actionSheet.controlAccentColor
        self.actionButtonNode.badgeTextColor = presentationData.theme.actionSheet.opaqueItemBackgroundColor
        
        if let startAtTimestampNode = self.startAtTimestampNode {
            startAtTimestampNode.titleTextColor = presentationData.theme.actionSheet.secondaryTextColor
            startAtTimestampNode.checkNodeTheme = CheckNodeTheme(backgroundColor: presentationData.theme.list.itemCheckColors.fillColor, strokeColor: presentationData.theme.list.itemCheckColors.foregroundColor, borderColor: presentationData.theme.list.itemCheckColors.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false)
        }
        
        self.contentNode?.updateTheme(presentationData.theme)
    }
    
    func setActionNodesHidden(_ hidden: Bool, inputField: Bool = false, actions: Bool = false, animated: Bool = true) {
        func updateActionNodesAlpha(_ nodes: [ASDisplayNode], alpha: CGFloat) {
            for node in nodes {
                if !node.alpha.isEqual(to: alpha) {
                    let previousAlpha = node.alpha
                    node.alpha = alpha
                    if animated {
                        node.layer.animateAlpha(from: previousAlpha, to: alpha, duration: alpha.isZero ? 0.08 : 0.32, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                    
                    if let inputNode = node as? ShareInputFieldNode, alpha.isZero {
                        inputNode.deactivateInput()
                    }
                }
            }
        }
        
        var actionNodes: [ASDisplayNode] = []
        if inputField {
            actionNodes.append(self.inputFieldNode)
        }
        if actions {
            actionNodes.append(contentsOf: [self.actionsBackgroundNode, self.actionButtonNode, self.actionSeparatorNode])
            if let startAtTimestampNode = self.startAtTimestampNode {
                actionNodes.append(startAtTimestampNode)
            }
        }
        updateActionNodesAlpha(actionNodes, alpha: hidden ? 0.0 : 1.0)
    }
    
    func transitionToContentNode(_ contentNode: (ASDisplayNode & ShareContentContainerNode)?, fastOut: Bool = false, animated: Bool = true) {
        if self.contentNode !== contentNode {
            let transition: ContainedViewLayoutTransition
            
            let previous = self.contentNode
            if let previous = previous {
                previous.setDidBeginDragging(nil)
                previous.setContentOffsetUpdated(nil)
                if animated {
                    transition = .animated(duration: 0.4, curve: .spring)
                    self.previousContentNode = previous
                    previous.alpha = 0.0
                    previous.layer.animateAlpha(from: 1.0, to: 0.0, duration: fastOut ? 0.1 : 0.2, removeOnCompletion: true, completion: { [weak self, weak previous] _ in
                        if let strongSelf = self, let previous = previous {
                            if strongSelf.previousContentNode === previous {
                                strongSelf.previousContentNode = nil
                            }
                            previous.removeFromSupernode()
                        }
                    })
                } else {
                    transition = .immediate
                    previous.removeFromSupernode()
                    self.previousContentNode = nil
                }
                
                self.contentNodeDidBeginDragging()
            } else {
                transition = .immediate
            }
            self.contentNode = contentNode
            
            if let (layout, navigationBarHeight, bottomGridInset) = self.containerLayout {
                if let contentNode = contentNode, let previous = previous {
                    contentNode.frame = previous.frame
                    contentNode.updateLayout(size: previous.bounds.size, isLandscape: layout.size.width > layout.size.height, bottomInset: bottomGridInset, transition: .immediate)
                    
                    contentNode.setDidBeginDragging({ [weak self] in
                        self?.contentNodeDidBeginDragging()
                    })
                    contentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                        self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
                    })
                    self.contentContainerNode.insertSubnode(contentNode, at: 0)
                    
                    contentNode.alpha = 1.0
                    if animated {
                        let animation = contentNode.layer.makeAnimation(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.35)
                        animation.fillMode = .both
                        if !fastOut {
                            animation.beginTime = contentNode.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.1
                        }
                        contentNode.layer.add(animation, forKey: "opacity")
                    }
                    
                    self.animateContentNodeOffsetFromBackgroundOffset = self.contentBackgroundNode.frame.minY
                    self.scheduleInteractiveTransition(transition)
                    
                    contentNode.activate()
                    previous.deactivate()
                    
                    if contentNode is ShareSearchContainerNode {
                        self.setActionNodesHidden(true, inputField: true, actions: true)
                    } else if !(contentNode is ShareLoadingContainer) {
                        self.setActionNodesHidden(false, inputField: !self.controllerInteraction!.selectedPeers.isEmpty || self.presetText != nil || self.mediaParameters?.publicLinkPrefix != nil, actions: true)
                    }
                } else {
                    if let contentNode = self.contentNode {
                        contentNode.setDidBeginDragging({ [weak self] in
                            self?.contentNodeDidBeginDragging()
                        })
                        contentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                            self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
                        })
                        self.contentContainerNode.insertSubnode(contentNode, at: 0)
                    }
                    
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
                }
            } else if let contentNode = contentNode {
                contentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                    self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
                })
                self.contentContainerNode.insertSubnode(contentNode, at: 0)
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        var bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        if insets.bottom > 0 {
            bottomInset -= 12.0
        }
        
        let buttonHeight: CGFloat = 57.0
        let sectionSpacing: CGFloat = 8.0
        let titleAreaHeight: CGFloat = 64.0
        
        let maximumContentHeight = layout.size.height - insets.top - max(bottomInset + buttonHeight, insets.bottom) - sectionSpacing
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 10.0 + layout.safeInsets.left)
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
        let contentFrame = contentContainerFrame.insetBy(dx: 0.0, dy: 0.0)
        
        var bottomGridInset: CGFloat = 0
 
        var actionButtonHeight: CGFloat = 0
        if self.defaultAction != nil || !self.controllerInteraction!.selectedPeers.isEmpty || self.presetText != nil || self.mediaParameters?.publicLinkPrefix != nil {
            actionButtonHeight = buttonHeight
            bottomGridInset += actionButtonHeight
        }
        if self.startAtTimestampNode != nil {
            bottomGridInset += buttonHeight
        }
        
        var inputCopyText: String?
        if !self.controllerInteraction!.selectedPeers.isEmpty || self.presetText != nil {
        } else {
            if let publicLinkPrefix = self.mediaParameters?.publicLinkPrefix {
                var timestampSuffix = ""
                if let startAtTimestamp = self.mediaParameters?.startAtTimestamp, let startAtTimestampNode = self.startAtTimestampNode, startAtTimestampNode.value {
                    var startAtTimestampString = ""
                    let hours = startAtTimestamp / 3600
                    let minutes = startAtTimestamp / 60 % 60
                    let seconds = startAtTimestamp % 60
                    if hours == 0 && minutes == 0 {
                        startAtTimestampString = "\(startAtTimestamp)"
                    } else {
                        if hours != 0 {
                            startAtTimestampString += "\(hours)h"
                        }
                        if minutes != 0 {
                            startAtTimestampString += "\(minutes)m"
                        }
                        if seconds != 0 {
                            startAtTimestampString += "\(seconds)s"
                        }
                    }
                    timestampSuffix = "?t=\(startAtTimestampString)"
                }
                inputCopyText = "\(publicLinkPrefix.visibleString)\(timestampSuffix)"
            }
        }
 
        let inputHeight = self.inputFieldNode.updateLayout(width: contentContainerFrame.size.width, inputCopyText: inputCopyText, transition: transition)
        if !self.controllerInteraction!.selectedPeers.isEmpty || self.presetText != nil || self.mediaParameters?.publicLinkPrefix != nil {
            bottomGridInset += inputHeight
        }
        
        self.containerLayout = (layout, navigationBarHeight, bottomGridInset)
        self.scheduledLayoutTransitionRequest = nil
        
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: width, height: buttonHeight)))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        
        transition.updateFrame(node: self.actionsBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset), size: CGSize(width: contentContainerFrame.size.width, height: bottomGridInset)), beginWithCurrentState: true)
        
        transition.updateFrame(node: self.actionButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - actionButtonHeight), size: CGSize(width: contentContainerFrame.size.width, height: buttonHeight)))
        
        if let startAtTimestampNode = self.startAtTimestampNode {
            transition.updateFrame(node: startAtTimestampNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - actionButtonHeight - buttonHeight), size: CGSize(width: contentContainerFrame.size.width, height: buttonHeight)))
        }
        
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset), size: CGSize(width: contentContainerFrame.size.width, height: inputHeight)), beginWithCurrentState: true)
        
        transition.updateFrame(node: self.actionSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset - UIScreenPixel), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)), beginWithCurrentState: true)
        
        let gridSize = CGSize(width: contentFrame.size.width, height: max(32.0, contentFrame.size.height - titleAreaHeight))
        
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: titleAreaHeight), size: gridSize))
            contentNode.updateLayout(size: gridSize, isLandscape: layout.size.width > layout.size.height, bottomInset: bottomGridInset, transition: transition)
        }
        
        if let topicsContentNode = self.topicsContentNode {
            transition.updateFrame(node: topicsContentNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: titleAreaHeight), size: gridSize))
            
            topicsContentNode.updateLayout(size: gridSize, isLandscape: layout.size.width > layout.size.height, bottomInset: self.contentNode === self.peersContentNode ? bottomGridInset : 0.0, transition: transition)
        }
        
        if let controller = self.controller {
            let subLayout = ContainerViewLayout(
                size: layout.size,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                intrinsicInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: layout.size.height - contentFrame.maxY - 6.0, right: 4.0),
                safeInsets: layout.safeInsets,
                additionalInsets: UIEdgeInsets(),
                statusBarHeight: nil,
                inputHeight: nil,
                inputHeightIsInteractivellyChanging: false,
                inVoiceOver: false
            )
            controller.presentationContext.containerLayoutUpdated(subLayout, transition: transition)
        }
    }
    
    private func contentNodeDidBeginDragging() {
        if let contentInfoView = self.contentInfoView, contentInfoView.alpha != 0.0 {
            ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: contentInfoView, alpha: 0.0)
            ComponentTransition.easeInOut(duration: 0.2).setScale(view: contentInfoView, scale: 0.5)
        }
    }
    
    private func contentNodeOffsetUpdated(_ contentOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        if let (layout, _, _) = self.containerLayout {
            var insets = layout.insets(options: [.statusBar, .input])
            insets.top = max(10.0, insets.top)
            let cleanInsets = layout.insets(options: [.statusBar])
            
            var bottomInset: CGFloat = 10.0 + cleanInsets.bottom
            if insets.bottom > 0 {
                bottomInset -= 12.0
            }
            let buttonHeight: CGFloat = 57.0
            let sectionSpacing: CGFloat = 8.0
            
            let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 10.0 + layout.safeInsets.left)
            
            let sideInset = floor((layout.size.width - width) / 2.0)
            
            let maximumContentHeight = layout.size.height - insets.top - max(bottomInset + buttonHeight, insets.bottom) - sectionSpacing
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
            
            var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY - contentOffset), size: contentFrame.size)
            if backgroundFrame.minY < contentFrame.minY {
                backgroundFrame.origin.y = contentFrame.minY
            }
            if backgroundFrame.maxY > contentFrame.maxY {
                backgroundFrame.size.height += contentFrame.maxY - backgroundFrame.maxY
            }
            if backgroundFrame.size.height < buttonHeight + 32.0 {
                backgroundFrame.origin.y -= buttonHeight + 32.0 - backgroundFrame.size.height
                backgroundFrame.size.height = buttonHeight + 32.0
            }
            transition.updateFrame(node: self.contentBackgroundNode, frame: backgroundFrame)
            
            if let contentInfoView = self.contentInfoView, let collectibleItemInfo = self.collectibleItemInfo {
                let contentInfoSize = contentInfoView.update(
                    environment: self.environment,
                    presentationData: self.presentationData,
                    collectibleItemInfo: collectibleItemInfo,
                    availableSize: CGSize(width: backgroundFrame.width, height: 1000.0)
                )
                let contentInfoFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY - 8.0 - contentInfoSize.height), size: contentInfoSize)
                
                if contentInfoView.bounds.isEmpty {
                    if contentInfoFrame.minY < 0.0 {
                        contentInfoView.alpha = 0.0
                    }
                }
                
                transition.updatePosition(layer: contentInfoView.layer, position: contentInfoFrame.center)
                transition.updateBounds(layer: contentInfoView.layer, bounds: CGRect(origin: CGPoint(), size: contentInfoFrame.size))
            }
            
            if let animateContentNodeOffsetFromBackgroundOffset = self.animateContentNodeOffsetFromBackgroundOffset {
                self.animateContentNodeOffsetFromBackgroundOffset = nil
                let offset = backgroundFrame.minY - animateContentNodeOffsetFromBackgroundOffset
                if let contentNode = self.contentNode {
                    transition.animatePositionAdditive(node: contentNode, offset: CGPoint(x: 0.0, y: -offset))
                }
                if let previousContentNode = self.previousContentNode {
                    transition.updatePosition(node: previousContentNode, position: previousContentNode.position.offsetBy(dx: 0.0, dy: offset))
                }
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }
    
    @objc func actionButtonPressed() {
        if self.controllerInteraction!.selectedPeers.isEmpty && self.presetText == nil {
            if let defaultAction = self.defaultAction {
                defaultAction.action()
            }
        } else {
            let _ = (self.showNames.get()
            |> take(1)).start(next: { [weak self] showNames in
                self?.send(showNames: showNames)
            })
        }
    }
        
    func send(peerId: PeerId? = nil, showNames: Bool = true, silently: Bool = false) {
        let peerIds: [PeerId]
        if let peerId = peerId {
            peerIds = [peerId]
        } else {
            peerIds = self.controllerInteraction!.selectedPeers.map { $0.peerId }
        }
        
        if let context = self.context, let tryShare = self.tryShare {
            let _ = (context.stateManager.postbox.combinedView(
                keys: peerIds.map { peerId in
                    return PostboxViewKey.peer(peerId: peerId, components: [])
                } + peerIds.map { peerId in
                    return PostboxViewKey.cachedPeerData(peerId: peerId)
                }
            )
            |> take(1)
            |> map { views -> ([EnginePeer.Id: EngineRenderedPeer?], [EnginePeer.Id: Int64]) in
                var result: [EnginePeer.Id: EngineRenderedPeer?] = [:]
                var requiresStars: [EnginePeer.Id: Int64] = [:]
                for peerId in peerIds {
                    if let view = views.views[PostboxViewKey.basicPeer(peerId)] as? PeerView, let peer = peerViewMainPeer(view) {
                        var peers: [EnginePeer.Id: EnginePeer] = [peer.id: EnginePeer(peer)]
                        if let channel = peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = view.peers[linkedMonoforumId] {
                            peers[mainChannel.id] = EnginePeer(mainChannel)
                        }
                        result[peerId] = EngineRenderedPeer(peerId: peer.id, peers: peers, associatedMedia: [:])
                        if peer is TelegramUser, let cachedPeerDataView = views.views[PostboxViewKey.cachedPeerData(peerId: peerId)] as? CachedPeerDataView {
                            if let cachedData = cachedPeerDataView.cachedPeerData as? CachedUserData {
                                requiresStars[peerId] = cachedData.sendPaidMessageStars?.value
                            }
                        } else if let channel = peer as? TelegramChannel {
                            requiresStars[peerId] = channel.sendPaidMessageStars?.value
                        }
                    }
                }
                return (result, requiresStars)
            }
            |> deliverOnMainQueue).start(next: { [weak self] peers, requiresStars in
                guard let self else {
                    return
                }
                
                var mappedPeers: [EngineRenderedPeer] = []
                for peerId in peerIds {
                    if let maybePeer = peers[peerId], let peer = maybePeer {
                        mappedPeers.append(peer)
                    }
                }
                
                if !tryShare(self.inputFieldNode.text, mappedPeers.compactMap(\.peer)) {
                    return
                }

                self.presentPaidMessageAlertIfNeeded(peers: mappedPeers, requiresStars: requiresStars, completion: { [weak self] in
                    self?.commitSend(peerId: peerId, showNames: showNames, silently: silently)
                })
                
            })
        } else {
            self.commitSend(peerId: peerId, showNames: showNames, silently: silently)
        }
    }
    
    private func presentPaidMessageAlertIfNeeded(peers: [EngineRenderedPeer], requiresStars: [EnginePeer.Id: Int64], completion: @escaping () -> Void) {
        var count: Int32 = Int32(self.messageCount)
        if !self.inputFieldNode.text.isEmpty {
            count += 1
        }
        var chargingPeers: [EngineRenderedPeer] = []
        var totalAmount: StarsAmount = .zero
        for peer in peers {
            if let stars = requiresStars[peer.peerId] {
                chargingPeers.append(peer)
                totalAmount = totalAmount + StarsAmount(value: stars, nanos: 0)
            }
        }
        if totalAmount.value > 0 {
            let controller = chatMessagePaymentAlertController(
                context: nil,
                presentationData: self.presentationData,
                updatedPresentationData: nil,
                peers: chargingPeers,
                count: count,
                amount: totalAmount,
                totalAmount: totalAmount,
                hasCheck: false,
                navigationController: nil,
                completion: { _ in
                    completion()
                }
            )
            self.present?(controller)
        } else {
            completion()
        }
    }
    
    private func commitSend(peerId: PeerId?, showNames: Bool, silently: Bool) {
        if !self.inputFieldNode.text.isEmpty {
            for peer in self.controllerInteraction!.selectedPeers {
                if case let .channel(channel) = peer.peer, channel.isRestrictedBySlowmode {
                    self.presentError(channel.title, self.presentationData.strings.Share_MultipleMessagesDisabled)
                    return
                }
            }
        }
        
        self.inputFieldNode.deactivateInput()
        let transition: ContainedViewLayoutTransition
        if peerId == nil {
            transition = .animated(duration: 0.12, curve: .easeInOut)
        } else {
            transition = .immediate
        }
        transition.updateAlpha(node: self.actionButtonNode, alpha: 0.0)
        transition.updateAlpha(node: self.inputFieldNode, alpha: 0.0)
        transition.updateAlpha(node: self.actionSeparatorNode, alpha: 0.0)
        transition.updateAlpha(node: self.actionsBackgroundNode, alpha: 0.0)
        if let startAtTimestampNode = self.startAtTimestampNode {
            transition.updateAlpha(node: startAtTimestampNode, alpha: 0.0)
        }
        
        let peerIds: [PeerId]
        var topicIds: [PeerId: Int64] = [:]
        if let peerId = peerId {
            peerIds = [peerId]
        } else {
            peerIds = self.controllerInteraction!.selectedPeers.map { $0.peerId }
            topicIds = self.controllerInteraction!.selectedTopics.mapValues { $0.0 }
        }
        
        if let context = self.context {
            self.environment.donateSendMessageIntent(account: context, peerIds: peerIds)
        }
        
        if let signal = self.share?(self.inputFieldNode.text, peerIds, topicIds, showNames, silently) {
            var wasDone = false
            let timestamp = CACurrentMediaTime()
            let doneImpl: (Bool) -> Void = { [weak self] shouldDelay in
                let minDelay: Double = shouldDelay ? 0.9 : 0.6
                let delay: Double
                let hapticDelay: Double
                
                if let strongSelf = self, let contentNode = strongSelf.contentNode as? ShareProlongedLoadingContainerNode {
                    delay = contentNode.completionDuration
                    hapticDelay = shouldDelay ? delay - 1.5 : delay
                } else {
                    delay = max(minDelay, (timestamp + minDelay) - CACurrentMediaTime())
                    hapticDelay = delay
                }
                         
                Queue.mainQueue().after(hapticDelay, {
                    if self?.hapticFeedback == nil {
                        self?.hapticFeedback = HapticFeedback()
                    }
                    self?.hapticFeedback?.success()
                })
                
                Queue.mainQueue().after(delay, {
                    self?.animateOut(shared: true, completion: {
                        self?.dismiss?(true)
                        self?.completed?(peerIds)
                    })
                })
            }
            
            if !self.fromForeignApp {
                self.animateOut(shared: true, completion: {
                })
                self.completed?(peerIds)
                
                let delay: Double
                if let peerId = peerIds.first, peerIds.count == 1 && peerId == self.context?.accountPeerId {
                    delay = 0.88
                } else {
                    delay = 0.44
                }
                
                Queue.mainQueue().after(delay) {
                    if self.hapticFeedback == nil {
                        self.hapticFeedback = HapticFeedback()
                    }
                    self.hapticFeedback?.success()
                }
            }
            var transitioned = false
            let fromForeignApp = self.fromForeignApp
            self.shareDisposable.set((signal
            |> deliverOnMainQueue).start(next: { [weak self] status in
                guard let strongSelf = self else {
                    return
                }
                
                if fromForeignApp, case let .preparing(long) = status, !transitioned {
                    transitioned = true
                    if long {
                        strongSelf.transitionToContentNode(ShareProlongedLoadingContainerNode(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, forceNativeAppearance: true, postbox: strongSelf.context?.stateManager.postbox, environment: strongSelf.environment), fastOut: true)
                    } else {
                        strongSelf.transitionToContentNode(ShareLoadingContainerNode(theme: strongSelf.presentationData.theme, forceNativeAppearance: true), fastOut: true)
                    }
                }
                
                if case let .done(correlationIds) = status, !fromForeignApp {
                    strongSelf.enqueued?(peerIds, correlationIds)
                    strongSelf.dismiss?(true)
                    return
                }
                                
                guard let contentNode = strongSelf.contentNode as? ShareLoadingContainer else {
                    return
                }
                
                switch status {
                    case .preparing:
                        contentNode.state = .preparing
                    case let .progress(value):
                        contentNode.state = .progress(value)
                    case .done:
                        contentNode.state = .done
                        if fromForeignApp {
                            if !wasDone {
                                wasDone = true
                                doneImpl(true)
                            }
                        } else {
                            strongSelf.dismiss?(true)
                        }
                }
            }, error: { _ in
                
            }, completed: {
                if !wasDone && fromForeignApp {
                    doneImpl(false)
                }
            }))
        }
    }
    
    func animateIn() {
        if let completion = self.outCompletion {
            self.outCompletion = nil
            completion()
            return
        }
        if self.contentNode != nil {
            self.isHidden = false
            
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            
            let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
            
            let dimPosition = self.dimNode.layer.position
            self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            })
        }
    }
    
    private var animatingOut = false
    var outCompletion: (() -> Void)?
    func animateOut(shared: Bool, completion: @escaping () -> Void) {
        guard !self.animatingOut else {
            return
        }
        self.animatingOut = true
        
        if let contentInfoView = self.contentInfoView, contentInfoView.alpha != 0.0 {
            ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: contentInfoView, alpha: 0.0)
            ComponentTransition.easeInOut(duration: 0.2).setScale(view: contentInfoView, scale: 0.5)
        }
        
        if self.contentNode != nil {
            var dimCompleted = false
            var offsetCompleted = false
            
            let internalCompletion: () -> Void = { [weak self] in
                if dimCompleted && offsetCompleted {
                    if let strongSelf = self {
                        strongSelf.animatingOut = false
                        strongSelf.isHidden = true
                        strongSelf.dimNode.layer.removeAllAnimations()
                        strongSelf.layer.removeAllAnimations()
                    }
                    completion()
                }
            }
            
            self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                dimCompleted = true
                internalCompletion()
            })
            
            let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
            let dimPosition = self.dimNode.layer.position
            self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                offsetCompleted = true
                internalCompletion()
            })
        } else {
            self.animatingOut = false
            self.outCompletion = completion
            Queue.mainQueue().after(0.2) {
                if let completion = self.outCompletion {
                    self.outCompletion = nil
                    completion()
                }
            }
        }
    }
    
    func updatePeers(context: ShareControllerAccountContext, switchableAccounts: [ShareControllerSwitchableAccount], peers: [(peer: EngineRenderedPeer, presence: EnginePeer.Presence?, requiresPremiumForMessaging: Bool, requiresStars: Int64?)], accountPeer: EnginePeer, defaultAction: ShareControllerAction?) {
        self.context = context
                
        if let peersContentNode = self.peersContentNode, peersContentNode.accountPeer.id == accountPeer.id {
            peersContentNode.peersValue.set(.single(peers))
            return
        }
        
        if let peerId = self.immediatePeerId {
            self.immediatePeerId = nil
            let _ = (context.stateManager.postbox.combinedView(keys: [PostboxViewKey.peer(peerId: peerId, components: [])])
            |> take(1)
            |> map { views -> EngineRenderedPeer? in
                guard let view = views.views[PostboxViewKey.peer(peerId: peerId, components: [])] as? PeerView else {
                    return nil
                }
                var peers: [EnginePeer.Id: EnginePeer] = [:]
                guard let peer = view.peers[peerId] else {
                    return nil
                }
                peers[peer.id] = EnginePeer(peer)

                if let secretChat = peer as? TelegramSecretChat {
                    guard let mainPeer = view.peers[secretChat.regularPeerId] else {
                        return nil
                    }
                    peers[mainPeer.id] = EnginePeer(mainPeer)
                }

                return EngineRenderedPeer(peerId: peerId, peers: peers, associatedMedia: view.media)
            }
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let strongSelf = self, let peer = peer {
                    strongSelf.controllerInteraction?.togglePeer(peer, peer.peerId != context.accountPeerId)
                }
            })
        }
        
        let animated = self.peersContentNode == nil
        let peersContentNode = SharePeersContainerNode(environment: self.environment, context: context, switchableAccounts: switchableAccounts, theme: self.presentationData.theme, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder, peers: peers, accountPeer: accountPeer, controllerInteraction: self.controllerInteraction!, externalShare: self.externalShare, isMainApp: self.environment.isMainApp, switchToAnotherAccount: { [weak self] in
            self?.switchToAnotherAccount?()
        }, debugAction: { [weak self] in
            self?.debugAction?()
        }, extendedInitialReveal: self.presetText != nil, segmentedValues: self.segmentedValues, fromPublicChannel: self.fromPublicChannel)
        self.peersContentNode = peersContentNode
        peersContentNode.openSearch = { [weak self] in
            let signal: Signal<([RecentlySearchedPeer], [EnginePeer.Id: Bool]), NoError> = _internal_recentlySearchedPeers(postbox: context.stateManager.postbox)
            |> take(1)
            |> mapToSignal { peers -> Signal<([RecentlySearchedPeer], [EnginePeer.Id: Bool]), NoError> in
                var possiblePremiumRequiredPeers = Set<EnginePeer.Id>()
                for peer in peers {
                    if let user = peer.peer.peer as? TelegramUser, user.flags.contains(.requirePremium) {
                        possiblePremiumRequiredPeers.insert(user.id)
                    }
                }
                
                if let context = context as? ShareControllerAppAccountContext {
                    context.context.account.viewTracker.refreshCanSendMessagesForPeerIds(peerIds: Array(possiblePremiumRequiredPeers))
                }
                
                return context.engineData.subscribe(
                    EngineDataMap(
                        possiblePremiumRequiredPeers.map(TelegramEngine.EngineData.Item.Peer.IsPremiumRequiredForMessaging.init(id:))
                    )
                )
                |> map { peerRequiresPremiumForMessaging -> ([RecentlySearchedPeer], [EnginePeer.Id: Bool]) in
                    return (peers, peerRequiresPremiumForMessaging)
                }
            }
            |> take(1)
            let _ = (signal
            |> deliverOnMainQueue).startStandalone(next: { peers, peerRequiresPremiumForMessaging in
                if let strongSelf = self {
                    let recentPeers: [(peer: EngineRenderedPeer, requiresPremiumForMessaging: Bool)] = peers.filter({ $0.peer.peerId.namespace != Namespaces.Peer.SecretChat }).map({
                        (EngineRenderedPeer($0.peer), peerRequiresPremiumForMessaging[$0.peer.peerId] ?? false)
                    })
                    
                    let searchContentNode = ShareSearchContainerNode(environment: strongSelf.environment, context: context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, controllerInteraction: strongSelf.controllerInteraction!, recentPeers: recentPeers)
                    searchContentNode.cancel = {
                        if let strongSelf = self, let peersContentNode = strongSelf.peersContentNode {
                            strongSelf.transitionToContentNode(peersContentNode)
                        }
                    }
                    strongSelf.transitionToContentNode(searchContentNode)
                }
            })
        }
        let openShare: (Bool) -> Void = { [weak self] reportReady in
            guard let strongSelf = self, let shareExternal = strongSelf.shareExternal else {
                return
            }
            
            let proceed: (Bool) -> Void = { asImage in
                var loadingTimestamp: Double?
                strongSelf.shareDisposable.set((shareExternal(asImage) |> deliverOnMainQueue).start(next: { state in
                    guard let strongSelf = self else {
                        return
                    }
                    switch state {
                        case .preparing:
                            if loadingTimestamp == nil {
                                strongSelf.inputFieldNode.deactivateInput()
                                let transition = ContainedViewLayoutTransition.animated(duration: 0.12, curve: .easeInOut)
                                transition.updateAlpha(node: strongSelf.actionButtonNode, alpha: 0.0)
                                transition.updateAlpha(node: strongSelf.inputFieldNode, alpha: 0.0)
                                transition.updateAlpha(node: strongSelf.actionSeparatorNode, alpha: 0.0)
                                transition.updateAlpha(node: strongSelf.actionsBackgroundNode, alpha: 0.0)
                                if let startAtTimestampNode = strongSelf.startAtTimestampNode {
                                    transition.updateAlpha(node: startAtTimestampNode, alpha: 0.0)
                                }
                                strongSelf.transitionToContentNode(ShareLoadingContainerNode(theme: strongSelf.presentationData.theme, forceNativeAppearance: true), fastOut: true)
                                loadingTimestamp = CACurrentMediaTime()
                                if reportReady {
                                    strongSelf.ready.set(.single(true))
                                }
                            }
                        case .done:
                            if let loadingTimestamp = loadingTimestamp {
                                let minDelay = 0.6
                                let delay = max(0.0, (loadingTimestamp + minDelay) - CACurrentMediaTime())
                                Queue.mainQueue().after(delay, {
                                    if let strongSelf = self {
                                        strongSelf.animateOut(shared: true, completion: {
                                            self?.dismiss?(true)
                                        })
                                    }
                                })
                            } else {
                                if reportReady {
                                    strongSelf.ready.set(.single(true))
                                }
                                strongSelf.animateOut(shared: true, completion: {
                                    self?.dismiss?(true)
                                })
                            }
                    }
                }))
            }
            
            if strongSelf.fromPublicChannel {
                proceed(true)
            } else {
                proceed(false)
            }
        }
        peersContentNode.openShare = { node, gesture in
            openShare(false)
        }
        peersContentNode.segmentedSelectedIndexUpdated = { [weak self] index in
            if let strongSelf = self, let _ = strongSelf.segmentedValues {
                strongSelf.selectedSegmentedIndex = index
                strongSelf.updateButton()
            }
        }
        if self.immediateExternalShare {
            openShare(true)
        } else {
            self.transitionToContentNode(peersContentNode, animated: animated)
            self.ready.set(.single(true))
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.actionButtonNode.hitTest(self.actionButtonNode.convert(point, from: self), with: event) {
            return result
        }
        if let startAtTimestampNode = self.startAtTimestampNode {
            if let result = startAtTimestampNode.hitTest(startAtTimestampNode.convert(point, from: self), with: event) {
                return result
            }
        }
        if self.bounds.contains(point) {
            if let contentInfoView = self.contentInfoView, contentInfoView.alpha != 0.0 {
                if let result = contentInfoView.hitTest(self.view.convert(point, to: contentInfoView), with: event) {
                    return result
                }
            }
            
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) && !self.cancelButtonNode.bounds.contains(self.convert(point, to: self.cancelButtonNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    private func scheduleInteractiveTransition(_ transition: ContainedViewLayoutTransition) {
        if let scheduledLayoutTransitionRequest = self.scheduledLayoutTransitionRequest {
            switch scheduledLayoutTransitionRequest.1 {
                case .immediate:
                    self.scheduleLayoutTransitionRequest(transition)
                default:
                    break
            }
        } else {
            self.scheduleLayoutTransitionRequest(transition)
        }
    }
    
    private func scheduleLayoutTransitionRequest(_ transition: ContainedViewLayoutTransition) {
        let requestId = self.scheduledLayoutTransitionRequestId
        self.scheduledLayoutTransitionRequestId += 1
        self.scheduledLayoutTransitionRequest = (requestId, transition)
        (self.view as? UITracingLayerView)?.schedule(layout: { [weak self] in
            if let strongSelf = self {
                if let (currentRequestId, currentRequestTransition) = strongSelf.scheduledLayoutTransitionRequest, currentRequestId == requestId {
                    strongSelf.scheduledLayoutTransitionRequest = nil
                    strongSelf.requestLayout(currentRequestTransition)
                }
            }
        })
        self.setNeedsLayout()
    }
    
    private func updateButton() {
        let count = self.controllerInteraction!.selectedPeers.count
        if count == 0 {
            if self.presetText != nil {
                self.actionButtonNode.setTitle(self.presentationData.strings.ShareMenu_Send, with: Font.medium(20.0), with: self.presentationData.theme.actionSheet.disabledActionTextColor, for: .normal)
                self.actionButtonNode.isEnabled = false
                self.actionButtonNode.badge = nil
            } else if let segmentedValues = self.segmentedValues {
                let value = segmentedValues[self.selectedSegmentedIndex]
                self.actionButtonNode.setTitle(value.actionTitle, with: Font.regular(20.0), with: self.presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
                self.actionButtonNode.isEnabled = true
                self.actionButtonNode.badge = nil
            } else if let defaultAction = self.defaultAction {
                self.actionButtonNode.setTitle(defaultAction.title, with: Font.regular(20.0), with: self.presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
                self.actionButtonNode.isEnabled = true
                self.actionButtonNode.badge = nil
            } else {
                self.actionButtonNode.setTitle(self.presentationData.strings.ShareMenu_Send, with: Font.medium(20.0), with: self.presentationData.theme.actionSheet.disabledActionTextColor, for: .normal)
                self.actionButtonNode.isEnabled = false
                self.actionButtonNode.badge = nil
            }
        } else {
            let text: String
            if let segmentedValues = self.segmentedValues {
                let value = segmentedValues[self.selectedSegmentedIndex]
                text = value.formatSendTitle(count)
            } else {
                text = self.presentationData.strings.ShareMenu_Send
            }
            self.actionButtonNode.isEnabled = true
            self.actionButtonNode.setTitle(text, with: Font.medium(20.0), with: self.presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
            self.actionButtonNode.badge = "\(count)"
        }
    }
    
    func transitionToProgress(signal: Signal<Void, NoError>) {
        self.inputFieldNode.deactivateInput()
        let transition = ContainedViewLayoutTransition.animated(duration: 0.12, curve: .easeInOut)
        transition.updateAlpha(node: self.actionButtonNode, alpha: 0.0)
        transition.updateAlpha(node: self.inputFieldNode, alpha: 0.0)
        transition.updateAlpha(node: self.actionSeparatorNode, alpha: 0.0)
        transition.updateAlpha(node: self.actionsBackgroundNode, alpha: 0.0)
        if let startAtTimestampNode = self.startAtTimestampNode {
            transition.updateAlpha(node: startAtTimestampNode, alpha: 0.0)
        }
        
        self.transitionToContentNode(ShareProlongedLoadingContainerNode(theme: self.presentationData.theme, strings: self.presentationData.strings, forceNativeAppearance: true, postbox: self.context?.stateManager.postbox, environment: self.environment), fastOut: true)
        let timestamp = CACurrentMediaTime()
        self.shareDisposable.set(signal.start(completed: { [weak self] in
            let minDelay = 0.6
            let delay = max(0.0, (timestamp + minDelay) - CACurrentMediaTime())
            Queue.mainQueue().after(delay, {
                if let strongSelf = self {
                    strongSelf.animateOut(shared: true, completion: {
                        self?.dismiss?(true)
                    })
                }
            })
        }))
    }
    
    func transitionToProgressWithValue(signal: Signal<Float?, NoError>, dismissImmediately: Bool = false, completion: @escaping () -> Void) {
        self.inputFieldNode.deactivateInput()
        
        if dismissImmediately {
            self.animateOut(shared: true, completion: {})
            
            self.shareDisposable.set((signal
            |> deliverOnMainQueue).start(next: { _ in

            }, completed: { [weak self] in
                if let strongSelf = self {
                    strongSelf.dismiss?(true)
                }
                
                completion()
            }))
        } else {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.12, curve: .easeInOut)
            transition.updateAlpha(node: self.actionButtonNode, alpha: 0.0)
            transition.updateAlpha(node: self.inputFieldNode, alpha: 0.0)
            transition.updateAlpha(node: self.actionSeparatorNode, alpha: 0.0)
            transition.updateAlpha(node: self.actionsBackgroundNode, alpha: 0.0)
            if let startAtTimestampNode = self.startAtTimestampNode {
                transition.updateAlpha(node: startAtTimestampNode, alpha: 0.0)
            }
            
            self.transitionToContentNode(ShareLoadingContainerNode(theme: self.presentationData.theme, forceNativeAppearance: true), fastOut: true)
            
            let timestamp = CACurrentMediaTime()
            var wasDone = false
            let doneImpl: (Bool) -> Void = { [weak self] shouldDelay in
                let minDelay: Double = shouldDelay ? 0.9 : 0.6
                let delay = max(minDelay, (timestamp + minDelay) - CACurrentMediaTime())
                Queue.mainQueue().after(delay, {
                    if let strongSelf = self {
                        strongSelf.animateOut(shared: true, completion: {
                            self?.dismiss?(true)
                        })
                    }
                })
            }
            self.shareDisposable.set((signal
            |> deliverOnMainQueue).start(next: { [weak self] status in
                guard let strongSelf = self, let contentNode = strongSelf.contentNode as? ShareLoadingContainer else {
                    return
                }
                if let status = status {
                    contentNode.state = .progress(status)
                }
            }, completed: { [weak self] in
                completion()
                
                guard let strongSelf = self, let contentNode = strongSelf.contentNode as? ShareLoadingContainer else {
                    return
                }
                contentNode.state = .done
                if !wasDone {
                    wasDone = true
                    doneImpl(true)
                }
            }))
        }
    }
}

private final class ShareContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceNode: ContextReferenceContentNode
    private let customPosition: CGPoint?
    
    init(sourceNode: ContextReferenceContentNode, customPosition: CGPoint?) {
        self.sourceNode = sourceNode
        self.customPosition = customPosition
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds, customPosition: self.customPosition)
    }
}

private func threadList(accountPeerId: EnginePeer.Id, postbox: Postbox, peerId: EnginePeer.Id, isMonoforum: Bool) -> Signal<EngineChatList, NoError> {
    if isMonoforum {
        let viewKey: PostboxViewKey = .savedMessagesIndex(peerId: peerId)
        let interfaceStateKey: PostboxViewKey = .chatInterfaceState(peerId: peerId)
        
        return postbox.combinedView(keys: [viewKey, interfaceStateKey])
        |> map { views -> EngineChatList in
            guard let view = views.views[viewKey] as? MessageHistorySavedMessagesIndexView else {
                preconditionFailure()
            }
            
            var draft: EngineChatList.Draft?
            if let interfaceStateView = views.views[interfaceStateKey] as? ChatInterfaceStateView {
                if let embeddedState = interfaceStateView.value, let _ = embeddedState.overrideChatTimestamp {
                    if let opaqueState = _internal_decodeStoredChatInterfaceState(state: embeddedState) {
                        if let text = opaqueState.synchronizeableInputState?.text {
                            draft = EngineChatList.Draft(text: text, entities: opaqueState.synchronizeableInputState?.entities ?? [])
                        }
                    }
                }
            }
             
            var items: [EngineChatList.Item] = []
            for item in view.items {
                guard let sourcePeer = item.peer else {
                    continue
                }
                
                let sourceId = PeerId(item.id)
                
                var messages: [EngineMessage] = []
                if let topMessage = item.topMessage {
                    messages.append(EngineMessage(topMessage))
                }
                
                let mappedMessageIndex = MessageIndex(id: MessageId(peerId: sourceId, namespace: item.index.id.namespace, id: item.index.id.id), timestamp: item.index.timestamp)
                
                let readCounters = EnginePeerReadCounters(state: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: Int32(item.unreadCount), markedUnread: item.markedUnread))]), isMuted: false)
                
                var itemDraft: EngineChatList.Draft?
                if let embeddedState = item.embeddedInterfaceState, let _ = embeddedState.overrideChatTimestamp {
                    if let opaqueState = _internal_decodeStoredChatInterfaceState(state: embeddedState) {
                        if let text = opaqueState.synchronizeableInputState?.text {
                            itemDraft = EngineChatList.Draft(text: text, entities: opaqueState.synchronizeableInputState?.entities ?? [])
                        }
                    }
                }
                
                items.append(EngineChatList.Item(
                    id: .chatList(sourceId),
                    index: .chatList(ChatListIndex(pinningIndex: item.pinnedIndex.flatMap(UInt16.init), messageIndex: mappedMessageIndex)),
                    messages: messages,
                    readCounters: readCounters,
                    isMuted: false,
                    draft: sourceId == accountPeerId ? draft : itemDraft,
                    threadData: nil,
                    renderedPeer: EngineRenderedPeer(peer: EnginePeer(sourcePeer)),
                    presence: nil,
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    hasFailed: false,
                    isContact: false,
                    autoremoveTimeout: nil,
                    storyStats: nil,
                    displayAsTopicList: false,
                    isPremiumRequiredToMessage: false,
                    mediaDraftContentType: nil
                ))
            }
            
            let list = EngineChatList(
                items: items.reversed(),
                groupItems: [],
                additionalItems: [],
                hasEarlier: false,
                hasLater: false,
                isLoading: view.isLoading
            )
            
            return list
        }
    } else {
        let viewKey: PostboxViewKey = .messageHistoryThreadIndex(
            id: peerId,
            summaryComponents: ChatListEntrySummaryComponents(
                components: [:]
            )
        )

        return postbox.combinedView(keys: [viewKey])
        |> mapToSignal { view -> Signal<CombinedView, NoError> in
            return postbox.transaction { transaction -> CombinedView in
                if let peer = transaction.getPeer(accountPeerId) {
                    transaction.updatePeersInternal([peer]) { current, _ in
                        return current ?? peer
                    }
                }
                return view
            }
        }
        |> map { views -> EngineChatList in
            guard let view = views.views[viewKey] as? MessageHistoryThreadIndexView else {
                preconditionFailure()
            }
            
            var items: [EngineChatList.Item] = []
            for item in view.items {
                guard let peer = view.peer else {
                    continue
                }
                guard let data = item.info.get(MessageHistoryThreadData.self) else {
                    continue
                }
                
                let pinnedIndex: EngineChatList.Item.PinnedIndex
                if let index = item.pinnedIndex {
                    pinnedIndex = .index(index)
                } else {
                    pinnedIndex = .none
                }
                
                items.append(EngineChatList.Item(
                    id: .forum(item.id),
                    index: .forum(pinnedIndex: pinnedIndex, timestamp: item.index.timestamp, threadId: item.id, namespace: item.index.id.namespace, id: item.index.id.id),
                    messages: item.topMessage.flatMap { [EngineMessage($0)] } ?? [],
                    readCounters: nil,
                    isMuted: false,
                    draft: nil,
                    threadData: data,
                    renderedPeer: EngineRenderedPeer(peer: EnginePeer(peer)),
                    presence: nil,
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    hasFailed: false,
                    isContact: false,
                    autoremoveTimeout: nil,
                    storyStats: nil,
                    displayAsTopicList: false,
                    isPremiumRequiredToMessage: false,
                    mediaDraftContentType: nil
                ))
            }
            
            let list = EngineChatList(
                items: items,
                groupItems: [],
                additionalItems: [],
                hasEarlier: false,
                hasLater: false,
                isLoading: view.isLoading
            )
            return list
        }
    }
}
