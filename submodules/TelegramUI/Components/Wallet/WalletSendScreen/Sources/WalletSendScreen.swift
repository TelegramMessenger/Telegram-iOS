import Foundation
import UIKit
import AppBundle
import Display
import AccountContext
import TelegramCore
import LocalizedPeerData
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import ComponentFlow
import WalletSendKeyboardComponent
import PremiumDiamondComponent
import ViewControllerComponent
import BundleIconComponent
import MultilineTextComponent
import ButtonComponent
import GlassControls
import PlainButtonComponent
import ContextUI
import AttachmentUI
import AlertComponent
import AlertCheckComponent
import AlertMultilineInputFieldComponent
import WalletContext
import WalletAuthorizationUI
import PasscodeCore
import QrCodeUI
import UndoUI

private enum WalletSendAmountSource: Equatable {
    case manual
    case transferLink
}

private enum WalletSendFeeDisplayState: Equatable {
    case hidden
    case loading
    case value(Int64)
    case unavailable
}

private struct WalletSendFeeRequest: Equatable {
    let walletAddress: String
    let walletPublicKey: String
    let address: String
    let comment: WalletContext.TransferFeeComment
}

private struct WalletSendTransferRequest {
    let feeRequest: WalletSendFeeRequest
    let publicKey: Data?
    let amount: Int64
    let sendAll: Bool
    let comment: String?
    let commentEncrypted: Bool
    var estimatedFee: Int64? = nil
}

private func deliverWalletSendEvents<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        return signal.start(next: { value in
            DispatchQueue.main.async {
                subscriber.putNext(value)
            }
        }, error: { error in
            DispatchQueue.main.async {
                subscriber.putError(error)
            }
        }, completed: {
            DispatchQueue.main.async {
                subscriber.putCompletion()
            }
        })
    }
}

private func walletSendShortAddress(_ address: String) -> String {
    guard address.count > 8 else {
        return address
    }
    return "\(address.prefix(4))…\(address.suffix(4))"
}

public final class WalletSendTransferAnimationSource {
    public let diamond: InteractiveDiamondComponent.View
    public weak var window: UIWindow?
    public let center: CGPoint
    public let width: CGFloat
    public let rotation: CGFloat
    private var secondImpactTime: CFTimeInterval?

    init(diamond: InteractiveDiamondComponent.View, window: UIWindow, center: CGPoint, width: CGFloat, rotation: CGFloat, spinStartedAt: CFTimeInterval?) {
        self.diamond = diamond
        self.window = window
        self.center = center
        self.width = width
        self.rotation = rotation
        self.secondImpactTime = spinStartedAt.map { $0 + 0.45 }
    }

    public static func capture(diamond: InteractiveDiamondComponent.View, width: CGFloat, spinStartedAt: CFTimeInterval? = nil) -> WalletSendTransferAnimationSource? {
        guard let window = diamond.window else { return nil }
        let layer = diamond.layer.presentation() ?? diamond.layer
        let windowLayer = window.layer.presentation() ?? window.layer
        let center = layer.convert(CGPoint(x: layer.bounds.midX, y: layer.bounds.midY), to: windowLayer)
        let left = layer.convert(CGPoint(x: layer.bounds.midX - width * 0.5, y: layer.bounds.midY), to: windowLayer)
        let right = layer.convert(CGPoint(x: layer.bounds.midX + width * 0.5, y: layer.bounds.midY), to: windowLayer)
        return WalletSendTransferAnimationSource(diamond: diamond, window: window, center: center,
            width: hypot(right.x - left.x, right.y - left.y), rotation: atan2(right.y - left.y, right.x - left.x), spinStartedAt: spinStartedAt)
    }

    public func updateFlightHaptics(at time: CFTimeInterval) {
        guard let secondImpactTime = self.secondImpactTime, time >= secondImpactTime else { return }
        self.secondImpactTime = nil
        guard UIApplication.shared.applicationState == .active else { return }
        Haptics.hit(0.6)
    }
}


public typealias WalletSendTransferAnimation = (String, WalletSendTransferAnimationSource?) -> Bool

public protocol WalletSendTransferAnimationController: AnyObject {
    var transferAnimation: WalletSendTransferAnimation? { get set }
}

@MainActor
private func walletPresentSubmissionUnknown(on controller: ViewController, context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)) -> ViewController {
    let alert = textAlertController(
        context: context,
        updatedPresentationData: updatedPresentationData,
        title: updatedPresentationData.initial.strings.Wallet_Transfer_PendingTitle,
        text: updatedPresentationData.initial.strings.Wallet_Transfer_PendingText,
        actions: [TextAlertAction(type: .defaultAction, title: updatedPresentationData.initial.strings.Common_OK, action: {
        })]
    )
    controller.present(alert, in: .window(.root))
    return alert
}

@MainActor
private func walletPresentTransferError(_ error: WalletContext.WalletError?, on controller: ViewController, context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)) {
    guard error != .authorizationCancelled else { return }
    let title: String
    let text: String
    switch error {
    case .walletKeyMismatch:
        title = updatedPresentationData.initial.strings.Wallet_Transfer_KeyChangedTitle
        text = updatedPresentationData.initial.strings.Wallet_Transfer_KeyChangedText
    case .commentTooLong:
        title = updatedPresentationData.initial.strings.Wallet_Transfer_CommentTooLongTitle
        text = updatedPresentationData.initial.strings.Wallet_Transfer_CommentTooLongText
    case .commentEncryptionRecipientUnavailable:
        title = updatedPresentationData.initial.strings.Wallet_Transfer_CommentEncryptionErrorTitle
        text = updatedPresentationData.initial.strings.Wallet_Transfer_CommentEncryptionUnavailable
    case .commentEncryptionFailed:
        title = updatedPresentationData.initial.strings.Wallet_Transfer_CommentEncryptionErrorTitle
        text = updatedPresentationData.initial.strings.Wallet_Transfer_CommentEncryptionErrorText
    default:
        title = updatedPresentationData.initial.strings.Wallet_Transfer_ErrorTitle
        text = updatedPresentationData.initial.strings.Wallet_Transfer_ErrorText
    }
    controller.present(textAlertController(
        context: context,
        updatedPresentationData: updatedPresentationData,
        title: title,
        text: text,
        actions: [TextAlertAction(type: .defaultAction, title: updatedPresentationData.initial.strings.Common_OK, action: {
        })]
    ), in: .window(.root))
}

@MainActor
fileprivate final class WalletPeerTransferSubmission {
    private let context: AccountContext
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    private let peer: EnginePeer
    private weak var controller: WalletSendScreen?
    private weak var navigationController: NavigationController?
    private weak var parentController: ViewController?
    private weak var walletContext: WalletContext?
    private var authorizationSession: PasscodeSession?
    private weak var submissionUnknownController: ViewController?
    private var walletAddress: String?
    private var walletPublicKey: String?
    private let observationDisposable = MetaDisposable()
    private let submissionDisposable = MetaDisposable()
    private var submissionStage: WalletContext.TransferSubmissionStage?
    private var preparedTransfer: WalletContext.PreparedTransfer?
    private var pendingRegistration: WalletContext.PendingTransferRegistration?
    private var hasObservedTransfer = false
    private var confirmationObserved = false
    private var observationStopped = false
    private var isInvalidated = false
    private let closeForm: (String?) -> Void
    private let presentErrorOnForm: (WalletContext.WalletError) -> Bool
    private var closeRequested = false
    private var isAuthorized = false
    private var isClosingForm = false
    private var formDisappeared = false
    private var result: Result<WalletContext.PendingTransfer, WalletContext.WalletError>?
    private var resultPresentationRequested = false
    private var successPresentationRequested = false

    init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        peer: EnginePeer,
        controller: WalletSendScreen,
        closeForm: @escaping (String?) -> Void,
        presentErrorOnForm: @escaping (WalletContext.WalletError) -> Bool
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.peer = peer
        self.controller = controller
        self.closeForm = closeForm
        self.presentErrorOnForm = presentErrorOnForm
        if let navigationController = controller.navigationController as? NavigationController {
            self.navigationController = navigationController
        } else if let parentController = controller.parentController() {
            self.parentController = parentController
            self.navigationController = parentController.navigationController as? NavigationController
        }
        controller.peerTransferSubmission = self
    }

    fileprivate func start(walletContext: WalletContext, request: WalletSendTransferRequest) {
        self.walletContext = walletContext
        self.walletAddress = request.feeRequest.walletAddress
        self.walletPublicKey = request.feeRequest.walletPublicKey
        self.observationDisposable.set((combineLatest(
            walletContext.state,
            self.context.sharedContext.activeAccountContexts
        )
        |> deliverOnMainQueue).start(next: { [self] state, accounts in
            guard !self.observationStopped else { return }
            guard accounts.primary?.account.id == self.context.account.id,
                  case let .wallet(info) = state.phase,
                  info.address == self.walletAddress, info.publicKey == self.walletPublicKey else {
                self.invalidate()
                return
            }
            guard let transferId = self.pendingRegistration?.id ?? self.preparedTransfer?.id else { return }
            let transaction = state.transactions.items.first(where: {
                $0.presentationId == "pending:\(transferId)"
            })
            let hasTransfer = transaction != nil || state.pendingTransfers.contains(where: { $0.id == transferId })
            if transaction?.status == .completed {
                self.confirmationObserved = true
                self.stopObserving()
                self.presentResultIfReady()
            } else if transaction?.status == .failed || (self.hasObservedTransfer && !hasTransfer) {
                self.stopObserving()
            }
            self.hasObservedTransfer = self.hasObservedTransfer || hasTransfer
        }))

        guard !self.isInvalidated else { return }
        self.submissionDisposable.set((walletContext.beginWalletFlow(reason: "Send Grams")
        |> mapToSignal { [self] session -> Signal<WalletContext.PreparedTransfer, WalletContext.WalletError> in
            guard !self.isInvalidated else {
                session.invalidate()
                return .fail(.authorizationCancelled)
            }
            self.authorizationSession = session
            self.isAuthorized = true
            return self.context.sharedContext.activeAccountContexts
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> deliverOnMainQueue
            |> mapToSignal { [self] primary, _, _ -> Signal<WalletContext.PreparedTransfer, WalletContext.WalletError> in
                guard !self.isInvalidated,
                      primary?.account.id == self.context.account.id,
                      case let .wallet(info) = walletContext.stateValue.phase,
                      info.address == self.walletAddress, info.publicKey == self.walletPublicKey else {
                    self.invalidate()
                    return .fail(.authorizationCancelled)
                }
                return walletContext.registerPendingTransfer(
                    walletAddress: request.feeRequest.walletAddress, walletPublicKey: request.feeRequest.walletPublicKey,
                    peerId: self.peer.id, address: request.feeRequest.address, amount: request.amount,
                    sendAll: request.sendAll, estimatedFee: request.estimatedFee,
                    comment: request.comment, commentEncrypted: request.commentEncrypted, session: session
                )
                |> mapToSignal { [self] registration -> Signal<WalletContext.PreparedTransfer, WalletContext.WalletError> in
                    guard !self.isInvalidated else {
                        let _ = walletContext.discardPendingTransferRegistration(registration).startStandalone()
                        return .fail(.authorizationCancelled)
                    }
                    self.pendingRegistration = registration
                    self.hasObservedTransfer = true
                    self.closeRequested = true
                    self.closeFormIfNeeded()
                    return walletContext.state
                    |> filter { $0.activeOperation == nil }
                    |> take(1)
                    |> castError(WalletContext.WalletError.self)
                    |> deliverOnMainQueue
                    |> mapToSignal { [self] state -> Signal<WalletContext.PreparedTransfer, WalletContext.WalletError> in
                        guard !self.isInvalidated,
                              case let .wallet(info) = state.phase,
                              info.address == self.walletAddress, info.publicKey == self.walletPublicKey else {
                            return .fail(.authorizationCancelled)
                        }
                        guard let balance = state.balance.currentValue, request.amount <= balance else {
                            return .fail(.insufficientBalance(required: request.amount))
                        }
                        if request.sendAll && balance != request.amount { return .fail(.previewFailed) }
                        return walletContext.prepareTransfer(
                            address: request.feeRequest.address,
                            amount: request.amount,
                            sendAll: request.sendAll,
                            comment: request.comment,
                            commentEncrypted: request.commentEncrypted,
                            recipientPublicKey: request.publicKey,
                            session: session,
                            pendingRegistration: registration,
                            estimatedFee: request.estimatedFee
                        )
                    }
                }
            }
        }
        |> mapToSignal { [self] prepared -> Signal<WalletContext.PendingTransfer, WalletContext.WalletError> in
            guard !self.isInvalidated, let session = self.authorizationSession else {
                let _ = walletContext.discardPreparedTransfer(prepared).startStandalone()
                return .fail(.authorizationCancelled)
            }
            self.preparedTransfer = prepared
            return walletContext.submitTransfer(prepared, recipientPeerId: self.peer.id, session: session, stageUpdated: { [weak self] stage in
                guard let self else { return }
                self.submissionStage = stage
                if stage == .submitted {
                    self.authorizationSession?.invalidate()
                    self.authorizationSession = nil
                }
            })
        }).start(next: { [self] pending in
            self.finish(.success(pending))
        }, error: { [self] error in
            self.finish(.failure(error))
        }))
    }

    private func withCurrentAccount(_ action: @escaping () -> Void) {
        guard !self.isInvalidated else { return }
        let _ = (self.context.sharedContext.activeAccountContexts
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [self] primary, _, _ in
            guard !self.isInvalidated else { return }
            guard primary?.account.id == self.context.account.id,
                  let walletContext = self.walletContext,
                  case let .wallet(info) = walletContext.stateValue.phase,
                  info.address == self.walletAddress, info.publicKey == self.walletPublicKey else {
                self.invalidate()
                return
            }
            action()
        })
    }

    func formWillDisappear() {
        self.isClosingForm = true
        if !self.isAuthorized {
            self.invalidate()
        }
    }

    func formDidDisappear() {
        self.formDisappeared = true
        self.presentResultIfReady()
    }

    func formDidAppear() {
        self.isClosingForm = false
        self.withCurrentAccount { [self] in
            if self.closeRequested {
                self.closeFormIfNeeded()
            }
            self.presentResultIfReady()
        }
    }

    private func closeFormIfNeeded() {
        guard !self.isClosingForm, !self.formDisappeared else { return }
        self.isClosingForm = true
        if self.controller == nil {
            self.formDisappeared = true
        } else {
            self.closeForm(self.pendingRegistration?.id ?? self.preparedTransfer?.id)
        }
    }

    private func finish(_ result: Result<WalletContext.PendingTransfer, WalletContext.WalletError>) {
        guard self.result == nil else { return }
        self.submissionDisposable.set(nil)
        self.authorizationSession?.invalidate()
        self.authorizationSession = nil
        self.result = result
        if case .failure = result {
            if let pendingRegistration, let walletContext = self.walletContext {
                let _ = walletContext.discardPendingTransferRegistration(pendingRegistration).startStandalone()
            }
            if let preparedTransfer, let walletContext = self.walletContext {
                let _ = walletContext.discardPreparedTransfer(preparedTransfer).startStandalone()
            }
            self.stopObserving()
        }
        self.withCurrentAccount { [self] in
            if case .success = result {
                self.closeRequested = true
                self.closeFormIfNeeded()
            }
            self.presentResultIfReady()
        }
    }

    private func presentResultIfReady() {
        if self.controller == nil {
            self.formDisappeared = true
        }
        guard !self.isInvalidated,
              !self.isClosingForm || self.formDisappeared else { return }
        if self.confirmationObserved {
            guard self.formDisappeared, !self.successPresentationRequested else { return }
            self.successPresentationRequested = true
            self.withCurrentAccount { [self] in
                self.detachFromForm()
                self.dismissSubmissionUnknown()
            }
            return
        }
        guard let result = self.result, !self.resultPresentationRequested else { return }
        self.resultPresentationRequested = true
        self.withCurrentAccount { [self] in
            guard !self.confirmationObserved else {
                self.presentResultIfReady()
                return
            }
            self.detachFromForm()
            if case let .failure(error) = result, !self.formDisappeared,
               self.presentErrorOnForm(error) {
                return
            }
            guard let presenter = self.resultPresenter else { return }
            switch result {
            case let .success(pending):
                if pending.status == .submissionUnknown, !self.observationStopped {
                    self.submissionUnknownController = walletPresentSubmissionUnknown(on: presenter, context: self.context, updatedPresentationData: self.updatedPresentationData)
                }
            case let .failure(error):
                walletPresentTransferError(error, on: presenter, context: self.context, updatedPresentationData: self.updatedPresentationData)
            }
        }
    }

    private var resultPresenter: ViewController? {
        let navigationController = self.navigationController
            ?? self.context.sharedContext.mainWindow?.viewController as? NavigationController
        return navigationController?.viewControllers.reversed().first(where: {
            $0 !== self.controller && $0 !== self.parentController
        }) as? ViewController
    }

    private func stopObserving() {
        self.observationStopped = true
        self.observationDisposable.dispose()
    }

    private func dismissSubmissionUnknown() {
        self.submissionUnknownController?.dismiss()
        self.submissionUnknownController = nil
    }

    private func invalidate() {
        guard !self.isInvalidated else { return }
        self.isInvalidated = true
        if let pendingRegistration, let walletContext = self.walletContext {
            let _ = walletContext.discardPendingTransferRegistration(pendingRegistration).startStandalone()
        }
        if self.submissionStage == nil || self.submissionStage == .waitingForPreviousTransfer {
            self.submissionDisposable.dispose()
            self.authorizationSession?.invalidate()
            self.authorizationSession = nil
            if let preparedTransfer, let walletContext = self.walletContext {
                let _ = walletContext.discardPreparedTransfer(preparedTransfer).startStandalone()
            }
        }
        self.stopObserving()
        self.dismissSubmissionUnknown()
        self.detachFromForm()
    }

    private func detachFromForm() {
        if self.controller?.peerTransferSubmission === self {
            self.controller?.peerTransferSubmission = nil
        }
    }
}

