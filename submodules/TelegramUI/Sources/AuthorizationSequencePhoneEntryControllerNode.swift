import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import PhoneInputNode
import CountrySelectionUI
import AuthorizationUI
import QrCode
import SwiftSignalKit
import Postbox
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode

private final class PhoneAndCountryNode: ASDisplayNode {
    let strings: PresentationStrings
    let countryButton: ASButtonNode
    let phoneBackground: ASImageNode
    let phoneInputNode: PhoneInputNode
    
    var selectCountryCode: (() -> Void)?
    var checkPhone: (() -> Void)?
    
    var preferredCountryIdForCode: [String: String] = [:]
    
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        
        let inset: CGFloat = 24.0
        
        let countryButtonBackground = generateImage(CGSize(width: 136.0, height: 67.0), rotatedContext: { size, context in
            let arrowSize: CGFloat = 10.0
            let lineWidth = UIScreenPixel
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: CGPoint(x: inset, y: lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width - inset, y: lineWidth / 2.0))
            context.strokePath()
            
            context.move(to: CGPoint(x: size.width - inset, y: size.height - arrowSize - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: 69.0, y: size.height - arrowSize - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: 69.0 - arrowSize, y: size.height - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: 69.0 - arrowSize - arrowSize, y: size.height - arrowSize - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: inset, y: size.height - arrowSize - lineWidth / 2.0))
            context.strokePath()
        })?.stretchableImage(withLeftCapWidth: 69, topCapHeight: 1)
        
        let countryButtonHighlightedBackground = generateImage(CGSize(width: 70.0, height: 67.0), rotatedContext: { size, context in
            let arrowSize: CGFloat = 10.0
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.list.itemHighlightedBackgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height - arrowSize)))
            context.move(to: CGPoint(x: size.width, y: size.height - arrowSize))
            context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize))
            context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height))
            context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize))
            context.closePath()
            context.fillPath()
        })?.stretchableImage(withLeftCapWidth: 69, topCapHeight: 2)
        
        let phoneInputBackground = generateImage(CGSize(width: 96.0, height: 57.0), rotatedContext: { size, context in
            let lineWidth = UIScreenPixel
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: CGPoint(x: inset, y: size.height - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth / 2.0))
            context.strokePath()
            context.move(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: size.height - 9.0))
            context.addLine(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: 8.0))
            context.strokePath()
        })?.stretchableImage(withLeftCapWidth: 95, topCapHeight: 2)
        
        self.countryButton = ASButtonNode()
        self.countryButton.displaysAsynchronously = false
        self.countryButton.setBackgroundImage(countryButtonBackground, for: [])
        self.countryButton.titleNode.maximumNumberOfLines = 1
        self.countryButton.titleNode.truncationMode = .byTruncatingTail
        self.countryButton.setBackgroundImage(countryButtonHighlightedBackground, for: .highlighted)
        
        self.phoneBackground = ASImageNode()
        self.phoneBackground.image = phoneInputBackground
        self.phoneBackground.displaysAsynchronously = false
        self.phoneBackground.displayWithoutProcessing = true
        self.phoneBackground.isLayerBacked = true
        
        self.phoneInputNode = PhoneInputNode()
        
        super.init()
        
        self.addSubnode(self.phoneBackground)
        self.addSubnode(self.countryButton)
        self.addSubnode(self.phoneInputNode)
        
        self.phoneInputNode.countryCodeField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.phoneInputNode.numberField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.phoneInputNode.countryCodeField.textField.textColor = theme.list.itemPrimaryTextColor
        self.phoneInputNode.numberField.textField.textColor = theme.list.itemPrimaryTextColor
        self.phoneInputNode.countryCodeField.textField.tintColor = theme.list.itemAccentColor
        self.phoneInputNode.numberField.textField.tintColor = theme.list.itemAccentColor
        
        self.phoneInputNode.countryCodeField.textField.tintColor = theme.list.itemAccentColor
        self.phoneInputNode.numberField.textField.tintColor = theme.list.itemAccentColor
        
        self.phoneInputNode.countryCodeField.textField.disableAutomaticKeyboardHandling = [.forward]
        self.phoneInputNode.numberField.textField.disableAutomaticKeyboardHandling = [.forward]
        
        self.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 24.0 + 16.0, bottom: 10.0, right: 0.0)
        self.countryButton.contentHorizontalAlignment = .left
        
        self.countryButton.addTarget(self, action: #selector(self.countryPressed), forControlEvents: .touchUpInside)
        
        let processNumberChange: (String) -> Bool = { [weak self] number in
            guard let strongSelf = self else {
                return false
            }
            if let (country, _) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(number, preferredCountries: strongSelf.preferredCountryIdForCode) {
                let flagString = emojiFlagForISOCountryCode(country.id)
                let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(country.id, strings: strongSelf.strings) ?? country.name
                strongSelf.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(20.0), with: theme.list.itemAccentColor, for: [])
                
                let maskFont = Font.with(size: 20.0, design: .regular, traits: [.monospacedNumbers])
                if let mask = AuthorizationSequenceCountrySelectionController.lookupPatternByNumber(number, preferredCountries: strongSelf.preferredCountryIdForCode).flatMap({ NSAttributedString(string: $0, font: maskFont, textColor: theme.list.itemPlaceholderTextColor) }) {
                    strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = nil
                    strongSelf.phoneInputNode.mask = mask
                } else {
                    strongSelf.phoneInputNode.mask = nil
                    strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: strings.Login_PhonePlaceholder, font: Font.regular(20.0), textColor: theme.list.itemPlaceholderTextColor)
                }
                return true
            } else {
                return false
            }
        }
        
        self.phoneInputNode.numberTextUpdated = { [weak self] number in
            if let strongSelf = self {
                let _ = processNumberChange(strongSelf.phoneInputNode.number)
            }
        }
        
        self.phoneInputNode.countryCodeUpdated = { [weak self] code, name in
            if let strongSelf = self {
                if let name = name {
                    strongSelf.preferredCountryIdForCode[code] = name
                }
                
                if processNumberChange(strongSelf.phoneInputNode.number) {
                } else if let code = Int(code), let name = name, let countryName = countryCodeAndIdToName[CountryCodeAndId(code: code, id: name)] {
                    let flagString = emojiFlagForISOCountryCode(name)
                    let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(name, strings: strongSelf.strings) ?? countryName
                    strongSelf.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(20.0), with: theme.list.itemAccentColor, for: [])
                    
                    if strongSelf.phoneInputNode.mask == nil {
                        strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: strings.Login_PhonePlaceholder, font: Font.regular(20.0), textColor: theme.list.itemPlaceholderTextColor)
                    }
                } else if let code = Int(code), let (countryId, countryName) = countryCodeToIdAndName[code] {
                    let flagString = emojiFlagForISOCountryCode(countryId)
                    let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(countryId, strings: strongSelf.strings) ?? countryName
                    strongSelf.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(20.0), with: theme.list.itemAccentColor, for: [])
                    
                    if strongSelf.phoneInputNode.mask == nil {
                        strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: strings.Login_PhonePlaceholder, font: Font.regular(20.0), textColor: theme.list.itemPlaceholderTextColor)
                    }
                } else {
                    strongSelf.countryButton.setTitle(strings.Login_SelectCountry, with: Font.regular(20.0), with: theme.list.itemAccentColor, for: [])
                    strongSelf.phoneInputNode.mask = nil
                    strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: strings.Login_PhonePlaceholder, font: Font.regular(20.0), textColor: theme.list.itemPlaceholderTextColor)
                }
            }
        }
        
        self.phoneInputNode.customFormatter = { number in
            if let (_, code) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(number, preferredCountries: [:]) {
                return code.code
            } else {
                return nil
            }
        }
        
        self.phoneInputNode.number = "+1"
        self.phoneInputNode.returnAction = { [weak self] in
            self?.checkPhone?()
        }
    }
    
    @objc func countryPressed() {
        self.selectCountryCode?()
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset: CGFloat = 24.0
        
        self.countryButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 67.0))
        self.phoneBackground.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - 57.0), size: CGSize(width: size.width - inset, height: 57.0))
        
        let countryCodeFrame = CGRect(origin: CGPoint(x: 18.0, y: size.height - 58.0), size: CGSize(width: 71.0, height: 57.0))
        let numberFrame = CGRect(origin: CGPoint(x: 107.0, y: size.height - 58.0), size: CGSize(width: size.width - 96.0 - 8.0, height: 57.0))
        let placeholderFrame = numberFrame.offsetBy(dx: 0.0, dy: 17.0 - UIScreenPixel)
        
        let phoneInputFrame = countryCodeFrame.union(numberFrame)
        
        self.phoneInputNode.frame = phoneInputFrame
        self.phoneInputNode.countryCodeField.frame = countryCodeFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
        self.phoneInputNode.numberField.frame = numberFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
        self.phoneInputNode.placeholderNode.frame = placeholderFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
    }
}

