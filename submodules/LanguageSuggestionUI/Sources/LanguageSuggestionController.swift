import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ActivityIndicator
import AccountContext
import AppBundle

public struct LanguageSuggestionControllerStrings {
    let ChooseLanguage: String
    let Other: String
    let English: String
    
    public init(localization: SuggestedLocalizationInfo) {
        var chooseLanguage = "Choose Your Language"
        var other = "Other"
        var english = "English"
        
        for entry in localization.extractedEntries {
            switch entry {
                case let .string(key, value):
                    switch key {
                        case "Localization.ChooseLanguage":
                            chooseLanguage = value
                        case "Localization.LanguageOther":
                            other = value
                        case "Localization.EnglishLanguageName":
                            english = value
                        default:
                            break
                    }
                default:
                    break
            }
        }
        
        self.ChooseLanguage = chooseLanguage
        self.Other = other
        self.English = english
    }

    public init(bundle: Bundle?) {
        var chooseLanguage = "Choose Your Language"
        var other = "Other"
        var english = "English"
        
        if let bundle = bundle {
            for key in LanguageSuggestionControllerStrings.keys {
                let value = bundle.localizedString(forKey: key, value: nil, table: nil)
                if value != key {
                    switch key {
                        case "Localization.ChooseLanguage":
                            chooseLanguage = value
                        case "Localization.LanguageOther":
                            other = value
                        case "Localization.EnglishLanguageName":
                            english = value
                        default:
                            break
                    }
                }
            }
        }
        
        self.ChooseLanguage = chooseLanguage
        self.Other = other
        self.English = english
    }
    
    public static let keys: [String] = [
        "Localization.ChooseLanguage",
        "Localization.LanguageOther",
        "Localization.EnglishLanguageName"
    ]
}

private enum LanguageSuggestionItemType {
    case localization(String)
    case disclosure
    case action
}

private struct LanguageSuggestionItem {
    public let type: LanguageSuggestionItemType
    public let title: String
    public let subtitle: String?
    public let action: () -> Void
    
    public init(type: LanguageSuggestionItemType, title: String, subtitle: String?, action: @escaping () -> Void) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
}

private final class LanguageSuggestionItemNode: HighlightableButtonNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let subtitleNode: ASTextNode
    private let iconNode: ASImageNode
    
    let item: LanguageSuggestionItem
    
    override var isSelected: Bool {
        didSet {
            if case .localization = self.item.type {
                self.iconNode.isHidden = !self.isSelected
            }
        }
    }
    
    init(theme: PresentationTheme, item: LanguageSuggestionItem) {
        self.item = item
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.backgroundNode.alpha = 0.0
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.actionSheet.opaqueItemSeparatorColor
        
        self.subtitleNode = ASTextNode()
        
        self.iconNode = ASImageNode()
    
        super.init()
        
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
        
        var color: UIColor = theme.actionSheet.primaryTextColor
        var alignment: ASHorizontalAlignment = .left
        var inset: CGFloat = 19.0
        var icon: UIImage?
        switch item.type {
            case .action:
                alignment = .middle
                color = theme.actionSheet.controlAccentColor
                inset = 0.0
            case .disclosure:
                icon = PresentationResourcesItemList.disclosureArrowImage(theme)
            case .localization:
                icon = PresentationResourcesItemList.checkIconImage(theme)
        }
        
        self.iconNode.image = icon
        self.contentHorizontalAlignment = alignment
        self.setTitle(item.title, with: Font.regular(17.0), with: color, for: [])
        
        var titleVerticalOffset: CGFloat = 0.0
        if let subtitle = item.subtitle {
            self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(14.0), textColor: theme.actionSheet.secondaryTextColor)
            titleVerticalOffset = 20.0
        }
        self.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: inset, bottom: titleVerticalOffset, right: 0.0)
        
        self.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                if value {
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 1.0
                } else if !strongSelf.backgroundNode.alpha.isZero {
                    strongSelf.backgroundNode.alpha = 0.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc func pressed() {
        self.item.action()
    }
    
    public func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: constrainedSize.width, height: self.item.subtitle != nil ? 58.0 : 44.0))
        self.backgroundNode.frame = bounds
        
        let subtitleSize = self.subtitleNode.measure(bounds.size)
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: 19.0, y: 31.0), size: subtitleSize)
        self.separatorNode.frame = CGRect(x: 0.0, y: bounds.height - UIScreenPixel, width: bounds.width, height: UIScreenPixel)
        if let icon = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: bounds.width - icon.size.width - 19.0, y: floorToScreenPixels((bounds.height - icon.size.height) / 2.0)), size: icon.size)
        }
        return bounds.size
    }
}

private final class LanguageSuggestionAlertContentNode: AlertContentNode {
    private var validLayout: CGSize?
    
    private let titleNode: ASTextNode
    private let subtitleNode: ASTextNode
    private let titleSeparatorNode: ASDisplayNode
    private let activityIndicator: ActivityIndicator
    
    private var nodes: [LanguageSuggestionItemNode]
    
