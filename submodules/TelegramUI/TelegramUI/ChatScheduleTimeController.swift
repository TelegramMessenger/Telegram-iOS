import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext

enum ChatScheduleTimeControllerMode {
    case scheduledMessages
    case reminders
}

final class ChatScheduleTimeController: ViewController {
    private var controllerNode: ChatScheduleTimeControllerNode {
        return self.displayNode as! ChatScheduleTimeControllerNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let mode: ChatScheduleTimeControllerMode
    private let completion: (Int32) -> Void
    
    init(context: AccountContext, mode: ChatScheduleTimeControllerMode, completion: @escaping (Int32) -> Void) {
        self.context = context
        self.mode = mode
        self.completion = completion
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatScheduleTimeControllerNode(context: self.context, mode: self.mode)
        self.controllerNode.completion = { [weak self] time in
            self?.completion(time + 5)
            self?.dismiss()
        }
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
    }
    
    override public func loadView() {
        super.loadView()
        
        self.statusBar.removeFromSupernode()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
