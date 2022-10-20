import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext

public class SetupTwoStepVerificationController: ViewController {
    private let context: AccountContext

    private let initialState: SetupTwoStepVerificationInitialState
    private let stateUpdated: (SetupTwoStepVerificationStateUpdate, Bool, SetupTwoStepVerificationController) -> Void
    
    private var controllerNode: SetupTwoStepVerificationControllerNode {
        return self.displayNode as! SetupTwoStepVerificationControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var didPlayPresentationAnimation = false
    
    private var currentBackAction = false
    private var currentNextAction: SetupTwoStepVerificationNextAction?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    public init(context: AccountContext, initialState: SetupTwoStepVerificationInitialState, stateUpdated: @escaping (SetupTwoStepVerificationStateUpdate, Bool, SetupTwoStepVerificationController) -> Void) {
        self.context = context

        self.initialState = initialState
        self.stateUpdated = stateUpdated
        
        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: self.presentationData.theme.rootController.navigationBar.accentTextColor, disabledButtonColor: self.presentationData.theme.rootController.navigationBar.disabledButtonColor, primaryTextColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    @objc private func backPressed() {
        self.controllerNode.activateBackAction()
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn(completion: presentationArguments.completion)
            }
        }
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = SetupTwoStepVerificationControllerNode(context: self.context, updateBackAction: { [weak self] action in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currentBackAction == action {
                return
            }
            strongSelf.currentBackAction = action
            let item: UIBarButtonItem?
            if action {
                item = UIBarButtonItem(backButtonAppearanceWithTitle: strongSelf.presentationData.strings.Common_Back, target: strongSelf, action: #selector(strongSelf.backPressed))
            } else {
                item = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, style: .plain, target: strongSelf, action: #selector(strongSelf.cancelPressed))
            }
            strongSelf.navigationItem.setLeftBarButton(item, animated: false)
        }, updateNextAction: { [weak self] action in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currentNextAction == action {
                return
            }
            strongSelf.currentNextAction = action
            let item: UIBarButtonItem?
            switch action {
                case .none:
                    item = nil
                case .activity:
                    item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.presentationData.theme.rootController.navigationBar.controlColor))
                case let .button(title, _):
                    item = UIBarButtonItem(title: title, style: .done, target: strongSelf, action: #selector(strongSelf.nextPressed))
            }
            if let title = item?.title, !title.isEmpty, strongSelf.navigationItem.rightBarButtonItem?.title == title {
            } else {
                strongSelf.navigationItem.setRightBarButton(item, animated: false)
            }
            if case let .button(_, isEnabled) = action {
                strongSelf.navigationItem.rightBarButtonItem?.isEnabled = isEnabled
            }
        }, stateUpdated: { [weak self] state, shouldDismiss in
            if let strongSelf = self {
                strongSelf.stateUpdated(state, shouldDismiss, strongSelf)
            }
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, dismiss: { [weak self] in
            self?.dismiss()
        }, initialState: self.initialState)
        self._ready.set(.single(true))
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func nextPressed() {
        self.controllerNode.activateNextAction()
    }
}
