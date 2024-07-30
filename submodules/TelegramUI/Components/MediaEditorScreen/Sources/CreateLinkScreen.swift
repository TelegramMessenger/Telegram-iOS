import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import BundleIconComponent
import ItemListUI
import AccountContext
import PresentationDataUtils
import ListSectionComponent
import TelegramStringFormatting
import MediaEditor
import UrlEscaping

private let linkTag = GenericComponentViewTag()
private let nameTag = GenericComponentViewTag()

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let isEdit: Bool
    let link: String
    let webpage: TelegramMediaWebpage?
    let state: CreateLinkSheetComponent.State
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        isEdit: Bool,
        link: String,
        webpage: TelegramMediaWebpage?,
        state: CreateLinkSheetComponent.State,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.isEdit = isEdit
        self.link = link
        self.webpage = webpage
        self.state = state
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.isEdit != rhs.isEdit {
            return false
        }
        if lhs.link != rhs.link {
            return false
        }
        if lhs.webpage != rhs.webpage {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let cancelButton = Child(Button.self)
        let doneButton = Child(Button.self)
        let title = Child(Text.self)
        let urlSection = Child(ListSectionComponent.self)
        let nameSection = Child(ListSectionComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = component.state
            
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let sideInset: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.list.blocksBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            let cancelButton = cancelButton.update(
                component: Button(
                    content: AnyComponent(
                        Text(
                            text: strings.Common_Cancel,
                            font: Font.regular(17.0),
                            color: theme.actionSheet.controlAccentColor
                        )
                    ),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(cancelButton
                .position(CGPoint(x: sideInset + cancelButton.size.width / 2.0, y: contentSize.height + cancelButton.size.height / 2.0))
            )
            
            let explicitLink = explicitUrl(context.component.link)
            var isValidLink = false
            if isValidUrl(explicitLink) {
                isValidLink = true
            }
            
            let controller = environment.controller
            let doneButton = doneButton.update(
                component: Button(
                    content: AnyComponent(
                        Text(
                            text: strings.Common_Done,
                            font: Font.bold(17.0),
                            color: isValidLink ? theme.actionSheet.controlAccentColor : theme.actionSheet.secondaryTextColor
                        )
                    ),
                    isEnabled: isValidLink,
                    action: { [weak state] in
                        if let controller = controller() as? CreateLinkScreen, let state {
                            if state.complete(controller: controller) {
                                component.dismiss()
                            }
                        }
                    }
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(doneButton
                .position(CGPoint(x: context.availableSize.width - sideInset - doneButton.size.width / 2.0, y: contentSize.height + doneButton.size.height / 2.0))
            )
            
            
            let title = title.update(
                component: Text(text: component.isEdit ? strings.MediaEditor_Link_EditTitle : strings.MediaEditor_Link_CreateTitle, font: Font.bold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 40.0
                         
            var urlItems: [AnyComponentWithIdentity<Empty>] = []
            if let webpage = state.webpage, case .Loaded = webpage.content, !state.dismissed {
                urlItems.append(
                    AnyComponentWithIdentity(
                        id: "webpage",
                        component: AnyComponent(
                            LinkPreviewComponent(
                                webpage: webpage,
                                theme: theme,
                                strings: strings,
                                presentLinkOptions: { [weak state] sourceNode in
                                    if let controller = controller() as? CreateLinkScreen {
                                        state?.presentLinkOptions(controller: controller, sourceNode: sourceNode)
                                    }
                                },
                                dismiss: { [weak state] in
                                    state?.dismissed = true
                                    state?.updated(transition: .easeInOut(duration: 0.25))
                                }
                            )
                        )
                    )
                )
            }
            urlItems.append(
                AnyComponentWithIdentity(
                    id: "url",
                    component: AnyComponent(
                        LinkFieldComponent(
                            textColor: theme.list.itemPrimaryTextColor,
                            placeholderColor: theme.list.itemPlaceholderTextColor,
                            text: state.link,
                            link: true,
                            placeholderText: strings.MediaEditor_Link_LinkTo_Placeholder,
                            textUpdated: { [weak state] text in
                                state?.link = text
                                state?.updated()
                            },
                            textReturned: { [weak state] in
                                if let controller = controller() as? CreateLinkScreen {
                                    state?.switchToNextField(controller: controller)
                                }
                            },
                            tag: linkTag
                        )
                    )
                )
            )
            
            state.selectLink = {
                if let controller = controller() as? CreateLinkScreen {
                    if let view = controller.node.hostView.findTaggedView(tag: linkTag) as? LinkFieldComponent.View {
                        view.selectAll()
                    }
                }
            }
            
            let urlSection = urlSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.MediaEditor_Link_LinkTo_Title.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: urlItems,
                    displaySeparators: false
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(urlSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + urlSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            contentSize.height += urlSection.size.height
            contentSize.height += 30.0
            
            let nameSection = nameSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.MediaEditor_Link_LinkName_Title.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(
                            id: "name",
                            component: AnyComponent(
                                LinkFieldComponent(
                                    textColor: theme.list.itemPrimaryTextColor,
                                    placeholderColor: theme.list.itemPlaceholderTextColor,
                                    text: state.name,
                                    link: false,
                                    placeholderText: strings.MediaEditor_Link_LinkName_Placeholder,
                                    textUpdated: { [weak state] text in
                                        state?.name = text
                                    },
                                    textReturned: { [weak state] in
                                        if let controller = controller() as? CreateLinkScreen, let state {
                                            if state.complete(controller: controller) {
                                                component.dismiss()
                                            }
                                        }
                                    },
                                    tag: nameTag
                                )
                            )
                        )
                    ]
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(nameSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + nameSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            contentSize.height += nameSection.size.height
            contentSize.height += 32.0
            
            contentSize.height += max(environment.inputHeight, environment.safeInsets.bottom)

            return contentSize
        }
    }
}

private final class CreateLinkSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let link: CreateLinkScreen.Link?
    
    init(
        context: AccountContext,
        link: CreateLinkScreen.Link?
    ) {
        self.context = context
        self.link = link
    }
    
    static func ==(lhs: CreateLinkSheetComponent, rhs: CreateLinkSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.link != rhs.link {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        fileprivate var link: String = "" {
            didSet {
                self.linkPromise.set(self.link)
            }
        }
        fileprivate var name: String = ""
        fileprivate var webpage: TelegramMediaWebpage?
        fileprivate var isDark = false
        fileprivate var dismissed = false
        
        private var positionBelowText = true
        private var largeMedia: Bool? = nil
        
        private let previewDisposable =  MetaDisposable()
        
        private let linkDisposable =  MetaDisposable()
        private let linkPromise = ValuePromise<String>()
        
        var selectLink: () -> Void = {}
        
        init(
            context: AccountContext,
            link: CreateLinkScreen.Link?
        ) {
            self.context = context
            
            self.link = link?.url ?? ""
            self.name = link?.name ?? ""
            self.webpage = link?.webpage
            self.isDark = link?.isDark ?? false
            self.positionBelowText = link?.positionBelowText ?? true
            self.largeMedia = link?.largeMedia
            
            super.init()
            
            if link == nil {
                Queue.mainQueue().after(0.1, {
                    let pasteboard = UIPasteboard.general
                    if pasteboard.hasURLs {
                        if let url = pasteboard.url?.absoluteString, !url.isEmpty {
                            self.link = url
                            self.updated()
                            
                            self.selectLink()
                        }
                    }
                })
            }
            
            self.linkDisposable.set((self.linkPromise.get()
            |> delay(1.5, queue: Queue.mainQueue())
            |> deliverOnMainQueue).startStrict(next: { [weak self] link in
                guard let self else {
                    return
                }
                
                guard !link.isEmpty else {
                    self.dismissed = false
                    self.previewDisposable.set(nil)
                    self.webpage = nil
                    self.updated(transition: .easeInOut(duration: 0.25))
                    return
                }
                
                let link = explicitUrl(link)
                
                if self.dismissed {
                    self.dismissed = false
                    self.webpage = nil
                }
                self.previewDisposable.set(
                    (webpagePreview(account: context.account, urls: [link])
                     |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                         guard let self else {
                             return
                         }
                         switch result {
                         case let .result(result):
                             self.webpage = result?.webpage
                         case .progress:
                             self.webpage = nil
                         }
                         self.updated(transition: .easeInOut(duration: 0.25))
                     })
                )
            }))
        }
        
        deinit {
            self.previewDisposable.dispose()
            self.linkDisposable.dispose()
        }
        
        func presentLinkOptions(controller: CreateLinkScreen, sourceNode: ASDisplayNode) {
            guard let webpage = self.webpage else {
                return
            }
            let link = explicitUrl(self.link)
            var name: String = self.name
            if name.isEmpty {
                name = self.link
            }
                        
            presentLinkOptionsController(context: self.context, selfController: controller, snapshotImage: controller.snapshotImage, isDark: self.isDark, sourceNode: sourceNode, url: link, name: name, positionBelowText: self.positionBelowText, largeMedia: self.largeMedia, webPage: webpage, completion: { [weak self] positionBelowText, largeMedia in
                guard let self else {
                    return
                }
                self.positionBelowText = positionBelowText
                self.largeMedia = largeMedia
            }, remove: { [weak self] in
                guard let self else {
                    return
                }
                self.dismissed = true
                self.updated(transition: .easeInOut(duration: 0.25))
            })
        }
        
        func switchToNextField(controller: CreateLinkScreen) {
            if let view = controller.node.hostView.findTaggedView(tag: nameTag) as? LinkFieldComponent.View {
                view.activateInput()
            }
        }
        
        func complete(controller: CreateLinkScreen) -> Bool {
            let explicitLink = explicitUrl(self.link)
            if !isValidUrl(explicitLink) {
                if let view = controller.node.hostView.findTaggedView(tag: linkTag) as? LinkFieldComponent.View {
                    view.animateError()
                }
                return false
            }
            
            let text = !self.name.isEmpty ? self.name : self.link
            
            var effectiveMedia: TelegramMediaWebpage?
            var webpageHasLargeMedia = false
            if let webpage = self.webpage, case let .Loaded(content) = webpage.content, !self.dismissed {
                effectiveMedia = webpage
                
                if let isMediaLargeByDefault = content.isMediaLargeByDefault, isMediaLargeByDefault {
                    webpageHasLargeMedia = true
                } else {
                    webpageHasLargeMedia = true
                }
            }
            
            var attributes: [MessageAttribute] = []
            attributes.append(TextEntitiesMessageAttribute(entities: [.init(range: 0 ..< (text as NSString).length, type: .Url)]))
            if !self.dismissed {
                attributes.append(WebpagePreviewMessageAttribute(leadingPreview: !self.positionBelowText, forceLargeMedia: self.largeMedia ?? webpageHasLargeMedia, isManuallyAdded: false, isSafe: true))
            }
            
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
            let message = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: text, attributes: attributes, media: effectiveMedia.flatMap { [$0] } ?? [], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            
            
            let completion = controller.completion
            let renderer = DrawingMessageRenderer(context: self.context, messages: [message], parentView: controller.view, isLink: true)
            renderer.render(completion: { result in
                completion(
                    CreateLinkScreen.Result(
                        url: self.link,
                        name: self.name,
                        webpage: effectiveMedia,
                        positionBelowText: self.positionBelowText,
                        largeMedia: self.largeMedia,
                        image: effectiveMedia != nil ? result.dayImage : nil,
                        nightImage: effectiveMedia != nil ? result.nightImage : nil
                    )
                )
            })
            return true
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, link: self.link)
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            var webpage = context.state.webpage
            if context.state.dismissed {
                webpage = nil
            }
            
            let link = context.state.link
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        isEdit: context.component.link != nil,
                        link: link,
                        webpage: webpage,
                        state: context.state,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .blur(.dark),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    isScrollEnabled: false,
                    animateOut: animateOut
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

public final class CreateLinkScreen: ViewControllerComponentContainer {
    public struct Link: Equatable {
        let url: String
        let name: String?
        let webpage: TelegramMediaWebpage?
        let positionBelowText: Bool
        let largeMedia: Bool?
        let isDark: Bool
        
        init(
            url: String,
            name: String?,
            webpage: TelegramMediaWebpage?,
            positionBelowText: Bool,
            largeMedia: Bool?,
            isDark: Bool
        ) {
            self.url = url
            self.name = name
            self.webpage = webpage
            self.positionBelowText = positionBelowText
            self.largeMedia = largeMedia
            self.isDark = isDark
        }
    }
    
    public struct Result {
        let url: String
        let name: String
        let webpage: TelegramMediaWebpage?
        let positionBelowText: Bool
        let largeMedia: Bool?
        let image: UIImage?
        let nightImage: UIImage?
    }
    
    private let context: AccountContext
    fileprivate let snapshotImage: UIImage?
    fileprivate let completion: (CreateLinkScreen.Result) -> Void
        
    public init(
        context: AccountContext,
        link: CreateLinkScreen.Link?,
        snapshotImage: UIImage?,
        completion: @escaping (CreateLinkScreen.Result) -> Void
    ) {
        self.context = context
        self.snapshotImage = snapshotImage
        self.completion = completion
        
        super.init(
            context: context,
            component: CreateLinkSheetComponent(
                context: context,
                link: link
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .dark
        )
        
        self.navigationPresentation = .flatModal
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let view = self.node.hostView.findTaggedView(tag: linkTag) as? LinkFieldComponent.View {
            view.activateInput()
        }
    }
        
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class LinkFieldComponent: Component {
    typealias EnvironmentType = Empty
    
    let textColor: UIColor
    let placeholderColor: UIColor
    let text: String
    let link: Bool
    let placeholderText: String
    let textUpdated: (String) -> Void
    let textReturned: () -> Void
    let tag: AnyObject?
    
    init(
        textColor: UIColor,
        placeholderColor: UIColor,
        text: String,
        link: Bool,
        placeholderText: String,
        textUpdated: @escaping (String) -> Void,
        textReturned: @escaping () -> Void,
        tag: AnyObject? = nil
    ) {
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.text = text
        self.link = link
        self.placeholderText = placeholderText
        self.textUpdated = textUpdated
        self.textReturned = textReturned
        self.tag = tag
    }
    
    static func ==(lhs: LinkFieldComponent, rhs: LinkFieldComponent) -> Bool {
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.placeholderText != rhs.placeholderText {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let placeholderView: ComponentView<Empty>
        private let textField: TextFieldNodeView
        
        private var component: LinkFieldComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.placeholderView = ComponentView<Empty>()
            self.textField = TextFieldNodeView(frame: .zero)

            super.init(frame: frame)

            self.textField.delegate = self
            self.textField.addTarget(self, action: #selector(self.textChanged(_:)), for: .editingChanged)
            
            self.addSubview(self.textField)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func textChanged(_ sender: Any) {
            let text = self.textField.text ?? ""
            self.component?.textUpdated(text)
            self.placeholderView.view?.isHidden = !text.isEmpty
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string == "\n" {
                self.component?.textReturned()
                return false
            }
            
            let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            if let component = self.component, !component.link && newText.count > 48 {
                self.animateError()
                return false
            }
            return true
        }
        
        func activateInput() {
            self.textField.becomeFirstResponder()
        }
        
        func selectAll() {
            self.textField.selectAll(nil)
        }
        
        func animateError() {
            self.textField.layer.addShakeAnimation()
            let hapticFeedback = HapticFeedback()
            hapticFeedback.error()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                let _ = hapticFeedback
            })
        }
        
        func update(component: LinkFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.textField.textColor = component.textColor
            self.textField.text = component.text
            self.textField.font = Font.regular(17.0)
            self.textField.keyboardAppearance = .dark
            
            if component.link {
                self.textField.keyboardType = .default
                self.textField.returnKeyType = .next
                self.textField.autocorrectionType = .no
                self.textField.autocapitalizationType = .none
                self.textField.textContentType = .URL
            } else {
                self.textField.returnKeyType = .done
            }
            
            self.component = component
            self.state = state
                        
            let placeholderSize = self.placeholderView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(
                    Text(
                        text: component.placeholderText,
                        font: Font.regular(17.0),
                        color: component.placeholderColor
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let size = CGSize(width: availableSize.width, height: 44.0)
            if let placeholderComponentView = self.placeholderView.view {
                if placeholderComponentView.superview == nil {
                    self.insertSubview(placeholderComponentView, at: 0)
                }
                
                placeholderComponentView.frame = CGRect(origin: CGPoint(x: 15.0, y: floorToScreenPixels((size.height - placeholderSize.height) / 2.0) + 1.0 - UIScreenPixel), size: placeholderSize)
                
                placeholderComponentView.isHidden = !component.text.isEmpty
            }
            
            self.textField.frame = CGRect(x: 15.0, y: 0.0, width: size.width - 30.0, height: 44.0)
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class LinkPreviewComponent: Component {
    typealias EnvironmentType = Empty
    
    let webpage: TelegramMediaWebpage
    let theme: PresentationTheme
    let strings: PresentationStrings
    let presentLinkOptions: (ASDisplayNode) -> Void
    let dismiss: () -> Void
    
    init(
        webpage: TelegramMediaWebpage,
        theme: PresentationTheme,
        strings: PresentationStrings,
        presentLinkOptions: @escaping (ASDisplayNode) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.webpage = webpage
        self.theme = theme
        self.strings = strings
        self.presentLinkOptions = presentLinkOptions
        self.dismiss = dismiss
    }
    
    static func ==(lhs: LinkPreviewComponent, rhs: LinkPreviewComponent) -> Bool {
        if lhs.webpage != rhs.webpage {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate {
        let closeButton: HighlightableButtonNode
        let lineNode: ASImageNode
        let iconView: UIImageView
        let titleNode: TextNode
        private var titleString: NSAttributedString?
        
        let textNode: TextNode
        private var textString: NSAttributedString?
        
        private var component: LinkPreviewComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.closeButton = HighlightableButtonNode()

            self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
            self.closeButton.displaysAsynchronously = false
            
            self.lineNode = ASImageNode()
            self.lineNode.displayWithoutProcessing = true
            self.lineNode.displaysAsynchronously = false
            
            self.iconView = UIImageView()
            self.iconView.image = UIImage(bundleImageName: "Chat/Input/Accessory Panels/LinkSettingsIcon")?.withRenderingMode(.alwaysTemplate)
            
            self.titleNode = TextNode()
            self.titleNode.displaysAsynchronously = false
            
            self.textNode = TextNode()
            self.textNode.displaysAsynchronously = false
            
            super.init(frame: frame)
            
            self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
            self.addSubnode(self.closeButton)
            
            self.addSubnode(self.lineNode)
            self.addSubview(self.iconView)
            self.addSubnode(self.titleNode)
            self.addSubnode(self.textNode)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func closePressed() {
            guard let component = self.component else {
                return
            }
            component.dismiss()
        }
        
        private var previousTapTimestamp: Double?
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, let component = self.component {
                let timestamp = CFAbsoluteTimeGetCurrent()
                if let previousTapTimestamp = self.previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                    return
                }
                self.previousTapTimestamp = CFAbsoluteTimeGetCurrent()
                component.presentLinkOptions(self.textNode)
            }
        }

        func update(component: LinkPreviewComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(component.theme), for: [])
                self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(component.theme)
                self.iconView.tintColor = component.theme.chat.inputPanel.panelControlAccentColor
            }
            
            let bounds = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 45.0))
                        
            var authorName = ""
            var text = ""
            switch component.webpage.content {
                case .Pending:
                    authorName = component.strings.Channel_NotificationLoading
                    text = ""//component.url
                case let .Loaded(content):
                    if let contentText = content.text {
                        text = contentText
                    } else {
                        if let file = content.file, let mediaKind = mediaContentKind(EngineMedia(file)) {
                            if content.type == "telegram_background" {
                                text = component.strings.Message_Wallpaper
                            } else if content.type == "telegram_theme" {
                                text = component.strings.Message_Theme
                            } else {
                                text = stringForMediaKind(mediaKind, strings: component.strings).0.string
                            }
                        } else if content.type == "telegram_theme" {
                            text = component.strings.Message_Theme
                        } else if content.type == "video" {
                            text = stringForMediaKind(.video, strings: component.strings).0.string
                        } else if content.type == "telegram_story" {
                            text = stringForMediaKind(.story, strings: component.strings).0.string
                        } else if let _ = content.image {
                            text = stringForMediaKind(.image, strings: component.strings).0.string
                        }
                    }
                    
                    if let title = content.title {
                        authorName = title
                    } else if let websiteName = content.websiteName {
                        authorName = websiteName
                    } else {
                        authorName = content.displayUrl
                    }
                
            }
            
            self.titleString = NSAttributedString(string: authorName, font: Font.medium(15.0), textColor: component.theme.chat.inputPanel.panelControlAccentColor)
            self.textString = NSAttributedString(string: text, font: Font.regular(15.0), textColor: component.theme.chat.inputPanel.primaryTextColor)
                        
            let inset: CGFloat = 0.0
            let leftInset: CGFloat = 55.0
            let textLineInset: CGFloat = 10.0
            let rightInset: CGFloat = 55.0
            let textRightInset: CGFloat = 20.0
            
            let closeButtonSize = CGSize(width: 44.0, height: bounds.height)
            self.closeButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - closeButtonSize.width - inset, y: 2.0), size: closeButtonSize)
            
            self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
            
            if let icon = self.iconView.image {
                self.iconView.frame = CGRect(origin: CGPoint(x: 7.0 + inset, y: 10.0), size: icon.size)
            }
            
            let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
            let makeTextLayout = TextNode.asyncLayout(self.textNode)
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: self.titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: self.textString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 7.0), size: titleLayout.size)
            
            self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 25.0), size: textLayout.size)
            
            let _ = titleApply()
            let _ = textApply()
            
            return bounds.size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
