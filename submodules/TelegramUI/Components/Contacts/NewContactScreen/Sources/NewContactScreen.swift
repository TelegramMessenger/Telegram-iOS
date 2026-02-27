import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import ListSectionComponent
import ListTextFieldItemComponent
import ListActionItemComponent
import TextFormat
import TextFieldComponent
import ListComposePollOptionComponent
import ListItemComponentAdaptor
import PresentationDataUtils
import EdgeEffect
import GlassBarButtonComponent
import Markdown
import CountrySelectionUI
import PhoneNumberFormat
import QrCodeUI
import MessageUI
import AvatarNode

final class NewContactScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    struct Result {
        let peer: EnginePeer?
        let firstName: String
        let lastName: String
        let phoneNumber: String
        let syncContactToPhone: Bool
        let addToPrivacyExceptions: Bool
        let note: NSAttributedString
    }
    
    let context: AccountContext
    let initialData: NewContactScreen.InitialData

    init(
        context: AccountContext,
        initialData: NewContactScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }

    static func ==(lhs: NewContactScreenComponent, rhs: NewContactScreenComponent) -> Bool {
        return true
    }
    
    enum ResolvedPeer: Equatable {
        case resolving
        case peer(peer: EnginePeer, isContact: Bool)
        case notFound
    }
    
    final class View: UIView, UIScrollViewDelegate, MFMessageComposeViewControllerDelegate {
        private let scrollView: UIScrollView
        private let edgeEffectView: EdgeEffectView
        
        private let nameSection = ComponentView<Empty>()
        private let phoneSection = ComponentView<Empty>()
        private let optionsSection = ComponentView<Empty>()
        private let noteSection = ComponentView<Empty>()
        private let qrSection = ComponentView<Empty>()
        private var avatarNode: AvatarNode?
        
        private let title = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
                
        private var isUpdating: Bool = false
        private var ignoreScrolling: Bool = false
        private var previousHadInputHeight: Bool = false
        
        private var component: NewContactScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var resolvedPeer: NewContactScreenComponent.ResolvedPeer?
        private var resolvedPeerDisposable = MetaDisposable()
        
        private let firstNameTag = NSObject()
        private let lastNameTag = NSObject()
        private let phoneTag = NSObject()
        private let noteTag = NSObject()
        
        private var updateFocusTag: Any?
        
        private var syncContactToPhone = true
        private var addToPrivacyExceptions = false
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        private var composer: MFMessageComposeViewController?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.edgeEffectView = EdgeEffectView()
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.addSubview(self.edgeEffectView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.resolvedPeerDisposable.dispose()
        }
        
        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func validatedInput() -> NewContactScreenComponent.Result? {
            var peer: EnginePeer?
            var firstName = ""
            var lastName = ""
            var phoneNumber = ""
            var note = NSAttributedString()
            if case let .peer(resolvedPeer, _) = self.resolvedPeer {
                peer = resolvedPeer
            }
            if let view = self.nameSection.findTaggedView(tag: self.firstNameTag) as? ListTextFieldItemComponent.View {
                firstName = view.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if firstName.isEmpty {
                    return nil
                }
            }
            if let view = self.nameSection.findTaggedView(tag: self.lastNameTag) as? ListTextFieldItemComponent.View {
                lastName = view.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let view = self.phoneSection.findTaggedView(tag: self.phoneTag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    if itemNode.codeNumberAndFullNumber.0.isEmpty || itemNode.codeNumberAndFullNumber.1.isEmpty {
                        return nil
                    }
                    phoneNumber = itemNode.phoneNumber
                }
            }
            if let view = self.noteSection.findTaggedView(tag: self.noteTag) as? ListComposePollOptionComponent.View {
                note = view.currentAttributedText
            }
            return Result(
                peer: peer,
                firstName: firstName,
                lastName: lastName,
                phoneNumber: phoneNumber,
                syncContactToPhone: self.syncContactToPhone,
                addToPrivacyExceptions: self.addToPrivacyExceptions,
                note: note
            )
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {

        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            
        }
        
        func updateCountryCode(code: Int32, name: String) {
            if let view = self.phoneSection.findTaggedView(tag: self.phoneTag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    itemNode.updateCountryCode(code: code, name: name)
                }
            }
        }
        
        private var currentPhoneNumber: String {
            if let view = self.phoneSection.findTaggedView(tag: tag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    return itemNode.phoneNumber
                }
            }
            return ""
        }
        
        func activateInput(tag: Any) {
            if let view = self.phoneSection.findTaggedView(tag: tag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    itemNode.activateInput()
                }
            }
            if let view = self.nameSection.findTaggedView(tag: tag) as? ListTextFieldItemComponent.View {
                view.activateInput()
            }
        }
        
        func deactivateInput() {
            self.endEditing(true)
        }
        
        func sendInvite() {
            guard MFMessageComposeViewController.canSendText(), let environment = self.environment else {
                return
            }
            let composer = MFMessageComposeViewController()
            composer.messageComposeDelegate = self
            composer.recipients = [self.currentPhoneNumber]
            let url = environment.strings.InviteText_URL
            let body = environment.strings.InviteText_SingleContact(url).string
            composer.body = body
            self.composer = composer
            if let window = self.window {
                window.rootViewController?.present(composer, animated: true)
            }
        }
        
        @objc public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            self.composer = nil
            
            controller.dismiss(animated: true, completion: nil)
        }
                
        func update(component: NewContactScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                        
            var alphaTransition = transition
            if !transition.animation.isImmediate {
                alphaTransition = alphaTransition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            let theme = environment.theme
            let strings = environment.strings
            
            var initialCountryCode: Int32?
            var updateFocusTag: Any?
            if self.component == nil {
                if let peer = component.initialData.peer {
                    self.resolvedPeer = .peer(peer: peer, isContact: false)
                }
                
                if component.initialData.shareViaException {
                    self.addToPrivacyExceptions = true
                }
                
                let countryCode: Int32
                if let phone = component.initialData.phoneNumber {
                    if let (_, code) = lookupCountryIdByNumber(phone, configuration: component.context.currentCountriesConfiguration.with { $0 }), let codeValue = Int32(code.code) {
                        countryCode = codeValue
                    } else if phone.hasPrefix("999") {
                        countryCode = 93
                    } else {
                        countryCode = AuthorizationSequenceCountrySelectionController.defaultCountryCode()
                    }
                    if let _ = component.initialData.peer {   
                    } else {
                        updateFocusTag = self.firstNameTag
                    }
                } else {
                    countryCode = AuthorizationSequenceCountrySelectionController.defaultCountryCode()
                    updateFocusTag = self.phoneTag
                }
                initialCountryCode = countryCode
            } else {
                updateFocusTag = self.updateFocusTag
                self.updateFocusTag = nil
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            let footerAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
            
            if themeUpdated {
                self.backgroundColor = theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
            
            var avatarInset: CGFloat = 0.0
            if let _ = component.initialData.peer {
                avatarInset = 84.0
            }
                    
            let nameSectionItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "firstName", component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass,
                    theme: theme,
                    initialText: component.initialData.firstName ?? "",
                    resetText: nil,
                    placeholder: strings.UserInfo_FirstNamePlaceholder,
                    autocapitalizationType: .sentences,
                    autocorrectionType: .default,
                    returnKeyType: .next,
                    contentInsets: UIEdgeInsets(top: 0.0, left: avatarInset, bottom: 0.0, right: 0.0),
                    updated: { value in
                    },
                    onReturn: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.updateFocusTag = self.lastNameTag
                        self.state?.updated()
                    },
                    tag: self.firstNameTag
                ))),
                AnyComponentWithIdentity(id: "lastName", component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass,
                    theme: theme,
                    initialText: component.initialData.lastName ?? "",
                    resetText: nil,
                    placeholder: strings.UserInfo_LastNamePlaceholder,
                    autocapitalizationType: .sentences,
                    autocorrectionType: .default,
                    returnKeyType: .next,
                    contentInsets: UIEdgeInsets(top: 0.0, left: avatarInset, bottom: 0.0, right: 0.0),
                    updated: { value in
                    },
                    onReturn: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.updateFocusTag = self.phoneTag
                        self.state?.updated()
                    },
                    tag: self.lastNameTag
                )))
            ]
            let nameSectionSize = self.nameSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: nameSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let nameSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: nameSectionSize)
            if let nameSectionView = self.nameSection.view as? ListSectionComponent.View {
                if nameSectionView.superview == nil {
                    self.scrollView.addSubview(nameSectionView)
                    self.nameSection.parentState = state
                }
                transition.setFrame(view: nameSectionView, frame: nameSectionFrame)
            }
            
            if let peer = component.initialData.peer {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 28.0))
                    avatarNode.setPeer(context: component.context, theme: theme, peer: peer)
                    self.scrollView.addSubview(avatarNode.view)
                    self.avatarNode = avatarNode
                }
                avatarNode.frame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight + floorToScreenPixels((nameSectionFrame.height - 66.0) / 2.0)), size: CGSize(width: 66.0, height: 66.0))
            }
            
            contentHeight += nameSectionSize.height
            contentHeight += sectionSpacing
            
            var phoneAccesory: PhoneInputItem.Accessory?
            switch self.resolvedPeer {
            case .resolving:
                phoneAccesory = .activity
            case .peer:
                phoneAccesory = .check
            default:
                phoneAccesory = nil
            }
            
            var phoneSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            var phoneFooterComponent: AnyComponent<Empty>?
            
            if let peer = component.initialData.peer {
                if let phone = component.initialData.phoneNumber {
                    phoneSectionItems.append(AnyComponentWithIdentity(id: "phone", component: AnyComponent(
                        ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: "title", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "mobile", font: Font.regular(14.0), textColor: theme.list.itemPrimaryTextColor))))),
                                AnyComponentWithIdentity(id: "value", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: formatPhoneNumber(context: component.context, number: phone), font: Font.regular(17.0), textColor: theme.list.itemAccentColor)))))
                            ], alignment: .left, spacing: 4.0)),
                            contentInsets: UIEdgeInsets(top: 15.0, left: 0.0, bottom: 15.0, right: 0.0),
                            accessory: nil,
                            action: nil
                        )))
                    )
                } else {
                    phoneSectionItems.append(AnyComponentWithIdentity(id: "phone", component: AnyComponent(
                        ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: "title", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "mobile", font: Font.regular(14.0), textColor: theme.list.itemPrimaryTextColor))))),
                                AnyComponentWithIdentity(id: "value", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.ContactInfo_PhoneNumberHidden, font: Font.regular(17.0), textColor: theme.list.itemAccentColor)))))
                            ], alignment: .left, spacing: 4.0)),
                            contentInsets: UIEdgeInsets(top: 15.0, left: 0.0, bottom: 15.0, right: 0.0),
                            accessory: nil,
                            action: nil
                        )))
                    )
                    phoneFooterComponent = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: strings.AddContact_ContactWillBeSharedAfterMutual(peer.compactDisplayTitle).string, font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)),
                        maximumNumberOfLines: 0
                    ))
                }
            } else {
                phoneSectionItems.append(AnyComponentWithIdentity(id: "phone", component: AnyComponent(
                    ListItemComponentAdaptor(
                        itemGenerator: PhoneInputItem(
                            theme: theme,
                            strings: strings,
                            value: (initialCountryCode, nil, ""),
                            accessory: phoneAccesory,
                            selectCountryCode: { [weak self] in
                                guard let self, let environment = self.environment, let controller = environment.controller() else {
                                    return
                                }
                                let countryController = AuthorizationSequenceCountrySelectionController(strings: strings, theme: environment.theme, glass: true)
                                countryController.completeWithCountryCode = { [weak self] code, name in
                                    guard let self else {
                                        return
                                    }
                                    self.updateCountryCode(code: Int32(code), name: name)
                                    self.activateInput(tag: self.phoneTag)
                                }
                                self.deactivateInput()
                                controller.push(countryController)
                            },
                            updated: { [weak self] number, mask in
                                guard let self, let component = self.component else {
                                    return
                                }
                                self.resolvedPeerDisposable.set(nil)
                                self.resolvedPeer = nil
                                if !self.isUpdating {
                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                }
                                
                                let cleanNumber = number.replacingOccurrences(of: "+", with: "")
                                var scheduleResolve = false
                                var resolveDelay: Double = 2.5
                                if !mask.isEmpty && abs(cleanNumber.count - mask.count) < 3 {
                                    scheduleResolve = true
                                    if abs(cleanNumber.count - mask.count) == 0 {
                                        resolveDelay = 0.1
                                    }
                                } else if mask.isEmpty && cleanNumber.count > 4 {
                                    scheduleResolve = true
                                }
                                
                                if scheduleResolve {
                                    self.resolvedPeerDisposable.set(
                                        ((Signal.complete() |> delay(resolveDelay, queue: Queue.mainQueue()))
                                         |> then(
                                            component.context.engine.peers.resolvePeerByPhone(phone: number)
                                            |> beforeStarted({ [weak self] in
                                                guard let self else {
                                                    return
                                                }
                                                self.resolvedPeer = .resolving
                                                if !self.isUpdating {
                                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                                }
                                            })
                                         )
                                         |> deliverOnMainQueue).start(next: { [weak self] peer in
                                             guard let self, let component = self.component else {
                                                 return
                                             }
                                             if let peer {
                                                 self.resolvedPeerDisposable.set((component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.IsContact(id: peer.id)) |> deliverOnMainQueue).start(next: { [weak self] isContact in
                                                     guard let self else {
                                                         return
                                                     }
                                                     self.resolvedPeer = .peer(peer: peer, isContact: isContact)
                                                     if !self.isUpdating {
                                                         self.state?.updated(transition: .easeInOut(duration: 0.2))
                                                     }
                                                 }))
                                             } else {
                                                 self.resolvedPeer = .notFound
                                                 if !self.isUpdating {
                                                     self.state?.updated(transition: .easeInOut(duration: 0.2))
                                                 }
                                             }
                                         })
                                    )
                                }
                            }
                        ),
                        params: ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true),
                        tag: self.phoneTag
                    )
                )))
                
                if let resolvedPeer = self.resolvedPeer {
                    if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                        self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
                    }
                    
                    let phoneFooterRawText: String
                    switch resolvedPeer {
                    case .resolving:
                        phoneFooterRawText = ""
                    case let .peer(_, isContact):
                        if isContact {
                            phoneFooterRawText = strings.AddContact_PhoneNumber_IsContact
                        } else {
                            phoneFooterRawText = strings.AddContact_PhoneNumber_Registered
                        }
                    case .notFound:
                        phoneFooterRawText = strings.AddContact_PhoneNumber_NotRegistered
                    }
                    let phoneFooterText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(phoneFooterRawText, attributes: footerAttributes))
                    if let range = phoneFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                        phoneFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: phoneFooterText.string))
                    }
                    phoneFooterComponent = AnyComponent(MultilineTextComponent(
                        text: .plain(phoneFooterText),
                        maximumNumberOfLines: 0,
                        highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] _, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            if case let .peer(peer, _) = self.resolvedPeer {
                                if let infoController = component.context.sharedContext.makePeerInfoController(context: component.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                    if let navigationController = component.context.sharedContext.mainWindow?.viewController as? NavigationController {
                                        navigationController.pushViewController(infoController)
                                    }
                                }
                            } else {
                                self.sendInvite()
                            }
                        }
                    ))
                }
            }
            
            let phoneSectionSize = self.phoneSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: phoneFooterComponent,
                    items: phoneSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let phoneSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: phoneSectionSize)
            if let phoneSectionView = self.phoneSection.view as? ListSectionComponent.View {
                if phoneSectionView.superview == nil {
                    self.scrollView.addSubview(phoneSectionView)
                    self.phoneSection.parentState = state
                }
                transition.setFrame(view: phoneSectionView, frame: phoneSectionFrame)
            }
            contentHeight += phoneSectionSize.height
            contentHeight += sectionSpacing
            
            if let initialCountryCode {
                self.updateCountryCode(code: initialCountryCode, name: "")
            }
            

            var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "syncContact", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.AddContact_SyncToPhone,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.syncContactToPhone, action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.syncContactToPhone = !self.syncContactToPhone
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                )))
            ]
            var optionsFooterComponent: AnyComponent<Empty>?
            if let peer = component.initialData.peer, component.initialData.shareViaException {
                optionsSectionItems.append(
                    AnyComponentWithIdentity(id: "privacy", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AddContact_SharedContactException,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.addToPrivacyExceptions, action: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.addToPrivacyExceptions = !self.addToPrivacyExceptions
                            self.state?.updated(transition: .spring(duration: 0.4))
                        })),
                        action: nil
                    )))
                )
                optionsFooterComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.AddContact_SharedContactExceptionInfo(peer.compactDisplayTitle).string, font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)),
                    maximumNumberOfLines: 0
                ))
            }
            
            let optionsSectionSize = self.optionsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: optionsFooterComponent,
                    items: optionsSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let optionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: optionsSectionSize)
            if let optionsSectionView = self.optionsSection.view {
                if optionsSectionView.superview == nil {
                    self.scrollView.addSubview(optionsSectionView)
                    self.optionsSection.parentState = state
                }
                transition.setFrame(view: optionsSectionView, frame: optionsSectionFrame)
            }
            contentHeight += optionsSectionSize.height
            contentHeight += sectionSpacing

            if case .peer = self.resolvedPeer {
                if let qrSectionView = self.qrSection.view, qrSectionView.superview != nil {
                    transition.setAlpha(view: qrSectionView, alpha: 0.0, completion: { _ in
                        qrSectionView.removeFromSuperview()
                    })
                }
                
                var characterLimit: Int = 128
                if let data = component.context.currentAppConfiguration.with({ $0 }).data, let value = data["contact_note_length_limit"] as? Double {
                    characterLimit = Int(value)
                }
                let noteSectionItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(
                        id: "note",
                        component: AnyComponent(
                            ListComposePollOptionComponent(
                                externalState: nil,
                                context: component.context,
                                style: .glass,
                                theme: theme,
                                strings: strings,
                                placeholder: NSAttributedString(string: strings.AddContact_NotePlaceholder, font: Font.regular(17.0), textColor: theme.list.itemPlaceholderTextColor),
                                characterLimit: characterLimit,
                                emptyLineHandling: .allowed,
                                returnKeyAction: nil,
                                backspaceKeyAction: nil,
                                selection: nil,
                                inputMode: nil,
                                toggleInputMode: nil,
                                tag: self.noteTag
                            )
                        )
                    )
                ]
                var noteSectionTransition = transition
                if self.noteSection.view == nil {
                    noteSectionTransition = .immediate
                }
                let noteSectionSize = self.noteSection.update(
                    transition: noteSectionTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: noteSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let noteSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: noteSectionSize)
                if let noteSectionView = self.noteSection.view {
                    if noteSectionView.superview == nil {
                        self.scrollView.addSubview(noteSectionView)
                        self.optionsSection.parentState = state
                        
                        noteSectionTransition = .immediate
                        transition.setAlpha(view: noteSectionView, alpha: 1.0)
                    }
                    noteSectionTransition.setFrame(view: noteSectionView, frame: noteSectionFrame)
                }
                contentHeight += noteSectionSize.height
                contentHeight += sectionSpacing
            } else {
                if let noteSectionView = self.noteSection.view, noteSectionView.superview != nil {
                    transition.setAlpha(view: noteSectionView, alpha: 0.0, completion: { _ in
                        noteSectionView.removeFromSuperview()
                    })
                }
                
                let qrSectionItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: "qr", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AddContact_AddQR,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: .custom(
                            AnyComponentWithIdentity(
                                id: "icon",
                                component: AnyComponent(BundleIconComponent(name: "Settings/QrIcon", tintColor: theme.list.itemAccentColor))
                            ),
                            false
                        ),
                        accessory: .none,
                        action: { [weak self] _ in
                            guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                                return
                            }
                            let scanController = QrCodeScanScreen(context: component.context, subject: .peer)
                            controller.push(scanController)
                        }
                    )))
                ]
                let qrSectionSize = self.qrSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: qrSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let qrSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: qrSectionSize)
                if let qrSectionView = self.qrSection.view {
                    var qrSectionTransition = transition
                    if qrSectionView.superview == nil {
                        self.scrollView.addSubview(qrSectionView)
                        self.optionsSection.parentState = state
                        
                        qrSectionTransition = .immediate
                        transition.setAlpha(view: qrSectionView, alpha: 1.0)
                    }
                    qrSectionTransition.setFrame(view: qrSectionView, frame: qrSectionFrame)
                }
                contentHeight += qrSectionSize.height
                contentHeight += sectionSpacing
            }
            
            
            let inputHeight = environment.inputHeight
            
            let combinedBottomInset: CGFloat
            combinedBottomInset = bottomInset + max(environment.safeInsets.bottom, 8.0 + inputHeight)
            contentHeight += combinedBottomInset
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            self.ignoreScrolling = false
                        

            let isValid = self.validatedInput() != nil
            
            let edgeEffectHeight: CGFloat = 66.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: environment.theme.list.blocksBackgroundColor, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectFrame.height, transition: transition)
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: strings.AddContact_Title,
                                font: Font.semibold(17.0),
                                textColor: environment.theme.rootController.navigationBar.primaryTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 40.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((environment.navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? NewContactScreen else {
                            return
                        }
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: 16.0), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: isValid ? environment.theme.list.itemCheckColors.fillColor : environment.theme.list.itemCheckColors.fillColor.desaturated().withMultipliedAlpha(0.5),
                    isDark: environment.theme.overallDarkAppearance,
                    state: .tintedGlass,
                    isEnabled: isValid,
                    component: AnyComponentWithIdentity(id: "done", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Done",
                            tintColor: environment.theme.list.itemCheckColors.foregroundColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? NewContactScreen else {
                            return
                        }
                        if let input = self.validatedInput() {
                            controller.complete(result: input)
                        }
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let doneButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - 16.0 - doneButtonSize.width, y: 16.0), size: doneButtonSize)
            if let doneButtonView = self.doneButton.view {
                if doneButtonView.superview == nil {
                    self.addSubview(doneButtonView)
                }
                transition.setFrame(view: doneButtonView, frame: doneButtonFrame)
            }
            
            if let updateFocusTag {
                self.activateInput(tag: updateFocusTag)
            }
                    
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class NewContactScreen: ViewControllerComponentContainer {
    public final class InitialData {
        fileprivate let peer: EnginePeer?
        fileprivate let firstName: String?
        fileprivate let lastName: String?
        fileprivate let phoneNumber: String?
        fileprivate let shareViaException: Bool
        
        fileprivate init(
            peer: EnginePeer?,
            firstName: String?,
            lastName: String?,
            phoneNumber: String?,
            shareViaException: Bool
        ) {
            self.peer = peer
            self.firstName = firstName
            self.lastName = lastName
            self.phoneNumber = phoneNumber
            self.shareViaException = shareViaException
        }
    }
    
    private let context: AccountContext
    fileprivate let completion: (EnginePeer?, DeviceContactStableId?, DeviceContactExtendedData?) -> Void
    private var isDismissed: Bool = false
            
    public init(
        context: AccountContext,
        initialData: InitialData,
        completion: @escaping (EnginePeer?, DeviceContactStableId?, DeviceContactExtendedData?) -> Void
    ) {
        self.context = context
        self.completion = completion
        
        let countriesConfiguration = context.currentCountriesConfiguration.with { $0 }
        AuthorizationSequenceCountrySelectionController.setupCountryCodes(countries: countriesConfiguration.countries, codesByPrefix: countriesConfiguration.countriesByPrefix)
        
        super.init(context: context, component: NewContactScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .none, theme: .default)
        
        self._hasGlassStyle = true
        self.navigationPresentation = .modal
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? NewContactScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public static func initialData(
        peer: EnginePeer? = nil,
        phoneNumber: String? = nil,
        shareViaException: Bool = false
    ) -> InitialData {
        if case let .user(user) = peer {
            return InitialData(
                peer: peer,
                firstName: user.firstName,
                lastName: user.lastName,
                phoneNumber: user.phone ?? phoneNumber,
                shareViaException: shareViaException
            )
        } else {
            return InitialData(
                peer: nil,
                firstName: nil,
                lastName: nil,
                phoneNumber: phoneNumber,
                shareViaException: false
            )
        }
    }
    
    fileprivate func complete(result: NewContactScreenComponent.Result) {
        let entities = generateChatInputTextEntities(result.note)
        if let peer = result.peer {
            let _ = (self.context.engine.contacts.addContactInteractively(
                peerId: peer.id,
                firstName: result.firstName,
                lastName: result.lastName,
                phoneNumber: result.phoneNumber,
                noteText: result.note.string,
                noteEntities: entities,
                addToPrivacyExceptions: result.addToPrivacyExceptions
            ) |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                if !result.syncContactToPhone {
                    self?.completion(result.peer, nil, nil)
                }
            })
        } else {
            let _ = self.context.engine.contacts.importContact(
                firstName: result.firstName,
                lastName: result.lastName,
                phoneNumber: result.phoneNumber,
                noteText: result.note.string,
                noteEntities: entities
            ).startStandalone()
        }
        
        if result.syncContactToPhone, let contactDataManager = self.context.sharedContext.contactDataManager {
            var urls: [DeviceContactUrlData] = []
            if let peer = result.peer {
                let appProfile = DeviceContactUrlData(appProfile: peer.id)
                var found = false
                for url in urls {
                    if url.label == appProfile.label && url.value == appProfile.value {
                        found = true
                        break
                    }
                }
                if !found {
                    urls.append(appProfile)
                }
            }
            
            var phoneNumbers: [DeviceContactPhoneNumberData] = []
            if !result.phoneNumber.isEmpty {
                phoneNumbers.append(DeviceContactPhoneNumberData(label: defaultContactLabel, value: result.phoneNumber))
            }
            let composedContactData = DeviceContactExtendedData(
                basicData: DeviceContactBasicData(
                    firstName: result.firstName,
                    lastName: result.lastName,
                    phoneNumbers: phoneNumbers
                ),
                middleName: "",
                prefix: "",
                suffix: "",
                organization: "",
                jobTitle: "",
                department: "",
                emailAddresses: [],
                urls: urls,
                addresses: [],
                birthdayDate: nil,
                socialProfiles: [],
                instantMessagingProfiles: [],
                note: ""
            )
            let _ = (contactDataManager.createContactWithData(composedContactData)
            |> deliverOnMainQueue).start(next: { [weak self] contactIdAndData in
                if let self, let contactIdAndData {
                    self.completion(result.peer, contactIdAndData.0, contactIdAndData.1)
                }
            })
        }
    }
}
