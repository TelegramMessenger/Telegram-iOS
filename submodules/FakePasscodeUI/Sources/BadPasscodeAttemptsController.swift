import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import FakePasscode

public final class BadPasscodeAttemptsController: ViewController, ReactiveToPasscodeSwitch {
    private var controllerNode: BadPasscodeAttemptsControllerNode {
        return self.displayNode as! BadPasscodeAttemptsControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var previousContentOffset: ListViewVisibleContentOffset?
    
    private var clearBtn: UIBarButtonItem?
    
    public var clear: (() -> Void)?
    
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.PasscodeSettings_BadAttempts
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.clearBtn = UIBarButtonItem(title: self.presentationData.strings.PasscodeSettings_BadAttempts_Clear, style: .plain, target: self, action: #selector(self.clearPressed))
        self.navigationItem.rightBarButtonItem = self.clearBtn
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
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
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = self.presentationData.strings.PasscodeSettings_BadAttempts
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
        
        let clearBtn = UIBarButtonItem(title: self.presentationData.strings.PasscodeSettings_BadAttempts_Clear, style: .plain, target: self, action: #selector(self.clearPressed))
        if self.navigationItem.rightBarButtonItem === self.clearBtn {
            self.navigationItem.rightBarButtonItem = clearBtn
        }
        self.clearBtn = clearBtn
    }
    
    override public func loadDisplayNode() {
        self.displayNode = BadPasscodeAttemptsControllerNode(context: self.context, presentationData: self.presentationData)
        
        self.controllerNode.listNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                var previousContentOffsetValue: CGFloat?
                if let previousContentOffset = strongSelf.previousContentOffset, case let .known(value) = previousContentOffset {
                    previousContentOffsetValue = value
                }
                switch offset {
                    case let .known(value):
                        let transition: ContainedViewLayoutTransition
                        if let previousContentOffsetValue = previousContentOffsetValue, value <= 0.0, previousContentOffsetValue > 30.0 {
                            transition = .animated(duration: 0.2, curve: .easeInOut)
                        } else {
                            transition = .immediate
                        }
                        strongSelf.navigationBar?.updateBackgroundAlpha(min(30.0, value) / 30.0, transition: transition)
                    case .unknown, .none:
                        strongSelf.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
                }
                
                strongSelf.previousContentOffset = offset
            }
        }
        
        self._ready.set(self.controllerNode._ready.get())
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, transition: transition)
    }
    
    @objc private func clearPressed() {
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.PasscodeSettings_BadAttempts_Clear, color: .destructive, action: { [weak actionSheet, weak self] in
                actionSheet?.dismissAnimated()
                
                if let strongSelf = self {
                    strongSelf.clear?()
                }
            })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
        
        self.present(actionSheet, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    public func passcodeSwitched() {
        self.dismiss(animated: false)
    }
}
