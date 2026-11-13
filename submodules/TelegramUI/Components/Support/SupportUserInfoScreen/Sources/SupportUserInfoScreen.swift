import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ViewControllerComponent
import TextFieldComponent
import UndoUI
import PresentationDataUtils
import ProgressNavigationButtonNode

private final class SupportUserInfoScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let initialText: NSAttributedString

    init(context: AccountContext, initialText: NSAttributedString) {
        self.context = context
        self.initialText = initialText
    }

    static func ==(lhs: SupportUserInfoScreenComponent, rhs: SupportUserInfoScreenComponent) -> Bool {
        return lhs.context === rhs.context && lhs.initialText == rhs.initialText
    }

    final class View: UIView {
        private let cardView = UIView()
        private let textField = ComponentView<Empty>()
        private let textFieldExternalState = TextFieldComponent.ExternalState()

        private var component: SupportUserInfoScreenComponent?
        private var environment: ViewControllerComponentContainer.Environment?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.cardView.layer.cornerRadius = 26.0
            self.cardView.layer.cornerCurve = .continuous
            self.cardView.clipsToBounds = true
            self.addSubview(self.cardView)

            self.cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.cardTapped)))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func cardTapped() {
            self.activateInput()
        }

        func activateInput() {
            (self.textField.view as? TextFieldComponent.View)?.activateInput()
        }

        func fieldText() -> NSAttributedString? {
            return (self.textField.view as? TextFieldComponent.View)?.getAttributedText()
        }

        func update(component: SupportUserInfoScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            if self.component == nil {
                self.textFieldExternalState.initialText = component.initialText
            }
            self.component = component
            self.environment = environment

            let theme = environment.theme
            self.backgroundColor = theme.list.blocksBackgroundColor
            self.cardView.backgroundColor = theme.list.itemBlocksBackgroundColor

            let sideInset = 16.0 + environment.safeInsets.left
            let topInset = environment.navigationHeight + 16.0
            let bottomInset = max(environment.inputHeight, environment.safeInsets.bottom) + 16.0
            let cardFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: CGSize(width: availableSize.width - sideInset - 16.0 - environment.safeInsets.right, height: max(60.0, availableSize.height - topInset - bottomInset)))
            transition.setFrame(view: self.cardView, frame: cardFrame)

            self.textField.parentState = state
            let textFieldSize = self.textField.update(
                transition: .immediate,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    externalState: self.textFieldExternalState,
                    fontSize: 17.0,
                    textColor: theme.list.itemPrimaryTextColor,
                    accentColor: theme.list.itemAccentColor,
                    insets: UIEdgeInsets(top: 12.0, left: 8.0, bottom: 12.0, right: 8.0),
                    hideKeyboard: false,
                    customInputView: nil,
                    placeholder: NSAttributedString(string: environment.strings.Support_Info_Placeholder, font: Font.regular(17.0), textColor: theme.list.itemPlaceholderTextColor),
                    resetText: nil,
                    isOneLineWhenUnfocused: false,
                    characterLimit: supportUserInfoMaxLength,
                    formatMenuAvailability: .available(TextFieldComponent.FormatMenuAvailability.Action.all),
                    lockedFormatAction: {},
                    present: { [weak self] controller in
                        self?.environment?.controller()?.present(controller, in: .window(.root))
                    },
                    paste: { _ in }
                )),
                environment: {},
                containerSize: cardFrame.size
            )
            if let textFieldView = self.textField.view {
                if textFieldView.superview == nil {
                    self.cardView.addSubview(textFieldView)
                }
                textFieldView.frame = CGRect(origin: CGPoint(), size: textFieldSize)
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class SupportUserInfoScreen: ViewControllerComponentContainer, StandalonePresentableController {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let originalEntities: [MessageTextEntity]
    private let originalContent: SupportUserInfoContent
    private let presentationData: PresentationData
    private let saveDisposable = MetaDisposable()
    private var didAppear = false

    public init(context: AccountContext, peerId: EnginePeer.Id, info: SupportUserInfo?) {
        self.context = context
        self.peerId = peerId
        self.originalEntities = info?.entities ?? []
        let initialText = supportUserInfoEditorText(info)
        self.originalContent = supportUserInfoContent(fieldText: initialText, originalEntities: info?.entities ?? [])
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(context: context, component: SupportUserInfoScreenComponent(context: context, initialText: initialText), navigationBarAppearance: .default, theme: .default)

        self.title = info == nil ? self.presentationData.strings.Support_Info_AddTitle : self.presentationData.strings.Support_Info_EditTitle
        self.updateNavigationButtons(isSaving: false)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.saveDisposable.dispose()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !self.didAppear {
            self.didAppear = true
            let position = self.view.layer.position
            self.view.layer.animatePosition(from: CGPoint(x: position.x, y: position.y + self.view.bounds.height), to: position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            self.componentView?.activateInput()
        }
    }

    private var componentView: SupportUserInfoScreenComponent.View? {
        return self.node.hostView.componentView as? SupportUserInfoScreenComponent.View
    }

    private func updateNavigationButtons(isSaving: Bool) {
        if isSaving {
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
        } else {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Save, style: .done, target: self, action: #selector(self.savePressed))
        }
        self.componentView?.isUserInteractionEnabled = !isSaving
    }

    private func close() {
        self.view.endEditing(true)
        let position = self.view.layer.position
        self.view.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + self.view.bounds.height), duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            self?.dismiss()
        })
    }

    private func presentToast(text: String) {
        self.present(UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), action: { _ in return false }), in: .window(.root))
    }

    @objc private func cancelPressed() {
        self.close()
    }

    @objc private func savePressed() {
        guard let fieldText = self.componentView?.fieldText() else {
            return
        }
        let content = supportUserInfoContent(fieldText: fieldText, originalEntities: self.originalEntities)
        switch supportUserInfoSaveDecision(original: self.originalContent, current: content) {
        case .close:
            self.close()
        case .tooLong:
            self.presentToast(text: self.presentationData.strings.Support_Info_TooLong)
        case .confirmDelete:
            let strings = self.presentationData.strings
            self.present(textAlertController(context: self.context, title: strings.Support_Info_DeleteTitle, text: strings.Support_Info_DeleteText, actions: [
                TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: strings.Common_Delete, action: { [weak self] in
                    self?.save(content: content)
                })
            ]), in: .window(.root))
        case .save:
            self.save(content: content)
        }
    }

    private func save(content: SupportUserInfoContent) {
        self.updateNavigationButtons(isSaving: true)
        self.saveDisposable.set((self.context.engine.peers.saveSupportUserInfo(peerId: self.peerId, text: content.text, entities: content.entities)
        |> deliverOnMainQueue).start(error: { [weak self] _ in
            guard let self else {
                return
            }
            self.updateNavigationButtons(isSaving: false)
            self.presentToast(text: self.presentationData.strings.Support_Info_SaveError)
        }, completed: { [weak self] in
            self?.close()
        }))
    }
}