private final class ContactSyncNode: ASDisplayNode {
    private let titleNode: ImmediateTextNode
    let switchNode: SwitchNode
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: strings.Privacy_ContactsSync, font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
        self.switchNode = SwitchNode()
        self.switchNode.frameColor = theme.list.itemSwitchColors.frameColor
        self.switchNode.contentColor = theme.list.itemSwitchColors.contentColor
        self.switchNode.handleColor = theme.list.itemSwitchColors.handleColor
        self.switchNode.isOn = true
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.switchNode)
    }
    
    func updateLayout(width: CGFloat) -> CGSize {
        let switchSize = CGSize(width: 51.0, height: 31.0)
        let inset: CGFloat = 24.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - switchSize.width - inset * 2.0 - 8.0, height: .greatestFiniteMagnitude))
        let height: CGFloat = 40.0
        self.titleNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        self.switchNode.frame = CGRect(origin: CGPoint(x: width - inset - switchSize.width, y: floor((height - switchSize.height) / 2.0)), size: switchSize)
        return CGSize(width: width, height: height)
    }
}

final class AuthorizationSequencePhoneEntryControllerNode: ASDisplayNode {
    private let sharedContext: SharedAccountContext
    private var account: UnauthorizedAccount
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    private let hasOtherAccounts: Bool
    
