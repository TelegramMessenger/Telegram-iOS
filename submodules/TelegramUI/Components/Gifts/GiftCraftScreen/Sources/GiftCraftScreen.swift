import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AppBundle
import LocalMediaResources
import TelegramPresentationData
import TelegramStringFormatting
import ViewControllerComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import ButtonComponent
import PlainButtonComponent
import GiftItemComponent
import GiftAnimationComponent
import AccountContext
import GlassBarButtonComponent
import ResizableSheetComponent
import AnimatedTextComponent
import Markdown
import InfoParagraphComponent
import PresentationDataUtils
import GiftViewScreen
import PeerInfoCoverComponent
import LottieComponent
import TooltipUI
import TextFormat
import GlassBackgroundComponent
import ConfettiEffect
import TelegramNotices

private final class CraftGiftPageContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    class ExternalState {
        fileprivate(set) var giftsMap: [Int64: GiftItem]
        fileprivate(set) var starGiftsMap: [Int64: StarGift.Gift] = [:]
        fileprivate(set) var displayFailure = false
        
        fileprivate(set) var testFailOrSuccess: Bool?
        
        public init() {
            self.giftsMap = [:]
        }
    }
    
    enum DisplayState {
        case `default`
        case crafting
        case failure
    }
    
    let context: AccountContext
    let craftContext: CraftGiftsContext
    let resaleContext: () -> ResaleGiftsContext?
    let colors: (UIColor, UIColor, UIColor, UIColor, UIColor)
    let gift: StarGift.UniqueGift
    let selectedGiftIds: [Int32: Int64]
    let displayState: DisplayState
    let displayInfo: Bool
    let result: CraftTableComponent.Result?
    let screenSize: CGSize
    let externalState: ExternalState
    let starsTopUpOptionsPromise: Promise<[StarsTopUpOption]?>
    let selectGift: (Int32, GiftItem) -> Void
    let removeGift: (Int32) -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        craftContext: CraftGiftsContext,
        resaleContext: @escaping () -> ResaleGiftsContext?,
        colors: (UIColor, UIColor, UIColor, UIColor, UIColor),
        gift: StarGift.UniqueGift,
        selectedGiftIds: [Int32: Int64],
        displayState: DisplayState,
        displayInfo: Bool,
        result: CraftTableComponent.Result?,
        screenSize: CGSize,
        externalState: ExternalState,
        starsTopUpOptionsPromise: Promise<[StarsTopUpOption]?>,
        selectGift: @escaping (Int32, GiftItem) -> Void,
        removeGift: @escaping (Int32) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.craftContext = craftContext
        self.resaleContext = resaleContext
        self.colors = colors
        self.gift = gift
        self.selectedGiftIds = selectedGiftIds
        self.displayState = displayState
        self.displayInfo = displayInfo
        self.result = result
        self.screenSize = screenSize
        self.externalState = externalState
        self.starsTopUpOptionsPromise = starsTopUpOptionsPromise
        self.selectGift = selectGift
        self.removeGift = removeGift
        self.dismiss = dismiss
    }
    
    static func ==(lhs: CraftGiftPageContent, rhs: CraftGiftPageContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.colors.0 != rhs.colors.0 || lhs.colors.1 != rhs.colors.1 || lhs.colors.2 != rhs.colors.2 || lhs.colors.3 != rhs.colors.3 {
            return false
        }
        if lhs.selectedGiftIds != rhs.selectedGiftIds {
            return false
        }
        if lhs.displayState != rhs.displayState {
            return false
        }
        if lhs.displayInfo != rhs.displayInfo {
            return false
        }
        if lhs.screenSize != rhs.screenSize {
            return false
        }
        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let tableContainer = UIView()
        private let background = SimpleGradientLayer()
        private let overlay = SimpleGradientLayer()
        private let pattern = ComponentView<Empty>()
    
        private let title = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        
        private var craftTable = ComponentView<Empty>()
        
        private var attributeDials: [AnyHashable: ComponentView<Empty>] = [:]
        private var attributeDialTags: [AnyHashable: GenericComponentViewTag] = [:]
        private var variantsButton: ComponentView<Empty>?
        private var variantsButtonMeasure = ComponentView<Empty>()
        
        private let craftingTitle = ComponentView<Empty>()
        private let craftingSubtitle = ComponentView<Empty>()
        private let craftingDescription = ComponentView<Empty>()
        private let craftingProbability = ComponentView<Empty>()
        private var craftingProbabilityMeasure = ComponentView<Empty>()
        
        private let failureTitle = ComponentView<Empty>()
        private let failureDescription = ComponentView<Empty>()
        private var failedGifts: [AnyHashable: ComponentView<Empty>] = [:]
        
        private let infoContainer = UIView()
        private var infoBackground = SimpleLayer()
        private var infoHeader = ComponentView<Empty>()
        private let infoTitle = ComponentView<Empty>()
        private let infoDescription = ComponentView<Empty>()
        private var infoList = ComponentView<Empty>()
                                
        private var craftState: CraftGiftsContext.State?
        private var craftStateDisposable: Disposable?
        
        private let upgradePreviewDisposable = DisposableSet()
        private var upgradePreview: [StarGift.UniqueGift.Attribute]?
        private var starGiftsMap: [Int64: StarGift.Gift] = [:]
                
        private var availableGifts: [GiftItem] = []
        private var giftMap: [Int64: GiftItem] = [:]
        private var isCrafting = false
                
        private var component: CraftGiftPageContent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                                    
            self.background.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.background.cornerRadius = 40.0
            self.background.type = .axial
            self.background.startPoint = CGPoint(x: 0.5, y: 0.0)
            self.background.endPoint = CGPoint(x: 0.5, y: 1.0)
            self.layer.addSublayer(self.background)
            
            self.overlay.type = .radial
            self.overlay.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.overlay.endPoint = CGPoint(x: 0.0, y: 1.0)
            self.layer.addSublayer(self.overlay)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.craftStateDisposable?.dispose()
            self.upgradePreviewDisposable.dispose()
        }
        
        func showAttributeInfo(tag: Any, text: String) {
            guard let component = self.component, let controller = self.environment?.controller() as? GiftCraftScreen else {
                return
            }
            controller.dismissAllTooltips()
            
            guard let sourceView = controller.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: controller.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x + 1.0, y: absoluteLocation.y - 12.0), size: CGSize())
            let tooltipController = TooltipScreen(account: component.context.account, sharedContext: component.context.sharedContext, text: .markdown(text: text), balancedTextLayout: true, style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            })
            controller.present(tooltipController, in: .current)
        }
        
        func openUpgradeVariants() {
            guard let component = self.component, let controller = self.environment?.controller(), let gift = self.starGiftsMap[component.gift.giftId] else {
                return
            }
            
            let _ = (component.context.engine.payments.getStarGiftUpgradeAttributes(giftId: component.gift.giftId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller] attributes in
                guard let attributes else {
                    return
                }
                let variantsController = component.context.sharedContext.makeGiftUpgradeVariantsScreen(
                    context: component.context,
                    gift: .generic(gift),
                    crafted: true,
                    attributes: attributes,
                    selectedAttributes: nil,
                    focusedAttribute: nil
                )
                controller?.push(variantsController)
            })
        }
                
        func update(component: CraftGiftPageContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                let initialGiftItem = GiftItem(
                    gift: component.gift,
                    reference: .slug(slug: component.gift.slug)
                )
                self.availableGifts = [
                    initialGiftItem
                ]
                self.giftMap = [initialGiftItem.gift.id: initialGiftItem]
                component.externalState.giftsMap = self.giftMap
                
                self.craftStateDisposable = (component.craftContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self, let component = self.component else {
                        return
                    }
                    self.craftState = state
                    
                    var items: [GiftItem] = []
                    var map: [Int64: GiftItem] = self.giftMap
                    var foundInitial = false
                    for gift in state.gifts {
                        guard let reference = gift.reference, case let .unique(uniqueGift) = gift.gift else {
                            continue
                        }
                        let giftItem = GiftItem(
                            gift: uniqueGift,
                            reference: reference
                        )
                        if uniqueGift.id == component.gift.id {
                            items.insert(giftItem, at: 0)
                            foundInitial = true
                        } else {
                            items.append(giftItem)
                        }
                        map[uniqueGift.id] = giftItem
                    }
                    
                    if !foundInitial {
                        items.insert(initialGiftItem, at: 0)
                        map[initialGiftItem.gift.id] = initialGiftItem
                    }
                    self.availableGifts = items
                    self.giftMap = map
                    self.component?.externalState.giftsMap = self.giftMap
                    
                    self.state?.updated(transition: .spring(duration: 0.4))
                    
                    if state.gifts.count < 18, case .ready(true, _) = state.dataState {
                        component.craftContext.loadMore()
                    }
                })
                
                self.upgradePreviewDisposable.add((component.context.engine.payments.getStarGiftUpgradeAttributes(giftId: initialGiftItem.gift.giftId)
                |> deliverOnMainQueue).start(next: { [weak self] attributes in
                    guard let self, let attributes else {
                        return
                    }
                    var filteredAttributes: [StarGift.UniqueGift.Attribute] = []
                    for attribute in attributes {
                        if case let .model(_, file, _, crafted) = attribute {
                            if crafted {
                                filteredAttributes.append(attribute)
                                self.upgradePreviewDisposable.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                            }
                        }
                    }
                    self.upgradePreview = filteredAttributes

                    self.state?.updated()
                }))
                
                self.upgradePreviewDisposable.add((.single(nil) |> then(component.context.engine.payments.cachedStarGifts())
                |> deliverOnMainQueue).start(next: { [weak self] starGifts in
                    guard let self, let component = self.component, let starGifts else {
                        return
                    }
                    var starGiftsMap: [Int64: StarGift.Gift] = [:]
                    for gift in starGifts {
                        if case let .generic(gift) = gift {
                            starGiftsMap[gift.id] = gift
                        }
                    }
                    self.starGiftsMap = starGiftsMap
                    component.externalState.starGiftsMap = starGiftsMap
                    self.state?.updated()
                }))
            }
            
            transition.setGradientColors(layer: self.background, colors: [component.colors.0, component.colors.1])
            transition.setGradientColors(layer: self.overlay, colors: [component.colors.2, component.colors.2.withAlphaComponent(0.0)])
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            self.component = component
            self.state = state
            self.environment = environment
            
            let isCrafting = [.crafting, .failure].contains(component.displayState)
            
            var selectedGifts: [Int32: GiftItem] = [:]
            for (index, giftId) in component.selectedGiftIds {
                if let gift = self.giftMap[giftId] {
                    selectedGifts[index] = gift
                }
            }
                                    
            var craftContentHeight: CGFloat = 0.0
            var infoContentHeight: CGFloat = 0.0
                        
            let anvilPath = getAppBundle().url(forResource: "Anvil", withExtension: "tgs")?.path ?? ""
            let anvilFile = TelegramMediaFile(
                fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: -123456789),
                partialReference: nil,
                resource: BundleResource(name: "Anvil", path: anvilPath),
                previewRepresentations: [],
                videoThumbnails: [],
                immediateThumbnailData: nil,
                mimeType: "application/x-tgsticker",
                size: nil,
                attributes: [
                    .FileName(fileName: "sticker.tgs"),
                    .CustomEmoji(isPremium: false, isSingleColor: true, alt: "", packReference: .animatedEmojiAnimations)
                ],
                alternativeRepresentations: []
            )
            
            var backgroundTransition = transition
            let backgroundSize = self.pattern.update(
                transition: backgroundTransition,
                component: AnyComponent(PeerInfoCoverComponent(
                    context: component.context,
                    subject: .custom(.clear, .clear, UIColor(rgb: 0x000000), anvilFile.fileId.id),
                    files: [anvilFile.fileId.id: anvilFile],
                    isDark: false,
                    avatarCenter: CGPoint(x: availableSize.width / 2.0, y: 169.0),
                    avatarSize: CGSize(width: 130.0, height: 130.0),
                    avatarScale: 1.0,
                    defaultHeight: 300.0,
                    gradientOnTop: true,
                    avatarTransitionFraction: 0.0,
                    patternTransitionFraction: 0.0,
                    patternIconScale: 1.5
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 169.0 * 2.0)
            )
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: isCrafting && !"".isEmpty ? floor((component.screenSize.height - backgroundSize.height) / 2.0) : 0.0), size: backgroundSize)
            if let backgroundView = self.pattern.view {
                if backgroundView.layer.superlayer == nil {
                    backgroundTransition = .immediate
                    backgroundView.clipsToBounds = true
                    backgroundView.isUserInteractionEnabled = false
                    self.layer.insertSublayer(backgroundView.layer, above: self.overlay)
                }
                backgroundTransition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
                                    
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_Title, font: Font.semibold(17.0), textColor: .white)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5), y: 16.0 + 22.0 - titleSize.height * 0.5), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
                transition.setAlpha(view: titleView, alpha: 1.0)
            }
            
            let giftTitle = "\(component.gift.title) #\(formatCollectibleNumber(component.gift.number, dateTimeFormat: environment.dateTimeFormat))"
            
            let descriptionFont = Font.regular(13.0)
            let descriptionBoldFont = Font.semibold(13.0)
            let descriptionColor = UIColor.white
            let rawDescriptionString = environment.strings.Gift_Craft_Description(giftTitle).string
            let descriptionString = parseMarkdownIntoAttributedString(rawDescriptionString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), bold: MarkdownAttributeSet(font: descriptionBoldFont, textColor: descriptionColor), link: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), linkAttribute: { _ in return nil })).mutableCopy() as! NSMutableAttributedString
            
            if let gift = self.starGiftsMap[component.gift.giftId] {
                let range = (descriptionString.string as NSString).range(of: "$")
                if range.location != NSNotFound {
                    descriptionString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: gift.file.fileId.id, file: gift.file, custom: nil, enableAnimation: false), range: range)
                }
            }
            
            let descriptionTextSize = self.descriptionText.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .white.withAlphaComponent(0.3),
                        text: .plain(descriptionString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {
                },
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            craftContentHeight += 291.0
            
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - descriptionTextSize.width) * 0.5), y: craftContentHeight), size: descriptionTextSize)
            if let descriptionTextView = self.descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.addSubview(descriptionTextView)
                }
                transition.setFrame(view: descriptionTextView, frame: descriptionTextFrame)
                transition.setAlpha(view: descriptionTextView, alpha: isCrafting ? 0.0 : 1.0)
                transition.setBlur(layer: descriptionTextView.layer, radius: isCrafting ? 10.0 : 0.0)
            }
            craftContentHeight += descriptionTextSize.height
            craftContentHeight += 16.0
            
            var attributes: [ResaleGiftsContext.Attribute: StarGift.UniqueGift.Attribute] = [:]
            var backdropAttributeCount: [ResaleGiftsContext.Attribute: (Int32, Int)] = [:]
            var patternAttributeCount: [ResaleGiftsContext.Attribute: (Int32, Int)] = [:]
            for (index, gift) in selectedGifts {
                for attribute in gift.gift.attributes {
                    switch attribute {
                    case let .backdrop(_, id, _, _, _, _, _):
                        let attributeId: ResaleGiftsContext.Attribute = .backdrop(id)
                        attributes[attributeId] = attribute
                        if let (minPosition, count) = backdropAttributeCount[attributeId] {
                            backdropAttributeCount[attributeId] = (min(index, minPosition), count + 1)
                        } else {
                            backdropAttributeCount[attributeId] = (index, 1)
                        }
                    case let .pattern(_, file, _):
                        let attributeId: ResaleGiftsContext.Attribute = .pattern(file.fileId.id)
                        attributes[attributeId] = attribute
                        if let (minPosition, count) = patternAttributeCount[attributeId] {
                            patternAttributeCount[attributeId] = (min(index, minPosition), count + 1)
                        } else {
                            patternAttributeCount[attributeId] = (index, 1)
                        }
                    default:
                        break
                    }
                }
            }
            var attributesCount: [ResaleGiftsContext.Attribute: (Int32, Int)] = [:]
            for (attributeId, value) in backdropAttributeCount {
                attributesCount[attributeId] = value
            }
            for (attributeId, value) in patternAttributeCount {
                attributesCount[attributeId] = value
            }
            
            var backdropAttributes: [(ResaleGiftsContext.Attribute, Int)] = []
            for (attributeId, count) in backdropAttributeCount {
                backdropAttributes.append((attributeId, count.1))
            }
            backdropAttributes = backdropAttributes.sorted(by: { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                } else {
                    return attributesCount[lhs.0]!.0 < attributesCount[rhs.0]!.0
                }
            })
            var patternAttributes: [(ResaleGiftsContext.Attribute, Int)] = []
            for (attributeId, count) in patternAttributeCount {
                patternAttributes.append((attributeId, count.1))
            }
            patternAttributes = patternAttributes.sorted(by: { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                } else {
                    return attributesCount[lhs.0]!.0 < attributesCount[rhs.0]!.0
                }
            })
            
            var combinedAttributes: [ResaleGiftsContext.Attribute] = []
            for (attributeId, _) in backdropAttributes {
                combinedAttributes.append(attributeId)
            }
            for (attributeId, _) in patternAttributes {
                combinedAttributes.append(attributeId)
            }
            
            let appConfiguration = component.context.currentAppConfiguration.with { $0 }
            let giftCraftConfiguration = GiftCraftConfiguration.with(appConfiguration: appConfiguration)
            
            var firstRowCount = 0
            var secondRowCount = 0
            switch combinedAttributes.count {
            case 0, 1, 2, 3, 4:
                firstRowCount = combinedAttributes.count
            case 5:
                firstRowCount = 2
                secondRowCount = 3
            case 6:
                firstRowCount = 3
                secondRowCount = 3
            case 7:
                firstRowCount = 3
                secondRowCount = 4
            case 8:
                firstRowCount = 4
                secondRowCount = 4
            default:
                break
            }
            
            let attributeDialSpacing: CGFloat = 18.0
            let attributeDialSize = CGSize(width: 48.0, height: 48.0)
            
            let attributeFirstRowTotalWidth = CGFloat(firstRowCount) * attributeDialSize.width + CGFloat(firstRowCount - 1) * attributeDialSpacing
            let attributeSecondRowTotalWidth = CGFloat(secondRowCount) * attributeDialSize.width + CGFloat(secondRowCount - 1) * attributeDialSpacing
            var attributeDialFrame: CGRect = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - attributeFirstRowTotalWidth) / 2.0), y: craftContentHeight), size: attributeDialSize)
            
            craftContentHeight += attributeDialSize.height
            craftContentHeight += 39.0
            
            var validIds: [AnyHashable] = []
            var attributeDialIndex = 0
            for attribute in combinedAttributes {
                let itemId = AnyHashable(attribute)
                validIds.append(itemId)
                
                var itemTransition = transition
                let visibleItem: ComponentView<Empty>
                if let current = self.attributeDials[itemId] {
                    visibleItem = current
                } else {
                    visibleItem = ComponentView()
                    self.attributeDials[itemId] = visibleItem
                    itemTransition = .immediate
                }
                
                let tag: GenericComponentViewTag
                if let current = self.attributeDialTags[itemId] {
                    tag = current
                } else {
                    tag = GenericComponentViewTag()
                    self.attributeDialTags[itemId] = tag
                }
                                
                let attributeCount = attributesCount[attribute]?.1 ?? 0
                let permille = Int(giftCraftConfiguration.craftAttributePermilles[selectedGifts.count - 1][attributeCount - 1])
                
                let dialContent: AnyComponentWithIdentity<Empty>
                var dialContentSize: CGSize?
                let tooltipText: String
                switch attribute {
                case .backdrop:
                    guard case let .backdrop(name, _, innerColor, outerColor, _, _, _) = attributes[attribute] else {
                        continue
                    }
                    dialContent = AnyComponentWithIdentity(
                        id: "color",
                        component: AnyComponent(
                            ColorSwatchComponent(
                                innerColor: UIColor(rgb: UInt32(bitPattern: innerColor)),
                                outerColor: UIColor(rgb: UInt32(bitPattern: outerColor))
                            )
                        )
                    )
                    tooltipText = environment.strings.Gift_Craft_BackdropTooltip("\(permille / 10)", name).string
                case .pattern:
                    guard case let .pattern(name, file, _) = attributes[attribute] else {
                        continue
                    }
                    dialContent = AnyComponentWithIdentity(
                        id: "symbol",
                        component: AnyComponent(
                            LottieComponent(
                                content: LottieComponent.ResourceContent(
                                    context: component.context,
                                    file: file,
                                    attemptSynchronously: true,
                                    providesPlaceholder: true
                                ),
                                color: .white,
                                size: CGSize(width: 32.0, height: 32.0)
                            )
                        )
                    )
                    dialContentSize = CGSize(width: 30.0, height: 30.0)
                    tooltipText = environment.strings.Gift_Craft_SymbolTooltip("\(permille / 10)", name).string
                default:
                    continue
                }
                
                let _ = visibleItem.update(
                    transition: itemTransition,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(
                                DialIndicatorComponent(
                                    content: dialContent,
                                    backgroundColor: .white.withAlphaComponent(0.1),
                                    foregroundColor: .white,
                                    diameter: 48.0,
                                    contentSize: dialContentSize,
                                    lineWidth: 4.0,
                                    fontSize: 10.0,
                                    progress: CGFloat(permille) / 10.0 / 100.0,
                                    value: permille / 10,
                                    suffix: "%"
                                )
                            ),
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                HapticFeedback().impact(.light)
                                
                            #if DEBUG
                                switch attribute {
                                case .backdrop:
                                    self.component?.externalState.testFailOrSuccess = true
                                case .pattern:
                                    self.component?.externalState.testFailOrSuccess = false
                                default:
                                    break
                                }
                            #endif
                                self.showAttributeInfo(tag: tag, text: tooltipText)
                            },
                            tag: tag
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                if let itemView = visibleItem.view {
                    if itemView.superview == nil {
                        self.addSubview(itemView)
                        
                        if !transition.animation.isImmediate {
                            itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    itemTransition.setFrame(view: itemView, frame: attributeDialFrame)
                    transition.setAlpha(view: itemView, alpha: isCrafting ? 0.0 : 1.0)
                    transition.setBlur(layer: itemView.layer, radius: isCrafting ? 10.0 : 0.0)
                }
                
                attributeDialFrame.origin.x += attributeDialSize.width + attributeDialSpacing
                attributeDialIndex += 1
                
                if attributeDialIndex == firstRowCount {
                    attributeDialFrame.origin.x = floorToScreenPixels((availableSize.width - attributeSecondRowTotalWidth) / 2.0)
                    attributeDialFrame.origin.y += 66.0
                }
            }
                        
            var removeIds: [AnyHashable] = []
            for (id, item) in self.attributeDials {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeIds {
                self.attributeDials.removeValue(forKey: id)
            }
            
            
            if secondRowCount == 0, case .default = component.displayState {
                let variantsString = environment.strings.Gift_Craft_ViewVariants
                let variantsButtonMeasure = self.variantsButtonMeasure.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: variantsString, font: Font.semibold(13.0), textColor: .clear)))),
                    environment: {},
                    containerSize: availableSize
                )
                
                let variantsButton: ComponentView<Empty>
                if let current = self.variantsButton {
                    variantsButton = current
                } else {
                    variantsButton = ComponentView<Empty>()
                    self.variantsButton = variantsButton
                }
                
                let variantsButtonSize = CGSize(width: variantsButtonMeasure.width + 87.0, height: 24.0)
                if let gift = self.starGiftsMap[component.gift.giftId] {
                    var variant1: GiftItemComponent.Subject = .starGift(gift: gift, price: "")
                    var variant2: GiftItemComponent.Subject = .starGift(gift: gift, price: "")
                    var variant3: GiftItemComponent.Subject = .starGift(gift: gift, price: "")
                    
                    if let upgradePreview = self.upgradePreview {
                        var i = 0
                        for attribute in upgradePreview {
                            if case .model = attribute {
                                switch i {
                                case 0:
                                    variant1 = .preview(attributes: [attribute], rarity: nil)
                                case 1:
                                    variant2 = .preview(attributes: [attribute], rarity: nil)
                                case 2:
                                    variant3 = .preview(attributes: [attribute], rarity: nil)
                                default:
                                    break
                                }
                                i += 1
                            }
                        }
                    }
                    
                    let _ = variantsButton.update(
                        transition: transition,
                        component: AnyComponent(
                            GlassBarButtonComponent(
                                size: variantsButtonSize,
                                backgroundColor: component.colors.3,
                                isDark: true,
                                state: .tintedGlass,
                                component: AnyComponentWithIdentity(id: "content", component: AnyComponent(HStack([
                                    AnyComponentWithIdentity(id: "icon1", component: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: environment.theme,
                                            strings: environment.strings,
                                            peer: nil,
                                            subject: variant1,
                                            isPlaceholder: false,
                                            mode: .tableIcon
                                        )
                                    )),
                                    AnyComponentWithIdentity(id: "icon2", component: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: environment.theme,
                                            strings: environment.strings,
                                            peer: nil,
                                            subject: variant2,
                                            isPlaceholder: false,
                                            mode: .tableIcon
                                        )
                                    )),
                                    AnyComponentWithIdentity(id: "icon3", component: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: environment.theme,
                                            strings: environment.strings,
                                            peer: nil,
                                            subject: variant3,
                                            isPlaceholder: false,
                                            mode: .tableIcon
                                        )
                                    )),
                                    AnyComponentWithIdentity(id: "text", component: AnyComponent(
                                        MultilineTextComponent(text: .plain(NSAttributedString(string: variantsString, font: Font.semibold(13.0), textColor: .white)))
                                    )),
                                    AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
                                        BundleIconComponent(name: "Item List/InlineTextRightArrow", tintColor: .white)
                                    ))
                                ], spacing: 3.0))),
                                action: { [weak self] _ in
                                    HapticFeedback().impact(.light)
                                    
                                    self?.openUpgradeVariants()
                                }
                            )
                        ),
                        environment: {},
                        containerSize: availableSize
                    )
                }
                let variantsButtonFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - variantsButtonSize.width) / 2.0), y: craftContentHeight), size: variantsButtonSize)
                var varitantsButtonTransition = transition
                if let variantsButtonView = variantsButton.view {
                    if variantsButtonView.superview == nil {
                        varitantsButtonTransition = .immediate
                        if let descriptionView = self.descriptionText.view {
                            self.insertSubview(variantsButtonView, aboveSubview: descriptionView)
                        } else {
                            self.addSubview(variantsButtonView)
                        }
                    }
                    varitantsButtonTransition.setFrame(view: variantsButtonView, frame: variantsButtonFrame)
                }
            } else if let variantsButton = self.variantsButton {
                self.variantsButton = nil
                if let variantsButtonView = variantsButton.view {
                    transition.setBlur(layer: variantsButtonView.layer, radius: isCrafting ? 10.0 : 0.0)
                    variantsButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                        variantsButtonView.removeFromSuperview()
                    })
                }
            }
            
            craftContentHeight += 145.0
            
            let permilleValue = selectedGifts.reduce(0, { $0 + Int($1.value.gift.craftChancePermille ?? 0) })
            if component.displayState == .crafting {
                var craftingOriginY = craftContentHeight * 0.5 - 16.0
                let offset: CGFloat = 0.0
                
                let craftingTitleSize = self.craftingTitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_Crafting_Title, font: Font.bold(20.0), textColor: .white)))
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let craftingTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - craftingTitleSize.width) * 0.5), y: craftingOriginY), size: craftingTitleSize)
                if let craftingTitleView = self.craftingTitle.view {
                    if craftingTitleView.superview == nil {
                        transition.animateAlpha(view: craftingTitleView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: craftingTitleView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: craftingTitleView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(craftingTitleView)
                    }
                    craftingTitleView.frame = craftingTitleFrame
                }
                craftingOriginY += craftingTitleSize.height
                craftingOriginY += 6.0
                
                let craftingSubtitleSize = self.craftingSubtitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: giftTitle, font: Font.semibold(13.0), textColor: .white.withAlphaComponent(0.5))))
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let craftingSubtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - craftingSubtitleSize.width) * 0.5), y: craftingOriginY), size: craftingSubtitleSize)
                if let craftingSubtitleView = self.craftingSubtitle.view {
                    if craftingSubtitleView.superview == nil {
                        transition.animateAlpha(view: craftingSubtitleView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: craftingSubtitleView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: craftingSubtitleView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(craftingSubtitleView)
                    }
                    craftingSubtitleView.frame = craftingSubtitleFrame
                }
                craftingOriginY += craftingSubtitleSize.height
                craftingOriginY += 21.0
                
                let descriptionFont = Font.regular(13.0)
                let descriptionBoldFont = Font.semibold(13.0)
                let descriptionColor = UIColor.white.withAlphaComponent(0.5)
                let rawDescriptionString = environment.strings.Gift_Craft_Crafting_Description
                let descriptionString = parseMarkdownIntoAttributedString(rawDescriptionString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), bold: MarkdownAttributeSet(font: descriptionBoldFont, textColor: descriptionColor), link: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), linkAttribute: { _ in return nil })).mutableCopy() as! NSMutableAttributedString
                                
                let craftingDescriptionSize = self.craftingDescription.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(descriptionString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let craftingDescriptionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - craftingDescriptionSize.width) * 0.5), y: craftingOriginY), size: craftingDescriptionSize)
                if let craftingDescriptionView = self.craftingDescription.view {
                    if craftingDescriptionView.superview == nil {
                        transition.animateAlpha(view: craftingDescriptionView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: craftingDescriptionView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: craftingDescriptionView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(craftingDescriptionView)
                    }
                    craftingDescriptionView.frame = craftingDescriptionFrame
                }
                craftingOriginY += craftingDescriptionSize.height
                craftingOriginY += 24.0
                
                let craftingProbabilityString = environment.strings.Gift_Craft_Crafting_SuccessChance("\(permilleValue / 10)").string
                let craftingProbabilityMeasure = self.craftingProbabilityMeasure.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: craftingProbabilityString, font: Font.semibold(13.0), textColor: .clear)))),
                    environment: {},
                    containerSize: availableSize
                )
                
                let craftingProbabilitySize = CGSize(width: craftingProbabilityMeasure.width + 18.0, height: 24.0)
                let _ = self.craftingProbability.update(
                    transition: transition,
                    component: AnyComponent(
                        GlassBarButtonComponent(
                            size: craftingProbabilitySize,
                            backgroundColor: component.colors.3.mixedWith(component.colors.1, alpha: 0.3),
                            isDark: true,
                            state: .tintedGlass,
                            component:  AnyComponentWithIdentity(id: "text", component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: craftingProbabilityString, font: Font.semibold(13.0), textColor: .white)))
                            )),
                            action: nil
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let craftingProbabilityFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - craftingProbabilitySize.width) * 0.5), y: craftingOriginY), size: craftingProbabilitySize)
                if let craftingProbabilityView = self.craftingProbability.view {
                    if craftingProbabilityView.superview == nil {
                        transition.animateAlpha(view: craftingProbabilityView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: craftingProbabilityView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: craftingProbabilityView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(craftingProbabilityView)
                    }
                    craftingProbabilityView.frame = craftingProbabilityFrame
                }
            } else {
                if let craftingTitleView = self.craftingTitle.view {
                    transition.setAlpha(view: craftingTitleView, alpha: 0.0, completion: { _ in
                        craftingTitleView.removeFromSuperview()
                    })
                    transition.animateBlur(layer: craftingTitleView.layer, fromRadius: 0.0, toRadius: 10.0)
                }
                if let craftingSubtitleView = self.craftingSubtitle.view {
                    transition.setAlpha(view: craftingSubtitleView, alpha: 0.0, completion: { _ in
                        craftingSubtitleView.removeFromSuperview()
                    })
                    transition.animateBlur(layer: craftingSubtitleView.layer, fromRadius: 0.0, toRadius: 10.0)
                }
                if let craftingDescriptionView = self.craftingDescription.view {
                    transition.setAlpha(view: craftingDescriptionView, alpha: 0.0, completion: { _ in
                        craftingDescriptionView.removeFromSuperview()
                    })
                    transition.animateBlur(layer: craftingDescriptionView.layer, fromRadius: 0.0, toRadius: 10.0)
                }
                if let craftingProbabilityView = self.craftingProbability.view {
                    craftingProbabilityView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                        craftingProbabilityView.removeFromSuperview()
                    })
                    transition.animateBlur(layer: craftingProbabilityView.layer, fromRadius: 0.0, toRadius: 10.0)
                }
            }
            
            if component.displayState == .failure {
                var failureOriginY = craftContentHeight * 0.5 - 16.0
                let offset: CGFloat = 0.0
                
                let failureTitleSize = self.failureTitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_CraftingFailed_Title, font: Font.bold(20.0), textColor: UIColor(rgb: 0xff746d))))
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let failureTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - failureTitleSize.width) * 0.5), y: failureOriginY), size: failureTitleSize)
                if let failureTitleView = self.failureTitle.view {
                    if failureTitleView.superview == nil {
                        transition.animateAlpha(view: failureTitleView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: failureTitleView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: failureTitleView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(failureTitleView)
                    }
                    failureTitleView.frame = failureTitleFrame
                }
                failureOriginY += failureTitleSize.height
                failureOriginY += 17.0
                
                let descriptionFont = Font.regular(13.0)
                let descriptionBoldFont = Font.semibold(13.0)
                let descriptionColor = UIColor(rgb: 0xf7af8c)
                let rawDescriptionString = environment.strings.Gift_Craft_CraftingFailed_Text(Int32(component.selectedGiftIds.count))
                let descriptionString = parseMarkdownIntoAttributedString(rawDescriptionString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), bold: MarkdownAttributeSet(font: descriptionBoldFont, textColor: descriptionColor), link: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), linkAttribute: { _ in return nil })).mutableCopy() as! NSMutableAttributedString
                                
                let failureDescriptionSize = self.failureDescription.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(descriptionString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let failureDescriptionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - failureDescriptionSize.width) * 0.5), y: failureOriginY), size: failureDescriptionSize)
                if let failureDescriptionView = self.failureDescription.view {
                    if failureDescriptionView.superview == nil {
                        transition.animateAlpha(view: failureDescriptionView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: failureDescriptionView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: failureDescriptionView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(failureDescriptionView)
                    }
                    failureDescriptionView.frame = failureDescriptionFrame
                }
                failureOriginY += failureDescriptionSize.height
                failureOriginY += 34.0
                
                var indices: [Int] = []
                for index in component.selectedGiftIds.keys.sorted() {
                    indices.append(Int(index))
                }
                var lostGifts: [GiftItem] = []
                for index in indices {
                    if let giftId = component.selectedGiftIds[Int32(index)], let gift = self.giftMap[giftId] {
                       lostGifts.append(gift)
                    }
                }
                
                let itemSize = CGSize(width: 80.0, height: 80.0)
                let itemSpacing: CGFloat = 16.0
                var itemDelay: Double = 0.2
                
                let totalItemsWidth: CGFloat = itemSize.width * CGFloat(lostGifts.count) + itemSpacing * CGFloat(lostGifts.count - 1)
                var itemOriginX: CGFloat = floor((availableSize.width - totalItemsWidth) / 2.0)
                
                for gift in lostGifts {
                    let itemId = AnyHashable(gift.gift.id)
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.failedGifts[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        self.failedGifts[itemId] = visibleItem
                        itemTransition = .immediate
                    }
                    
                    let ribbonText = "#\(gift.gift.number)"
                    let ribbonColor: GiftItemComponent.Ribbon.Color = .custom(0xff645b, 0xff645b)
                    
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            GiftItemComponent(
                                context: component.context,
                                style: .glass,
                                theme: environment.theme,
                                strings: environment.strings,
                                peer: nil,
                                subject: .uniqueGift(gift: gift.gift, price: nil),
                                ribbon: GiftItemComponent.Ribbon(text: ribbonText, font: .monospaced, color: ribbonColor, outline: nil),
                                badge: nil,
                                resellPrice: nil,
                                isHidden: false,
                                isSelected: false,
                                isPinned: false,
                                isEditing: false,
                                mode: .grid,
                                action: nil,
                                contextAction: nil
                            )
                        ),
                        environment: {},
                        containerSize: itemSize
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: itemOriginX, y: failureOriginY), size: itemSize)
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.addSubview(itemView)
                            
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25, delay: itemDelay)
                                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: itemDelay)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                    itemOriginX += itemSize.width + itemSpacing
                    itemDelay += 0.07
                }
            }
            
            let tableSize = CGSize(width: availableSize.width, height: 320.0)
            let craftTableSize = self.craftTable.update(
                transition: transition,
                component: AnyComponent(
                    CraftTableComponent(
                        context: component.context,
                        gifts: selectedGifts,
                        buttonColor: component.colors.3,
                        isCrafting: isCrafting,
                        result: component.result,
                        select: { [weak self] index in
                            guard let self, let component = self.component, let environment = self.environment, let genericGift = self.starGiftsMap[component.gift.giftId], let resaleContext = component.resaleContext() else {
                                return
                            }
                            
                            HapticFeedback().impact(.light)
                            
                            let selectController = SelectCraftGiftScreen(
                                context: component.context,
                                craftContext: component.craftContext,
                                resaleContext: resaleContext,
                                gift: component.gift,
                                genericGift: genericGift,
                                selectedGiftIds: Set(component.selectedGiftIds.values),
                                starsTopUpOptions: component.starsTopUpOptionsPromise.get(),
                                selectGift: { [weak self] item in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    if self.giftMap[item.gift.id] == nil {
                                        self.giftMap[item.gift.id] = item
                                    }
                                    component.selectGift(index, item)
                                }
                            )
                            environment.controller()?.push(selectController)
                        },
                        remove: { [weak self] index in
                            guard let self else {
                                return
                            }
                            HapticFeedback().impact(.light)
                            
                            self.component?.removeGift(index)
                        },
                        willFinish: { [weak self] success in
                            guard let self, let component = self.component else {
                                return
                            }
                            if !success {
                                component.externalState.displayFailure = true
                            }
                            self.state?.updated(transition: .easeInOut(duration: 0.5))
                        },
                        finished: { [weak self] view in
                            guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() as? GiftCraftScreen else {
                                return
                            }
                            var references: [StarGiftReference] = []
                            for gift in selectedGifts.values {
                                references.append(gift.reference)
                            }
                            Queue.mainQueue().after(0.5) {
                                controller.profileGiftsContext?.removeStarGifts(references: references)
                            }
                            if let _ = view {
                                if case let .gift(gift) = component.result {
                                    let giftController = GiftViewScreen(context: component.context, subject: .profileGift(component.context.account.peerId, gift))
                                    if let navigationController = controller.navigationController {
                                        navigationController.pushViewController(giftController, animated: true)
                                        
                                        navigationController.view.addSubview(ConfettiView(frame: navigationController.view.bounds))
                                    }
                                    Queue.mainQueue().after(0.5) {
                                        controller.profileGiftsContext?.insertStarGifts(gifts: [gift])
                                    }
                                }
                                controller.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { _ in
                                    controller.dismiss()
                                })
                                
                                HapticFeedback().success()
                            } else {
                                Queue.mainQueue().after(0.35) {
                                    HapticFeedback().error()
                                }
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: tableSize.height)
            )
            let craftTableFrame = CGRect(origin: CGPoint(x: 0.0, y: isCrafting && !"".isEmpty ? floor((component.screenSize.height - craftTableSize.height) / 2.0) : 10.0), size: craftTableSize)
            if let craftTableView = self.craftTable.view {
                if craftTableView.superview == nil {
                    craftTableView.layer.cornerRadius = 40.0
                    craftTableView.clipsToBounds = true
                    craftTableView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    self.addSubview(craftTableView)
                }
                transition.setFrame(view: craftTableView, frame: craftTableFrame)
            }
            
            transition.setAlpha(view: self.infoContainer, alpha: component.displayInfo ? 1.0 : 0.0)
            
            let infoHeaderSize = self.infoHeader.update(
                transition: transition,
                component: AnyComponent(
                    GiftCompositionComponent(
                        context: component.context,
                        theme: environment.theme,
                        subject: .unique(nil, component.gift),
                        animationOffset: nil,
                        animationScale: nil,
                        displayAnimationStars: false,
                        animateScaleOnTransition: false,
                        externalState: nil,
                        requestUpdate: { _ in
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 260.0)
            )
            let infoHeaderFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - infoHeaderSize.width) * 0.5), y: 0.0), size: infoHeaderSize)
            if let infoHeaderView = self.infoHeader.view {
                if infoHeaderView.superview == nil {
                    self.infoContainer.layer.allowsGroupOpacity = true
                    self.addSubview(self.infoContainer)
                    
                    self.infoContainer.layer.addSublayer(self.infoBackground)
                    
                    infoHeaderView.layer.cornerRadius = 40.0
                    infoHeaderView.clipsToBounds = true
                    infoHeaderView.layer.allowsGroupOpacity = true
                    infoHeaderView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    self.infoContainer.addSubview(infoHeaderView)
                }
                transition.setFrame(view: infoHeaderView, frame: infoHeaderFrame)
                
                if self.subviews.last !== self.infoContainer {
                    self.bringSubviewToFront(self.infoContainer)
                }
            }
            infoContentHeight += infoHeaderSize.height
            infoContentHeight += 16.0
            
            let infoTitleSize = self.infoTitle.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_Info_Title, font: Font.bold(20.0), textColor: .white)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let infoTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - infoTitleSize.width) * 0.5), y: infoHeaderSize.height - 87.0), size: infoTitleSize)
            if let infoTitleView = self.infoTitle.view {
                if infoTitleView.superview == nil {
                    self.infoContainer.addSubview(infoTitleView)
                }
                transition.setFrame(view: infoTitleView, frame: infoTitleFrame)
            }
            
            let infoDescriptionTextSize = self.infoDescription.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: environment.strings.Gift_Craft_Info_Description,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(14.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6)),
                            bold: MarkdownAttributeSet(font: Font.semibold(14.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6)),
                            link: MarkdownAttributeSet(font: Font.regular(14.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6)),
                            linkAttribute: { _ in return nil }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let infoDescriptionTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - infoDescriptionTextSize.width) * 0.5), y: infoHeaderSize.height - 56.0), size: infoDescriptionTextSize)
            if let infoDescriptionTextView = self.infoDescription.view {
                if infoDescriptionTextView.superview == nil {
                    self.infoContainer.addSubview(infoDescriptionTextView)
                }
                transition.setFrame(view: infoDescriptionTextView, frame: infoDescriptionTextFrame)
            }
            
            
            self.infoBackground.backgroundColor = environment.theme.list.modalPlainBackgroundColor.cgColor
            
            let infoBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 80.0), size: CGSize(width: availableSize.width, height: 1000.0))
            transition.setFrame(layer: self.infoBackground, frame: infoBackgroundFrame)
            
            let titleColor = environment.theme.list.itemPrimaryTextColor
            let textColor = environment.theme.list.itemSecondaryTextColor
            let accentColor = environment.theme.list.itemAccentColor
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "paragraph1",
                    component: AnyComponent(InfoParagraphComponent(
                        title: environment.strings.Gift_Craft_Info_Paragraph1_Title,
                        titleColor: titleColor,
                        text: environment.strings.Gift_Craft_Info_Paragraph1_Text,
                        textColor: textColor,
                        accentColor: accentColor,
                        iconName: "Premium/Craft/Rare",
                        iconColor: environment.theme.list.itemAccentColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "paragraph2",
                    component: AnyComponent(InfoParagraphComponent(
                        title: environment.strings.Gift_Craft_Info_Paragraph2_Title,
                        titleColor: titleColor,
                        text: environment.strings.Gift_Craft_Info_Paragraph2_Text,
                        textColor: textColor,
                        accentColor: accentColor,
                        iconName: "Premium/Craft/Chance",
                        iconColor: accentColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "paragraph3",
                    component: AnyComponent(InfoParagraphComponent(
                        title: environment.strings.Gift_Craft_Info_Paragraph3_Title,
                        titleColor: titleColor,
                        text: environment.strings.Gift_Craft_Info_Paragraph3_Text,
                        textColor: textColor,
                        accentColor: accentColor,
                        iconName: "Premium/Craft/Result",
                        iconColor: accentColor
                    ))
                )
            )
            
            let infoListSize = self.infoList.update(
                transition: transition,
                component: AnyComponent(
                    List(items)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 64.0, height: 10000)
            )
            let infoListFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - infoListSize.width) / 2.0), y: infoContentHeight), size: infoListSize)
            if let infoListView = self.infoList.view {
                if infoListView.superview == nil {
                    self.infoContainer.addSubview(infoListView)
                }
                transition.setFrame(view: infoListView, frame: infoListFrame)
            }
        
            if component.displayInfo {
                infoContentHeight += infoListSize.height
                infoContentHeight += 95.0
            }
            transition.setFrame(view: self.infoContainer, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: infoContentHeight)))
                        
            transition.setFrame(layer: self.background, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: craftContentHeight)))
            transition.setFrame(layer: self.overlay, frame: CGRect(origin: CGPoint(x: 0.0, y: isCrafting && !"".isEmpty ? floor((component.screenSize.height - availableSize.width) / 2.0) : 169.0 - availableSize.width * 0.5), size: CGSize(width: availableSize.width, height: availableSize.width)))
            
            let effectiveContentHeight: CGFloat
            if component.displayInfo {
                effectiveContentHeight = infoContentHeight
            } else {
                effectiveContentHeight = craftContentHeight
            }
                        
            return CGSize(width: availableSize.width, height: effectiveContentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let craftContext: CraftGiftsContext
    let gift: StarGift.UniqueGift
    
    init(
        context: AccountContext,
        craftContext: CraftGiftsContext,
        gift: StarGift.UniqueGift
    ) {
        self.context = context
        self.craftContext = craftContext
        self.gift = gift
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let giftId: Int64
        
        var displayInfo = false
        var isCrafting = false
        var inProgress = false
        var displayFailure = false
        var result: CraftTableComponent.Result?
        var selectedGiftIds: [Int32: Int64] = [:]
        
        let starsTopUpOptionsPromise = Promise<[StarsTopUpOption]?>(nil)
                
        private var _resaleContext: ResaleGiftsContext?
        var resaleContext: ResaleGiftsContext {
            if let current = self._resaleContext {
                return current
            } else {
                let resaleContext = ResaleGiftsContext(account: self.context.account, giftId: self.giftId, forCrafting: true)
                self._resaleContext = resaleContext
                return resaleContext
            }
        }
        
        let preloadDisposable = DisposableSet()
        
        init(context: AccountContext, gift: StarGift.UniqueGift) {
            self.context = context
            self.giftId = gift.giftId
            self.selectedGiftIds[0] = gift.id
            
            super.init()
                        
            let _ = (ApplicationSpecificNotice.getGiftCraftingTips(accountManager: context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self] count in
                guard let self else {
                    return
                }
                if count < 1 {
                    self.displayInfo = true
                    self.updated()
                    
                    let _ = ApplicationSpecificNotice.incrementGiftCraftingTips(accountManager: context.sharedContext.accountManager).start()
                }
            })
            
            self.starsTopUpOptionsPromise.set(context.engine.payments.starsTopUpOptions() |> map(Optional.init))
        }
        
        deinit {
            self.preloadDisposable.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, gift: self.gift)
    }
    
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let externalState = CraftGiftPageContent.ExternalState()
        let playButtonAnimation = ActionSlot<Void>()
                
        return { context in
            let component = context.component
            let environment = context.environment[EnvironmentType.self]
            let state = context.state
            
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
            if externalState.displayFailure {
                state.displayFailure = true
                state.inProgress = false
            }
            
            let controller = environment.controller
            
            let craftContext = context.component.craftContext
            
            let dismiss: (Bool) -> Void = { animated in
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
            
            let theme = environment.theme
                        
            var colors: (UIColor, UIColor, UIColor, UIColor, UIColor) = (
                UIColor(rgb: 0x263245),
                UIColor(rgb: 0x232e3f),
                UIColor(rgb: 0x304059),
                UIColor(rgb: 0x425168),
                theme.list.itemCheckColors.fillColor
            )
            var permilleValue: Int32 = 0
            for id in state.selectedGiftIds.values {
                if let gift = externalState.giftsMap[id] {
                    permilleValue += gift.gift.craftChancePermille ?? 0
                }
            }
            if permilleValue >= 950 {
                colors.0 = UIColor(rgb: 0x1b3b3d)
                colors.1 = UIColor(rgb: 0x1a2f38)
                colors.2 = UIColor(rgb: 0x22464a)
                colors.3 = UIColor(rgb: 0x2d4e50)
                if !state.displayInfo {
                    colors.4 = UIColor(rgb: 0x33bf54)
                }
            }
            if state.displayFailure {
                colors.0 = UIColor(rgb: 0x46231a)
                colors.1 = UIColor(rgb: 0x381b1a)
                colors.2 = UIColor(rgb: 0x51291f)
                colors.3 = UIColor(rgb: 0x683e34)
                if !state.displayInfo {
                    colors.4 = UIColor(rgb: 0x683e34)
                }
            }
            
            var buttonColor = colors.3
            if state.displayInfo, let backdropAttribute = component.gift.attributes.first(where: { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }), case let .backdrop(_, _, _, outerColor, _, _, _) = backdropAttribute {
                buttonColor = UIColor(rgb: UInt32(bitPattern: outerColor)).mixedWith(.white, alpha: 0.2)
            }
            
            var backgroundColor = colors.1
            if state.displayInfo {
                backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            let giftTitle = "\(component.gift.title) #\(formatCollectibleNumber(component.gift.number, dateTimeFormat: environment.dateTimeFormat))"
            
            let buttonContent: AnyComponentWithIdentity<Empty>
            if state.displayInfo {
                var buttonTitle: [AnyComponentWithIdentity<Empty>] = []
                buttonTitle.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "anim_ok"),
                    color: environment.theme.list.itemCheckColors.foregroundColor,
                    startingPosition: .begin,
                    size: CGSize(width: 28.0, height: 28.0),
                    playOnce: playButtonAnimation
                ))))
                buttonTitle.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ButtonTextContentComponent(
                    text: strings.Gift_Craft_Info_Understood,
                    badge: 0,
                    textColor: environment.theme.list.itemCheckColors.foregroundColor,
                    badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                    badgeForeground: environment.theme.list.itemCheckColors.fillColor
                ))))
                buttonContent = AnyComponentWithIdentity(id: "info", component: AnyComponent(
                    HStack(buttonTitle, spacing: 2.0)
                ))
            } else if state.displayFailure {
                buttonContent = AnyComponentWithIdentity(id: "fail", component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_CraftingFailed_CraftAnotherGift, font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor)))
                ))
            } else {
                var buttonAnimatedItems: [AnimatedTextComponent.Item] = []
                
                let rawString = environment.strings.Gift_Craft_Crafting_SuccessChance("{p}").string
                var startIndex = rawString.startIndex
                while true {
                    if let range = rawString.range(of: "{", range: startIndex ..< rawString.endIndex) {
                        if range.lowerBound != startIndex {
                            buttonAnimatedItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedItems.count), content: .text(String(rawString[startIndex ..< range.lowerBound]))))
                        }
                        
                        startIndex = range.upperBound
                        if let endRange = rawString.range(of: "}", range: startIndex ..< rawString.endIndex) {
                            let controlString = rawString[range.upperBound ..< endRange.lowerBound]
                            if controlString == "p" {
                                buttonAnimatedItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedItems.count), content: .number(Int(permilleValue / 10), minDigits: 1)))
                            }
                            startIndex = endRange.upperBound
                        }
                    } else {
                        break
                    }
                }
                if startIndex != rawString.endIndex {
                    buttonAnimatedItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedItems.count), content: .text(String(rawString[startIndex ..< rawString.endIndex]))))
                }

                buttonContent = AnyComponentWithIdentity(id: "craft", component: AnyComponent(
                    VStack([
                        AnyComponentWithIdentity(
                            id: AnyHashable("label"),
                            component: AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: AnyHashable("label"),
                                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_Craft(giftTitle).string, font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor))))
                                    )
                                ], spacing: 2.0)
                            )
                        ),
                        AnyComponentWithIdentity(
                            id: AnyHashable("level"),
                            component: AnyComponent(
                                AnimatedTextComponent(
                                    font: Font.with(size: 13.0, weight: .medium, traits: .monospacedNumbers),
                                    color: environment.theme.list.itemCheckColors.foregroundColor,
                                    items: buttonAnimatedItems,
                                    noDelay: true
                                )
                            )
                        )
                    ], spacing: 0.0)
                ))
            }
            
            var displayState: CraftGiftPageContent.DisplayState = .default
            if state.displayFailure {
                displayState = .failure
            } else if state.isCrafting {
                displayState = .crafting
            }
                        
            let hideButtons = displayState == .crafting
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(
                        CraftGiftPageContent(
                            context: component.context,
                            craftContext: component.craftContext,
                            resaleContext: { [weak state] in
                                return state?.resaleContext
                            },
                            colors: colors,
                            gift: component.gift,
                            selectedGiftIds: state.selectedGiftIds,
                            displayState: displayState,
                            displayInfo: state.displayInfo,
                            result: state.result,
                            screenSize: context.availableSize,
                            externalState: externalState,
                            starsTopUpOptionsPromise: state.starsTopUpOptionsPromise,
                            selectGift: { [weak state] index, gift in
                                guard let state else {
                                    return
                                }
                                state.selectedGiftIds[index] = gift.gift.id
                                state.updated(transition: .spring(duration: 0.4))
                            },
                            removeGift: { [weak state] index in
                                guard let state else {
                                    return
                                }
                                state.selectedGiftIds[index] = nil
                                state.updated(transition: .spring(duration: 0.4))
                            },
                            dismiss: {
                                dismiss(true)
                            }
                        )
                    ),
                    leftItem: hideButtons ? nil : AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: buttonColor,
                            isDark: true,
                            state: .tintedGlass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: .white
                                )
                            )),
                            action: { [weak state] _ in
                                guard let state else {
                                    return
                                }
                                if state.displayInfo {
                                    state.displayInfo = false
                                    state.updated(transition: .spring(duration: 0.3))
                                } else {
                                    dismiss(true)
                                }
                            }
                        )
                    ),
                    rightItem: hideButtons || state.displayInfo ? nil : AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: buttonColor,
                            isDark: true,
                            state: .tintedGlass,
                            component: AnyComponentWithIdentity(id: "info", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Question",
                                    tintColor: .white
                                )
                            )),
                            action: { [weak state] _ in
                                guard let state, !state.inProgress else {
                                    return
                                }
                                state.displayInfo = true
                                state.updated(transition: .spring(duration: 0.3))
                                playButtonAnimation.invoke(Void())
                            }
                        )
                    ),
                    hasTopEdgeEffect: false,
                    bottomItem: hideButtons ? nil : AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: colors.4,
                                foreground: environment.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: buttonContent,
                            isEnabled: state.displayInfo ? true : state.selectedGiftIds.count > 0,
                            displaysProgress: state.inProgress,
                            action: { [weak state] in
                                guard let state else {
                                    return
                                }
                                if state.displayInfo {
                                    state.displayInfo = false
                                    state.updated(transition: .spring(duration: 0.3))
                                } else if state.displayFailure, let genericGift = externalState.starGiftsMap[component.gift.giftId] {
                                    HapticFeedback().impact(.light)
                                    
                                    let selectController = SelectCraftGiftScreen(
                                        context: component.context,
                                        craftContext: component.craftContext,
                                        resaleContext: state.resaleContext,
                                        gift: component.gift,
                                        genericGift: genericGift,
                                        selectedGiftIds: Set(),
                                        starsTopUpOptions: state.starsTopUpOptionsPromise.get(),
                                        selectGift: { item in
                                            if let controller = controller() as? GiftCraftScreen, let navigationController = controller.navigationController as? NavigationController {
                                                let craftController = GiftCraftScreen(context: component.context, gift: item.gift, profileGiftsContext: controller.profileGiftsContext)
                                                controller.dismissAnimated()
                                                navigationController.pushViewController(craftController)
                                            }
                                        }
                                    )
                                    environment.controller()?.push(selectController)
                                } else {
                                    HapticFeedback().impact(.medium)
                                    
                                    state.inProgress = true
                                    state.updated(transition: .spring(duration: 0.3))
                                    
                                    if let testFailOrSuccess = externalState.testFailOrSuccess {
                                        Queue.mainQueue().after(0.5, {
                                            state.isCrafting = true
                                            if testFailOrSuccess {
                                                state.result = .gift(ProfileGiftsContext.State.StarGift(gift: .unique(component.gift), reference: nil, fromPeer: nil, date: 0, text: "", entities: nil, nameHidden: false, savedToProfile: false, pinnedToTop: false, convertStars: nil, canUpgrade: false, canExportDate: nil, upgradeStars: nil, transferStars: nil, canTransferDate: nil, canResaleDate: nil, collectionIds: nil, prepaidUpgradeHash: nil, upgradeSeparate: false, dropOriginalDetailsStars: nil, number: nil, isRefunded: false, canCraftAt: nil))
                                            } else {
                                                state.result = .fail
                                            }
                                            state.updated(transition: .spring(duration: 0.8))
                                        })
                                        return
                                    }
                                    
                                    var indices: [Int] = []
                                    for index in state.selectedGiftIds.keys.sorted() {
                                        indices.append(Int(index))
                                    }
                                    var references: [StarGiftReference] = []
                                    for index in indices {
                                        if let giftId = state.selectedGiftIds[Int32(index)], let gift = externalState.giftsMap[giftId] {
                                            references.append(gift.reference)
                                        }
                                    }
                                    let _ = (craftContext.craft(references: references)
                                    |> deliverOnMainQueue).start(next: { [weak state] result in
                                        guard let state else {
                                            return
                                        }
                                        state.isCrafting = true
                                        state.result = .gift(result)
                                        state.updated(transition: .spring(duration: 0.8))
                                        
                                        if case let .unique(uniqueGift) = result.gift {
                                            for attribute in uniqueGift.attributes {
                                                switch attribute {
                                                case let .model(_, file, _, _):
                                                    state.preloadDisposable.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                                case let .pattern(_, file, _):
                                                    state.preloadDisposable.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    }, error: { error in
                                        switch error {
                                        case .craftFailed:
                                            state.isCrafting = true
                                            state.result = .fail
                                            state.updated(transition: .spring(duration: 0.8))
                                            
                                            Queue.mainQueue().after(1.0) {
                                                craftContext.reload()
                                            }
                                        default:
                                            if let navigationController = controller()?.navigationController {
                                                var text: String = strings.Login_UnknownError
                                                switch error {
                                                case let .tooEarly(canCraftDate):
                                                    let dateString = stringForFullDate(timestamp: canCraftDate, strings: strings, dateTimeFormat: dateTimeFormat)
                                                    text = strings.Gift_Craft_Unavailable_Text(dateString).string
                                                case .unavailable:
                                                    text = strings.Gift_Craft_Error_NotAvailable
                                                default:
                                                    break
                                                }
                                                dismiss(true)
                                                let alertController = textAlertController(context: component.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
                                                (navigationController.topViewController as? ViewController)?.present(alertController, in: .window(.root))
                                            }
                                        }
                                    })
                                }
                            }
                        )
                    ),
                    backgroundColor: .color(backgroundColor),
                    isFullscreen: false,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
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


public class GiftCraftScreen: ViewControllerComponentContainer {
    fileprivate weak var profileGiftsContext: ProfileGiftsContext?
    
    public init(
        context: AccountContext,
        gift: StarGift.UniqueGift,
        profileGiftsContext: ProfileGiftsContext?
    ) {
        self.profileGiftsContext = profileGiftsContext
        
        let craftContext = CraftGiftsContext(account: context.account, giftId: gift.giftId)
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                craftContext: craftContext,
                gift: gift
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
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            return true
        })
    }
    
    public func dismissAnimated() {
        self.dismissAllTooltips()
        
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}



private struct GiftCraftConfiguration {
    static var defaultValue: GiftCraftConfiguration {
        return GiftCraftConfiguration(
            craftAttributePermilles: [[90], [80, 200], [70, 190, 460], [60, 180, 450, 1000]]
        )
    }
    
    let craftAttributePermilles: [[Int32]]
        
    fileprivate init(
        craftAttributePermilles: [[Int32]]
    ) {
        self.craftAttributePermilles = craftAttributePermilles
    }
    
    static func with(appConfiguration: AppConfiguration) -> GiftCraftConfiguration {
        if let data = appConfiguration.data {
            var craftAttributePermilles: [[Int32]] = []
            if let value = data["stargifts_craft_attribute_permilles"] as? [[Double]] {
                craftAttributePermilles = value.map { innerArray in
                    innerArray.map { Int32($0) }
                }
            } else {
                craftAttributePermilles = GiftCraftConfiguration.defaultValue.craftAttributePermilles
            }
            
            return GiftCraftConfiguration(
                craftAttributePermilles: craftAttributePermilles
            )
        } else {
            return .defaultValue
        }
    }
}