private final class WalletSendScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    let peer: EnginePeer?
    let resolvedAddress: WalletUserAddress?
    let allowOpenRecipientChat: Bool
    let initialAddress: String
    let initialAmountNanograms: Int64?
    let walletContext: WalletContext
    let transferAnimation: WalletSendTransferAnimation?
    let completed: (() -> Void)?

    init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        peer: EnginePeer?,
        resolvedAddress: WalletUserAddress?,
        allowOpenRecipientChat: Bool,
        initialAddress: String,
        initialAmountNanograms: Int64?,
        walletContext: WalletContext,
        transferAnimation: WalletSendTransferAnimation?,
        completed: (() -> Void)?
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.peer = peer
        self.resolvedAddress = resolvedAddress
        self.allowOpenRecipientChat = allowOpenRecipientChat
        self.initialAddress = initialAddress
        self.initialAmountNanograms = initialAmountNanograms
        self.walletContext = walletContext
        self.transferAnimation = transferAnimation
        self.completed = completed
    }

    static func ==(lhs: WalletSendScreenComponent, rhs: WalletSendScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.updatedPresentationData.initial !== rhs.updatedPresentationData.initial || lhs.updatedPresentationData.signal !== rhs.updatedPresentationData.signal {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.resolvedAddress != rhs.resolvedAddress {
            return false
        }
        if lhs.allowOpenRecipientChat != rhs.allowOpenRecipientChat {
            return false
        }
        if lhs.initialAddress != rhs.initialAddress {
            return false
        }
        if lhs.initialAmountNanograms != rhs.initialAmountNanograms {
            return false
        }
        if lhs.walletContext !== rhs.walletContext {
            return false
        }
        return true
    }

    final class View: UIView {
        private let controlButtons = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let recipient = ComponentView<Empty>()
        private var isRecipientScreenVisible = true
        private var openingStart: CFTimeInterval?
        private var openingFinished = false
        private var openingFinish: (start: CFTimeInterval, amount: WalletSendAmountIntro, recipientTime: Double)?
        private var openingDisplayLink: SharedDisplayLinkDriver.Link?
        private var openingInForeground = UIApplication.shared.applicationState != .background
        private static let openingAnimationKey = "walletSendOpening"

        private var recipientInfoAlert: AlertScreen?
        private weak var copyAddressToast: UndoOverlayController?
        private let amountField: WalletSendAmountField = WalletSendAnimatedAmountField()
        private let keyboard = ComponentView<Empty>()
        private let emptyHint = ComponentView<Empty>()
        private let rateButton = WalletSendAnimatedRateButton()
        private let insufficientText = ComponentView<Empty>()
        private let depositButton = ComponentView<Empty>()
        private let balanceText = ComponentView<Empty>()
        private let feeText = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let commentBackgroundView = WalletSendCommentBackgroundView()
        private let commentText = ComponentView<Empty>()

        var isAmountInputActive: Bool {
            return self.amountField.isInputActive
        }

        private var component: WalletSendScreenComponent?
        private var environment: EnvironmentType?
        private weak var componentState: EmptyComponentState?
        private var isUpdating = false
        private var pendingUpdateTransition: ComponentTransition?
        private var isAttachmentTabBarVisible: Bool?
        private var hasActivatedAmountInput = false
        private var needsAmountFocus = false
        private var isAmountFocusScheduled = false
        private var previousIsInsufficient: Bool?
        private var previousFeeDisplayState: WalletSendFeeDisplayState?

        private var walletContext: WalletContext?
        private let walletDisposable = MetaDisposable()
        private let peerAddressDisposable = MetaDisposable()
        private var peerAddressResolution = WalletSendPeerAddressResolution()
        private var isVisible = false
        private weak var transferPreviewController: ViewController?
        private let feeDisposable = MetaDisposable()
        private let transferDisposable = MetaDisposable()
        private let signingAccessDisposable = MetaDisposable()
        private var restorationSession: PasscodeSession?
        private var restorationGeneration = 0
        private var cachedFeeEstimate: WalletContext.TransferFeeEstimate?
        private var lastKnownFee: Int64?
        private var pendingSend: WalletSendTransferRequest?
        private var sendRevision = 0
        private var isClosingAfterRegistration = false
        private var scheduledSendRevision: Int?
        private var scheduledSigningAccessRevision: Int?
        private var isPreparingActualTransfer = false
        private var feeRequest: WalletSendFeeRequest?
        private var feeRevision = 0
        private var isEstimatingFee = false
        private var feePreparationFailed = false
        private var commentSessionAvailable = true
        private let commentEnvironmentDisposable = MetaDisposable()
        private let commentCredentialChangesDisposable = MetaDisposable()
        private var walletInfo: WalletContext.WalletInfo?
        private var walletBalance: Int64?
        private var gaslessInfo: WalletContext.Resource<WalletGaslessInfo> = .idle
        private var walletAddress: String?
        private var walletIsLoading = true
        private var isPreparingTransfer = false
        private var isSubmittingTransfer = false
        private var isResolvingSigningAccess = false
        private var continueSendingAfterSigningAccess = false
        private weak var recoveryPhraseImportController: ViewController?

        private var inputMode: WalletSendInputMode = .gram
        private var amount: Int64 = 0
        private var amountSource: WalletSendAmountSource = .manual
        private var didApplyInitialAmount = false
        private var comment: String?
        private var isCommentPublic = false
        private var currentFiatCurrency: WalletContext.FiatCurrency = .usd
        private var currentRate: Double?
        private var lastRateText = ""
        private var lastRateDisplaysGramIcon = false
        private var recipientAddress = ""
        private var recipientPublicKey: Data?
        private var initialAddress: String?

        private func currentPresentationData(for component: WalletSendScreenComponent) -> (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
            let presentationData = component.updatedPresentationData.initial
            return (
                initial: presentationData.withUpdated(theme: self.environment?.theme ?? component.updatedPresentationData.initial.theme),
                signal: component.updatedPresentationData.signal
            )
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.amountField)
            if !UIAccessibility.isReduceMotionEnabled {
                (self.amountField as? WalletSendAnimatedAmountField)?.updateOpening(WalletSendAmountIntro(time: 0.0))
            }
            (self.amountField as? WalletSendAnimatedAmountField)?.openingInterrupted = { [weak self] in
                self?.finishOpening(animated: true)
            }
            self.rateButton.action = { [weak self] in self?.toggleInputMode() }
            self.amountField.amountUpdated = { [weak self] amount in
                guard let self, !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer else {
                    return
                }
                self.amountSource = .manual
                self.amount = amount
                if self.inputMode == .gram, !self.validateTransferAmount() {
                    return
                }
                if !self.isUpdating {
                    self.requestUpdate(transition: .immediate)
                }
            }
            self.amountField.focusUpdated = { [weak self] focused in
                guard let self else {
                    return
                }
                if focused {
                    self.hasActivatedAmountInput = true
                    self.expandAttachmentMenuForInput()
                }
                if !focused {
                    (self.keyboard.view as? WalletSendKeyboardComponent.View)?.cancelKeyPresses()
                }
                if !self.isUpdating {
                    self.requestUpdate(transition: .spring(duration: 0.4))
                }
            }

            self.commentBackgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.commentPressed)))
            self.addSubview(self.commentBackgroundView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func requestUpdate(transition: ComponentTransition) {
            let isScheduled = self.pendingUpdateTransition != nil
            self.pendingUpdateTransition = transition
            guard !isScheduled else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let transition = self.pendingUpdateTransition else { return }
                self.pendingUpdateTransition = nil
                self.componentState?.updated(transition: transition)
            }
        }

        private func activateAmountInputIfNeeded() {
            guard self.needsAmountFocus, !self.isAmountFocusScheduled else { return }
            self.isAmountFocusScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isAmountFocusScheduled = false
                guard self.needsAmountFocus, self.isVisible,
                      !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer else { return }
                self.needsAmountFocus = false
                self.amountField.activateInput()
            }
        }

        private func expandAttachmentMenuForInput() {
            guard let controller = self.environment?.controller() as? WalletSendScreen else { return }
            DispatchQueue.main.async { [weak self, weak controller] in
                guard let self, let controller, self.isVisible, self.amountField.isInputActive,
                      self.environment?.controller() === controller else { return }
                controller.requestAttachmentMenuExpansion()
                controller.cancelPanGesture()
            }
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let insufficientTextView = self.insufficientText.view,
               insufficientTextView.alpha > 0.0, insufficientTextView.frame.contains(point) {
                return self
            }
            return super.hitTest(point, with: event)
        }

        deinit {
            self.openingDisplayLink?.invalidate()
            self.restorationSession?.invalidate()
            self.commentEnvironmentDisposable.dispose()
            self.commentCredentialChangesDisposable.dispose()
            self.invalidateFeePreparation()
            self.feeDisposable.dispose()
            self.walletDisposable.dispose()
            self.peerAddressDisposable.dispose()
            self.transferDisposable.dispose()
            self.signingAccessDisposable.dispose()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil {
                if self.openingStart != nil { self.finishOpening(animated: false) }
            } else {
                self.updateOpening()
            }
        }

        private func finishOpening(animated: Bool) {
            guard !self.openingFinished else { return }
            if animated, let start = self.openingStart, self.openingFinish == nil,
               self.openingInForeground, !UIAccessibility.isReduceMotionEnabled {
                let now = CACurrentMediaTime()
                self.openingFinish = (now, WalletSendAmountIntro(time: now - start), now - start)
                for view in [self.balanceText.view, self.sendButton.view].compactMap({ $0 }) {
                    view.layer.removeAnimation(forKey: Self.openingAnimationKey)
                }
                self.updateOpening()
                return
            }
            if animated, self.openingFinish != nil { return }
            self.openingFinished = true
            self.openingFinish = nil
            self.openingDisplayLink?.invalidate()
            self.openingDisplayLink = nil
            (self.amountField as? WalletSendAnimatedAmountField)?.updateOpening(nil)
            (self.recipient.view as? WalletSendRecipientComponent.View)?.updateOpening(time: nil)
            for view in [self.balanceText.view, self.sendButton.view].compactMap({ $0 }) {
                view.layer.removeAnimation(forKey: Self.openingAnimationKey)
            }
        }

        private func updateOpening() {
            guard !self.openingFinished else { return }
            guard self.openingInForeground, self.isRecipientScreenVisible, !UIAccessibility.isReduceMotionEnabled else {
                self.finishOpening(animated: false)
                return
            }
            guard self.component != nil, !self.amountField.bounds.isEmpty else { return }
            let now = CACurrentMediaTime()
            if self.openingStart == nil, self.window != nil {
                self.openingStart = now
            }
            let elapsed = self.openingStart.map { now - $0 } ?? 0.0
            var amount = WalletSendAmountIntro(time: elapsed)
            var recipientTime = elapsed
            if let finish = self.openingFinish {
                let p = min(1.0, max(0.0, (now - finish.start) / 0.15))
                if p >= 1.0 { self.finishOpening(animated: false); return }
                let k = p * p * (3.0 - 2.0 * p)
                amount = finish.amount.finishing(CGFloat(k))
                recipientTime = finish.recipientTime + (2.1 - finish.recipientTime) * k
            } else if elapsed >= 2.1 {
                self.finishOpening(animated: false)
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            (self.amountField as? WalletSendAnimatedAmountField)?.updateOpening(elapsed < WalletSendAmountIntro.duration || self.openingFinish != nil ? amount : nil)
            (self.recipient.view as? WalletSendRecipientComponent.View)?.updateOpening(time: recipientTime)
            CATransaction.commit()
            if self.openingStart != nil {
                for view in [self.balanceText.view, self.sendButton.view].compactMap({ $0 }) where view.layer.animation(forKey: Self.openingAnimationKey) == nil {
                    let duration = self.openingFinish.map { max(0.0, 0.15 - (now - $0.start)) }
                        ?? max(0.0, WalletSendAmountIntro.duration - elapsed)
                    guard duration > 0.0 else { continue }
                    let samples = max(2, Int(ceil(duration * 120.0)))
                    let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
                    animation.values = (0 ... samples).map { index -> CGFloat in
                        let dt = duration * Double(index) / Double(samples)
                        if let finish = self.openingFinish {
                            let p = min(1.0, max(0.0, (now + dt - finish.start) / 0.15))
                            return finish.amount.rise * CGFloat(1.0 - p * p * (3.0 - 2.0 * p))
                        }
                        return index == samples ? 0.0 : WalletSendAmountIntro(time: elapsed + dt).rise
                    }
                    animation.duration = duration
                    animation.isAdditive = true
                    animation.calculationMode = .linear
                    view.layer.add(animation, forKey: Self.openingAnimationKey)
                }
                if self.openingDisplayLink == nil {
                    self.openingDisplayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                        self?.updateOpening()
                    })
                }
            }
        }

        func viewWillAppear() {
            self.isRecipientScreenVisible = true
            self.updateOpening()
            if let recipientView = self.recipient.view as? WalletSendRecipientComponent.View {
                recipientView.setAnimationVisible(recipientView.alpha > 0.0)
            }
        }

        func viewDidAppear() {
            self.isVisible = true
            Haptics.prime()
            self.activateAmountInputIfNeeded()
            self.resolvePeerAddressIfNeeded()
            self.feePreparationFailed = false
            self.updateFeePreparation()
            self.requestUpdate(transition: .immediate)
        }

        func viewWillDisappear() {
            self.finishOpening(animated: false)
            self.isVisible = false
            self.isRecipientScreenVisible = false
            (self.recipient.view as? WalletSendRecipientComponent.View)?.setAnimationVisible(false)
            Haptics.cancelRefusal()
            self.needsAmountFocus = false
            self.copyAddressToast?.dismiss()
            (self.keyboard.view as? WalletSendKeyboardComponent.View)?.cancelKeyPresses()
            if let controller = self.environment?.controller() as? WalletSendScreen, controller.parentController() != nil {
                self.amountField.endEditing(true)
            }
            if !self.isSubmittingTransfer {
                self.cancelPendingSend()
                if self.isEstimatingFee {
                    self.invalidateFeePreparation()
                }
            }
        }

        private func resolvePeerAddressIfNeeded() {
            guard let component = self.component, component.resolvedAddress == nil,
                  let peer = component.peer,
                  let generation = self.peerAddressResolution.begin() else {
                return
            }
            self.peerAddressDisposable.set((component.context.engine.wallet.getUserAddresses(
                userIds: [peer.id],
                force: true
            )
            |> deliverOnMainQueue).start(next: { [weak self] addresses in
                guard let self, self.component?.walletContext === component.walletContext else {
                    return
                }
                self.completePeerAddressResolution(peerId: peer.id, generation: generation, recipient: addresses.first(where: { $0.userId == peer.id }))
            }, error: { [weak self] _ in
                guard let self, self.component?.walletContext === component.walletContext else {
                    return
                }
                self.completePeerAddressResolution(peerId: peer.id, generation: generation, recipient: nil)
            }))
        }

        private func completePeerAddressResolution(peerId: EnginePeer.Id, generation: Int, recipient: WalletUserAddress?) {
            guard let component = self.component, component.resolvedAddress == nil,
                  let peer = component.peer, peer.id == peerId,
                  self.peerAddressResolution.complete(generation: generation, recipient: recipient) else {
                return
            }
            if let recipient = self.peerAddressResolution.recipient {
                self.applyResolvedRecipient(recipient)
                component.walletContext.rememberWalletPeer(peer, address: recipient.address)
            } else {
                self.updateRecipient(address: "", publicKey: nil)
            }
            self.requestUpdate(transition: .easeInOut(duration: 0.2))
        }

        private var shouldSendAll: Bool {
            guard self.amountSource == .manual, self.amount > 0, let walletBalance = self.walletBalance else {
                return false
            }
            return self.amount == walletBalance && !self.feesAreCovered(amount: self.amount)
        }

        private var commentEncrypted: Bool {
            return self.component?.peer != nil
                && self.comment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && !self.isCommentPublic
        }

        private var currentFeeRequest: WalletSendFeeRequest? {
            guard let walletInfo = self.walletInfo, !self.recipientAddress.isEmpty else { return nil }
            let comment: WalletContext.TransferFeeComment
            if self.commentEncrypted {
                comment = .encrypted
            } else if let text = self.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                comment = .plainText(byteCount: text.utf8.count)
            } else {
                comment = .none
            }
            return WalletSendFeeRequest(
                walletAddress: walletInfo.address,
                walletPublicKey: walletInfo.publicKey,
                address: self.recipientAddress,
                comment: comment
            )
        }

        private var isSelfTransfer: Bool {
            return WalletContext.isSelfTransfer(recipient: self.recipientAddress, walletAddress: self.walletAddress)
        }

        private func feesAreCovered(amount: Int64) -> Bool {
            guard !self.isSelfTransfer, let component = self.component else {
                return false
            }
            let configuration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            return WalletContext.isGaslessEligible(
                amount: amount,
                gaslessInfo: self.gaslessInfo.currentValue,
                minimumAmount: configuration.transferGaslessMinAmount
            )
        }

        private var feeDisplayState: WalletSendFeeDisplayState {
            guard self.amount > 0 else {
                if case .value? = self.previousFeeDisplayState, let fee = self.lastKnownFee, fee > 0 {
                    return .value(fee)
                }
                return .hidden
            }
            if !self.isSelfTransfer {
                if case .stale = self.gaslessInfo {
                    return .hidden
                }
                guard self.gaslessInfo.currentValue != nil else {
                    return .hidden
                }
            }
            if !self.shouldSendAll && self.feesAreCovered(amount: self.amount) {
                return .hidden
            }
            if self.feeRequest == self.currentFeeRequest,
               let fee = self.cachedFeeEstimate?.fee ?? (self.isEstimatingFee ? self.lastKnownFee : nil) {
                let effectiveAmount = self.shouldSendAll ? max(0, self.amount - fee) : self.amount
                if self.feesAreCovered(amount: effectiveAmount) || fee == 0 {
                    return .hidden
                }
                return .value(fee)
            }
            if self.feePreparationFailed {
                return .unavailable
            }
            if self.peerAddressResolution.state == .failed || self.peerAddressResolution.state == .errorPresented || self.peerAddressResolution.state == .cancelled {
                return .unavailable
            }
            if !self.walletIsLoading && self.currentFeeRequest == nil {
                return .unavailable
            }
            return .loading
        }

        private func updateFeePreparation() {
            guard self.isVisible, self.transferPreviewController == nil,
                  self.commentSessionAvailable, !self.isSubmittingTransfer else { return }
            let request = self.currentFeeRequest
            if self.feeRequest != request {
                if let pendingSend = self.pendingSend, pendingSend.feeRequest != request {
                    self.cancelPendingSend()
                }
                self.invalidateFeePreparation()
                self.feeRequest = request
            }
            guard let request else { return }
            if self.cachedFeeEstimate != nil {
                self.continuePendingSend()
                return
            }
            guard !self.isEstimatingFee, !self.feePreparationFailed else { return }
            self.isEstimatingFee = true
            let revision = self.feeRevision
            Queue.mainQueue().after(0.4) { [weak self] in
                guard let self, self.feeRevision == revision, self.feeRequest == request else { return }
                self.prepareFee(request: request, revision: revision)
            }
        }

        private func prepareFee(request: WalletSendFeeRequest, revision: Int) {
            guard let walletContext = self.walletContext,
                  self.isVisible, self.commentSessionAvailable,
                  self.feeRevision == revision, self.currentFeeRequest == request else { return }
            self.isEstimatingFee = true
            self.feePreparationFailed = false
            self.feeDisposable.set((walletContext.state
            |> filter { $0.activeOperation == nil }
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> mapToSignal { _ in
                return walletContext.estimateTransferFee(address: request.address, comment: request.comment)
            }
            |> deliverWalletSendEvents).start(next: { [weak self] estimate in
                guard let self, self.walletContext === walletContext,
                      self.isVisible, self.feeRevision == revision, self.currentFeeRequest == request else { return }
                self.isEstimatingFee = false
                self.cachedFeeEstimate = estimate
                self.lastKnownFee = estimate.fee
                self.continuePendingSend()
                self.requestUpdate(transition: .easeInOut(duration: 0.2))
            }, error: { [weak self] error in
                guard let self, self.walletContext === walletContext, self.feeRevision == revision else { return }
                let wasSending = self.pendingSend != nil
                self.isEstimatingFee = false
                self.feePreparationFailed = true
                if wasSending { self.cancelPendingSend() }
                self.requestUpdate(transition: .easeInOut(duration: 0.2))
                if wasSending { self.presentTransferError(error) }
            }))
        }

        fileprivate func invalidateCommentSession() {
            if !self.isSubmittingTransfer {
                self.cancelPendingSend()
            }
        }

        private func updateRecipient(address: String, publicKey: Data?) {
            guard self.recipientAddress != address || self.recipientPublicKey != publicKey else {
                return
            }
            let previousRequest = self.currentFeeRequest
            self.cancelPendingSend()
            self.recipientAddress = address
            self.recipientPublicKey = publicKey
            if previousRequest != self.currentFeeRequest {
                self.invalidateFeePreparation()
            }
        }

        private func applyResolvedRecipient(_ recipient: WalletUserAddress) {
            let address = WalletContext.transferRecipient(from: self.component?.initialAddress ?? "")?.address ?? recipient.address
            let accountAddress = WalletContext.transferAddress(from: address)
            let publicKey = accountAddress != nil && accountAddress == WalletContext.transferAddress(from: recipient.address)
                ? recipient.publicKey : nil
            self.updateRecipient(address: address, publicKey: publicKey)
        }

        private func applyRecipient(_ value: String) {
            let previousRequest = self.currentFeeRequest
            var address = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let components = URLComponents(string: address), components.scheme?.lowercased() == "ton" {
                if components.host?.lowercased() == "transfer" {
                    address = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                } else if let host = components.host, !host.isEmpty {
                    address = host
                }
                if let amountValue = components.queryItems?.first(where: { $0.name == "amount" })?.value,
                   let amount = Int64(amountValue), amount > 0 {
                    self.amount = amount
                    self.amountSource = .transferLink
                }
                if let comment = components.queryItems?.first(where: { $0.name == "text" })?.value, !comment.isEmpty {
                    self.comment = comment
                }
            }
            if let resolvedAddress = self.component?.resolvedAddress {
                self.applyResolvedRecipient(resolvedAddress)
            } else {
                self.updateRecipient(address: address, publicKey: nil)
            }
            if previousRequest != self.currentFeeRequest {
                self.invalidateFeePreparation()
            }
            if !self.isUpdating {
                self.requestUpdate(transition: .easeInOut(duration: 0.2))
            }
        }

        private func toggleInputMode() {
            guard !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer,
                  let rate = self.currentRate, rate.isFinite, rate > 0.0 else {
                return
            }
            Haptics.hit(0.6)
            switch self.inputMode {
            case .gram:
                self.inputMode = .fiat
            case .fiat:
                self.inputMode = .gram
                self.amount = (self.amount / 1_000_000) * 1_000_000
                guard self.validateTransferAmount() else {
                    return
                }
            }
            self.requestUpdate(transition: .easeInOut(duration: 0.25))
        }

        private func dismiss() {
            Haptics.cancelRefusal()
            self.abandonRestoration()
            self.cancelPendingSend()
            self.isVisible = false
            self.peerAddressResolution.state = .cancelled
            self.peerAddressDisposable.set(nil)
            guard let controller = self.environment?.controller() as? WalletSendScreen else {
                return
            }
            if let parentController = controller.parentController() {
                parentController.dismiss(animated: true)
            } else {
                controller.dismiss()
            }
        }

        @objc private func commentPressed() {
            guard self.component?.peer != nil, let comment = self.comment, !comment.isEmpty else {
                return
            }
            self.showCommentAlert()
        }

        private func openReceive() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            guard let walletAddress = self.walletAddress else {
                return
            }
            let receiveController = component.context.sharedContext.makeWalletReceiveScreen(
                context: component.context,
                address: walletAddress
            )
            if let parentController = (controller as? AttachmentContainable)?.parentController() {
                parentController.push(receiveController)
            } else {
                controller.push(receiveController)
            }
        }

        private var canOpenRecipientChat: Bool {
            guard let component = self.component, component.allowOpenRecipientChat, component.peer != nil,
                  !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer,
                  let controller = self.environment?.controller() as? WalletSendScreen,
                  controller.parentController() == nil,
                  controller.navigationController is NavigationController else {
                return false
            }
            return true
        }

        private func openRecipientChat() {
            guard self.isVisible, self.canOpenRecipientChat,
                  let component = self.component, let peer = component.peer,
                  let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                return
            }
            self.copyAddressToast?.dismiss()
            self.amountField.endEditing(true)
            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: component.context,
                chatLocation: .peer(peer),
                keepStack: .always,
                useExisting: true
            ))
        }

        private func copyRecipientAddress(_ address: String) {
            guard self.isVisible, !address.isEmpty,
                  let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            UIPasteboard.general.string = address
            Haptics.hit(0.4)
            self.copyAddressToast?.dismiss()
            let toast = UndoOverlayController(
                presentationData: self.currentPresentationData(for: component).initial,
                content: .copy(text: self.currentPresentationData(for: component).initial.strings.Wallet_TonAddressCopied),
                position: .bottom,
                action: { _ in false }
            )
            self.copyAddressToast = toast
            controller.present(toast, in: .current)
        }

        private func showRecipientInfoAlert() {
            guard self.recipientInfoAlert == nil, self.isVisible,
                  !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer,
                  let component = self.component,
                  !self.recipientAddress.isEmpty,
                  let controller = self.environment?.controller() else {
                return
            }

            let presentationData = self.currentPresentationData(for: component).initial
            let title: String
            let recipientName: String?
            if let peer = component.peer {
                let fullName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                let shortName = peer.compactDisplayTitle.isEmpty ? fullName : peer.compactDisplayTitle
                title = presentationData.strings.Wallet_Send_RecipientWallet(shortName).string
                if let username = peer.addressName, !username.isEmpty {
                    recipientName = "@\(username)"
                } else {
                    recipientName = fullName
                }
            } else {
                title = presentationData.strings.Wallet_Send_UnlinkedWallet
                recipientName = nil
            }
            let peerId = component.peer?.id
            let recipientAddress = self.recipientAddress
            var restoreInputFocus = self.amountField.isInputActive
            let openChat: (() -> Void)?
            if self.canOpenRecipientChat {
                openChat = { [weak self] in
                    guard let self, let alertController = self.recipientInfoAlert else { return }
                    restoreInputFocus = false
                    alertController.dismiss(completion: { [weak self] in
                        self?.openRecipientChat()
                    })
                }
            } else {
                openChat = nil
            }
            let alertController = AlertScreen(
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: true, allowInputInset: true),
                content: [
                    AnyComponentWithIdentity(
                        id: "recipientInfo",
                        component: AnyComponent(WalletSendRecipientAlertContentComponent(
                            title: title,
                            recipientName: recipientName,
                            address: recipientAddress,
                            openChat: openChat,
                            copyAddress: { [weak self] in
                                guard let self, let alertController = self.recipientInfoAlert else { return }
                                alertController.dismiss(completion: { [weak self] in
                                    self?.copyRecipientAddress(recipientAddress)
                                })
                            }
                        ))
                    )
                ],
                actions: [
                    AlertScreen.Action(title: presentationData.strings.Common_OK, type: .default)
                ],
                updatedPresentationData: self.currentPresentationData(for: component)
            )
            self.recipientInfoAlert = alertController
            alertController.dismissed = { [weak self, weak controller, weak alertController] _ in
                DispatchQueue.main.async { [weak self, weak controller, weak alertController] in
                    guard let self, self.recipientInfoAlert === alertController else {
                        return
                    }
                    self.recipientInfoAlert = nil
                    guard restoreInputFocus, self.isVisible, self.window != nil,
                          let controller, self.environment?.controller() === controller, !controller.isBeingDismissed,
                          self.component?.peer?.id == peerId, self.recipientAddress == recipientAddress,
                          !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer else {
                        return
                    }
                    self.amountField.activateInput()
                }
            }
            controller.present(alertController, in: .window(.root))
        }

        private func showCommentAlert() {
            guard !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer,
                  let component = self.component, let controller = self.environment?.controller() else {
                return
            }

            let strings = self.currentPresentationData(for: component).initial.strings
            let inputState = AlertMultilineInputFieldComponent.ExternalState()
            let publicCommentState = AlertCheckComponent.ExternalState()
            let isEditingComment = self.comment?.isEmpty == false

            let content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AlertTitleComponent(title: isEditingComment ? strings.Wallet_Send_EditComment : strings.Wallet_Send_AddComment))
                ),
                AnyComponentWithIdentity(
                    id: "input",
                    component: AnyComponent(AlertMultilineInputFieldComponent(
                        context: component.context,
                        initialValue: NSAttributedString(string: self.comment ?? ""),
                        placeholder: strings.Wallet_OptionalMessage,
                        maxHeight: (controller.view.window?.bounds.height ?? UIScreen.main.bounds.height) * 0.31,
                        returnKeyType: .default,
                        keyboardType: .default,
                        autocapitalizationType: .sentences,
                        autocorrectionType: .default,
                        isInitiallyFocused: true,
                        externalState: inputState
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "publicComment",
                    component: AnyComponent(AlertCheckComponent(
                        title: strings.Wallet_Send_PublicComment,
                        initialValue: self.isCommentPublic,
                        externalState: publicCommentState
                    ))
                )
            ]

            let alertController = AlertScreen(
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: false, allowInputInset: true),
                content: content,
                actions: [
                    AlertScreen.Action(title: strings.Common_Cancel),
                    AlertScreen.Action(title: isEditingComment ? strings.Common_Save : strings.Wallet_Send_Add, type: .default, action: { [weak self] in
                        guard let self, !self.isPreparingTransfer, !self.isSubmittingTransfer else {
                            return
                        }
                        let value = inputState.value.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        let comment = value.isEmpty ? nil : value
                        let previousRequest = self.currentFeeRequest
                        self.comment = comment
                        self.isCommentPublic = publicCommentState.value
                        if previousRequest != self.currentFeeRequest {
                            self.invalidateFeePreparation()
                        }
                        self.requestUpdate(transition: .spring(duration: 0.35))
                    })
                ],
                updatedPresentationData: self.currentPresentationData(for: component)
            )
            controller.present(alertController, in: .window(.root))
        }

        private func openMoreMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller(), !self.isPreparingTransfer else {
                return
            }
            Haptics.hit(0.4)

            let strings = self.currentPresentationData(for: component).initial.strings
            var items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(
                    text: strings.Wallet_Send_DepositFunds,
                    icon: { theme in
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Context Menu/AddCircle"),
                            color: theme.contextMenu.primaryColor
                        )
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openReceive()
                    }
                ))
            ]
            if component.peer != nil {
                items.append(.action(ContextMenuActionItem(
                    text: self.comment?.isEmpty == false ? strings.Wallet_Send_EditComment : strings.Wallet_Send_AddComment,
                    icon: { theme in
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"),
                            color: theme.contextMenu.primaryColor
                        )
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.showCommentAlert()
                    }
                )))
            }
            let contextController = makeContextController(
                presentationData: self.currentPresentationData(for: component).initial,
                source: .reference(WalletSendContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
        }

        private func validateTransferAmount() -> Bool {
            guard let component = self.component, self.amount > 0 else {
                return true
            }
            let configuration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            guard self.amount < configuration.transferMinAmount else {
                return true
            }

            self.amount = configuration.transferMinAmount
            self.amountField.setAmount(self.amount)
            self.amountField.layer.addShakeAnimation()
            Haptics.refuse()
            if !self.isUpdating {
                self.requestUpdate(transition: .immediate)
            }
            return false
        }

        private func send() {
            guard let component = self.component,
                  self.isVisible, self.transferPreviewController == nil, self.commentSessionAvailable,
                  self.amount > 0,
                  !self.isPreparingTransfer,
                  !self.isSubmittingTransfer,
                  !self.isResolvingSigningAccess,
                  !self.walletIsLoading,
                  self.walletInfo != nil,
                  let balance = self.walletBalance,
                  self.amount <= balance else {
                return
            }
            guard !self.recipientAddress.isEmpty else {
                return
            }
            guard self.validateTransferAmount() else {
                return
            }
            self.finishOpening(animated: true)
            guard let feeRequest = self.currentFeeRequest else { return }
            self.sendRevision &+= 1
            if component.transferAnimation == nil || UIAccessibility.isReduceMotionEnabled {
                Haptics.hit(0.95)
                let revision = self.sendRevision
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                    guard let self, self.sendRevision == revision,
                          self.isVisible, self.commentSessionAvailable,
                          self.isPreparingTransfer || self.isSubmittingTransfer,
                          UIApplication.shared.applicationState == .active else { return }
                    Haptics.hit(0.6)
                }
            }
            self.pendingSend = WalletSendTransferRequest(
                feeRequest: feeRequest,
                publicKey: self.recipientPublicKey,
                amount: self.amount,
                sendAll: self.shouldSendAll,
                comment: self.comment,
                commentEncrypted: self.commentEncrypted
            )
            self.isPreparingTransfer = true
            self.amountField.isUserInteractionEnabled = false
            self.amountField.endEditing(true)
            self.requestUpdate(transition: .immediate)
            self.performSend(component: component)
        }

        private func resolveSigningAccess(walletInfo: WalletContext.WalletInfo) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  !self.isResolvingSigningAccess else {
                return
            }
            self.continueSendingAfterSigningAccess = false
            if walletInfo.canSign {
                self.abandonRestoration()
                self.performSend(component: component)
                return
            }
            if walletInfo.canExportPhrase {
                self.isResolvingSigningAccess = true
                let generation = self.restorationGeneration
                self.requestUpdate(transition: .easeInOut(duration: 0.2))
                self.signingAccessDisposable.set(performWalletAuthorizedOperation(
                    context: component.context,
                    updatedPresentationData: self.currentPresentationData(for: component),
                    present: { [weak controller] alert in
                        controller?.present(alert, in: .window(.root))
                    },
                    operation: { [weak self] password -> Signal<[String], WalletContext.WalletError> in
                        guard let self, self.restorationGeneration == generation else { return .fail(.authorizationCancelled) }
                        return self.restorationAuthorization()
                        |> mapToSignal { session in component.walletContext.recoveryPhrase(password: password, session: session) }
                    },
                    next: { [weak self] _ in
                        guard let self, self.restorationGeneration == generation, self.component?.walletContext === component.walletContext else {
                            return
                        }
                        self.abandonRestoration()
                        self.continueSendingAfterSigningAccess = true
                        self.resumeSendingAfterSigningAccessIfReady()
                        self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    },
                    failed: { [weak self] error in
                        guard let self, self.restorationGeneration == generation else { return }
                        self.finishResolvingSigningAccess(error: error)
                    }
                ))
            } else {
                self.cancelPendingSend()
                self.requestUpdate(transition: .immediate)
                self.openRecoveryPhraseImport()
            }
        }

        private func resumeSendingAfterSigningAccessIfReady() {
            guard self.continueSendingAfterSigningAccess,
                  self.isVisible, self.commentSessionAvailable, !self.isSubmittingTransfer,
                  !self.isResolvingSigningAccess,
                  !self.walletIsLoading,
                  self.walletInfo?.canSign == true,
                  self.pendingSend != nil,
                  let walletContext = self.walletContext,
                  let component = self.component, component.walletContext === walletContext else {
                return
            }
            let revision = self.sendRevision
            guard self.scheduledSigningAccessRevision != revision else { return }
            self.scheduledSigningAccessRevision = revision
            let peerId = component.peer?.id
            DispatchQueue.main.async { [weak self] in
                guard let self, self.scheduledSigningAccessRevision == revision else { return }
                self.scheduledSigningAccessRevision = nil
                guard self.sendRevision == revision, self.walletContext === walletContext,
                      self.isVisible, self.commentSessionAvailable, !self.isSubmittingTransfer,
                      self.continueSendingAfterSigningAccess, !self.isResolvingSigningAccess,
                      !self.walletIsLoading, self.walletInfo?.canSign == true,
                      self.pendingSend != nil,
                      let component = self.component, component.walletContext === walletContext,
                      component.peer?.id == peerId else { return }
                self.continueSendingAfterSigningAccess = false
                self.performSend(component: component)
            }
        }

        fileprivate func abandonRestoration() {
            self.signingAccessDisposable.set(nil)
            self.scheduledSigningAccessRevision = nil
            self.restorationGeneration &+= 1
            self.restorationSession?.invalidate()
            self.restorationSession = nil
            self.isResolvingSigningAccess = false
            self.continueSendingAfterSigningAccess = false
        }

        private func restorationAuthorization() -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let component = self.component else { return .fail(.authorizationCancelled) }
            if let session = self.restorationSession, session.isValid { return .single(session) }
            let generation = self.restorationGeneration
            return component.walletContext.beginWalletFlow(reason: "Restore wallet")
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.restorationGeneration == generation else {
                    session.invalidate()
                    return .fail(.authorizationCancelled)
                }
                self.restorationSession?.invalidate()
                self.restorationSession = session
                return .single(session)
            }
        }

        private func finishResolvingSigningAccess(error: WalletContext.WalletError) {
            self.cancelPendingSend()
            self.requestUpdate(transition: .easeInOut(duration: 0.2))
            if error == .authorizationCancelled { return }
            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            let strings = self.currentPresentationData(for: component).initial.strings
            let message = walletAuthorizationErrorMessage(error, strings: strings)
            let generation = self.restorationGeneration
            controller.present(textAlertController(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                title: message?.title ?? strings.Wallet_RestoreErrorTitle,
                text: message?.text ?? strings.Wallet_NetworkError,
                actions: [
                    TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: { [weak self] in
                        guard let self, self.restorationGeneration == generation else { return }
                        self.abandonRestoration()
                    }),
                    TextAlertAction(type: .defaultAction, title: strings.Wallet_Retry, action: { [weak self] in
                        guard let self, self.restorationGeneration == generation else { return }
                        self.send()
                    })
                ],
                dismissOnOutsideTap: false
            ), in: .window(.root))
        }

        private func openRecoveryPhraseImport() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let hostController: ViewController
            if controller.navigationController != nil {
                hostController = controller
            } else if let parentController = (controller as? AttachmentContainable)?.parentController(),
                      parentController.navigationController != nil {
                hostController = parentController
            } else {
                return
            }
            let importController = component.context.sharedContext.makeWalletImportScreen(
                context: component.context,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.completeRecoveryPhraseImport()
                }
            )
            self.recoveryPhraseImportController = importController
            hostController.push(importController)
        }

        private func completeRecoveryPhraseImport() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  let importController = self.recoveryPhraseImportController else {
                return
            }
            self.recoveryPhraseImportController = nil
            importController.dismiss(animated: true)
            let presentationData = self.currentPresentationData(for: component).initial
            Queue.mainQueue().after(0.4) { [weak controller] in
                controller?.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: presentationData.strings.Wallet_Settings_WalletImportedTitle,
                        text: presentationData.strings.Wallet_Settings_WalletImportedText,
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ), in: .current)
            }
        }

        private func performSend(component: WalletSendScreenComponent) {
            guard self.isVisible, self.commentSessionAvailable,
                  self.walletContext === component.walletContext,
                  let request = self.pendingSend,
                  let walletInfo = self.walletInfo else { return }
            guard self.currentFeeRequest == request.feeRequest else {
                self.cancelPendingSend()
                self.requestUpdate(transition: .immediate)
                return
            }
            if component.peer == nil {
                if walletInfo.canSign {
                    self.openTransferPreview(request)
                } else {
                    self.resolveSigningAccess(walletInfo: walletInfo)
                }
                return
            }
            self.feePreparationFailed = false
            self.updateFeePreparation()
            self.requestUpdate(transition: .immediate)
        }

        private func continuePendingSend() {
            guard self.isVisible, self.commentSessionAvailable,
                  self.component?.peer != nil,
                  !self.isSubmittingTransfer, !self.isResolvingSigningAccess,
                  !self.isPreparingActualTransfer,
                  let walletContext = self.walletContext,
                  let request = self.pendingSend,
                  self.currentFeeRequest == request.feeRequest,
                  self.feeRequest == request.feeRequest, self.cachedFeeEstimate != nil else { return }
            let revision = self.sendRevision
            guard self.scheduledSendRevision != revision else { return }
            self.scheduledSendRevision = revision
            let peerId = self.component?.peer?.id
            DispatchQueue.main.async { [weak self] in
                guard let self, self.scheduledSendRevision == revision else { return }
                self.scheduledSendRevision = nil
                guard self.sendRevision == revision, self.walletContext === walletContext,
                      self.component?.walletContext === walletContext, self.component?.peer?.id == peerId else { return }
                self.beginPendingSend()
            }
        }

        private func beginPendingSend() {
            guard self.isVisible, self.commentSessionAvailable,
                  self.component?.peer != nil,
                  !self.isSubmittingTransfer, !self.isResolvingSigningAccess,
                  !self.isPreparingActualTransfer,
                  let walletContext = self.walletContext,
                  let request = self.pendingSend,
                  self.currentFeeRequest == request.feeRequest,
                  self.feeRequest == request.feeRequest, self.cachedFeeEstimate != nil else { return }
            self.isPreparingActualTransfer = true
            let revision = self.sendRevision
            let peerId = self.component?.peer?.id
            self.transferDisposable.set((walletContext.state
            |> filter { $0.activeOperation == nil }
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> deliverWalletSendEvents).start(next: { [weak self] state in
                guard let self, self.sendRevision == revision, self.pendingSend != nil,
                      self.isVisible, self.commentSessionAvailable, self.walletContext === walletContext,
                      self.component?.walletContext === walletContext, self.component?.peer?.id == peerId,
                      self.currentFeeRequest == request.feeRequest else { return }
                guard case let .wallet(info) = state.phase else {
                    self.cancelPendingSend()
                    self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    self.presentTransferError(.unavailable)
                    return
                }
                if !info.canSign {
                    self.isPreparingActualTransfer = false
                    self.resolveSigningAccess(walletInfo: info)
                    return
                }
                self.startPeerTransfer(request)
            }, error: { [weak self] error in
                guard let self, self.sendRevision == revision, self.walletContext === walletContext else { return }
                self.cancelPendingSend()
                self.requestUpdate(transition: .easeInOut(duration: 0.2))
                self.presentTransferError(error)
            }))
        }

        private func startPeerTransfer(_ request: WalletSendTransferRequest) {
            guard self.isVisible, let component = self.component, let peer = component.peer,
                  let controller = self.environment?.controller() as? WalletSendScreen else {
                self.cancelPendingSend()
                self.requestUpdate(transition: .immediate)
                return
            }
            var request = request
            request.estimatedFee = self.cachedFeeEstimate?.fee
            self.isSubmittingTransfer = true
            self.isPreparingTransfer = false
            self.isPreparingActualTransfer = false
            self.pendingSend = nil
            let submission = WalletPeerTransferSubmission(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                peer: peer,
                controller: controller,
                closeForm: { [weak self, weak controller] transferId in
                    guard let self, self.isVisible, let controller,
                          self.component?.walletContext === component.walletContext,
                          self.component?.peer?.id == peer.id else { return }
                    self.closeAfterTransferRegistration(transferId, component: component, controller: controller)
                },
                presentErrorOnForm: { [weak self] error in
                    guard let self, self.isVisible,
                          self.component?.walletContext === component.walletContext else { return false }
                    self.isSubmittingTransfer = false
                    self.cancelPendingSend()
                    self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    self.presentTransferError(error)
                    return true
                }
            )
            self.requestUpdate(transition: .immediate)
            submission.start(walletContext: component.walletContext, request: request)
        }

        private func closeAfterTransferRegistration(_ transferId: String?, component: WalletSendScreenComponent, controller: WalletSendScreen) {
            guard !self.isClosingAfterRegistration else { return }
            self.isClosingAfterRegistration = true
            let close: () -> Void = { [weak self, weak controller] in
                guard let self, let controller, self.isVisible else { return }
                self.isVisible = false
                let parentController = controller.parentController()
                component.completed?()
                if let parentController {
                    parentController.dismiss(animated: true)
                } else {
                    controller.dismiss()
                }
            }
            guard let transferId, let transferAnimation = component.transferAnimation else {
                close()
                return
            }
            let revision = self.sendRevision
            let presentationId = "pending:\(transferId)"
            var spinStartedAt: CFTimeInterval?
            let launch: () -> Void = { [weak self, weak controller] in
                guard let self, self.isVisible, self.sendRevision == revision,
                      self.component?.walletContext === component.walletContext,
                      controller?.peerTransferSubmission != nil else {
                    self?.isClosingAfterRegistration = false
                    return
                }
                let stillExists = component.walletContext.stateValue.transactions.items.contains(where: {
                    $0.presentationId == presentationId && $0.status != .failed
                })
                if stillExists {
                    let animate = self.commentSessionAvailable && UIApplication.shared.applicationState != .background
                        && !UIAccessibility.isReduceMotionEnabled
                    let source = animate ? (self.amountField as? WalletSendAnimatedAmountField)?.takeTransferDiamond(spinStartedAt: spinStartedAt) : nil
                    if !transferAnimation(presentationId, source) {
                        source?.diamond.isRenderingEnabled = false
                        source?.diamond.removeFromSuperview()
                    }
                }
                close()
            }
            guard self.commentSessionAvailable, UIApplication.shared.applicationState != .background,
                  !UIAccessibility.isReduceMotionEnabled else {
                launch()
                return
            }
            controller.transferAnimationWillStart?(presentationId)
            let switchedFromFiat = self.inputMode == .fiat
            if switchedFromFiat {
                self.inputMode = .gram
                self.requestUpdate(transition: .easeInOut(duration: 0.25))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (switchedFromFiat ? 0.54 : 0.0)) { [weak self] in
                guard let self, self.isVisible, self.sendRevision == revision else {
                    self?.isClosingAfterRegistration = false
                    return
                }
                guard self.commentSessionAvailable, UIApplication.shared.applicationState != .background,
                      !UIAccessibility.isReduceMotionEnabled else {
                    launch()
                    return
                }
                spinStartedAt = CACurrentMediaTime()
                (self.amountField as? WalletSendAnimatedAmountField)?.spinForTransfer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: launch)
            }
        }

        private func openTransferPreview(_ request: WalletSendTransferRequest) {
            guard self.isVisible, let component = self.component, component.peer == nil,
                  let controller = self.environment?.controller() else {
                self.cancelPendingSend()
                self.requestUpdate(transition: .immediate)
                return
            }

            let initialFee = self.feeRequest == request.feeRequest ? self.cachedFeeEstimate?.fee : nil
            let dismissSendScreen: () -> Void = { [weak controller] in
                guard let controller else { return }
                if let navigationController = controller.navigationController as? NavigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers.removeAll(where: { $0 === controller })
                    navigationController.setViewControllers(viewControllers, animated: false)
                } else {
                    controller.dismiss(animated: false)
                }
                component.completed?()
            }
            let previewController = component.context.sharedContext.makeWalletTransactionPreviewScreen(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                walletContext: component.walletContext,
                address: request.feeRequest.address,
                amount: request.amount,
                sendAll: request.sendAll,
                comment: request.comment,
                initialFee: initialFee,
                dismissSendScreen: dismissSendScreen
            )
            (previewController as? WalletSendTransferAnimationController)?.transferAnimation = component.transferAnimation
            self.transferPreviewController = previewController
            self.cancelPendingSend()
            if self.isEstimatingFee {
                self.invalidateFeePreparation()
            }
            self.requestUpdate(transition: .immediate)
            controller.push(previewController)
        }

        private func invalidateFeePreparation() {
            self.feeRevision &+= 1
            self.feeDisposable.set(nil)
            self.feeRequest = nil
            self.isEstimatingFee = false
            self.feePreparationFailed = false
            self.cachedFeeEstimate = nil
        }

        private func cancelPendingSend() {
            guard !self.isSubmittingTransfer else { return }
            self.isClosingAfterRegistration = false
            self.sendRevision &+= 1
            self.scheduledSendRevision = nil
            self.pendingSend = nil
            self.isPreparingTransfer = false
            self.isPreparingActualTransfer = false
            self.transferDisposable.set(nil)
            self.abandonRestoration()
            self.amountField.isUserInteractionEnabled = true
        }

        private func presentTransferError(_ error: WalletContext.WalletError? = nil) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            walletPresentTransferError(error, on: controller, context: component.context, updatedPresentationData: self.currentPresentationData(for: component))
        }

        func update(
            component: WalletSendScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            let peerChanged = self.component?.peer?.id != component.peer?.id
            let resolvedAddressChanged = self.component?.resolvedAddress != component.resolvedAddress
            self.component = component
            self.environment = environment
            self.componentState = state
            let attachmentController = environment.controller() as? WalletSendScreen
            let isInAttachmentMenu = attachmentController?.parentController() != nil
            let isLandscape = availableSize.width > availableSize.height && environment.metrics.widthClass == .compact

            if peerChanged || resolvedAddressChanged || self.walletContext !== component.walletContext {
                self.needsAmountFocus = false
            }
            if peerChanged || resolvedAddressChanged || (component.peer != nil && self.walletContext !== component.walletContext) {
                self.peerAddressDisposable.set(nil)
                self.peerAddressResolution.reset(resolvedAddress: component.resolvedAddress)
                self.updateRecipient(address: component.resolvedAddress?.address ?? "", publicKey: component.resolvedAddress?.publicKey)
                if let peer = component.peer, let resolvedAddress = component.resolvedAddress {
                    component.walletContext.rememberWalletPeer(peer, address: resolvedAddress.address)
                }
                self.initialAddress = nil
            }

            if self.initialAddress != component.initialAddress {
                self.initialAddress = component.initialAddress
                if !component.initialAddress.isEmpty {
                    self.applyRecipient(component.initialAddress)
                }
                self.needsAmountFocus = !isInAttachmentMenu && (component.peer != nil || !component.initialAddress.isEmpty)
            }

            if !self.didApplyInitialAmount {
                self.didApplyInitialAmount = true
                if let amount = component.initialAmountNanograms {
                    self.amount = amount
                    self.amountSource = .transferLink
                }
            }

            if self.walletContext !== component.walletContext {
                self.isSubmittingTransfer = false
                self.invalidateCommentSession()
                self.invalidateFeePreparation()
                self.lastKnownFee = nil
                self.walletContext = component.walletContext
                self.signingAccessDisposable.set(nil)
                self.walletInfo = nil
                self.walletBalance = nil
                self.gaslessInfo = .idle
                self.walletAddress = nil
                self.walletIsLoading = true
                self.isResolvingSigningAccess = false
                self.continueSendingAfterSigningAccess = false
                self.currentFiatCurrency = .usd
                self.currentRate = nil
                self.inputMode = .gram
                let accountId = component.context.account.id
                self.commentEnvironmentDisposable.set((combineLatest(
                    component.context.sharedContext.applicationBindings.applicationInForeground,
                    component.context.sharedContext.appLockContext.isPasscodeLocked,
                    component.context.sharedContext.activeAccountContexts |> map { primary, _, _ in primary?.account.id == accountId }
                ) |> deliverOnMainQueue).start(next: { [weak self] foreground, locked, current in
                    guard let self else { return }
                    self.openingInForeground = foreground
                    if !foreground { self.finishOpening(animated: false) }
                    self.commentSessionAvailable = foreground && !locked && current
                    if !self.commentSessionAvailable {
                        self.invalidateCommentSession()
                        if !self.isSubmittingTransfer { self.invalidateFeePreparation() }
                    } else {
                        self.updateFeePreparation()
                    }
                    if !self.isUpdating { self.requestUpdate(transition: .immediate) }
                }))
                self.commentCredentialChangesDisposable.set(PasscodeCredentialStore.shared.changes.start(next: { [weak self] _ in
                    self?.invalidateCommentSession()
                    self?.requestUpdate(transition: .immediate)
                }))
                let observedWalletContext = component.walletContext
                self.walletDisposable.set((component.walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.walletContext === observedWalletContext else {
                        return
                    }
                    if let previousInfo = self.walletInfo {
                        switch walletState.phase {
                        case let .wallet(info) where previousInfo.address == info.address && previousInfo.publicKey == info.publicKey:
                            break
                        default:
                            self.abandonRestoration()
                            self.invalidateCommentSession()
                            if !self.isSubmittingTransfer { self.invalidateFeePreparation() }
                            self.lastKnownFee = nil
                        }
                    }
                    self.walletBalance = walletState.balance.currentValue
                    self.gaslessInfo = walletState.gaslessInfo
                    if case .idle = walletState.gaslessInfo {
                        observedWalletContext.ensureGaslessInfo()
                    }
                    if case let .wallet(info) = walletState.phase {
                        self.walletInfo = info
                    } else {
                        self.walletInfo = nil
                    }
                    self.walletAddress = walletState.walletAddress
                    let isOwnPreparation = (self.isEstimatingFee || self.isPreparingActualTransfer)
                        && walletState.activeOperation == .preparingTransfer
                    self.walletIsLoading = self.walletInfo == nil
                        || walletState.balance.currentValue == nil
                        || (walletState.activeOperation != nil && !isOwnPreparation)
                    self.currentFiatCurrency = walletState.fiat.selectedCurrency
                    if let rate = walletState.fiat.selectedRate,
                       rate.unitsPerGram.isFinite,
                       rate.unitsPerGram > 0.0 {
                        self.currentRate = rate.unitsPerGram
                    } else {
                        self.currentRate = nil
                        self.inputMode = .gram
                    }
                    self.resumeSendingAfterSigningAccessIfReady()
                    if !self.isUpdating {
                        self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    }
                }))
            }

            if self.isVisible {
                self.resolvePeerAddressIfNeeded()
            }
            self.updateFeePreparation()
            let isAmountInputEnabled = !self.isPreparingTransfer && !self.isResolvingSigningAccess && !self.isSubmittingTransfer
            self.amountField.isUserInteractionEnabled = isAmountInputEnabled

            let theme = environment.theme
            self.backgroundColor = theme.list.modalPlainBackgroundColor

            let headerButtonSize = CGSize(width: 44.0, height: 44.0)
            let headerOriginY = environment.safeInsets.top + 16.0
            let controlButtonsWidth = max(
                1.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 32.0
            )
            let controlButtonsSize = self.controlButtons.update(
                transition: transition,
                component: AnyComponent(GlassControlPanelComponent(
                    theme: theme,
                    leftItem: GlassControlPanelComponent.Item(
                        items: [
                            GlassControlGroupComponent.Item(
                                id: AnyHashable("close"),
                                content: .icon("Navigation/Close"),
                                action: { [weak self] in
                                    guard let self else { return }
                                    Haptics.hit(0.4)
                                    self.dismiss()
                                }
                            )
                        ],
                        background: .panel
                    ),
                    centralItem: nil,
                    rightItem: GlassControlPanelComponent.Item(
                        items: [
                            GlassControlGroupComponent.Item(
                                id: AnyHashable("more"),
                                content: .animation("anim_morewide"),
                                action: { [weak self] in
                                    guard let self,
                                          let controlsView = self.controlButtons.view as? GlassControlPanelComponent.View,
                                          let sourceView = controlsView.rightItemView?.itemView(id: AnyHashable("more")) else {
                                        return
                                    }
                                    self.openMoreMenu(sourceView: sourceView)
                                }
                            )
                        ],
                        background: .panel
                    ),
                    centerAlignmentIfPossible: true,
                    isDark: theme.overallDarkAppearance
                )),
                environment: {},
                containerSize: CGSize(width: controlButtonsWidth, height: headerButtonSize.height)
            )
            if let controlButtonsView = self.controlButtons.view {
                if controlButtonsView.superview == nil {
                    self.addSubview(controlButtonsView)
                }
                transition.setFrame(
                    view: controlButtonsView,
                    frame: CGRect(
                        origin: CGPoint(x: environment.safeInsets.left + 16.0, y: headerOriginY),
                        size: controlButtonsSize
                    )
                )
            }

            let titleInset = environment.safeInsets.left + 72.0
            let titleAvailableWidth = max(0.0, availableSize.width - titleInset * 2.0)
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Wallet_Send_Title,
                        font: Font.semibold(17.0),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: titleAvailableWidth, height: headerButtonSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(
                        x: titleInset + floorToScreenPixels((titleAvailableWidth - titleSize.width) / 2.0),
                        y: headerOriginY + floorToScreenPixels((headerButtonSize.height - titleSize.height) / 2.0),
                        width: titleSize.width,
                        height: titleSize.height
                    )
                )
            }

            var recipientFrame: CGRect?
            if !isLandscape && (component.peer != nil || !self.recipientAddress.isEmpty) {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let recipientSize = self.recipient.update(
                    transition: transition,
                    component: AnyComponent(WalletSendRecipientComponent(
                        context: component.context,
                        theme: theme,
                        strings: environment.strings,
                        nameDisplayOrder: presentationData.nameDisplayOrder,
                        peer: component.peer,
                        address: self.recipientAddress,
                        isLoading: self.recipientAddress.isEmpty && (self.peerAddressResolution.state == .notRequested || self.peerAddressResolution.state == .loading),
                        openChat: self.canOpenRecipientChat ? { [weak self] in
                            self?.openRecipientChat()
                        } : nil,
                        copyAddress: { [weak self] in
                            guard let self else { return }
                            self.copyRecipientAddress(self.recipientAddress)
                        },
                        openInfo: { [weak self] in
                            self?.showRecipientInfoAlert()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: controlButtonsWidth, height: .greatestFiniteMagnitude)
                )
                let frame = CGRect(
                    x: environment.safeInsets.left + 16.0,
                    y: headerOriginY + headerButtonSize.height + 14.0,
                    width: recipientSize.width,
                    height: recipientSize.height
                )
                recipientFrame = frame
                if let recipientView = self.recipient.view {
                    if recipientView.superview == nil {
                        self.addSubview(recipientView)
                    }
                    recipientView.isUserInteractionEnabled = true
                    recipientView.accessibilityElementsHidden = false
                    transition.setFrame(view: recipientView, frame: frame)
                    transition.setAlpha(view: recipientView, alpha: 1.0)
                    if self.openingFinished {
                        (recipientView as? WalletSendRecipientComponent.View)?.updateOpening(time: nil)
                    }
                    (recipientView as? WalletSendRecipientComponent.View)?.setAnimationVisible(self.isRecipientScreenVisible)
                }
            } else if let recipientView = self.recipient.view {
                (recipientView as? WalletSendRecipientComponent.View)?.setAnimationVisible(false)
                recipientView.isUserInteractionEnabled = false
                recipientView.accessibilityElementsHidden = true
                transition.setAlpha(view: recipientView, alpha: 0.0)
            }

            let isKeyboardVisible = !isInAttachmentMenu || self.hasActivatedAmountInput
            let keyboardSize = self.keyboard.update(
                transition: transition,
                component: AnyComponent(WalletSendKeyboardComponent(
                    theme: theme,
                    safeInsets: environment.safeInsets,
                    isLandscape: isLandscape,
                    mode: .decimal(separator: environment.dateTimeFormat.decimalSeparator),
                    deleteTitle: environment.strings.Common_Delete,
                    isEnabled: isAmountInputEnabled && environment.isVisible && isKeyboardVisible,
                    action: { [weak self] action in
                        guard let self, self.isVisible,
                              !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer else {
                            return
                        }
                        switch action {
                        case let .insertText(text):
                            if self.amountField.insertText(text) {
                                Haptics.hit()
                            }
                        case .deleteBackward:
                            if self.amountField.deleteBackward() {
                                Haptics.hit(0.4)
                            }
                        }
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            let keyboardFrame = CGRect(
                x: 0.0,
                y: isKeyboardVisible ? availableSize.height - environment.additionalInsets.bottom - keyboardSize.height : availableSize.height,
                width: keyboardSize.width,
                height: keyboardSize.height
            )
            if let keyboardView = self.keyboard.view {
                if keyboardView.superview == nil {
                    self.addSubview(keyboardView)
                    keyboardView.frame = keyboardFrame
                    keyboardView.alpha = isKeyboardVisible ? 1.0 : 0.0
                }
                keyboardView.isUserInteractionEnabled = isAmountInputEnabled && isKeyboardVisible
                keyboardView.accessibilityElementsHidden = !isKeyboardVisible
                transition.setFrame(view: keyboardView, frame: keyboardFrame)
                transition.setAlpha(view: keyboardView, alpha: isKeyboardVisible ? 1.0 : 0.0)
            }
            let usableBottom = isKeyboardVisible ? keyboardFrame.minY : availableSize.height - environment.additionalInsets.bottom - environment.safeInsets.bottom
            let hasAmount = self.amount > 0
            let isInsufficient = hasAmount
                && !self.walletIsLoading
                && self.walletBalance.map { self.amount > $0 } == true
            let feeDisplayState = self.feeDisplayState
            let showFees = feeDisplayState != .hidden
            let feeVisibilityChanged = self.previousFeeDisplayState.map { ($0 != .hidden) != showFees } ?? false
            var contentPositionTransition = transition
            var contentVisibilityTransition = transition
            var statusVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
            if self.previousIsInsufficient == nil || !environment.isVisible {
                contentPositionTransition = .immediate
                contentVisibilityTransition = .immediate
                statusVisibilityTransition = .immediate
            } else if self.previousIsInsufficient != isInsufficient || feeVisibilityChanged {
                let reduceMotion = UIAccessibility.isReduceMotionEnabled
                statusVisibilityTransition = .easeInOut(duration: reduceMotion ? 0.15 : 0.22)
                contentPositionTransition = reduceMotion ? .immediate : statusVisibilityTransition
                contentVisibilityTransition = statusVisibilityTransition
            }
            self.previousIsInsufficient = isInsufficient
            self.previousFeeDisplayState = feeDisplayState
            let hasPositiveBalance = self.walletBalance.map { $0 > 0 } == true
            let hasZeroBalance = self.walletBalance == 0
            let sendButtonY = usableBottom - 68.0
            let showSendButton = hasAmount || component.peer != nil || !component.initialAddress.isEmpty
            let showBalance = (hasAmount || hasPositiveBalance) && !hasZeroBalance
            let balanceSlotY = sendButtonY - (showFees ? 58.0 : 36.0)
            
            var centralContentLayouts: [(view: UIView, frame: CGRect, transition: ComponentTransition)] = []
            var insufficientRowLayouts: [(view: UIView, frame: CGRect, transition: ComponentTransition)] = []
            let amountWidth = max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 32.0)
            let amountFrame = CGRect(
                x: environment.safeInsets.left + 16.0,
                y: 0.0,
                width: amountWidth,
                height: 74.0
            )
            var centralContentFrame = amountFrame
            contentPositionTransition.setBounds(view: self.amountField, bounds: CGRect(origin: .zero, size: amountFrame.size))
            centralContentLayouts.append((self.amountField, amountFrame, contentPositionTransition))
            self.amountField.update(
                mode: self.inputMode,
                amount: self.amount,
                rate: self.currentRate,
                fiatCurrency: self.currentFiatCurrency,
                dateTimeFormat: environment.dateTimeFormat,
                theme: theme,
                isVisible: environment.isVisible || (!self.openingFinished && self.isRecipientScreenVisible && self.openingInForeground),
                transition: transition
            )

            let emptyHint = environment.strings.Wallet_Send_AmountPlaceholder
            let showEmptyHint = !self.needsAmountFocus && !self.hasActivatedAmountInput && !self.amountField.isInputActive && !self.amountField.hasInputText
            let emptyHintSize = self.emptyHint.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: emptyHint,
                            font: Font.regular(15.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    )),
                    action: { [weak self] in
                        self?.amountField.activateInput()
                    },
                    isEnabled: showEmptyHint && isAmountInputEnabled,
                    animateScale: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 24.0)
            )
            let emptyHintFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - emptyHintSize.width) / 2.0),
                y: amountFrame.maxY + 5.0,
                width: emptyHintSize.width,
                height: emptyHintSize.height
            )
            if showEmptyHint {
                centralContentFrame = centralContentFrame.union(emptyHintFrame)
            }
            if let emptyHintView = self.emptyHint.view {
                if emptyHintView.superview == nil {
                    self.addSubview(emptyHintView)
                }
                emptyHintView.accessibilityLabel = emptyHint
                emptyHintView.accessibilityElementsHidden = !showEmptyHint
                contentPositionTransition.setBounds(view: emptyHintView, bounds: CGRect(origin: .zero, size: emptyHintFrame.size))
                centralContentLayouts.append((emptyHintView, emptyHintFrame, contentPositionTransition))
                contentVisibilityTransition.setAlpha(view: emptyHintView, alpha: showEmptyHint ? 1.0 : 0.0)
            }

            var rateText = ""
            if hasAmount, let rate = self.currentRate {
                switch self.inputMode {
                case .gram:
                    let fiatSwitchSuffix = " \(self.currentFiatCurrency.code)"
                    let formattedFiatValue = formatTonFiatValue(
                        self.amount,
                        divide: true,
                        rate: rate,
                        currencySymbol: "",
                        dateTimeFormat: environment.dateTimeFormat
                    )
                    rateText = "~" + formattedFiatValue + fiatSwitchSuffix
                case .fiat:
                    rateText = formatTonAmountText(
                        self.amount,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 2
                    )
                }
            }
            let showRate = !isLandscape && hasAmount && !rateText.isEmpty
            if showRate {
                self.lastRateText = rateText
                self.lastRateDisplaysGramIcon = self.inputMode == .fiat
            }
            let rateButtonSize = self.rateButton.update(
                text: self.lastRateText,
                displaysGramIcon: self.lastRateDisplaysGramIcon,
                mode: self.inputMode,
                dateTimeFormat: environment.dateTimeFormat,
                theme: theme,
                isVisible: environment.isVisible && showRate,
                isEnabled: showRate && isAmountInputEnabled,
                timing: (self.amountField as? WalletSendAnimatedAmountField)?.motionTiming,
                maxWidth: availableSize.width - 64.0
            )
            let rateButtonFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - rateButtonSize.width) / 2.0),
                y: amountFrame.maxY - 1.0,
                width: rateButtonSize.width,
                height: rateButtonSize.height
            )
            if !isLandscape && self.currentRate != nil {
                centralContentFrame = centralContentFrame.union(rateButtonFrame)
            }
            let amountContentBottom = isLandscape ? amountFrame.maxY : rateButtonFrame.maxY
            do {
                let rateButtonView = self.rateButton
                var rateVisibilityTransition = statusVisibilityTransition
                if rateButtonView.superview == nil {
                    self.addSubview(rateButtonView)
                    rateVisibilityTransition = .immediate
                }
                rateButtonView.bounds = CGRect(origin: .zero, size: rateButtonFrame.size)
                centralContentLayouts.append((rateButtonView, rateButtonFrame, contentPositionTransition))
                rateVisibilityTransition.setAlpha(view: rateButtonView, alpha: showRate ? 1.0 : 0.0)
                rateVisibilityTransition.setScale(view: rateButtonView, scale: showRate ? 1.0 : 0.01)
            }

            let insufficientTextSize = self.insufficientText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Wallet_Send_InsufficientFunds,
                        font: Font.regular(14.0),
                        textColor: theme.list.itemDestructiveColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 22.0)
            )
            let insufficientSlotFrame = CGRect(
                x: 16.0,
                y: amountContentBottom + 10.0,
                width: availableSize.width - 32.0,
                height: 22.0
            )
            let showDeposit = hasZeroBalance || isInsufficient || (!hasAmount && !hasPositiveBalance)
            let isDepositInline = !hasZeroBalance && (hasAmount || hasPositiveBalance)
            let depositItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Wallet_Send_DepositFunds,
                            font: Font.regular(14.0),
                            textColor: theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "arrow",
                    component: AnyComponent(BundleIconComponent(
                        name: "Item List/InlineTextRightArrow",
                        tintColor: theme.list.itemAccentColor,
                        maxSize: CGSize(width: 8.0, height: 14.0)
                    ))
                )
            ]
            let depositButtonSize = self.depositButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack(depositItems, spacing: 3.0)),
                    minSize: CGSize(width: isDepositInline ? 0.0 : availableSize.width - 32.0, height: 40.0),
                    action: { [weak self] in
                        self?.openReceive()
                    },
                    isEnabled: showDeposit
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(0.0, availableSize.width - 32.0 - (isDepositInline ? insufficientTextSize.width + 4.0 : 0.0)),
                    height: 40.0
                )
            )
            let insufficientOriginX = floorToScreenPixels((availableSize.width - insufficientTextSize.width - (isDepositInline ? 4.0 + depositButtonSize.width : 0.0)) / 2.0)
            let depositButtonFrame = CGRect(
                x: isDepositInline ? insufficientOriginX + insufficientTextSize.width + 4.0 : floorToScreenPixels((availableSize.width - depositButtonSize.width) / 2.0),
                y: (isDepositInline ? insufficientSlotFrame.midY : balanceSlotY + 12.0) - depositButtonSize.height / 2.0,
                width: depositButtonSize.width,
                height: depositButtonSize.height
            )
            let insufficientTextFrame = CGRect(
                x: insufficientOriginX,
                y: insufficientSlotFrame.minY + floorToScreenPixels((insufficientSlotFrame.height - insufficientTextSize.height) / 2.0),
                width: insufficientTextSize.width,
                height: insufficientTextSize.height
            )
            if isInsufficient {
                centralContentFrame = centralContentFrame.union(insufficientTextFrame)
            }
            if showDeposit && isDepositInline {
                centralContentFrame = centralContentFrame.union(depositButtonFrame)
            }
            
            var insufficientPositionTransition = contentPositionTransition
            if let insufficientTextView = self.insufficientText.view {
                let isNewlyAdded = insufficientTextView.superview == nil
                var insufficientVisibilityTransition = statusVisibilityTransition
                if isNewlyAdded {
                    self.addSubview(insufficientTextView)
                    insufficientVisibilityTransition = .immediate
                    insufficientPositionTransition = .immediate
                }
                insufficientPositionTransition.setBounds(view: insufficientTextView, bounds: CGRect(origin: .zero, size: insufficientTextFrame.size))
                insufficientRowLayouts.append((insufficientTextView, insufficientTextFrame, insufficientPositionTransition))
                insufficientVisibilityTransition.setAlpha(view: insufficientTextView, alpha: isInsufficient ? 1.0 : 0.0)
            }
            if let depositButtonView = self.depositButton.view {
                var depositPositionTransition = contentPositionTransition
                var depositVisibilityTransition = statusVisibilityTransition
                if depositButtonView.superview == nil {
                    self.addSubview(depositButtonView)
                    depositPositionTransition = .immediate
                    depositVisibilityTransition = .immediate
                }
                depositPositionTransition.setBounds(view: depositButtonView, bounds: CGRect(origin: .zero, size: depositButtonFrame.size))
                if isDepositInline {
                    insufficientRowLayouts.append((depositButtonView, depositButtonFrame, depositPositionTransition))
                } else {
                    depositPositionTransition.setPosition(view: depositButtonView, position: depositButtonFrame.center)
                }
                depositVisibilityTransition.setAlpha(view: depositButtonView, alpha: showDeposit ? 1.0 : 0.0)
            }

            let hideCommentPreview = isInAttachmentMenu && environment.metrics.widthClass == .regular && isInsufficient
            if !hideCommentPreview, component.peer != nil, let comment = self.comment, !comment.isEmpty {
                let isInitialCommentLayout = self.commentText.view?.superview == nil
                var commentTransition = transition
                if isInitialCommentLayout {
                    commentTransition = .immediate
                }
                let commentPositionTransition: ComponentTransition = isInitialCommentLayout ? .immediate : contentPositionTransition

                self.commentBackgroundView.isUserInteractionEnabled = true

                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

                let commentSize = self.commentText.update(
                    transition: commentTransition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: comment,
                            font: Font.semibold(16.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 120.0, height: 1000.0)
                )
                let bubbleSize = CGSize(width: commentSize.width + 34.0, height: max(34.0, commentSize.height + 14.0))
                self.commentBackgroundView.update(
                    size: bubbleSize,
                    maxCornerRadius: presentationData.chatBubbleCorners.mainRadius,
                    minCornerRadius: presentationData.chatBubbleCorners.auxiliaryRadius,
                    theme: theme
                )
                let commentOriginY: CGFloat
                if isInsufficient {
                    commentOriginY = (isDepositInline ? depositButtonFrame.maxY : insufficientTextFrame.maxY) + 8.0
                } else {
                    commentOriginY = amountContentBottom + 15.0
                }
                let bubbleFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - bubbleSize.width) / 2.0 + 3.0),
                    y: commentOriginY,
                    width: bubbleSize.width,
                    height: bubbleSize.height
                )
                centralContentFrame = centralContentFrame.union(bubbleFrame)
                ComponentTransition.immediate.setBounds(
                    view: self.commentBackgroundView,
                    bounds: CGRect(origin: .zero, size: bubbleFrame.size)
                )
                centralContentLayouts.append((self.commentBackgroundView, bubbleFrame, commentPositionTransition))
                if let commentTextView = self.commentText.view {
                    if commentTextView.superview == nil {
                        commentTextView.isUserInteractionEnabled = false
                        self.commentBackgroundView.addSubview(commentTextView)
                    }
                    let commentTextFrame = CGRect(
                        x: 14.0 - UIScreenPixel,
                        y: floorToScreenPixels((bubbleFrame.height - commentSize.height) / 2.0),
                        width: commentSize.width,
                        height: commentSize.height
                    )
                    ComponentTransition.immediate.setBounds(
                        view: commentTextView,
                        bounds: CGRect(origin: .zero, size: commentTextFrame.size)
                    )
                    commentPositionTransition.setPosition(view: commentTextView, position: commentTextFrame.center)
                }
                statusVisibilityTransition.setAlpha(view: self.commentBackgroundView, alpha: 1.0)
            } else {
                self.commentBackgroundView.isUserInteractionEnabled = false
                statusVisibilityTransition.setAlpha(view: self.commentBackgroundView, alpha: 0.0)
            }

            let formattedBalance: String
            if let balance = self.walletBalance {
                formattedBalance = formatTonAmountText(
                    balance,
                    dateTimeFormat: environment.dateTimeFormat,
                    maxDecimalPositions: 2,
                    formatString: environment.strings.Currency_Grams
                )
            } else {
                formattedBalance = "–"
            }

            let balanceTextSize = self.balanceText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Wallet_Send_Balance(formattedBalance).string,
                        font: Font.regular(14.0),
                        textColor: theme.list.itemSecondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 24.0)
            )
            let balanceTextFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - balanceTextSize.width) / 2.0),
                y: balanceSlotY + floorToScreenPixels((24.0 - balanceTextSize.height) / 2.0),
                width: balanceTextSize.width,
                height: balanceTextSize.height
            )
            if let balanceTextView = self.balanceText.view {
                var balancePositionTransition = contentPositionTransition
                if balanceTextView.superview == nil {
                    self.addSubview(balanceTextView)
                    balancePositionTransition = .immediate
                }
                balancePositionTransition.setBounds(view: balanceTextView, bounds: CGRect(origin: .zero, size: balanceTextFrame.size))
                balancePositionTransition.setPosition(view: balanceTextView, position: balanceTextFrame.center)
            }

            let feeValueComponent: AnyComponentWithIdentity<Empty>
            if feeDisplayState == .loading {
                feeValueComponent = AnyComponentWithIdentity(
                    id: "placeholder",
                    component: AnyComponent(WalletSendFeePlaceholderComponent(
                        color: theme.overallDarkAppearance ? theme.list.itemModalBlocksBackgroundColor : theme.list.itemInputField.backgroundColor
                    ))
                )
            } else {
                let feeValue: String
                var feeValueColor: UIColor = theme.list.itemSecondaryTextColor
                if case let .value(fee) = feeDisplayState {
                    feeValue = formatTonAmountText(
                        fee,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 5,
                        formatString: environment.strings.Currency_Grams
                    )
                } else {
                    feeValue = environment.strings.Currency_Grams(0).replacingOccurrences(of: "0", with: "0\(environment.dateTimeFormat.decimalSeparator)00000")
                    feeValueColor = .clear
                }
                feeValueComponent = AnyComponentWithIdentity(
                    id: "value",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: feeValue,
                            font: Font.regular(14.0),
                            textColor: feeValueColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                )
            }
            let feeTextSize: CGSize
            if !showFees, let feeTextView = self.feeText.view {
                feeTextSize = feeTextView.bounds.size
            } else {
                feeTextSize = self.feeText.update(
                    transition: .immediate,
                    component: AnyComponent(HStack([
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: environment.strings.Wallet_Send_NetworkFee,
                                    font: Font.regular(14.0),
                                    textColor: theme.list.itemSecondaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))
                        ),
                        feeValueComponent
                    ], spacing: 3.0)),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 32.0, height: 24.0)
                )
            }
            let feeTextFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - feeTextSize.width) / 2.0),
                y: sendButtonY - 24.0 - floorToScreenPixels(feeTextSize.height / 2.0),
                width: feeTextSize.width,
                height: feeTextSize.height
            )
            if let feeTextView = self.feeText.view {
                var feePositionTransition = contentPositionTransition
                if feeTextView.superview == nil {
                    feeTextView.isUserInteractionEnabled = false
                    self.addSubview(feeTextView)
                    feePositionTransition = .immediate
                }
                feePositionTransition.setBounds(view: feeTextView, bounds: CGRect(origin: .zero, size: feeTextFrame.size))
                feePositionTransition.setPosition(view: feeTextView, position: feeTextFrame.center)
                contentVisibilityTransition.setAlpha(view: feeTextView, alpha: showFees ? 1.0 : 0.0)
            }

            let centralContentTop = recipientFrame?.maxY ?? (headerOriginY + headerButtonSize.height)
            var centralContentBottom = showSendButton ? sendButtonY : usableBottom
            if showBalance {
                centralContentBottom = min(centralContentBottom, balanceTextFrame.minY)
            }
            if showDeposit && !isDepositInline {
                centralContentBottom = min(centralContentBottom, depositButtonFrame.minY)
            }
            if showFees {
                centralContentBottom = min(centralContentBottom, feeTextFrame.minY)
            }
            let centralContentOriginY = floorToScreenPixels(centralContentTop + max(
                12.0,
                (centralContentBottom - centralContentTop - centralContentFrame.height) / 2.0
            ))
            let centralContentOffsetY = centralContentOriginY - centralContentFrame.minY
            let insufficientRowOffsetY = min(centralContentOffsetY, balanceTextFrame.maxY - insufficientTextFrame.maxY)
            if let balanceTextView = self.balanceText.view {
                let insufficientTextBottom = insufficientTextFrame.maxY + insufficientRowOffsetY
                let isBalanceVisible = showBalance && (!isInsufficient || balanceTextFrame.minY - insufficientTextBottom >= 16.0)
                contentVisibilityTransition.setAlpha(view: balanceTextView, alpha: isBalanceVisible ? 1.0 : 0.0)
            }
            for layout in centralContentLayouts {
                layout.transition.setPosition(view: layout.view, position: layout.frame.center.offsetBy(dx: 0.0, dy: centralContentOffsetY))
            }
            for layout in insufficientRowLayouts {
                layout.transition.setPosition(view: layout.view, position: layout.frame.center.offsetBy(dx: 0.0, dy: insufficientRowOffsetY))
            }
            if !environment.isVisible {
                let contentViews = centralContentLayouts.map { $0.view } + insufficientRowLayouts.map { $0.view }
                    + [self.depositButton.view, self.balanceText.view, self.feeText.view].compactMap { $0 }
                for view in contentViews {
                    for key in ["position", "bounds", "bounds.origin", "bounds.size", "opacity"] {
                        view.layer.removeAnimation(forKey: key)
                    }
                }
                self.rateButton.layer.removeAnimation(forKey: "transform.scale")
            }
            self.activateAmountInputIfNeeded()

            let amountTitle: String
            if self.amount > 0 {
                amountTitle = formatTonAmountText(
                    self.amount,
                    dateTimeFormat: environment.dateTimeFormat,
                    maxDecimalPositions: self.inputMode == .fiat ? 2 : 9,
                    formatString: environment.strings.Currency_Grams
                )
            } else {
                amountTitle = environment.strings.Wallet_Send_Grams
            }

            let sendTitle: String
            let sendTitlePrefix: String?
            if component.peer == nil {
                sendTitle = environment.strings.Wallet_Continue
                sendTitlePrefix = nil
            } else {
                let formattedTitle = environment.strings.Wallet_Send_Amount(amountTitle)
                sendTitle = formattedTitle.string
                if let amountRange = formattedTitle.ranges.first(where: { $0.index == 0 }) {
                    sendTitlePrefix = (formattedTitle.string as NSString).substring(to: amountRange.range.location)
                } else {
                    sendTitlePrefix = nil
                }
            }
            var sendSubtitle: String?
            if component.peer != nil, hasAmount, self.inputMode == .fiat {
                let fiatAmountText = walletSendInputText(
                    amount: self.amount,
                    mode: .fiat,
                    rate: self.currentRate,
                    dateTimeFormat: environment.dateTimeFormat
                )
                if !fiatAmountText.isEmpty {
                    sendSubtitle = "~" + walletSendGroupedAmountText(fiatAmountText, dateTimeFormat: environment.dateTimeFormat)
                        + " " + self.currentFiatCurrency.code
                }
            }
            let hasRecipient = !self.recipientAddress.isEmpty
            let canSend = hasAmount
                && hasRecipient
                && !self.isPreparingTransfer
                && !self.isSubmittingTransfer
                && !self.isResolvingSigningAccess
                && !self.walletIsLoading
                && !isInsufficient
                && self.walletInfo != nil
                && self.walletBalance != nil
            let sendButtonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "send",
                        component: AnyComponent(WalletSendButtonContentComponent(
                            title: sendTitle,
                            titlePrefix: sendTitlePrefix,
                            subtitle: sendSubtitle,
                            color: theme.list.itemCheckColors.foregroundColor,
                            isVisible: environment.isVisible && showSendButton,
                            mode: self.inputMode,
                            dateTimeFormat: environment.dateTimeFormat,
                            timing: (self.amountField as? WalletSendAnimatedAmountField)?.motionTiming
                        ))
                    ),
                    isEnabled: canSend,
                    displaysProgress: self.isResolvingSigningAccess || self.isPreparingTransfer || self.isSubmittingTransfer,
                    action: { [weak self] in
                        self?.send()
                    }
                )),
                environment: {},
                containerSize: CGSize(
                    width: isLandscape ? 350.0 : controlButtonsWidth,
                    height: 52.0
                )
            )
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.addSubview(sendButtonView)
                }
                transition.setFrame(
                    view: sendButtonView,
                    frame: CGRect(
                        x: isLandscape ? floorToScreenPixels((availableSize.width - sendButtonSize.width) / 2.0) : environment.safeInsets.left + 16.0,
                        y: sendButtonY,
                        width: sendButtonSize.width,
                        height: sendButtonSize.height
                    )
                )
                transition.setAlpha(view: sendButtonView, alpha: showSendButton ? 1.0 : 0.0)
                sendButtonView.isUserInteractionEnabled = hasAmount
            }

            if let keyboardView = self.keyboard.view {
                self.bringSubviewToFront(keyboardView)
            }

            if isInAttachmentMenu {
                let isTabBarVisible = !isKeyboardVisible
                if self.isAttachmentTabBarVisible != isTabBarVisible {
                    self.isAttachmentTabBarVisible = isTabBarVisible
                    DispatchQueue.main.async { [weak self, weak attachmentController] in
                        guard let self, self.isAttachmentTabBarVisible == isTabBarVisible else { return }
                        attachmentController?.updateTabBarVisibility(isTabBarVisible, transition.containedViewLayoutTransition)
                    }
                }
            }

            self.updateOpening()
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletSendScreen: ViewControllerComponentContainer, AttachmentContainable {
    private let walletContext: WalletContext
    private var balanceRefreshDisposable: Disposable?
    private var gaslessInfoDisposable: Disposable?
    private var refreshBalanceOnOpen: Bool
    fileprivate var peerTransferSubmission: WalletPeerTransferSubmission?
    
    public var transferAnimationWillStart: ((String) -> Void)?

    public var requestAttachmentMenuExpansion: () -> Void = {
    }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in
    }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var cancelPanGesture: () -> Void = {
    }
    public var isContainerPanning: () -> Bool = {
        return false
    }
    public var isContainerExpanded: () -> Bool = {
        return false
    }
    public var allowsCollapsing: Bool {
        guard self.isNodeLoaded else {
            return true
        }
        return (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.isAmountInputActive != true
    }
    public var ignoresInputHeightInRegularLayout: Bool {
        return true
    }
    public var mediaPickerContext: AttachmentMediaPickerContext?
    public var isMinimized = false

    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        useDefaultAccent: Bool = true,
        peer: EnginePeer,
        walletContext: WalletContext,
        resolvedAddress: WalletUserAddress? = nil,
        initialAddress: String = "",
        initialAmountNanograms: Int64? = nil,
        refreshBalanceOnOpen: Bool = true,
        allowOpenRecipientChat: Bool = true,
        transferAnimation: WalletSendTransferAnimation? = nil,
        completed: (() -> Void)? = nil
    ) {
        self.walletContext = walletContext
        self.refreshBalanceOnOpen = refreshBalanceOnOpen
        var updatedPresentationData = updatedPresentationData ?? (
            initial: context.sharedContext.currentPresentationData.with { $0 },
            signal: context.sharedContext.presentationData
        )
        if useDefaultAccent {
            updatedPresentationData = presentationDataWithDefaultAccent(updatedPresentationData)
        }
        super.init(
            context: context,
            component: WalletSendScreenComponent(
                context: context,
                updatedPresentationData: updatedPresentationData,
                peer: peer,
                resolvedAddress: resolvedAddress,
                allowOpenRecipientChat: allowOpenRecipientChat,
                initialAddress: initialAddress,
                initialAmountNanograms: initialAmountNanograms,
                walletContext: walletContext,
                transferAnimation: transferAnimation,
                completed: completed
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        useDefaultAccent: Bool = true,
        walletContext: WalletContext,
        address: String,
        initialAmountNanograms: Int64? = nil,
        refreshBalanceOnOpen: Bool = true,
        transferAnimation: WalletSendTransferAnimation? = nil,
        completed: (() -> Void)? = nil
    ) {
        self.walletContext = walletContext
        self.refreshBalanceOnOpen = refreshBalanceOnOpen
        var updatedPresentationData = updatedPresentationData ?? (
            initial: context.sharedContext.currentPresentationData.with { $0 },
            signal: context.sharedContext.presentationData
        )
        if useDefaultAccent {
            updatedPresentationData = presentationDataWithDefaultAccent(updatedPresentationData)
        }
        super.init(
            context: context,
            component: WalletSendScreenComponent(
                context: context,
                updatedPresentationData: updatedPresentationData,
                peer: nil,
                resolvedAddress: nil,
                allowOpenRecipientChat: false,
                initialAddress: address,
                initialAmountNanograms: initialAmountNanograms,
                walletContext: walletContext,
                transferAnimation: transferAnimation,
                completed: completed
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        guard layout.metrics.widthClass == .regular else {
            return nil
        }
        return CGSize(
            width: min(480.0, layout.size.width - 20.0),
            height: min(layout.size.width, layout.size.height) - 88.0
        )
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.viewWillAppear()

        if self.gaslessInfoDisposable == nil {
            self.gaslessInfoDisposable = self.walletContext.beginGaslessInfoUpdates()
        }
        if self.refreshBalanceOnOpen {
            self.refreshBalanceOnOpen = false
            self.balanceRefreshDisposable = self.walletContext.refreshBalance()
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.navigationController?.viewControllers.contains(where: { $0 === self }) != true && self.parentController() == nil {
            (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.abandonRestoration()
            (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        }

        let peerTransferSubmission = self.peerTransferSubmission
        self.peerTransferSubmission = nil
        peerTransferSubmission?.formDidDisappear()

        self.balanceRefreshDisposable?.dispose()
        self.balanceRefreshDisposable = nil
        self.gaslessInfoDisposable?.dispose()
        self.gaslessInfoDisposable = nil
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.viewDidAppear()
        self.peerTransferSubmission?.formDidAppear()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        self.peerTransferSubmission?.formWillDisappear()
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.viewWillDisappear()

        super.viewWillDisappear(animated)
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        super.dismiss(completion: completion)
    }

    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        super.dismiss(animated: flag, completion: completion)
    }

    override public func viewWillLeaveNavigation() {
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        super.viewWillLeaveNavigation()
    }

    deinit {
        self.balanceRefreshDisposable?.dispose()
        self.gaslessInfoDisposable?.dispose()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WalletSendContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceView,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            actionsPosition: .bottom
        )
    }
}
