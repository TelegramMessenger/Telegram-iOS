import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import ButtonComponent
import Markdown
import BalancedTextComponent
import AvatarNode
import TextFormat
import TelegramStringFormatting
import StarsAvatarComponent
import EmojiTextAttachmentView
import UndoUI
import ConfettiEffect
import PlainButtonComponent
import CheckComponent
import TooltipUI

private let modelButtonTag = GenericComponentViewTag()
private let backdropButtonTag = GenericComponentViewTag()
private let symbolButtonTag = GenericComponentViewTag()

private final class GiftViewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: GiftViewScreen.Subject
    let cancel: (Bool) -> Void
    let openPeer: (EnginePeer) -> Void
    let updateSavedToProfile: (Bool) -> Void
    let convertToStars: () -> Void
    let openStarsIntro: () -> Void
    let sendGift: (EnginePeer.Id) -> Void
    let openMyGifts: () -> Void
    let transferGift: () -> Void
    let showAttributeInfo: (Any) -> Void
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        cancel: @escaping  (Bool) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        updateSavedToProfile: @escaping (Bool) -> Void,
        convertToStars: @escaping () -> Void,
        openStarsIntro: @escaping () -> Void,
    	sendGift: @escaping (EnginePeer.Id) -> Void,
    	openMyGifts: @escaping () -> Void,
        transferGift: @escaping () -> Void,
        showAttributeInfo: @escaping (Any) -> Void,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.subject = subject
        self.cancel = cancel
        self.openPeer = openPeer
        self.updateSavedToProfile = updateSavedToProfile
        self.convertToStars = convertToStars
        self.openStarsIntro = openStarsIntro
        self.sendGift = sendGift
        self.openMyGifts = openMyGifts
        self.transferGift = transferGift
        self.showAttributeInfo = showAttributeInfo
        self.getController = getController
    }
    
    static func ==(lhs: GiftViewSheetContent, rhs: GiftViewSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let getController: () -> ViewController?
        
        private var disposable: Disposable?
        var initialized = false
        
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        var starGiftsMap: [Int64: StarGift.Gift] = [:]
        
        var cachedCircleImage: UIImage?
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedOverlayCloseImage: UIImage?
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
        
        var inProgress = false
        
        var inUpgrade = false
        var isUpgradedMock = false
        
        var keepName = false
        
        var mockFiles: [TelegramMediaFile] = []
        var mockIconFiles: [TelegramMediaFile] = []
        var upgradedMockId: Int = 0
        var upgradedMockBackgroundColor: UIColor = .white
        var upgradedMockIcon: TelegramMediaFile?
        
        init(context: AccountContext, subject: GiftViewScreen.Subject, getController: @escaping () -> ViewController?) {
            self.context = context
            self.getController = getController
            
            super.init()
            
            if let arguments = subject.arguments {
                var peerIds: [EnginePeer.Id] = [arguments.peerId, context.account.peerId]
                if let fromPeerId = arguments.fromPeerId, !peerIds.contains(fromPeerId) {
                    peerIds.append(fromPeerId)
                }
                self.disposable = combineLatest(queue: Queue.mainQueue(),
                    context.engine.data.get(EngineDataMap(
                        peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                            return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                        }
                    )),
                    .single(nil) |> then(context.engine.payments.cachedStarGifts())
                ).startStrict(next: { [weak self] peers, starGifts in
                    if let strongSelf = self {
                        var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                        for peerId in peerIds {
                            if let maybePeer = peers[peerId], let peer = maybePeer {
                                peersMap[peerId] = peer
                            }
                        }
                        strongSelf.peerMap = peersMap

                        var starGiftsMap: [Int64: StarGift.Gift] = [:]
                        if let starGifts {
                            for gift in starGifts {
                                if case let .generic(gift) = gift {
                                    starGiftsMap[gift.id] = gift
                                }
                            }
                        }
                        strongSelf.starGiftsMap = starGiftsMap
                        
                        strongSelf.initialized = true
                        
                        strongSelf.updated(transition: .immediate)
                    }
                })
            }
            
            #if DEBUG
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                self.context.engine.stickers.loadedStickerPack(reference: .name("RingColors"), forceActualized: false),
                self.context.engine.stickers.loadedStickerPack(reference: .iconStatusEmoji, forceActualized: false)
                |> map { result -> [TelegramMediaFile] in
                    switch result {
                    case let .result(_, items, _):
                        return items.map(\.file)
                    default:
                        return []
                    }
                }
                |> take(1)
            ).start(next: { [weak self] result, icons in
                guard let self else {
                    return
                }
                if case let .result(_, items, _) = result {
                    self.mockFiles = items.map { $0.file }
                    self.mockIconFiles = icons
                    self.updated()
                }
            })
            #endif
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func doMockUpgrade() {
            self.inUpgrade = false
            self.isUpgradedMock = true
            self.upgradedMockId = Int.random(in: 0 ..< self.mockFiles.count)
            self.upgradedMockBackgroundColor = self.context.peerNameColors.profileColors.values.randomElement()?.main ?? .white
            self.upgradedMockIcon = self.mockIconFiles.randomElement()
            self.updated(transition: .spring(duration: 0.4))
            
            if let controller = self.getController() {
                controller.view.addSubview(ConfettiView(frame: controller.view.bounds))
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject, getController: self.getController)
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        let animation = Child(GiftCompositionComponent.self)
        let title = Child(MultilineTextComponent.self)
        let description = Child(MultilineTextComponent.self)
        let hiddenText = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        let additionalText = Child(MultilineTextComponent.self)
        let button = Child(ButtonComponent.self)
        
        let upgradeTitle = Child(MultilineTextComponent.self)
        let upgradeDescription = Child(BalancedTextComponent.self)
        let upgradePerks = Child(List<Empty>.self)
        let upgradeKeepName = Child(PlainButtonComponent.self)
                
        let spaceRegex = try? NSRegularExpression(pattern: "\\[(.*?)\\]", options: [])
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left

            let closeImage: UIImage
            let closeOverlayImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            if let image = state.cachedOverlayCloseImage {
                closeOverlayImage = image
            } else {
                closeOverlayImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.1), foregroundColor: .white)!
                state.cachedOverlayCloseImage = closeOverlayImage
            }
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: state.inUpgrade || state.isUpgradedMock ? closeOverlayImage : closeImage)),
                    action: { [weak component] in
                        component?.cancel(true)
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            
            var titleString: String
            var animationFile: TelegramMediaFile?
            let stars: Int64
            let convertStars: Int64?
            let text: String?
            let entities: [MessageTextEntity]?
            let limitTotal: Int32?
            var incoming = false
            var savedToProfile = false
            var converted = false
            var giftId: Int64 = 0
            var date: Int32?
            var soldOut = false
            var nameHidden = false
            if case let .soldOutGift(gift) = component.subject {
                animationFile = gift.file
                stars = gift.price
                text = nil
                entities = nil
                limitTotal = gift.availability?.total
                convertStars = nil
                soldOut = true
                titleString = strings.Gift_View_UnavailableTitle
            } else if let arguments = component.subject.arguments, case let .generic(gift) = arguments.gift {
                animationFile = gift.file
                stars = gift.price
                text = arguments.text
                entities = arguments.entities
                limitTotal = gift.availability?.total
                convertStars = arguments.convertStars
                incoming = arguments.incoming || arguments.peerId == component.context.account.peerId
                savedToProfile = arguments.savedToProfile
                converted = arguments.converted
                giftId = gift.id
                date = arguments.date
                titleString = incoming ? strings.Gift_View_ReceivedTitle : strings.Gift_View_Title
                nameHidden = arguments.nameHidden
            } else {
                animationFile = nil
                stars = 0
                text = nil
                entities = nil
                limitTotal = nil
                convertStars = nil
                titleString = ""
            }
            
            #if DEBUG
            if state.mockFiles.count > 1 {
                animationFile = state.mockFiles[1]
            }
            #endif
                        
            var originY: CGFloat = 0.0
            if let animationFile, !state.mockFiles.isEmpty {
                let animationHeight: CGFloat
                let animationSubject: GiftCompositionComponent.Subject
                if state.isUpgradedMock {
                    animationHeight = 240.0
                    animationSubject = .unique(state.mockFiles[state.upgradedMockId], state.upgradedMockBackgroundColor, state.upgradedMockIcon)
                } else if state.inUpgrade {
                    animationHeight = 258.0
                    animationSubject = .preview(state.mockFiles, state.mockIconFiles)
                } else {
                    animationHeight = 210.0
                    if !state.mockFiles.isEmpty {
                        animationSubject = .generic(state.mockFiles[1])
                    } else {
                        animationSubject = .generic(animationFile)
                    }
                }
                let animation = animation.update(
                    component: GiftCompositionComponent(
                        context: component.context,
                        theme: environment.theme,
                        subject: animationSubject
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: animationHeight),
                    transition: .immediate
                )
                context.add(animation
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: animationHeight / 2.0))
                )
                originY += animationHeight
            }
            
            if state.inUpgrade {
                let upgradeTitle = upgradeTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Gift_Upgrade_Title,
                            font: Font.bold(20.0),
                            textColor: .white,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(upgradeTitle
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 191.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                
                let upgradeDescription = upgradeDescription.update(
                    component: BalancedTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Gift_Upgrade_Description,
                            font: Font.regular(13.0),
                            textColor: UIColor.white.withAlphaComponent(0.6),
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 5,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(upgradeDescription
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 208.0 + upgradeDescription.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += 24.0
                
                let textColor = theme.actionSheet.primaryTextColor
                let secondaryTextColor = theme.actionSheet.secondaryTextColor
                let linkColor = theme.actionSheet.controlAccentColor
                
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: "unique",
                        component: AnyComponent(ParagraphComponent(
                            title: strings.Gift_Upgrade_Unique_Title,
                            titleColor: textColor,
                            text: strings.Gift_Upgrade_Unique_Description,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Unique",
                            iconColor: linkColor
                        ))
                    )
                )
                items.append(
                    AnyComponentWithIdentity(
                        id: "transferable",
                        component: AnyComponent(ParagraphComponent(
                            title: strings.Gift_Upgrade_Transferable_Title,
                            titleColor: textColor,
                            text: strings.Gift_Upgrade_Transferable_Description,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Transferable",
                            iconColor: linkColor
                        ))
                    )
                )
                items.append(
                    AnyComponentWithIdentity(
                        id: "tradable",
                        component: AnyComponent(ParagraphComponent(
                            title: strings.Gift_Upgrade_Tradable_Title,
                            titleColor: textColor,
                            text: strings.Gift_Upgrade_Tradable_Description,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Tradable",
                            iconColor: linkColor,
                            badge: strings.Gift_Upgrade_Soon
                        ))
                    )
                )
                
                let perksSideInset = sideInset + 12.0
                let upgradePerks = upgradePerks.update(
                    component: List(items),
                    availableSize: CGSize(width: context.availableSize.width - perksSideInset * 2.0, height: 10000.0),
                    transition: context.transition
                )
                context.add(upgradePerks
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + upgradePerks.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += upgradePerks.size.height
                originY += 16.0
                
                let checkTheme = CheckComponent.Theme(
                    backgroundColor: theme.list.itemCheckColors.fillColor,
                    strokeColor: theme.list.itemCheckColors.foregroundColor,
                    borderColor: theme.list.itemCheckColors.strokeColor,
                    overlayBorder: false,
                    hasInset: false,
                    hasShadow: false
                )
                let upgradeKeepName = upgradeKeepName.update(
                    component: PlainButtonComponent(
                        content: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                theme: checkTheme,
                                size: CGSize(width: 18.0, height: 18.0),
                                selected: state.keepName
                            ))),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: strings.Gift_Upgrade_AddName, font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor))
                            )))
                        ],
                        spacing: 10.0
                        )),
                        effectAlignment: .center,
                        action: { [weak state] in
                            guard let state else {
                                return
                            }
                            state.keepName = !state.keepName
                            state.updated(transition: .easeInOut(duration: 0.2))
                        },
                        animateAlpha: false,
                        animateScale: false
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 1000.0),
                    transition: context.transition
                )
                context.add(upgradeKeepName
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + upgradeKeepName.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += upgradeKeepName.size.height
                originY += 18.0
            } else {
                var descriptionText: String
                if state.isUpgradedMock {
                    //TODO:localize
                    titleString = "Ring"
                    descriptionText = "\(strings.Gift_Unique_Collectible) #175"
                } else if soldOut {
                    descriptionText = strings.Gift_View_UnavailableDescription
                } else if incoming {
                    if let convertStars {
                        if !converted {
                            descriptionText = strings.Gift_View_KeepUpgradeOrConvertDescription(strings.Gift_View_KeepOrConvertDescription_Stars(Int32(convertStars))).string
                        } else {
                            descriptionText = strings.Gift_View_ConvertedDescription(strings.Gift_View_ConvertedDescription_Stars(Int32(convertStars))).string
                        }
                    } else {
                        descriptionText = strings.Gift_View_BotDescription
                    }
                } else if let peerId = component.subject.arguments?.peerId, let peer = state.peerMap[peerId] {
                    if case .message = component.subject, let convertStars {
                        descriptionText = strings.Gift_View_OtherDescription(peer.compactDisplayTitle, strings.Gift_View_OtherDescription_Stars(Int32(convertStars))).string
                    } else {
                        descriptionText = ""
                    }
                } else {
                    descriptionText = ""
                }
                if let spaceRegex {
                    let nsRange = NSRange(descriptionText.startIndex..., in: descriptionText)
                    let matches = spaceRegex.matches(in: descriptionText, options: [], range: nsRange)
                    var modifiedString = descriptionText
                    
                    for match in matches.reversed() {
                        let matchRange = Range(match.range, in: descriptionText)!
                        let matchedSubstring = String(descriptionText[matchRange])
                        let replacedSubstring = matchedSubstring.replacingOccurrences(of: " ", with: "\u{00A0}")
                        modifiedString.replaceSubrange(matchRange, with: replacedSubstring)
                    }
                    descriptionText = modifiedString
                }
                
                let title = title.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: titleString,
                            font: state.isUpgradedMock ? Font.bold(20.0) : Font.bold(25.0),
                            textColor: state.isUpgradedMock ? .white : theme.actionSheet.primaryTextColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: state.isUpgradedMock ? 190.0 : 177.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                
//                originY += 32.0
//                if soldOut {
//                    originY -= 12.0
//                }
                
                let linkColor = theme.actionSheet.controlAccentColor
                if !descriptionText.isEmpty {
                    if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                        state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
                    }
                    
                    let textFont: UIFont
                    let textColor: UIColor
                    if state.isUpgradedMock {
                        textFont = Font.regular(13.0)
                        textColor = UIColor.white.withAlphaComponent(0.6)
                    } else {
                        textFont = soldOut ? Font.medium(15.0) : Font.regular(15.0)
                        textColor = soldOut ? theme.list.itemDestructiveColor : theme.list.itemPrimaryTextColor
                    }

                    let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    })
                    let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                    if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                        attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                    }
                    let description = description.update(
                        component: MultilineTextComponent(
                            text: .plain(attributedString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 5,
                            lineSpacing: 0.2,
                            highlightColor: linkColor.withAlphaComponent(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { _, _ in
                                component.openStarsIntro()
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                        transition: .immediate
                    )
                    context.add(description
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: 207.0 + description.size.height / 2.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                    
                    if state.isUpgradedMock {
                        originY += 16.0
                    } else {
                        originY += description.size.height + 21.0
                        if soldOut {
                            originY -= 7.0
                        }
                    }
                } else {
                    originY += 21.0
                }
                
                if nameHidden && incoming && !state.isUpgradedMock {
                    let textFont = Font.regular(13.0)
                    let textColor = theme.list.itemSecondaryTextColor
                    
                    let hiddenText = hiddenText.update(
                        component: MultilineTextComponent(
                            text: .plain(NSAttributedString(string: text != nil ? strings.Gift_View_NameAndMessageHidden : strings.Gift_View_NameHidden, font: textFont, textColor: textColor)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 2,
                            lineSpacing: 0.2
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                        transition: .immediate
                    )
                    context.add(hiddenText
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY))
                    )
                    
                    originY += hiddenText.size.height
                    originY += 11.0
                }
                
                let tableFont = Font.regular(15.0)
                let tableBoldFont = Font.semibold(15.0)
                let tableItalicFont = Font.italic(15.0)
                let tableBoldItalicFont = Font.semiboldItalic(15.0)
                let tableMonospaceFont = Font.monospace(15.0)
                
                let tableTextColor = theme.list.itemPrimaryTextColor
                let tableLinkColor = theme.list.itemAccentColor
                var tableItems: [TableComponent.Item] = []
                
                if !soldOut {
                    if state.isUpgradedMock {
                        if let peer = state.peerMap[component.context.account.peerId] {
                            let ownerComponent = AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(0),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(
                                                PeerCellComponent(
                                                    context: component.context,
                                                    theme: theme,
                                                    strings: strings,
                                                    peer: peer
                                                )
                                            ),
                                            action: {
                                                component.openPeer(peer)
                                                Queue.mainQueue().after(1.0, {
                                                    component.cancel(false)
                                                })
                                            }
                                        ))
                                    ),
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(1),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(ButtonContentComponent(
                                                context: component.context,
                                                text: strings.Gift_Unique_Transfer,
                                                color: theme.list.itemAccentColor
                                            )),
                                            action: {
                                                component.transferGift()
                                                Queue.mainQueue().after(1.0, {
                                                    component.cancel(false)
                                                })
                                            }
                                        ))
                                    )
                                ], spacing: 4.0)
                            )
                            tableItems.append(.init(
                                id: "owner",
                                title: strings.Gift_Unique_Owner,
                                component: ownerComponent
                            ))
                        }
                    } else if let peerId = component.subject.arguments?.fromPeerId, let peer = state.peerMap[peerId] {
                        let fromComponent: AnyComponent<Empty>
                        if incoming {
                            fromComponent = AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(0),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(
                                                PeerCellComponent(
                                                    context: component.context,
                                                    theme: theme,
                                                    strings: strings,
                                                    peer: peer
                                                )
                                            ),
                                            action: {
                                                component.openPeer(peer)
                                                Queue.mainQueue().after(1.0, {
                                                    component.cancel(false)
                                                })
                                            }
                                        ))
                                    ),
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(1),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(ButtonContentComponent(
                                                context: component.context,
                                                text: strings.Gift_View_Send,
                                                color: theme.list.itemAccentColor
                                            )),
                                            action: {
                                                component.sendGift(peerId)
                                                Queue.mainQueue().after(1.0, {
                                                    component.cancel(false)
                                                })
                                            }
                                        ))
                                    )
                                ], spacing: 4.0)
                            )
                        } else {
                            fromComponent = AnyComponent(Button(
                                content: AnyComponent(
                                    PeerCellComponent(
                                        context: component.context,
                                        theme: theme,
                                        strings: strings,
                                        peer: peer
                                    )
                                ),
                                action: {
                                    component.openPeer(peer)
                                    Queue.mainQueue().after(1.0, {
                                        component.cancel(false)
                                    })
                                }
                            ))
                        }
                        tableItems.append(.init(
                            id: "from",
                            title: strings.Gift_View_From,
                            component: fromComponent
                        ))
                    } else {
                        tableItems.append(.init(
                            id: "from_anon",
                            title: strings.Gift_View_From,
                            component: AnyComponent(
                                PeerCellComponent(
                                    context: component.context,
                                    theme: theme,
                                    strings: strings,
                                    peer: nil
                                )
                            )
                        ))
                    }
                }
                
                if state.isUpgradedMock {
                    let showAttributeInfo = component.showAttributeInfo
                    let modelComponent = AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Silver Glamour", font: tableFont, textColor: tableTextColor))))
                            ),
                            AnyComponentWithIdentity(
                                id: AnyHashable(1),
                                component: AnyComponent(Button(
                                    content: AnyComponent(ButtonContentComponent(
                                        context: component.context,
                                        text: "2%",
                                        color: theme.list.itemAccentColor
                                    )),
                                    action: {
                                        showAttributeInfo(modelButtonTag)
                                    }
                                ).tagged(modelButtonTag))
                            )
                        ], spacing: 4.0)
                    )
                    
                    tableItems.append(.init(
                        id: "model",
                        title: strings.Gift_Unique_Model,
                        component: modelComponent
                    ))
                    
                    let circleImage: UIImage
                    if let image = state.cachedCircleImage {
                        circleImage = image
                    } else {
                        circleImage = generateFilledCircleImage(diameter: 14.0, color: .white)!.withRenderingMode(.alwaysTemplate)
                        state.cachedCircleImage = circleImage
                    }
                    
                    let backdropComponent = AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(Image(image: circleImage, tintColor: state.upgradedMockBackgroundColor, size: CGSize(width: 14.0, height: 14.0)))
                            ),
                            AnyComponentWithIdentity(
                                id: AnyHashable(1),
                                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Green", font: tableFont, textColor: tableTextColor))))
                            ),
                            AnyComponentWithIdentity(
                                id: AnyHashable(2),
                                component: AnyComponent(Button(
                                    content: AnyComponent(ButtonContentComponent(
                                        context: component.context,
                                        text: "5%",
                                        color: theme.list.itemAccentColor
                                    )),
                                    action: {
                                        showAttributeInfo(backdropButtonTag)
                                    }
                                ).tagged(backdropButtonTag))
                            )
                        ], spacing: 4.0)
                    )
                    tableItems.append(.init(
                        id: "backdrop",
                        title: strings.Gift_Unique_Backdrop,
                        component: backdropComponent
                    ))
                    
                    let symbolComponent = AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Monkey", font: tableFont, textColor: tableTextColor))))
                            ),
                            AnyComponentWithIdentity(
                                id: AnyHashable(1),
                                component: AnyComponent(Button(
                                    content: AnyComponent(ButtonContentComponent(
                                        context: component.context,
                                        text: "2%",
                                        color: theme.list.itemAccentColor
                                    )),
                                    action: {
                                        showAttributeInfo(symbolButtonTag)
                                    }
                                ).tagged(symbolButtonTag))
                            )
                        ], spacing: 4.0)
                    )
                    tableItems.append(.init(
                        id: "symbol",
                        title: strings.Gift_Unique_Symbol,
                        component: symbolComponent
                    ))
                    
                    tableItems.append(.init(
                        id: "availability",
                        title: strings.Gift_Unique_Availability,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Unique_Issued("354/985").string, font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                } else {
                    if case let .soldOutGift(gift) = component.subject, let soldOut = gift.soldOut {
                        tableItems.append(.init(
                            id: "firstDate",
                            title: strings.Gift_View_FirstSale,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: soldOut.firstSale, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                        
                        tableItems.append(.init(
                            id: "lastDate",
                            title: strings.Gift_View_LastSale,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: soldOut.lastSale, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                    } else if let date {
                        tableItems.append(.init(
                            id: "date",
                            title: strings.Gift_View_Date,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: date, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                    }
                    
                    let valueString = "⭐️\(presentationStringsFormattedNumber(abs(Int32(stars)), dateTimeFormat.groupingSeparator))"
                    let valueAttributedString = NSMutableAttributedString(string: valueString, font: tableFont, textColor: tableTextColor)
                    let range = (valueAttributedString.string as NSString).range(of: "⭐️")
                    if range.location != NSNotFound {
                        valueAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                        valueAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
                    }
                    
                    let valueComponent: AnyComponent<Empty>
                    if let convertStars, incoming && !converted {
                        valueComponent = AnyComponent(
                            HStack([
                                AnyComponentWithIdentity(
                                    id: AnyHashable(0),
                                    component: AnyComponent(MultilineTextWithEntitiesComponent(
                                        context: component.context,
                                        animationCache: component.context.animationCache,
                                        animationRenderer: component.context.animationRenderer,
                                        placeholderColor: theme.list.mediaPlaceholderColor,
                                        text: .plain(valueAttributedString),
                                        maximumNumberOfLines: 0
                                    ))
                                ),
                                AnyComponentWithIdentity(
                                    id: AnyHashable(1),
                                    component: AnyComponent(Button(
                                        content: AnyComponent(ButtonContentComponent(
                                            context: component.context,
                                            text: strings.Gift_View_Sale(strings.Gift_View_Sale_Stars(Int32(convertStars))).string,
                                            color: theme.list.itemAccentColor
                                        )),
                                        action: {
                                            component.convertToStars()
                                        }
                                    ))
                                )
                            ], spacing: 4.0)
                        )
                    } else {
                        valueComponent = AnyComponent(MultilineTextWithEntitiesComponent(
                            context: component.context,
                            animationCache: component.context.animationCache,
                            animationRenderer: component.context.animationRenderer,
                            placeholderColor: theme.list.mediaPlaceholderColor,
                            text: .plain(valueAttributedString),
                            maximumNumberOfLines: 0
                        ))
                    }
                    
                    tableItems.append(.init(
                        id: "value",
                        title: strings.Gift_View_Value,
                        component: valueComponent,
                        insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
                    ))
                    
                    if let limitTotal {
                        var remains: Int32 = 0
                        if let gift = state.starGiftsMap[giftId], let availability = gift.availability {
                            remains = availability.remains
                        }
                        let remainsString = presentationStringsFormattedNumber(remains, environment.dateTimeFormat.groupingSeparator)
                        let totalString = presentationStringsFormattedNumber(limitTotal, environment.dateTimeFormat.groupingSeparator)
                        tableItems.append(.init(
                            id: "availability",
                            title: strings.Gift_View_Availability,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_View_Availability_NewOf("\(remainsString)", "\(totalString)").string, font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                    }
                    
                    if !soldOut {
                        //TODO:localize
                        var items: [AnyComponentWithIdentity<Empty>] = []
                        items.append(
                            AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_View_Status_NonUnique, font: tableFont, textColor: tableTextColor))))
                            )
                        )
                        if incoming {
                            items.append(
                                AnyComponentWithIdentity(
                                    id: AnyHashable(1),
                                    component: AnyComponent(Button(
                                        content: AnyComponent(ButtonContentComponent(
                                            context: component.context,
                                            text: strings.Gift_View_Status_Upgrade,
                                            color: theme.list.itemAccentColor
                                        )),
                                        action: { [weak state] in
                                            state?.inUpgrade = true
                                            state?.updated(transition: .spring(duration: 0.4))
                                        }
                                    ))
                                )
                            )
                        }
                        tableItems.append(.init(
                            id: "status",
                            title: strings.Gift_View_Status,
                            component: AnyComponent(
                                HStack(items, spacing: 4.0)
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
                        ))
                    }
                    
                    if let text {
                        let attributedText = stringWithAppliedEntities(text, entities: entities ?? [], baseColor: tableTextColor, linkColor: tableLinkColor, baseFont: tableFont, linkFont: tableFont, boldFont: tableBoldFont, italicFont: tableItalicFont, boldItalicFont: tableBoldItalicFont, fixedFont: tableMonospaceFont, blockQuoteFont: tableFont, message: nil)
                        
                        tableItems.append(.init(
                            id: "text",
                            title: nil,
                            component: AnyComponent(
                                MultilineTextWithEntitiesComponent(
                                    context: component.context,
                                    animationCache: component.context.animationCache,
                                    animationRenderer: component.context.animationRenderer,
                                    placeholderColor: theme.list.mediaPlaceholderColor,
                                    text: .plain(attributedText),
                                    maximumNumberOfLines: 0,
                                    handleSpoilers: true
                                )
                            )
                        ))
                    }
                }
                
                let table = table.update(
                    component: TableComponent(
                        theme: environment.theme,
                        items: tableItems
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(table
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += table.size.height + 23.0
                
                if incoming && !converted {
                    if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                        state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, theme)
                    }
                    let descriptionText = savedToProfile ? strings.Gift_View_DisplayedInfoHide : strings.Gift_View_HiddenInfo
                    
                    let textFont = Font.regular(13.0)
                    let textColor = theme.list.itemSecondaryTextColor
                    let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    })
                    let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                    if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedSmallChevronImage?.0 {
                        attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                    }
                    
                    originY -= 5.0
                    let additionalText = additionalText.update(
                        component: MultilineTextComponent(
                            text: .plain(attributedString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 5,
                            lineSpacing: 0.2,
                            highlightColor: linkColor.withAlphaComponent(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { _, _ in
                                component.updateSavedToProfile(false)
                                Queue.mainQueue().after(1.0, {
                                    component.cancel(false)
                                })
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                        transition: .immediate
                    )
                    context.add(additionalText
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + additionalText.size.height / 2.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                    originY += additionalText.size.height
                    originY += 16.0
                }
            }
            
            let buttonChild: _UpdatedChildComponent
            if state.inUpgrade {
                if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                    state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
                }
                
                //TODO:localize
                let amountString = "25"
                let buttonAttributedString = NSMutableAttributedString(string: "\(strings.Gift_Upgrade_Upgrade)   #  \(amountString)", font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: environment.theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: ButtonComponent.Background(
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                            cornerRadius: 10.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            state?.doMockUpgrade()
                        }),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
            } else if incoming && !converted && !savedToProfile {
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: ButtonComponent.Background(
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                            cornerRadius: 10.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: savedToProfile ? strings.Gift_View_Hide : strings.Gift_View_Display, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: {
                            component.updateSavedToProfile(!savedToProfile)
                        }),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
            } else {
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: ButtonComponent.Background(
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                            cornerRadius: 10.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Common_OK, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: {
                            component.cancel(true)
                        }),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
            }
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: originY), size: buttonChild.size)
            context.add(buttonChild
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
                .cornerRadius(10.0)
            )
            originY += buttonChild.size.height
            originY += 7.0
            
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
            
            let contentSize = CGSize(width: context.availableSize.width, height: originY + 5.0 + environment.safeInsets.bottom)
        
            return contentSize
        }
    }
}

private final class GiftViewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: GiftViewScreen.Subject
    let openPeer: (EnginePeer) -> Void
    let updateSavedToProfile: (Bool) -> Void
    let convertToStars: () -> Void
    let openStarsIntro: () -> Void
    let sendGift: (EnginePeer.Id) -> Void
    let openMyGifts: () -> Void
    let transferGift: () -> Void
    let showAttributeInfo: (Any) -> Void
    
    init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        openPeer: @escaping (EnginePeer) -> Void,
        updateSavedToProfile: @escaping (Bool) -> Void,
        convertToStars: @escaping () -> Void,
        openStarsIntro: @escaping () -> Void,
        sendGift: @escaping (EnginePeer.Id) -> Void,
        openMyGifts: @escaping () -> Void,
        transferGift: @escaping () -> Void,
        showAttributeInfo: @escaping (Any) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.openPeer = openPeer
        self.updateSavedToProfile = updateSavedToProfile
        self.convertToStars = convertToStars
        self.openStarsIntro = openStarsIntro
        self.sendGift = sendGift
        self.openMyGifts = openMyGifts
        self.transferGift = transferGift
        self.showAttributeInfo = showAttributeInfo
    }
    
    static func ==(lhs: GiftViewSheetComponent, rhs: GiftViewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(GiftViewSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        cancel: { animate in
                            if animate {
                                if let controller = controller() as? GiftViewScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { [weak controller] _ in
                                        controller?.dismiss(completion: nil)
                                    })
                                }
                            } else if let controller = controller() {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        },
                        openPeer: context.component.openPeer,
                        updateSavedToProfile: context.component.updateSavedToProfile,
                        convertToStars: context.component.convertToStars,
                        openStarsIntro: context.component.openStarsIntro,
                        sendGift: context.component.sendGift,
                        openMyGifts: context.component.openMyGifts,
                        transferGift: context.component.transferGift,
                        showAttributeInfo: context.component.showAttributeInfo,
                        getController: controller
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        if let controller = controller() as? GiftViewScreen {
                            controller.dismissAllTooltips()
                        }
                    }
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
                                if let controller = controller() as? GiftViewScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftViewScreen {
                                    controller.dismissAllTooltips()
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
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public class GiftViewScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case message(EngineMessage)
        case profileGift(EnginePeer.Id, ProfileGiftsContext.State.StarGift)
        case soldOutGift(StarGift.Gift)
        
        var arguments: (peerId: EnginePeer.Id, fromPeerId: EnginePeer.Id?, fromPeerName: String?, messageId: EngineMessage.Id?, incoming: Bool, gift: StarGift, date: Int32, convertStars: Int64?, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, savedToProfile: Bool, converted: Bool)? {
            switch self {
            case let .message(message):
                if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .starGift(gift, convertStars, text, entities, nameHidden, savedToProfile, converted, _, _) = action.action {
                    return (message.id.peerId, message.author?.id, message.author?.compactDisplayTitle, message.id, message.flags.contains(.Incoming), gift, message.timestamp, convertStars, text, entities, nameHidden, savedToProfile, converted)
                }
            case let .profileGift(peerId, gift):
                return (peerId, gift.fromPeer?.id, gift.fromPeer?.compactDisplayTitle, gift.messageId, false, gift.gift, gift.date, gift.convertStars, gift.text, gift.entities, gift.nameHidden, gift.savedToProfile, false)
            case .soldOutGift:
                return nil
            }
            return nil
        }
    }
    
    private let context: AccountContext
    public var disposed: () -> Void = {}
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        forceDark: Bool = false,
        updateSavedToProfile: ((Bool) -> Void)? = nil,
        convertToStars: (() -> Void)? = nil
    ) {
        self.context = context
        
        var openPeerImpl: ((EnginePeer) -> Void)?
        var updateSavedToProfileImpl: ((Bool) -> Void)?
        var convertToStarsImpl: (() -> Void)?
        var openStarsIntroImpl: (() -> Void)?
        var sendGiftImpl: ((EnginePeer.Id) -> Void)?
        var openMyGiftsImpl: (() -> Void)?
        var transferGiftImpl: (() -> Void)?
        var showAttributeInfoImpl: ((Any) -> Void)?
        
        super.init(
            context: context,
            component: GiftViewSheetComponent(
                context: context,
                subject: subject,
                openPeer: { peerId in
                    openPeerImpl?(peerId)
                },
                updateSavedToProfile: { added in
                    updateSavedToProfileImpl?(added)
                },
                convertToStars: {
                    convertToStarsImpl?()
                },
                openStarsIntro: {
                    openStarsIntroImpl?()
                },
                sendGift: { peerId in
                    sendGiftImpl?(peerId)
                },
                openMyGifts: {
                    openMyGiftsImpl?()
                },
                transferGift: {
                    transferGiftImpl?()
                },
                showAttributeInfo: { tag in
                    showAttributeInfoImpl?(tag)
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
        
        openPeerImpl = { [weak self] peer in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            self.dismissAllTooltips()
            
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)
            )
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer else {
                    return
                }
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), subject: nil, botStart: nil, updateTextInputState: nil, keepStack: .always, useExisting: true, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: nil, animated: true))
            })
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        updateSavedToProfileImpl = { [weak self] added in
            guard let self, let arguments = subject.arguments, let messageId = arguments.messageId else {
                return
            }
            if let updateSavedToProfile {
                updateSavedToProfile(added)
            } else {
                let _ = (context.engine.payments.updateStarGiftAddedToProfile(messageId: messageId, added: added)
                |> deliverOnMainQueue).startStandalone()
            }
            
            self.dismissAnimated()
            
            let text = added ? presentationData.strings.Gift_Displayed_NewText : presentationData.strings.Gift_Hidden_NewText
            if let navigationController = self.navigationController as? NavigationController {
                Queue.mainQueue().after(0.5) {
                    if let lastController = navigationController.viewControllers.last as? ViewController, case let .generic(gift) = arguments.gift {
                        let resultController = UndoOverlayController(
                            presentationData: presentationData,
                            content: .sticker(context: context, file: gift.file, loop: false, title: nil, text: text, undoText: updateSavedToProfile == nil ? presentationData.strings.Gift_Displayed_View : nil, customAction: nil),
                            elevatedLayout: lastController is ChatController,
                            action: { [weak navigationController] action in
                                if case .undo = action, let navigationController {
                                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                                    |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                        guard let peer, let navigationController else {
                                            return
                                        }
                                        if let controller = context.sharedContext.makePeerInfoController(
                                            context: context,
                                            updatedPresentationData: nil,
                                            peer: peer._asPeer(),
                                            mode: .myProfileGifts,
                                            avatarInitiallyExpanded: false,
                                            fromChat: false,
                                            requestsContext: nil
                                        ) {
                                            navigationController.pushViewController(controller, animated: true)
                                        }
                                    })
                                }
                                return true
                            }
                        )
                        lastController.present(resultController, in: .window(.root))
                    }
                }
            }
        }
        
        convertToStarsImpl = { [weak self] in
            guard let self, let arguments = subject.arguments, let messageId = arguments.messageId, let fromPeerName = arguments.fromPeerName, let convertStars = arguments.convertStars, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            
            let configuration = GiftConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            let starsConvertMaxDate = arguments.date + configuration.convertToStarsPeriod
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            if currentTime > starsConvertMaxDate {
                let days: Int32 = Int32(ceil(Float(configuration.convertToStarsPeriod) / 86400.0))
                let controller = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Convert_Title,
                    text: presentationData.strings.Gift_Convert_Period_Unavailable_Text(presentationData.strings.Gift_Convert_Period_Unavailable_Days(days)).string,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ],
                    parseMarkdown: true
                )
                self.present(controller, in: .window(.root))
            } else {
                let delta = starsConvertMaxDate - currentTime
                let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                
                let text = presentationData.strings.Gift_Convert_Period_Text(fromPeerName, presentationData.strings.Gift_Convert_Period_Stars(Int32(convertStars)), presentationData.strings.Gift_Convert_Period_Days(days)).string
                let controller = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Convert_Title,
                    text: text,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_Convert_Convert, action: { [weak self, weak navigationController] in
                            if let convertToStars {
                                convertToStars()
                            } else {
                                let _ = (context.engine.payments.convertStarGift(messageId: messageId)
                                         |> deliverOnMainQueue).startStandalone()
                            }
                            self?.dismissAnimated()
                            
                            if let navigationController {
                                Queue.mainQueue().after(0.5) {
                                    if let starsContext = context.starsContext {
                                        navigationController.pushViewController(context.sharedContext.makeStarsTransactionsScreen(context: context, starsContext: starsContext), animated: true)
                                    }
                                    
                                    if let lastController = navigationController.viewControllers.last as? ViewController {
                                        let resultController = UndoOverlayController(
                                            presentationData: presentationData,
                                            content: .universal(
                                                animation: "StarsBuy",
                                                scale: 0.066,
                                                colors: [:],
                                                title: presentationData.strings.Gift_Convert_Success_Title,
                                                text: presentationData.strings.Gift_Convert_Success_Text(presentationData.strings.Gift_Convert_Success_Text_Stars(Int32(convertStars))).string,
                                                customUndoText: nil,
                                                timeout: nil
                                            ),
                                            elevatedLayout: lastController is ChatController,
                                            action: { _ in return true}
                                        )
                                        lastController.present(resultController, in: .window(.root))
                                    }
                                }
                            }
                        })
                    ],
                    parseMarkdown: true
                )
                self.present(controller, in: .window(.root))
            }
        }
        openStarsIntroImpl = { [weak self] in
            guard let self else {
                return
            }
            let introController = context.sharedContext.makeStarsIntroScreen(context: context)
            self.push(introController)
        }
        sendGiftImpl = { [weak self] peerId in
            guard let self else {
                return
            }
            let _ = (context.engine.payments.premiumGiftCodeOptions(peerId: nil, onlyCached: true)
            |> filter { !$0.isEmpty }
            |> deliverOnMainQueue).start(next: { giftOptions in
                let premiumOptions = giftOptions.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                let controller = context.sharedContext.makeGiftOptionsController(context: context, peerId: peerId, premiumOptions: premiumOptions, hasBirthday: false)
                self.push(controller)
            })
        }
        openMyGiftsImpl = { [weak self] in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                guard let peer, let navigationController else {
                    return
                }
                if let controller = context.sharedContext.makePeerInfoController(
                    context: context,
                    updatedPresentationData: nil,
                    peer: peer._asPeer(),
                    mode: .myProfileGifts,
                    avatarInitiallyExpanded: false,
                    fromChat: false,
                    requestsContext: nil
                ) {
                    navigationController.pushViewController(controller, animated: true)
                }
            })
        }
        
        transferGiftImpl = { [weak self] in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            let _ = (context.account.stateManager.contactBirthdays
            |> take(1)
            |> deliverOnMainQueue).start(next: { birthdays in
                let controller = context.sharedContext.makePremiumGiftController(context: context, source: .settings(birthdays), transfer: true, completion: nil)
                navigationController.pushViewController(controller)
            })
        }
        
        showAttributeInfoImpl = { [weak self] tag in
            guard let self else {
                return
            }
            guard let sourceView = self.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: self.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 12.0), size: CGSize())
            let controller = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: presentationData.strings.Gift_Unique_AttributeDescription("5%").string), location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .ignore
            })
            self.present(controller, in: .current)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    public func dismissAnimated() {
        self.dismissAllTooltips()

        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
    
    fileprivate func dismissAllTooltips() {
//        self.window?.forEachController({ controller in
//            if let controller = controller as? UndoOverlayController {
//                controller.dismiss()
//            }
//        })
//        self.forEachController({ controller in
//            if let controller = controller as? UndoOverlayController {
//                controller.dismiss()
//            }
//            return true
//        })
    }
}

