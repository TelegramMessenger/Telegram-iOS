import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import MultilineTextComponent
import TelegramPresentationData
import AppBundle
import BundleIconComponent
import PlainButtonComponent
import Markdown
import TelegramCore
import AccountContext

public final class BirthdayPickerContentComponent: Component {
    public let context: AccountContext
    public let mode: BirthdayPickerScreen.Mode
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let settings: Signal<AccountPrivacySettings?, NoError>
    public let value: TelegramBirthday
    public let canHideYear: Bool
    public let updateValue: (TelegramBirthday) -> Void
    public let dismiss: () -> Void
    public let openSettings: () -> Void
    public let requestHideYear: (ComponentTransition) -> Void
    
    public init(
        context: AccountContext,
        mode: BirthdayPickerScreen.Mode,
        theme: PresentationTheme,
        strings: PresentationStrings,
        settings: Signal<AccountPrivacySettings?, NoError>,
        value: TelegramBirthday,
        canHideYear: Bool,
        updateValue: @escaping (TelegramBirthday) -> Void,
        dismiss: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        requestHideYear: @escaping (ComponentTransition) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.theme = theme
        self.strings = strings
        self.settings = settings
        self.value = value
        self.canHideYear = canHideYear
        self.updateValue = updateValue
        self.dismiss = dismiss
        self.openSettings = openSettings
        self.requestHideYear = requestHideYear
    }
    
    public static func ==(lhs: BirthdayPickerContentComponent, rhs: BirthdayPickerContentComponent) -> Bool {
        if lhs.mode != rhs.mode {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.canHideYear != rhs.canHideYear {
            return false
        }
        return true
    }
        
    public final class View: UIView {
        private let title = ComponentView<Empty>()
        private let picker = ComponentView<Empty>()
        private let mainText = ComponentView<Empty>()
        private let hideYear = ComponentView<Empty>()
        
        private var chevronImage: UIImage?
        
        private var component: BirthdayPickerContentComponent?
        private var state: EmptyComponentState?
        
        private var disposable: Disposable?
        private var settings: AccountPrivacySettings?
        private var peer: EnginePeer?
        
        private var isUpdating = false
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
    
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let result = super.hitTest(point, with: event) {
                return result
            } else {
                return nil
            }
        }
        
        func update(component: BirthdayPickerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                        
            self.component = component
            self.state = state
            
            if self.disposable == nil {
                let peer: Signal<EnginePeer?, NoError>
                if case let .suggest(peerId) = component.mode {
                    peer = component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                } else {
                    peer = .single(nil)
                }
                self.disposable = combineLatest(queue: Queue.mainQueue(),
                    component.settings,
                    peer
                ).start(next: { [weak self, weak state] settings, peer in
                    if let self {
                        self.settings = settings
                        self.peer = peer
                        if !self.isUpdating {
                            state?.updated()
                        }
                    }
                })
            }

            let sideInset: CGFloat = 16.0
        
            var contentHeight: CGFloat = 0.0
            
            let titleString = NSMutableAttributedString()
            let titleRawString: String
            if let peer = self.peer {
                var peerName = peer.compactDisplayTitle
                if peerName.count > 20 {
                    peerName = "\(peerName.prefix(20))…"
                }
                titleRawString = component.strings.SuggestBirthdate_Suggest_Title(peerName).string
            } else {
                titleRawString = component.strings.Birthday_Title
            }
            
            titleString.append(NSAttributedString(string: titleRawString, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
        
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleString),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize))
            }
            contentHeight += titleSize.height
            contentHeight += 16.0
            
            let pickerSize = self.picker.update(
                transition: transition,
                component: AnyComponent(BirthdayPickerComponent(
                    theme: BirthdayPickerComponent.Theme(presentationTheme: component.theme),
                    strings: component.strings,
                    value: component.value,
                    valueUpdated: { [weak self] value in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.updateValue(value)
                        if component.canHideYear && value.year == nil {
                            component.requestHideYear(.spring(duration: 0.4))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 226.0)
            )
            if let pickerView = self.picker.view {
                if pickerView.superview == nil {
                    self.addSubview(pickerView)
                }
                transition.setFrame(view: pickerView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - pickerSize.width) * 0.5), y: contentHeight), size: pickerSize))
            }
            contentHeight += pickerSize.height
            contentHeight += 8.0
        
            switch component.mode {
            case .generic:
                var isContacts = true
                if let settings = self.settings {
                    if case .enableContacts = settings.birthday {
                    } else {
                        isContacts = false
                    }
                }
                
                let mainText = NSMutableAttributedString()
                mainText.append(parseMarkdownIntoAttributedString(isContacts ? component.strings.Birthday_HelpContacts : component.strings.Birthday_Help, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(
                        font: Font.regular(13.0),
                        textColor: component.theme.list.itemSecondaryTextColor
                    ),
                    bold: MarkdownAttributeSet(
                        font: Font.semibold(13.0),
                        textColor: component.theme.list.itemSecondaryTextColor
                    ),
                    link: MarkdownAttributeSet(
                        font: Font.regular(13.0),
                        textColor: component.theme.list.itemAccentColor,
                        additionalAttributes: [:]
                    ),
                    linkAttribute: { attributes in
                        return ("URL", "")
                    }
                )))
                if self.chevronImage == nil {
                    self.chevronImage = UIImage(bundleImageName: "Contact List/SubtitleArrow")
                }
                if let range = mainText.string.range(of: ">"), let chevronImage = self.chevronImage {
                    mainText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: mainText.string))
                }
                
                let mainTextSize = self.mainText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(mainText),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2,
                        highlightColor: component.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                        highlightInset: mainText.string.contains(">") ? UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0) : .zero,
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                                return NSAttributedString.Key(rawValue: "URL")
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] _, _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.openSettings()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                if let mainTextView = self.mainText.view {
                    if mainTextView.superview == nil {
                        self.addSubview(mainTextView)
                    }
                    transition.setFrame(view: mainTextView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - mainTextSize.width) * 0.5), y: contentHeight), size: mainTextSize))
                }
                contentHeight += mainTextSize.height
                contentHeight += 12.0
            case .acceptSuggestion:
                if component.canHideYear {
                    contentHeight += 21.0
                    let hideYearSize = self.hideYear.update(
                        transition: .immediate,
                        component: AnyComponent(PlainButtonComponent(content: AnyComponent(Text(text: component.strings.SuggestBirthdate_Accept_HideYear, font: Font.regular(17.0), color: component.theme.list.itemAccentColor)), action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateValue(TelegramBirthday(day: component.value.day, month: component.value.month, year: nil))
                            component.requestHideYear(.spring(duration: 0.4).withUserData(BirthdayPickerComponent.TransitionHint(animate: true)))
                        }, animateScale: false)),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    if let hideYearView = self.hideYear.view {
                        if hideYearView.superview == nil {
                            self.addSubview(hideYearView)
                        }
                        transition.setFrame(view: hideYearView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - hideYearSize.width) * 0.5), y: contentHeight), size: hideYearSize))
                    }
                    contentHeight += hideYearSize.height
                    contentHeight += 20.0
                } else if let hideYearView = self.hideYear.view {
                    transition.setAlpha(view: hideYearView, alpha: 0.0, completion: { _ in
                        hideYearView.removeFromSuperview()
                    })
                }
            case .suggest:
                break
            }

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
