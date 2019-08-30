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
    private let currentTime: Int32?
    private let minimalTime: Int32?
    private let dismissByTapOutside: Bool
    private let completion: (Int32) -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, mode: ChatScheduleTimeControllerMode, currentTime: Int32? = nil, minimalTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        self.context = context
        self.mode = mode
        self.currentTime = currentTime
        self.minimalTime = minimalTime
        self.dismissByTapOutside = dismissByTapOutside
        self.completion = completion
        
        super.init(navigationBarPresentationData: nil)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatScheduleTimeControllerNode(context: self.context, mode: self.mode, currentTime: self.currentTime, minimalTime: self.minimalTime, dismissByTapOutside: self.dismissByTapOutside)
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