private final class TableComponent: CombinedComponent {
    class Item: Equatable {
        public let id: AnyHashable
        public let title: String?
        public let component: AnyComponent<Empty>
        public let insets: UIEdgeInsets?

        public init<IdType: Hashable>(id: IdType, title: String?, component: AnyComponent<Empty>, insets: UIEdgeInsets? = nil) {
            self.id = AnyHashable(id)
            self.title = title
            self.component = component
            self.insets = insets
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.component != rhs.component {
                return false
            }
            if lhs.insets != rhs.insets {
                return false
            }
            return true
        }
    }
    
    private let theme: PresentationTheme
    private let items: [Item]

    public init(theme: PresentationTheme, items: [Item]) {
        self.theme = theme
        self.items = items
    }

    public static func ==(lhs: TableComponent, rhs: TableComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedBorderImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }

    public static var body: Body {
        let leftColumnBackground = Child(Rectangle.self)
        let verticalBorder = Child(Rectangle.self)
        let titleChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let valueChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let borderChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let outerBorder = Child(Image.self)

        return { context in
            let verticalPadding: CGFloat = 11.0
            let horizontalPadding: CGFloat = 12.0
            let borderWidth: CGFloat = 1.0
            
            let backgroundColor = context.component.theme.actionSheet.opaqueItemBackgroundColor
            let borderColor = backgroundColor.mixedWith(context.component.theme.list.itemBlocksSeparatorColor, alpha: 0.6)
            
            var leftColumnWidth: CGFloat = 0.0
            
            var updatedTitleChildren: [Int: _UpdatedChildComponent] = [:]
            var updatedValueChildren: [(_UpdatedChildComponent, UIEdgeInsets)] = []
            var updatedBorderChildren: [_UpdatedChildComponent] = []
            
            var i = 0
            for item in context.component.items {
                guard let title = item.title else {
                    i += 1
                    continue
                }
                let titleChild = titleChildren[item.id].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: title, font: Font.regular(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                    )),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                updatedTitleChildren[i] = titleChild
                
                if titleChild.size.width > leftColumnWidth {
                    leftColumnWidth = titleChild.size.width
                }
                i += 1
            }
            
            leftColumnWidth = max(100.0, leftColumnWidth + horizontalPadding * 2.0)
            let rightColumnWidth = context.availableSize.width - leftColumnWidth
            
            i = 0
            var rowHeights: [Int: CGFloat] = [:]
            var totalHeight: CGFloat = 0.0
            var innerTotalHeight: CGFloat = 0.0
            
            for item in context.component.items {
                let insets: UIEdgeInsets
                if let customInsets = item.insets {
                    insets = customInsets
                } else {
                    insets = UIEdgeInsets(top: 0.0, left: horizontalPadding, bottom: 0.0, right: horizontalPadding)
                }
                
                var titleHeight: CGFloat = 0.0
                if let titleChild = updatedTitleChildren[i] {
                    titleHeight = titleChild.size.height
                }
                
                let availableValueWidth: CGFloat
                if titleHeight > 0.0 {
                    availableValueWidth = rightColumnWidth
                } else {
                    availableValueWidth = context.availableSize.width
                }
                
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: availableValueWidth - insets.left - insets.right, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append((valueChild, insets))
               
                let rowHeight = max(40.0, max(titleHeight, valueChild.size.height) + verticalPadding * 2.0)
                rowHeights[i] = rowHeight
                totalHeight += rowHeight
                if titleHeight > 0.0 {
                    innerTotalHeight += rowHeight
                }
                
                if i < context.component.items.count - 1 {
                    let borderChild = borderChildren[item.id].update(
                        component: AnyComponent(Rectangle(color: borderColor)),
                        availableSize: CGSize(width: context.availableSize.width, height: borderWidth),
                        transition: context.transition
                    )
                    updatedBorderChildren.append(borderChild)
                }
                
                i += 1
            }
            
            let leftColumnBackground = leftColumnBackground.update(
                component: Rectangle(color: context.component.theme.list.itemInputField.backgroundColor),
                availableSize: CGSize(width: leftColumnWidth, height: innerTotalHeight),
                transition: context.transition
            )
            context.add(
                leftColumnBackground
                    .position(CGPoint(x: leftColumnWidth / 2.0, y: innerTotalHeight / 2.0))
            )
            
            let borderImage: UIImage
            if let (currentImage, theme) = context.state.cachedBorderImage, theme === context.component.theme {
                borderImage = currentImage
            } else {
                let borderRadius: CGFloat = 5.0
                borderImage = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.setFillColor(backgroundColor.cgColor)
                    context.fill(bounds)
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setBlendMode(.clear)
                    context.addPath(path)
                    context.fillPath()
                    
                    context.setBlendMode(.normal)
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(borderWidth)
                    context.addPath(path)
                    context.strokePath()
                })!.stretchableImage(withLeftCapWidth: 5, topCapHeight: 5)
                context.state.cachedBorderImage = (borderImage, context.component.theme)
            }
            
            let outerBorder = outerBorder.update(
                component: Image(image: borderImage),
                availableSize: CGSize(width: context.availableSize.width, height: totalHeight),
                transition: context.transition
            )
            context.add(outerBorder
                .position(CGPoint(x: context.availableSize.width / 2.0, y: totalHeight / 2.0))
            )
            
            let verticalBorder = verticalBorder.update(
                component: Rectangle(color: borderColor),
                availableSize: CGSize(width: borderWidth, height: innerTotalHeight),
                transition: context.transition
            )
            context.add(
                verticalBorder
                    .position(CGPoint(x: leftColumnWidth - borderWidth / 2.0, y: innerTotalHeight / 2.0))
            )
            
            i = 0
            var originY: CGFloat = 0.0
            for (valueChild, valueInsets) in updatedValueChildren {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let valueFrame: CGRect
                if let titleChild = updatedTitleChildren[i] {
                    let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                    context.add(titleChild
                        .position(titleFrame.center)
                    )
                    valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + valueInsets.left, y: originY + verticalPadding), size: valueChild.size)
                } else {
                    valueFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: valueChild.size)
                }
                
                context.add(valueChild
                    .position(valueFrame.center)
                )
                
                if i < updatedBorderChildren.count {
                    let borderChild = updatedBorderChildren[i]
                    context.add(borderChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + rowHeight - borderWidth / 2.0))
                    )
                }
                
                originY += rowHeight
                i += 1
            }
            
            return CGSize(width: context.availableSize.width, height: totalHeight)
        }
    }
}

