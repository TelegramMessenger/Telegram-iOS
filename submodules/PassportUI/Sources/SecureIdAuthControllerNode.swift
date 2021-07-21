import Foundation
import UIKit
import SwiftSignalKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ActivityIndicator
import AccountContext

final class SecureIdAuthControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let requestLayout: (ContainedViewLayoutTransition) -> Void
    private let interaction: SecureIdAuthControllerInteraction
    
    private var hapticFeedback: HapticFeedback?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let activityIndicator: ActivityIndicator
    private let scrollNode: ASScrollNode
    private let headerNode: SecureIdAuthHeaderNode
    private var contentNode: (ASDisplayNode & SecureIdAuthContentNode)?
    private var dismissedContentNode: (ASDisplayNode & SecureIdAuthContentNode)?
    private let acceptNode: SecureIdAuthAcceptNode
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private var state: SecureIdAuthControllerState?
    
    private let deleteValueDisposable = MetaDisposable()
    
    init(context: AccountContext, presentationData: PresentationData, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void, interaction: SecureIdAuthControllerInteraction) {
        self.context = context
        self.presentationData = presentationData
        self.requestLayout = requestLayout
        self.interaction = interaction
        
        self.activityIndicator = ActivityIndicator(type: .custom(presentationData.theme.list.freeMonoIconColor, 22.0, 2.0, false))
        self.activityIndicator.isHidden = true
        
        self.scrollNode = ASScrollNode()
        self.headerNode = SecureIdAuthHeaderNode(context: context, theme: presentationData.theme, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder)
        self.acceptNode = SecureIdAuthAcceptNode(title: presentationData.strings.Passport_Authorize, theme: presentationData.theme)
        
        super.init()
        
        self.addSubnode(self.activityIndicator)
        
        self.scrollNode.view.alwaysBounceVertical = true
        self.addSubnode(self.scrollNode)
        
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.acceptNode.pressed = { [weak self] in
            guard let strongSelf = self, let state = strongSelf.state, case let .form(form) = state, let encryptedFormData = form.encryptedFormData, let formData = form.formData else {
                return
            }
            
            for (field, _, filled) in parseRequestedFormFields(formData.requestedFields, values: formData.values, primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry) {
                if !filled {
                    if let contentNode = strongSelf.contentNode as? SecureIdAuthFormContentNode {
                        if let rect = contentNode.frameForField(field) {
                            let subRect = contentNode.view.convert(rect, to: strongSelf.scrollNode.view)
                            strongSelf.scrollNode.view.scrollRectToVisible(subRect, animated: true)
                        }
                        contentNode.highlightField(field)
                    }
                    if strongSelf.hapticFeedback == nil {
                        strongSelf.hapticFeedback = HapticFeedback()
                    }
                    strongSelf.hapticFeedback?.error()
                    return
                }
            }
            
            strongSelf.interaction.grant()
        }
    }
    
    deinit {
        self.deleteValueDisposable.dispose()
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.isDisappearing = true
        self.view.endEditing(true)
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    private var isDisappearing = false
    
    private var previousHeaderNodeAlpha: CGFloat = 0.0
    private var hadContentNode = false
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        if self.isDisappearing {
            return
        }
        
        let previousHadContentNode = self.hadContentNode
        self.hadContentNode = self.contentNode != nil
        
        var insetOptions: ContainerViewLayoutInsetOptions = []
        if self.contentNode is SecureIdAuthPasswordOptionContentNode {
            insetOptions.insert(.input)
        }
        
        var insets = layout.insets(options: insetOptions)
        insets.bottom = max(insets.bottom, layout.safeInsets.bottom)
        
        let activitySize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - activitySize.width) / 2.0), y: insets.top + floor((layout.size.height - insets.top - insets.bottom - activitySize.height) / 2.0)), size: activitySize))
        
        var headerNodeTransition: ContainedViewLayoutTransition = self.headerNode.bounds.height.isZero ? .immediate : transition
        if self.previousHeaderNodeAlpha.isZero && !self.headerNode.alpha.isZero {
            headerNodeTransition = .immediate
        }
        self.previousHeaderNodeAlpha = self.headerNode.alpha
        let headerLayout: (compact: CGFloat, expanded: CGFloat, apply: (Bool) -> Void)
        if self.headerNode.alpha.isZero {
            headerLayout = (0.0, 0.0, { _ in })
        } else {
            headerLayout = self.headerNode.updateLayout(width: layout.size.width, transition: headerNodeTransition)
        }
        
        let acceptHeight = self.acceptNode.updateLayout(width: layout.size.width, bottomInset: layout.intrinsicInsets.bottom, transition: transition)
        
        var footerHeight: CGFloat = 0.0
        var contentSpacing: CGFloat
        
        var acceptNodeTransition = transition
        if !previousHadContentNode {
            acceptNodeTransition = .immediate
        }
        
        acceptNodeTransition.updateFrame(node: self.acceptNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - acceptHeight), size: CGSize(width: layout.size.width, height: acceptHeight)))
        var minContentSpacing: CGFloat = 10.0
        if self.acceptNode.supernode != nil {
            footerHeight += (acceptHeight - layout.intrinsicInsets.bottom)
            contentSpacing = 25.0
            minContentSpacing = 25.0
        } else {
            if self.contentNode is SecureIdAuthListContentNode {
                contentSpacing = 16.0
            } else if self.contentNode is SecureIdAuthPasswordSetupContentNode {
                contentSpacing = 24.0
            } else {
                contentSpacing = 56.0
            }
        }
        
        insets.bottom += footerHeight
        
        let wrappingContentRect = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - insets.bottom - navigationBarHeight))
        let contentRect = CGRect(origin: CGPoint(), size: wrappingContentRect.size)
        transition.updateFrame(node: self.scrollNode, frame: wrappingContentRect)
        
        if let contentNode = self.contentNode {
            let contentFirstTime = contentNode.bounds.isEmpty
            let contentNodeTransition: ContainedViewLayoutTransition = contentFirstTime ? .immediate : transition
            let contentLayout = contentNode.updateLayout(width: layout.size.width, transition: contentNodeTransition)
            
            let headerHeight: CGFloat
            if self.contentNode is SecureIdAuthPasswordOptionContentNode && headerLayout.expanded + contentLayout.height + minContentSpacing + 14.0 + 16.0 > contentRect.height {
                headerHeight = headerLayout.compact
                headerLayout.apply(false)
            } else {
                headerHeight = headerLayout.expanded
                headerLayout.apply(true)
            }
            
            contentSpacing = max(minContentSpacing, min(contentSpacing, contentRect.height - (headerHeight + contentLayout.height + minContentSpacing + 14.0 + 16.0)))
            
            let boundingHeight = headerHeight + contentLayout.height + contentSpacing
            
            var boundingRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: boundingHeight))
            if contentNode is SecureIdAuthListContentNode {
                boundingRect.origin.y = contentRect.minY
            } else {
                boundingRect.origin.y = contentRect.minY + floor((contentRect.height - boundingHeight) / 2.0)
            }
            boundingRect.origin.y = max(boundingRect.origin.y, 14.0)
            
            if self.headerNode.alpha.isZero {
                headerNodeTransition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: -boundingRect.width, y: self.headerNode.frame.minY), size: CGSize(width: boundingRect.width, height: headerHeight)))
            } else {
                headerNodeTransition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: boundingRect.minY), size: CGSize(width: boundingRect.width, height: headerHeight)))
            }
            
            contentNodeTransition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: boundingRect.minY + headerHeight + contentSpacing), size: CGSize(width: boundingRect.width, height: contentLayout.height)))
            
            if contentFirstTime {
                contentNode.didAppear()
                if transition.isAnimated {
                    contentNode.animateIn()
                    if !(contentNode is SecureIdAuthPasswordOptionContentNode || contentNode is SecureIdAuthPasswordSetupContentNode) && previousHadContentNode {
                        transition.animatePositionAdditive(node: contentNode, offset: CGPoint(x: layout.size.width, y: 0.0))
                    }
                }
            }
            
            self.scrollNode.view.contentSize = CGSize(width: boundingRect.width, height: 14.0 + boundingRect.height + 16.0)
        }
        
        if let dismissedContentNode = self.dismissedContentNode {
            self.dismissedContentNode = nil
            transition.updatePosition(node: dismissedContentNode, position: CGPoint(x: -layout.size.width / 2.0, y: dismissedContentNode.position.y), completion: { [weak dismissedContentNode] _ in
                dismissedContentNode?.removeFromSupernode()
            })
        }
    }
    
    func transitionToContentNode(_ contentNode: (ASDisplayNode & SecureIdAuthContentNode)?, transition: ContainedViewLayoutTransition) {
        if let current = self.contentNode {
            current.willDisappear()
            if let dismissedContentNode = self.dismissedContentNode, dismissedContentNode !== current {
                dismissedContentNode.removeFromSupernode()
            }
            self.dismissedContentNode = current
        }
        
        self.contentNode = contentNode
        
        if let contentNode = self.contentNode {
            self.scrollNode.addSubnode(contentNode)
            if let _ = self.validLayout {
                if transition.isAnimated {
                    self.scheduleLayoutTransitionRequest(.animated(duration: 0.5, curve: .spring))
                } else {
                    self.scheduleLayoutTransitionRequest(.immediate)
                }
            }
        }
    }
    
    func updateState(_ state: SecureIdAuthControllerState, transition: ContainedViewLayoutTransition) {
        self.state = state
        
        var displayActivity = false
        
        switch state {
            case let .form(form):
                if let encryptedFormData = form.encryptedFormData, let verificationState = form.verificationState {
                    if self.headerNode.supernode == nil {
                        self.scrollNode.addSubnode(self.headerNode)
                        self.headerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                    self.headerNode.updateState(formData: encryptedFormData, verificationState: verificationState)
                    
                    var contentNode: (ASDisplayNode & SecureIdAuthContentNode)?
                    
                    switch verificationState {
                        case let .noChallenge(noChallengeState):
                            if let _ = self.contentNode as? SecureIdAuthPasswordSetupContentNode {
                            } else {
                                let current = SecureIdAuthPasswordSetupContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, setupPassword: { [weak self] in
                                    self?.interaction.setupPassword()
                                })
                                contentNode = current
                            }
                            switch noChallengeState {
                                case .notSet:
                                    (self.contentNode as? SecureIdAuthPasswordSetupContentNode)?.updatePendingConfirmation(false)
                                    (contentNode as? SecureIdAuthPasswordSetupContentNode)?.updatePendingConfirmation(false)
                                case .awaitingConfirmation:
                                    (self.contentNode as? SecureIdAuthPasswordSetupContentNode)?.updatePendingConfirmation(true)
                                    (contentNode as? SecureIdAuthPasswordSetupContentNode)?.updatePendingConfirmation(true)
                            }
                        case let .passwordChallenge(hint, challengeState, _):
                            if let current = self.contentNode as? SecureIdAuthPasswordOptionContentNode {
                                current.updateIsChecking(challengeState == .checking)
                                if case .invalid = challengeState {
                                    current.updateIsInvalid()
                                }
                                contentNode = current
                            } else {
                                let current = SecureIdAuthPasswordOptionContentNode(theme: presentationData.theme, strings: presentationData.strings, hint: hint, checkPassword: { [weak self] password in
                                    if let strongSelf = self {
                                        strongSelf.interaction.checkPassword(password)
                                    }
                                }, passwordHelp: { [weak self] in
                                    self?.interaction.openPasswordHelp()
                                })
                                current.updateIsChecking(challengeState == .checking)
                                if case .invalid = challengeState {
                                    current.updateIsInvalid()
                                }
                                contentNode = current
                            }
                        case .verified:
                            if let encryptedFormData = form.encryptedFormData, let formData = form.formData {
                                if let current = self.contentNode as? SecureIdAuthFormContentNode {
                                    current.updateValues(formData.values)
                                    contentNode = current
                                } else {
                                    let current = SecureIdAuthFormContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder, peer: encryptedFormData.servicePeer, privacyPolicyUrl: encryptedFormData.form.termsUrl, form: formData, primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry, openField: { [weak self] field in
                                        if let strongSelf = self {
                                            switch field {
                                                case .identity, .address:
                                                    strongSelf.presentDocumentSelection(field: field)
                                                case .phone:
                                                    strongSelf.presentPlaintextSelection(type: .phone)
                                                case .email:
                                                    strongSelf.presentPlaintextSelection(type: .email)
                                            }
                                        }
                                    }, openURL: { [weak self] url in
                                        self?.interaction.openUrl(url)
                                    }, openMention: { [weak self] mention in
                                        self?.interaction.openMention(mention)
                                    }, requestLayout: { [weak self] in
                                        if let strongSelf = self, let (layout, navigationHeight) = strongSelf.validLayout {
                                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                                        }
                                    })
                                    contentNode = current
                                }
                            }
                    }
                    
                    if case .verified = verificationState {
                        if self.acceptNode.supernode == nil {
                            self.addSubnode(self.acceptNode)
                            if transition.isAnimated {
                                self.acceptNode.layer.animatePosition(from: CGPoint(x: 0.0, y: self.acceptNode.bounds.height), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            }
                        }
                    }
                    
                    if self.contentNode !== contentNode {
                        self.transitionToContentNode(contentNode, transition: transition)
                    }
                } else {
                    displayActivity = true
                }
            case let .list(list):
                if let _ = list.encryptedValues, let verificationState = list.verificationState {
                    if case .verified = verificationState {
                        if !self.headerNode.alpha.isZero {
                            self.headerNode.alpha = 0.0
                            self.headerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                        }
                    } else {
                        if self.headerNode.supernode == nil {
                            self.scrollNode.addSubnode(self.headerNode)
                            self.headerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                        self.headerNode.updateState(formData: nil, verificationState: verificationState)
                    }
                    
                    var contentNode: (ASDisplayNode & SecureIdAuthContentNode)?
                    
                    switch verificationState {
                        case let .passwordChallenge(hint, challengeState, _):
                            if let current = self.contentNode as? SecureIdAuthPasswordOptionContentNode {
                                current.updateIsChecking(challengeState == .checking)
                                if case .invalid = challengeState {
                                    current.updateIsInvalid()
                                }
                                contentNode = current
                            } else {
                                let current = SecureIdAuthPasswordOptionContentNode(theme: presentationData.theme, strings: presentationData.strings, hint: hint, checkPassword: { [weak self] password in
                                    self?.interaction.checkPassword(password)
                                }, passwordHelp: { [weak self] in
                                    self?.interaction.openPasswordHelp()
                                })
                                current.updateIsChecking(challengeState == .checking)
                                if case .invalid = challengeState {
                                    current.updateIsInvalid()
                                }
                                contentNode = current
                            }
                        case .noChallenge:
                            contentNode = nil
                        case .verified:
                            if let _ = list.encryptedValues, let values = list.values {
                                if let current = self.contentNode as? SecureIdAuthListContentNode {
                                    current.updateValues(values)
                                    contentNode = current
                                } else {
                                    let current = SecureIdAuthListContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, openField: { [weak self] field in
                                        self?.openListField(field)
                                    }, deleteAll: { [weak self] in
                                        self?.deleteAllValues()
                                    }, requestLayout: { [weak self] in
                                        if let strongSelf = self, let (layout, navigationHeight) = strongSelf.validLayout {
                                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                                        }
                                    })
                                    current.updateValues(values)
                                    contentNode = current
                                }
                            }
                    }
                    
                    if self.contentNode !== contentNode {
                        self.transitionToContentNode(contentNode, transition: transition)
                    }
                } else {
                    displayActivity = true
                }
        }
        if displayActivity != !self.activityIndicator.isHidden {
            self.activityIndicator.isHidden = !displayActivity
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
    
    private func presentDocumentSelection(field: SecureIdParsedRequestedFormField) {
        guard let state = self.state, case let .form(form) = state, let verificationState = form.verificationState, case let .verified(secureIdContext) = verificationState, let encryptedFormData = form.encryptedFormData, let formData = form.formData else {
            return
        }
        let updatedValues: ([SecureIdValueKey], [SecureIdValueWithContext]) -> Void = { [weak self] touchedKeys, updatedValues in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interaction.updateState { state in
                guard let formData = form.formData, case let .form(form) = state else {
                    return state
                }
                var values = formData.values.filter { value in
                    return !touchedKeys.contains(value.value.key)
                }
                values.append(contentsOf: updatedValues)
                return .form(SecureIdAuthControllerFormState(twoStepEmail: form.twoStepEmail, encryptedFormData: form.encryptedFormData, formData: SecureIdForm(peerId: formData.peerId, requestedFields: formData.requestedFields, values: values), verificationState: form.verificationState, removingValues: form.removingValues))
            }
        }
        
        switch field {
            case let .identity(personalDetails, document):
                if let document = document {
                    var hasValueType: (document: SecureIdRequestedIdentityDocument, requireSelfie: Bool, hasSelfie: Bool, requireTranslation: Bool, hasTranslation: Bool)?
                    switch document {
                        case let .just(type):
                            if let value = findValue(formData.values, key: type.document.valueKey)?.1 {
                                let data = extractSecureIdValueAdditionalData(value.value)
                                switch value.value {
                                    case .passport:
                                        hasValueType = (.passport, type.selfie, data.selfie, type.translation, data.translation)
                                    case .idCard:
                                        hasValueType = (.idCard, type.selfie, data.selfie, type.translation, data.translation)
                                    case .driversLicense:
                                        hasValueType = (.driversLicense, type.selfie, data.selfie, type.translation, data.translation)
                                    case .internalPassport:
                                        hasValueType = (.internalPassport, type.selfie, data.selfie, type.translation, data.translation)
                                    default:
                                        break
                                }
                            }
                        case let .oneOf(types):
                            inner: for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                                if let value = findValue(formData.values, key: type.document.valueKey)?.1 {
                                    let data = extractSecureIdValueAdditionalData(value.value)
                                    var dataFilled = true
                                    if type.selfie && !data.selfie {
                                        dataFilled = false
                                    }
                                    if type.translation && !data.translation {
                                        dataFilled = false
                                    }
                                    if hasValueType == nil || dataFilled {
                                        switch value.value {
                                            case .passport:
                                                hasValueType = (.passport, type.selfie, data.selfie, type.translation, data.translation)
                                            case .idCard:
                                                hasValueType = (.idCard, type.selfie, data.selfie, type.translation, data.translation)
                                            case .driversLicense:
                                                hasValueType = (.driversLicense, type.selfie, data.selfie, type.translation, data.translation)
                                            case .internalPassport:
                                                hasValueType = (.internalPassport, type.selfie, data.selfie, type.translation, data.translation)
                                            default:
                                                break
                                        }
                                        
                                        if dataFilled {
                                            break inner
                                        }
                                    }
                                }
                            }
                    }
                    if let (hasValueType, requireSelfie, hasSelfie, requireTranslation, hasTranslation) = hasValueType {
                        var scrollTo: SecureIdDocumentFormScrollToSubject?
                        if requireSelfie && !hasSelfie {
                            scrollTo = .selfie
                        }
                        else if requireTranslation && !hasTranslation {
                            scrollTo = .translation
                        }
                        self.interaction.push(SecureIdDocumentFormController(context: self.context, secureIdContext: secureIdContext, requestedData: .identity(details: personalDetails, document: hasValueType, selfie: requireSelfie, translations: requireTranslation), scrollTo: scrollTo, primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry, values: formData.values, updatedValues: { values in
                            var keys: [SecureIdValueKey] = []
                            if personalDetails != nil {
                                keys.append(.personalDetails)
                            }
                            keys.append(hasValueType.valueKey)
                            updatedValues(keys, values)
                        }))
                        return
                    }
                } else if personalDetails != nil {
                    self.interaction.push(SecureIdDocumentFormController(context: self.context, secureIdContext: secureIdContext, requestedData: .identity(details: personalDetails, document: nil, selfie: false, translations: false), primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry, values: formData.values, updatedValues: { values in
                        updatedValues([.personalDetails], values)
                    }))
                    return
                }
            case let .address(addressDetails, document):
                if let document = document {
                    var hasValueType: (document: SecureIdRequestedAddressDocument, requireTranslation: Bool, hasTranslation: Bool)?
                    switch document {
                        case let .just(type):
                            if let value = findValue(formData.values, key: type.document.valueKey)?.1 {
                                let data = extractSecureIdValueAdditionalData(value.value)
                                switch value.value {
                                    case .utilityBill:
                                        hasValueType = (.utilityBill, type.translation, data.translation)
                                    case .bankStatement:
                                        hasValueType = (.bankStatement, type.translation, data.translation)
                                    case .rentalAgreement:
                                        hasValueType = (.rentalAgreement, type.translation, data.translation)
                                    case .passportRegistration:
                                        hasValueType = (.passportRegistration, type.translation, data.translation)
                                    case .temporaryRegistration:
                                        hasValueType = (.temporaryRegistration, type.translation, data.translation)
                                    default:
                                        break
                                }
                            }
                        case let .oneOf(types):
                            inner: for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                                if let value = findValue(formData.values, key: type.document.valueKey)?.1 {
                                    let data = extractSecureIdValueAdditionalData(value.value)
                                    var dataFilled = true
                                    if type.translation && !data.translation {
                                        dataFilled = false
                                    }
                                    
                                    if hasValueType == nil || dataFilled {
                                        switch value.value {
                                            case .utilityBill:
                                                hasValueType = (.utilityBill, type.translation, data.translation)
                                            case .bankStatement:
                                                hasValueType = (.bankStatement, type.translation, data.translation)
                                            case .rentalAgreement:
                                                hasValueType = (.rentalAgreement, type.translation, data.translation)
                                            case .passportRegistration:
                                                hasValueType = (.passportRegistration, type.translation, data.translation)
                                            case .temporaryRegistration:
                                                hasValueType = (.temporaryRegistration, type.translation, data.translation)
                                            default:
                                                break
                                        }
                                        
                                        if dataFilled {
                                            break inner
                                        }
                                    }
                                }
                            }
                    }
                    if let (hasValueType, requireTranslation, hasTranslation) = hasValueType {
                        var scrollTo: SecureIdDocumentFormScrollToSubject?
                        if requireTranslation && !hasTranslation {
                            scrollTo = .translation
                        }
                        self.interaction.push(SecureIdDocumentFormController(context: self.context, secureIdContext: secureIdContext, requestedData: .address(details: addressDetails, document: hasValueType, translations: requireTranslation), scrollTo: scrollTo, primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry, values: formData.values, updatedValues: { values in
                            var keys: [SecureIdValueKey] = []
                            if addressDetails {
                                keys.append(.address)
                            }
                            keys.append(hasValueType.valueKey)
                            updatedValues(keys, values)
                        }))
                        return
                    }
                } else if addressDetails {
                    self.interaction.push(SecureIdDocumentFormController(context: self.context, secureIdContext: secureIdContext, requestedData: .address(details: addressDetails, document: nil, translations: false), primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry, values: formData.values, updatedValues: { values in
                        updatedValues([.address], values)
                    }))
                    return
                }
            default:
                break
        }
        
        let completionImpl: (SecureIdDocumentFormRequestedData) -> Void = { [weak self] requestedData in
            guard let strongSelf = self, let state = strongSelf.state, let verificationState = state.verificationState, case .verified = verificationState, let formData = form.formData, let validLayout = strongSelf.validLayout?.0 else {
                return
            }
            
            var attachmentType: SecureIdAttachmentMenuType? = nil
            var attachmentTarget: SecureIdAddFileTarget? = nil
            switch requestedData {
                case let .identity(_, document, _, _):
                    if let document = document {
                        switch document {
                            case .idCard, .driversLicense:
                                attachmentType = .idCard
                            default:
                                attachmentType = .generic
                        }
                        attachmentTarget = .frontSide(document)
                    }
                case .address:
                    attachmentType = .multiple
                    attachmentTarget = .scan
            }
            
            let controller = SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: requestedData, primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry, values: formData.values, updatedValues: { values in
                var keys: [SecureIdValueKey] = []
                switch requestedData {
                    case let .identity(details, document, _, _):
                        if details != nil {
                            keys.append(.personalDetails)
                        }
                        if let document = document {
                            keys.append(document.valueKey)
                        }
                    case let .address(details, document, _):
                        if details {
                            keys.append(.address)
                        }
                        if let document = document {
                            keys.append(document.valueKey)
                        }
                }
                updatedValues(keys, values)
            })
            
            if let attachmentType = attachmentType, let type = attachmentTarget {
                presentLegacySecureIdAttachmentMenu(context: strongSelf.context, present: { [weak self] c in
                    self?.interaction.present(c, nil)
                    }, validLayout: validLayout, type: attachmentType, recognizeDocumentData: true, completion: { [weak self] resources, recognizedData in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.interaction.present(controller, nil)
                        controller.addDocuments(type: type, resources: resources, recognizedData: recognizedData, removeDocumentId: nil)
                })
            } else {
                strongSelf.interaction.present(controller, nil)
            }
        }
        
        let itemsForField = documentSelectionItemsForField(field: field, strings: self.presentationData.strings)
        if itemsForField.count == 1 {
            completionImpl(itemsForField[0].1)
        } else {
            let controller = SecureIdDocumentTypeSelectionController(context: self.context, field: field, currentValues: formData.values, completion: completionImpl)
            self.interaction.present(controller, nil)
        }
    }
    
    private func presentPlaintextSelection(type: SecureIdPlaintextFormType) {
        guard let state = self.state, case let .form(form) = state, let formData = form.formData, let verificationState = form.verificationState, case let .verified(secureIdContext) = verificationState else {
            return
        }
        
        var immediatelyAvailableValue: SecureIdValue?
        var currentValue: SecureIdValueWithContext?
        switch type {
            case .phone:
                if let peer = form.encryptedFormData?.accountPeer as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
                    immediatelyAvailableValue = .phone(SecureIdPhoneValue(phone: phone))
                }
                currentValue = findValue(formData.values, key: .phone)?.1
            case .email:
                if let email = form.twoStepEmail {
                    immediatelyAvailableValue = .email(SecureIdEmailValue(email: email))
                }
                currentValue = findValue(formData.values, key: .email)?.1
        }
        let openForm: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interaction.push(SecureIdPlaintextFormController(context: strongSelf.context, secureIdContext: secureIdContext, type: type, immediatelyAvailableValue: immediatelyAvailableValue, updatedValue: { valueWithContext in
                if let strongSelf = self {
                    strongSelf.interaction.updateState { state in
                        if case let .form(form) = state, let formData = form.formData {
                            var values = formData.values
                            switch type {
                                case .phone:
                                    while let index = findValue(values, key: .phone)?.0 {
                                        values.remove(at: index)
                                    }
                                case .email:
                                    while let index = findValue(values, key: .email)?.0 {
                                        values.remove(at: index)
                                    }
                            }
                            if let valueWithContext = valueWithContext {
                                values.append(valueWithContext)
                            }
                            return .form(SecureIdAuthControllerFormState(twoStepEmail: form.twoStepEmail, encryptedFormData: form.encryptedFormData, formData: SecureIdForm(peerId: formData.peerId, requestedFields: formData.requestedFields, values: values), verificationState: form.verificationState, removingValues: form.removingValues))
                        }
                        return state
                    }
                }
            }))
        }
        
        if let currentValue = currentValue {
            let controller = ActionSheetController(presentationData: self.presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            let text: String
            switch currentValue.value {
                case .phone:
                    text = self.presentationData.strings.Passport_Phone_Delete
                default:
                    text = self.presentationData.strings.Passport_Email_Delete
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: text, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.interaction.updateState { state in
                        if case var .form(form) = state {
                            form.removingValues = true
                            return .form(form)
                        }
                        return state
                    }
                    strongSelf.deleteValueDisposable.set((deleteSecureIdValues(network: strongSelf.context.account.network, keys: Set([currentValue.value.key]))
                        |> deliverOnMainQueue).start(completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.interaction.updateState { state in
                                if case var .form(form) = state, let formData = form.formData {
                                    form.removingValues = false
                                    form.formData = SecureIdForm(peerId: formData.peerId, requestedFields: formData.requestedFields, values: formData.values.filter {
                                        $0.value.key != currentValue.value.key
                                    })
                                    return .form(form)
                                }
                                return state
                            }
                        }))
                })]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
            self.view.endEditing(true)
            self.interaction.present(controller, nil)
        } else {
            openForm()
        }
    }
    
    private func openListField(_ field: SecureIdAuthListContentField) {
        guard let state = self.state, case let .list(list) = state, let verificationState = list.verificationState, case let .verified(secureIdContext) = verificationState else {
            return
        }
        guard let values = list.values else {
            return
        }
        
        let updatedValues: (SecureIdValueKey) -> ([SecureIdValueWithContext]) -> Void = { valueKey in
            return { [weak self] updatedValues in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.interaction.updateState { state in
                    guard case var .list(list) = state, var values = list.values else {
                        return state
                    }
                    
                    values = values.filter({ value in
                        return value.value.key != valueKey
                    })
                    
                    values.append(contentsOf: updatedValues)
                    
                    list.values = values
                    return .list(list)
                }
            }
        }
        
        let openAction: (SecureIdValueKey) -> Void = { [weak self] field in
            guard let strongSelf = self, let state = strongSelf.state, case let .list(list) = state else {
                return
            }
            let primaryLanguageByCountry = list.primaryLanguageByCountry ?? [:]
            switch field {
                case .personalDetails:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .identity(details: ParsedRequestedPersonalDetails(nativeNames: false), document: nil, selfie: false, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .passport:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .identity(details: nil, document: .passport, selfie: false, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .internalPassport:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .identity(details: nil, document: .internalPassport, selfie: false, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .driversLicense:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .identity(details: nil, document: .driversLicense, selfie: false, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .idCard:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .identity(details: nil, document: .idCard, selfie: false, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .address:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .address(details: true, document: nil, translations: false), primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .utilityBill:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .address(details: false, document: .utilityBill, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .bankStatement:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .address(details: false, document: .bankStatement, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .rentalAgreement:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .address(details: false, document: .rentalAgreement, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .passportRegistration:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .address(details: false, document: .passportRegistration, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .temporaryRegistration:
                    strongSelf.interaction.push(SecureIdDocumentFormController(context: strongSelf.context, secureIdContext: secureIdContext, requestedData: .address(details: false, document: .temporaryRegistration, translations: false), requestOptionalData: true, primaryLanguageByCountry: primaryLanguageByCountry, values: values, updatedValues: updatedValues(field)))
                case .phone:
                    break
                case .email:
                    break
            }
        }
        
        let deleteField: (SecureIdValueKey) -> Void = { [weak self] field in
            guard let strongSelf = self else {
                return
            }
            
            let controller = ActionSheetController(presentationData: strongSelf.presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            let text: String
            switch field {
                case .phone:
                    text = strongSelf.presentationData.strings.Passport_Phone_Delete
                default:
                    text = strongSelf.presentationData.strings.Passport_Email_Delete
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: text, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.interaction.updateState { state in
                        if case var .list(list) = state {
                            list.removingValues = true
                            return .list(list)
                        }
                        return state
                    }
                    strongSelf.deleteValueDisposable.set((deleteSecureIdValues(network: strongSelf.context.account.network, keys: Set([field]))
                        |> deliverOnMainQueue).start(completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.interaction.updateState { state in
                                if case var .list(list) = state , let values = list.values {
                                    list.removingValues = false
                                    list.values = values.filter {
                                        $0.value.key != field
                                    }
                                    return .list(list)
                                }
                                return state
                            }
                        }))
                })]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
            strongSelf.view.endEditing(true)
            strongSelf.interaction.present(controller, nil)
        }
        
        switch field {
            case .identity, .address:
                let keys: [(SecureIdValueKey, String, String)]
                let strings = self.presentationData.strings
                if case .identity = field {
                    keys = [
                        (.personalDetails, strings.Passport_Identity_AddPersonalDetails, strings.Passport_Identity_EditPersonalDetails),
                        (.passport, strings.Passport_Identity_AddPassport, strings.Passport_Identity_EditPassport),
                        (.idCard, strings.Passport_Identity_AddIdentityCard, strings.Passport_Identity_EditIdentityCard),
                        (.driversLicense, strings.Passport_Identity_AddDriversLicense, strings.Passport_Identity_EditDriversLicense),
                        (.internalPassport, strings.Passport_Identity_AddInternalPassport, strings.Passport_Identity_EditInternalPassport),
                    ]
                } else {
                    keys = [
                        (.address, strings.Passport_Address_AddResidentialAddress, strings.Passport_Address_EditResidentialAddress), (.utilityBill, strings.Passport_Address_AddUtilityBill, strings.Passport_Address_EditUtilityBill),
                        (.bankStatement, strings.Passport_Address_AddBankStatement, strings.Passport_Address_EditBankStatement),
                        (.rentalAgreement, strings.Passport_Address_AddRentalAgreement, strings.Passport_Address_EditRentalAgreement),
                        (.passportRegistration, strings.Passport_Address_AddPassportRegistration, strings.Passport_Address_EditPassportRegistration),
                        (.temporaryRegistration, strings.Passport_Address_AddTemporaryRegistration, strings.Passport_Address_EditTemporaryRegistration)
                    ]
                }
                
                let controller = ActionSheetController(presentationData: self.presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                var items: [ActionSheetItem] = []
                for (key, add, edit) in keys {
                    items.append(ActionSheetButtonItem(title: findValue(values, key: key) != nil ? edit : add, action: {
                        dismissAction()
                        openAction(key)
                    }))
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                self.view.endEditing(true)
                self.interaction.present(controller, nil)
            case .phone:
                if findValue(values, key: .phone) != nil {
                    deleteField(.phone)
                } else {
                    var immediatelyAvailableValue: SecureIdValue?
                    if let peer = list.accountPeer as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
                        immediatelyAvailableValue = .phone(SecureIdPhoneValue(phone: phone))
                    }
                    self.interaction.push(SecureIdPlaintextFormController(context: self.context, secureIdContext: secureIdContext, type: .phone, immediatelyAvailableValue: immediatelyAvailableValue, updatedValue: { value in
                        updatedValues(.phone)(value.flatMap({ [$0] }) ?? [])
                    }))
                }
            case .email:
                if findValue(values, key: .email) != nil {
                    deleteField(.email)
                } else {
                    var immediatelyAvailableValue: SecureIdValue?
                    if let email = list.twoStepEmail {
                        immediatelyAvailableValue = .email(SecureIdEmailValue(email: email))
                    }
                    self.interaction.push(SecureIdPlaintextFormController(context: self.context, secureIdContext: secureIdContext, type: .email, immediatelyAvailableValue: immediatelyAvailableValue, updatedValue: { value in
                        updatedValues(.email)(value.flatMap({ [$0] }) ?? [])
                    }))
                }
        }
    }
    
    private func deleteAllValues() {
        let controller = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let items: [ActionSheetItem] = [
            ActionSheetTextItem(title: self.presentationData.strings.Passport_DeletePassportConfirmation),
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Delete, color: .destructive, enabled: true, action: { [weak self] in
                dismissAction()
                self?.interaction.deleteAll()
            })
        ]
        controller.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
        self.view.endEditing(true)
        self.interaction.present(controller, nil)
    }
}