    private let animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    private let phoneAndCountryNode: PhoneAndCountryNode
    private let contactSyncNode: ContactSyncNode
    private let proceedNode: SolidRoundedButtonNode
    
    private var qrNode: ASImageNode?
    private let exportTokenDisposable = MetaDisposable()
    private let tokenEventsDisposable = MetaDisposable()
    var accountUpdated: ((UnauthorizedAccount) -> Void)?
    
    private let debugAction: () -> Void
    
    var currentNumber: String {
        return self.phoneAndCountryNode.phoneInputNode.number
    }
    
    var codeAndNumber: (Int32?, String?, String) {
        get {
            return self.phoneAndCountryNode.phoneInputNode.codeAndNumber
        } set(value) {
            self.phoneAndCountryNode.phoneInputNode.codeAndNumber = value
        }
    }
    
    var syncContacts: Bool {
        get {
            if self.hasOtherAccounts {
                return self.contactSyncNode.switchNode.isOn
            } else {
                return true
            }
        }
    }
    
    var selectCountryCode: (() -> Void)?
    var checkPhone: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.phoneAndCountryNode.phoneInputNode.enableEditing = !self.inProgress
            self.phoneAndCountryNode.phoneInputNode.alpha = self.inProgress ? 0.6 : 1.0
            self.phoneAndCountryNode.countryButton.isEnabled = !self.inProgress
            
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
                } else {
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }
    
    init(sharedContext: SharedAccountContext, account: UnauthorizedAccount, strings: PresentationStrings, theme: PresentationTheme, debugAction: @escaping () -> Void, hasOtherAccounts: Bool) {
        self.sharedContext = sharedContext
        self.account = account
        
        self.strings = strings
        self.theme = theme
        self.debugAction = debugAction
        self.hasOtherAccounts = hasOtherAccounts
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "IntroPhone"), width: 256, height: 256, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = true
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: strings.Login_PhoneTitle, font: Font.light(30.0), textColor: theme.list.itemPrimaryTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.maximumNumberOfLines = 0
        self.noticeNode.isUserInteractionEnabled = true
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.lineSpacing = 0.1
        self.noticeNode.attributedText = NSAttributedString(string: strings.Login_PhoneAndCountryHelp, font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        self.contactSyncNode = ContactSyncNode(theme: theme, strings: strings)
        
        self.phoneAndCountryNode = PhoneAndCountryNode(strings: strings, theme: theme)
        
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: SolidRoundedButtonTheme(theme: self.theme), height: 50.0, cornerRadius: 11.0, gloss: false)
        self.proceedNode.progressType = .embedded
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.list.plainBackgroundColor
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.phoneAndCountryNode)
        self.addSubnode(self.contactSyncNode)
        self.addSubnode(self.proceedNode)
        self.addSubnode(self.animationNode)
        self.contactSyncNode.isHidden = true
        
        self.phoneAndCountryNode.selectCountryCode = { [weak self] in
            self?.selectCountryCode?()
        }
        self.phoneAndCountryNode.checkPhone = { [weak self] in
            self?.checkPhone?()
        }
        
        self.tokenEventsDisposable.set((account.updateLoginTokenEvents
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.refreshQrToken()
        }))
        
        self.proceedNode.pressed = { [weak self] in
            self?.checkPhone?()
        }
    }
    
    deinit {
        self.exportTokenDisposable.dispose()
        self.tokenEventsDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.titleNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.debugTap(_:))))
        #if DEBUG
        self.noticeNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.debugQrTap(_:))))
        #endif
    }
    
    private var animationSnapshotView: UIView?
    private var textSnapshotView: UIView?
    private var forcedButtonFrame: CGRect?
    
    func willAnimateIn(buttonFrame: CGRect, animationSnapshot: UIView, textSnapshot: UIView) {
        self.proceedNode.frame = buttonFrame
        self.proceedNode.title = "Start Messaging"
        
        self.animationSnapshotView = animationSnapshot
        self.view.insertSubview(animationSnapshot, at: 0)
        
        self.textSnapshotView = textSnapshot
        self.view.insertSubview(textSnapshot, at: 0)
        
        let nodes: [ASDisplayNode] = [
            self.animationNode,
            self.titleNode,
            self.noticeNode,
            self.phoneAndCountryNode,
            self.contactSyncNode
        ]

        for node in nodes {
            node.alpha = 0.0
        }
    }
    
    func animateIn(buttonFrame: CGRect, animationSnapshot: UIView, textSnapshot: UIView) {
        self.proceedNode.animateTitle(to: self.strings.Login_Continue)
        
        let duration: Double = 0.3
        
        self.animationSnapshotView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?.animationSnapshotView?.removeFromSuperview()
            self?.animationSnapshotView = nil
        })
        self.animationSnapshotView?.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -100.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
       
        self.textSnapshotView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?.textSnapshotView?.removeFromSuperview()
            self?.textSnapshotView = nil
        })
        self.textSnapshotView?.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -140.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
    
        let nodes: [ASDisplayNode] = [
            self.animationNode,
            self.titleNode,
            self.noticeNode,
            self.phoneAndCountryNode,
            self.contactSyncNode
        ]

        for node in nodes {
            node.alpha = 1.0
            node.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
    }
    
    func updateCountryCode() {
        self.phoneAndCountryNode.phoneInputNode.codeAndNumber = self.codeAndNumber
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [])
        insets.top = layout.statusBarHeight ?? 20.0
        
        if let inputHeight = layout.inputHeight, !inputHeight.isZero {
            insets.bottom = max(inputHeight, insets.bottom)
        }
        
        self.titleNode.attributedText = NSAttributedString(string: strings.Login_PhoneTitle, font: Font.bold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        let inset: CGFloat = 24.0
        
        let animationSize = CGSize(width: 100.0, height: 100.0)
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let noticeSize = self.noticeNode.measure(CGSize(width: min(274.0, layout.size.width - 28.0), height: CGFloat.greatestFiniteMagnitude))
        let proceedHeight = self.proceedNode.updateLayout(width: layout.size.width - inset * 2.0, transition: transition)
        let proceedSize = CGSize(width: layout.size.width - inset * 2.0, height: proceedHeight)
        
        var items: [AuthorizationLayoutItem] = [
            AuthorizationLayoutItem(node: self.animationNode, size: animationSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.phoneAndCountryNode, size: CGSize(width: layout.size.width, height: 115.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 30.0, maxValue: 30.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
        ]
        let contactSyncSize = self.contactSyncNode.updateLayout(width: layout.size.width)
        if self.hasOtherAccounts {
            self.contactSyncNode.isHidden = false
            items.append(AuthorizationLayoutItem(node: self.contactSyncNode, size: contactSyncSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 14.0, maxValue: 14.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        } else {
            self.contactSyncNode.isHidden = true
        }
        
        let buttonFrame: CGRect
        if let forcedButtonFrame = self.forcedButtonFrame, (layout.inputHeight ?? 0.0).isZero {
            buttonFrame = forcedButtonFrame
        } else {
            buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize)
        }
        
        transition.updateFrame(node: self.proceedNode, frame: buttonFrame)
        
        self.animationNode.updateLayout(size: animationSize)
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 80.0)), items: items, transition: transition, failIfDoesNotFit: false)
    }
    
    func activateInput() {
        self.phoneAndCountryNode.phoneInputNode.numberField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.phoneAndCountryNode.phoneInputNode.countryCodeField.layer.addShakeAnimation()
        self.phoneAndCountryNode.phoneInputNode.numberField.layer.addShakeAnimation()
    }
    
    private var debugTapCounter: (Double, Int) = (0.0, 0)
    @objc private func debugTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let timestamp = CACurrentMediaTime()
            if self.debugTapCounter.0 < timestamp - 0.4 {
                self.debugTapCounter.0 = timestamp
                self.debugTapCounter.1 = 0
            }
            
            if self.debugTapCounter.0 >= timestamp - 0.4 {
                self.debugTapCounter.0 = timestamp
                self.debugTapCounter.1 += 1
            }
            
            if self.debugTapCounter.1 >= 10 {
                self.debugTapCounter.1 = 0
                
                self.debugAction()
            }
        }
    }
    
    @objc private func debugQrTap(_ recognizer: UITapGestureRecognizer) {
        if self.qrNode == nil {
            let qrNode = ASImageNode()
            qrNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 64.0 + 16.0), size: CGSize(width: 200.0, height: 200.0))
            self.qrNode = qrNode
            self.addSubnode(qrNode)
            
            self.refreshQrToken()
        }
    }
    
    private func refreshQrToken() {
        let sharedContext = self.sharedContext
        let account = self.account
        let tokenSignal = sharedContext.activeAccountContexts
        |> castError(ExportAuthTransferTokenError.self)
        |> take(1)
        |> mapToSignal { activeAccountsAndInfo -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
            let (_, activeAccounts, _) = activeAccountsAndInfo
            let activeProductionUserIds = activeAccounts.map({ $0.1.account }).filter({ !$0.testingEnvironment }).map({ $0.peerId.id })
            let activeTestingUserIds = activeAccounts.map({ $0.1.account }).filter({ $0.testingEnvironment }).map({ $0.peerId.id })
            
            let allProductionUserIds = activeProductionUserIds
            let allTestingUserIds = activeTestingUserIds
            
            return TelegramEngineUnauthorized(account: account).auth.exportAuthTransferToken(accountManager: sharedContext.accountManager, otherAccountUserIds: account.testingEnvironment ? allTestingUserIds : allProductionUserIds, syncContacts: true)
        }
        
        self.exportTokenDisposable.set((tokenSignal
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case let .displayToken(token):
                var tokenString = token.value.base64EncodedString()
                print("export token \(tokenString)")
                tokenString = tokenString.replacingOccurrences(of: "+", with: "-")
                tokenString = tokenString.replacingOccurrences(of: "/", with: "_")
                let urlString = "tg://login?token=\(tokenString)"
                let _ = (qrCode(string: urlString, color: .black, backgroundColor: .white, icon: .none)
                |> deliverOnMainQueue).start(next: { _, generate in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let context = generate(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: 200.0, height: 200.0), boundingSize: CGSize(width: 200.0, height: 200.0), intrinsicInsets: UIEdgeInsets()))
                    if let image = context?.generateImage() {
                        strongSelf.qrNode?.image = image
                    }
                })
                
                let timestamp = Int32(Date().timeIntervalSince1970)
                let timeout = max(5, token.validUntil - timestamp)
                strongSelf.exportTokenDisposable.set((Signal<Never, NoError>.complete()
                |> delay(Double(timeout), queue: .mainQueue())).start(completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.refreshQrToken()
                }))
            case let .changeAccountAndRetry(account):
                strongSelf.exportTokenDisposable.set(nil)
                strongSelf.account = account
                strongSelf.accountUpdated?(account)
                strongSelf.tokenEventsDisposable.set((account.updateLoginTokenEvents
                |> deliverOnMainQueue).start(next: { _ in
                    self?.refreshQrToken()
                }))
                strongSelf.refreshQrToken()
            case .loggedIn, .passwordRequested:
                strongSelf.exportTokenDisposable.set(nil)
            }
        }))
    }
}