private final class PeerCellComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: EnginePeer?) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
    }

    static func ==(lhs: PeerCellComponent, rhs: PeerCellComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        private let text = ComponentView<Empty>()
                
        private var component: PeerCellComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                                         
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                    
            let avatarSize = CGSize(width: 22.0, height: 22.0)
            let spacing: CGFloat = 6.0
            
            let peerName: String
            let avatarOverride: AvatarNodeImageOverride?
            if let peerValue = component.peer {
                peerName = peerValue.compactDisplayTitle
                avatarOverride = nil
            } else {
                peerName = component.strings.Gift_View_HiddenName
                avatarOverride = .anonymousSavedMessagesIcon(isColored: true)
            }
            
            let avatarNaturalSize = CGSize(width: 40.0, height: 40.0)
            self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, overrideImage: avatarOverride)
            self.avatarNode.bounds = CGRect(origin: .zero, size: avatarNaturalSize)
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: peerName, font: Font.regular(15.0), textColor: component.peer != nil ? component.theme.list.itemAccentColor : component.theme.list.itemPrimaryTextColor, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarSize.width - spacing, height: availableSize.height)
            )
            
            let size = CGSize(width: avatarSize.width + textSize.width + spacing, height: textSize.height)
            
            let avatarFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0)), size: avatarSize)
            self.avatarNode.frame = avatarFrame
            
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let textFrame = CGRect(origin: CGPoint(x: avatarSize.width + spacing, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
                transition.setFrame(view: view, frame: textFrame)
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

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
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

private final class ButtonContentComponent: Component {
    let context: AccountContext
    let text: String
    let color: UIColor
    
    public init(
        context: AccountContext,
        text: String,
        color: UIColor
    ) {
        self.context = context
        self.text = text
        self.color = color
    }

    public static func ==(lhs: ButtonContentComponent, rhs: ButtonContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: ButtonContentComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            self.backgroundLayer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ButtonContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
                        
            let attributedText = NSAttributedString(string: component.text, font: Font.regular(11.0), textColor: component.color)
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .white,
                        text: .plain(attributedText)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let padding: CGFloat = 6.0
            let size = CGSize(width: titleSize.width + padding * 2.0, height: 18.0)
                        
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let backgroundColor = component.color.withAlphaComponent(0.1)
            self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
            self.backgroundLayer.cornerRadius = size.height / 2.0
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private struct GiftConfiguration {
    static var defaultValue: GiftConfiguration {
        return GiftConfiguration(convertToStarsPeriod: 90 * 86400)
    }
    
    let convertToStarsPeriod: Int32
    
    fileprivate init(convertToStarsPeriod: Int32) {
        self.convertToStarsPeriod = convertToStarsPeriod
    }
    
    static func with(appConfiguration: AppConfiguration) -> GiftConfiguration {
        if let data = appConfiguration.data {
            var convertToStarsPeriod: Int32?
            if let value = data["stargifts_convert_period_max"] as? Double {
                convertToStarsPeriod = Int32(value)
            }
            return GiftConfiguration(convertToStarsPeriod: convertToStarsPeriod ?? GiftConfiguration.defaultValue.convertToStarsPeriod)
        } else {
            return .defaultValue
        }
    }
}

private final class ParagraphComponent: CombinedComponent {
    let title: String
    let titleColor: UIColor
    let text: String
    let textColor: UIColor
    let accentColor: UIColor
    let iconName: String
    let iconColor: UIColor
    let badge: String?
    let action: () -> Void
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        accentColor: UIColor,
        iconName: String,
        iconColor: UIColor,
        badge: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.accentColor = accentColor
        self.iconName = iconName
        self.iconColor = iconColor
        self.badge = badge
        self.action = action
    }
    
    static func ==(lhs: ParagraphComponent, rhs: ParagraphComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        let badgeBackground = Child(RoundedRectangle.self)
        let badgeText = Child(MultilineTextComponent.self)
        
        return { context in
            let component = context.component
            
            let leftInset: CGFloat = 32.0
            let rightInset: CGFloat = 24.0
            let textSideInset: CGFloat = leftInset + 8.0
            let spacing: CGFloat = 5.0
            
            let textTopInset: CGFloat = 9.0
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.semibold(15.0),
                        textColor: component.titleColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = component.textColor
            let accentColor = component.accentColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: accentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        component.action()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: context.availableSize.height),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.iconColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
         
            context.add(title
                .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            if let badge = component.badge {
                let badgeText = badgeText.update(
                    component: MultilineTextComponent(text: .plain(NSAttributedString(string: badge, font: Font.semibold(11.0), textColor: .white))),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                let badgeWidth = badgeText.size.width + 7.0
                let badgeBackground = badgeBackground.update(
                    component: RoundedRectangle(
                        color: component.accentColor,
                        cornerRadius: 5.0),
                    availableSize: CGSize(width: badgeWidth, height: 16.0),
                    transition: context.transition
                )
                
                context.add(badgeBackground
                    .position(CGPoint(x: textSideInset + title.size.width + badgeWidth / 2.0 + 5.0, y: textTopInset + title.size.height / 2.0))
                )
                
                context.add(badgeText
                    .position(CGPoint(x: textSideInset + title.size.width + badgeWidth / 2.0 + 5.0, y: textTopInset + title.size.height / 2.0))
                )
            }
            
            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(icon
                .position(CGPoint(x: 15.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 20.0)
        }
    }
}