    private let disposable = MetaDisposable()
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(presentationData: PresentationData, strings: LanguageSuggestionControllerStrings, englishStrings: LanguageSuggestionControllerStrings, suggestedLocalization: LocalizationInfo, openSelection: @escaping () -> Void, applyLocalization: @escaping (String, () -> Void) -> Void, dismiss: @escaping () -> Void) {
        let selectedLocalization = ValuePromise(suggestedLocalization.languageCode, ignoreRepeated: true)
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: strings.ChooseLanguage, font: Font.bold(presentationData.listsFontSize.baseDisplaySize), textColor: presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        self.titleNode.maximumNumberOfLines = 2
        
        self.subtitleNode = ASTextNode()
        self.subtitleNode.attributedText = NSAttributedString(string: englishStrings.ChooseLanguage, font: Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0)), textColor: presentationData.theme.actionSheet.secondaryTextColor, paragraphAlignment: .center)
        self.subtitleNode.maximumNumberOfLines = 2
        
        self.titleSeparatorNode = ASDisplayNode()
        self.titleSeparatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor
        
        self.activityIndicator = ActivityIndicator(type: .custom(presentationData.theme.actionSheet.controlAccentColor, 22.0, 1.0, false))
        self.activityIndicator.isHidden = true
        
        var items: [LanguageSuggestionItem] = []
        items.append(LanguageSuggestionItem(type: .localization(suggestedLocalization.languageCode), title: suggestedLocalization.localizedTitle, subtitle: suggestedLocalization.title, action: {
                selectedLocalization.set(suggestedLocalization.languageCode)
        }))
        items.append(LanguageSuggestionItem(type: .localization("en"), title: strings.English, subtitle: englishStrings.English, action: {
            selectedLocalization.set("en")
        }))
        items.append(LanguageSuggestionItem(type: .disclosure, title: strings.Other, subtitle: englishStrings.Other != strings.Other ? englishStrings.Other : nil, action: {
            openSelection()
        }))
        
        var applyImpl: (() -> Void)?
        items.append(LanguageSuggestionItem(type: .action, title: "OK", subtitle: nil, action: {
            applyImpl?()
        }))
        
        self.nodes = items.map { LanguageSuggestionItemNode(theme: presentationData.theme, item: $0) }
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.titleSeparatorNode)
        self.addSubnode(self.activityIndicator)
        for node in self.nodes {
            self.addSubnode(node)
        }
        
        self.disposable.set(selectedLocalization.get().start(next: { [weak self] selectedCode in
            if let strongSelf = self {
                for node in strongSelf.nodes {
                    if case let .localization(code) = node.item.type {
                        node.isSelected = code == selectedCode
                    }
                }
            }
        }))
        
        applyImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.isUserInteractionEnabled = false
                
                _ = (selectedLocalization.get()
                |> take(1)).start(next: { selectedCode in
                    applyLocalization(selectedCode, { [weak self] in
                        if let strongSelf = self {
                            strongSelf.activityIndicator.isHidden = false
                            if let lastNode = strongSelf.nodes.last {
                                lastNode.isHidden = true
                            }
                        }
                    })
                })
            }
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
 
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width, 270.0)
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 17.0)
        
        let titleSize = self.titleNode.measure(size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 3.0
        
        let subtitleSize = self.subtitleNode.measure(size)
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - subtitleSize.width) / 2.0), y: origin.y), size: subtitleSize))
        origin.y += subtitleSize.height + 17.0
        transition.updateFrame(node: self.titleSeparatorNode, frame: CGRect(x: 0.0, y: origin.y - UIScreenPixel, width: size.width, height: UIScreenPixel))
        
        var lastNodeSize: CGSize?
        for node in self.nodes {
            let size = node.updateLayout(size)
            transition.updateFrame(node: node, frame: CGRect(origin: origin, size: size))
            origin.y += size.height
            lastNodeSize = size
        }
        
        if let lastSize = lastNodeSize {
            let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
            transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - indicatorSize.width) / 2.0), y: origin.y - lastSize.height + floorToScreenPixels((lastSize.height - indicatorSize.height) / 2.0)), size: indicatorSize))
        }
        
        return CGSize(width: size.width, height: origin.y - UIScreenPixel)
    }
}

public func languageSuggestionController(context: AccountContext, suggestedLocalization: SuggestedLocalizationInfo, currentLanguageCode: String, openSelection: @escaping () -> Void) -> AlertController? {
    guard let localization = suggestedLocalization.availableLocalizations.filter({ $0.languageCode == suggestedLocalization.languageCode }).first else {
        return nil
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = LanguageSuggestionControllerStrings(localization: suggestedLocalization)
    guard let mainPath = getAppBundle().path(forResource: "en", ofType: "lproj") else {
        return nil
    }
    let englishStrings = LanguageSuggestionControllerStrings(bundle: Bundle(path: mainPath))
    
    let disposable = MetaDisposable()
    
    var dismissImpl: ((Bool) -> Void)?
    let contentNode = LanguageSuggestionAlertContentNode(presentationData: presentationData, strings: strings, englishStrings: englishStrings, suggestedLocalization: localization, openSelection: {
        dismissImpl?(true)
        openSelection()
    }, applyLocalization: { languageCode, startActivity in
        if languageCode == currentLanguageCode {
            dismissImpl?(true)
        } else {
            startActivity()
            disposable.set((context.engine.localization.downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, languageCode: languageCode)
            |> deliverOnMainQueue).start(completed: {
                dismissImpl?(true)
            }))
        }
    }, dismiss: {
        dismissImpl?(true)
    })
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
