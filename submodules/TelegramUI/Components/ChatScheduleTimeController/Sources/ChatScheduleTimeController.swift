import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData

public enum ChatScheduleTimeControllerMode {
    case scheduledMessages(sendWhenOnlineAvailable: Bool)
    case reminders
    case suggestPost(needsTime: Bool, isAdmin: Bool, funds: (amount: CurrencyAmount, commissionPermille: Int)?)
}

public enum ChatScheduleTimeControllerStyle {
    case `default`
    case media
}

public final class ChatScheduleTimeController: ViewController {
    private var controllerNode: ChatScheduleTimeControllerNode {
        return self.displayNode as! ChatScheduleTimeControllerNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let mode: ChatScheduleTimeControllerMode
    private let style: ChatScheduleTimeControllerStyle
    private let currentTime: Int32?
    private let minimalTime: Int32?
    private let dismissByTapOutside: Bool
    private let completion: (Int32) -> Void
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public var dismissed: () -> Void = {}
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mode: ChatScheduleTimeControllerMode, style: ChatScheduleTimeControllerStyle, currentTime: Int32? = nil, minimalTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        self.context = context
        self.mode = mode
        self.style = style
        self.currentTime = currentTime != scheduleWhenOnlineTimestamp ? currentTime : nil
        self.minimalTime = minimalTime
        self.dismissByTapOutside = dismissByTapOutside
        self.completion = completion
        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatScheduleTimeControllerNode(context: self.context, presentationData: self.presentationData, mode: self.mode, style: self.style, currentTime: self.currentTime, minimalTime: self.minimalTime, dismissByTapOutside: self.dismissByTapOutside)
        self.controllerNode.completion = { [weak self] time in
            guard let strongSelf = self else {
                return
            }
            if time == 0 {
                strongSelf.completion(time)
            } else {
                strongSelf.completion(time == scheduleWhenOnlineTimestamp ? time : time + 5)
            }
            strongSelf.dismiss()
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
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismissed()
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
