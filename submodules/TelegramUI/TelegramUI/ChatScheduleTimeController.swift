import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext

enum ChatScheduleTimeControllerMode {
    case scheduledMessages(sendWhenOnlineAvailable: Bool)
    case reminders
}

final class ChatScheduleTimeController: ViewController {
    private var controllerNode: ChatScheduleTimeControllerNode {
        return self.displayNode as! ChatScheduleTimeControllerNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let peerId: PeerId
    private let mode: ChatScheduleTimeControllerMode
    private let editingTime: Bool
    private let currentTime: Int32?
    private let minimalTime: Int32?
    private let dismissByTapOutside: Bool
    private let completion: (Int32) -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, peerId: PeerId, mode: ChatScheduleTimeControllerMode, currentTime: Int32? = nil, minimalTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        self.context = context
        self.peerId = peerId
        self.mode = mode
        self.editingTime = currentTime != nil
        self.currentTime = currentTime != scheduleWhenOnlineTimestamp ? currentTime : nil
        self.minimalTime = minimalTime
        self.dismissByTapOutside = dismissByTapOutside
        self.completion = completion
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
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
            guard let strongSelf = self else {
                return
            }
            if time == scheduleWhenOnlineTimestamp {
                let _ = (strongSelf.context.account.viewTracker.peerView(strongSelf.peerId)
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] peerView in
                    guard let strongSelf = self, let peer = peerViewMainPeer(peerView) else {
                        return
                    }
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if !strongSelf.editingTime, let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case let .present(statusTimestamp) = presence.status, statusTimestamp >= timestamp {
                        strongSelf.completion(0)
                    } else {
                        strongSelf.completion(time)
                    }
                })
            } else {
                strongSelf.completion(time + 5)
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
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
