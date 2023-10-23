import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import UndoUI
import PresentationDataUtils

//TODO:localize

public func PremiumBoostScreen(
    context: AccountContext,
    contentContext: Any?,
    peerId: EnginePeer.Id,
    isCurrent: Bool,
    status: ChannelBoostStatus?,
    myBoostStatus: MyBoostStatus?,
    forceDark: Bool,
    openPeer: @escaping (EnginePeer) -> Void,
    presentController: @escaping (ViewController) -> Void,
    pushController: @escaping (ViewController) -> Void,
    dismissed: @escaping () -> Void
) {
    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> deliverOnMainQueue).startStandalone(next: { peer in
        guard let peer, let status else {
            return
        }
        
        var myBoostCount: Int32 = 0
        var availableBoosts: [MyBoostStatus.Boost] = []
        var occupiedBoosts: [MyBoostStatus.Boost] = []
        if let myBoostStatus {
            for boost in myBoostStatus.boosts {
                if let boostPeer = boost.peer {
                    if boostPeer.id == peer.id {
                        myBoostCount += 1
                    } else {
                        occupiedBoosts.append(boost)
                    }
                } else {
                    availableBoosts.append(boost)
                }
            }
        }
                
        var currentLevel = Int32(status.level)
        var currentLevelBoosts = Int32(status.currentLevelBoosts)
        var nextLevelBoosts = status.nextLevelBoosts.flatMap(Int32.init)
        
        if myBoostCount > 0 && status.boosts == currentLevelBoosts {
            currentLevel = max(0, currentLevel - 1)
            nextLevelBoosts = currentLevelBoosts
            currentLevelBoosts = max(0, currentLevelBoosts - 1)
        }
        
        let subject: PremiumLimitScreen.Subject = .storiesChannelBoost(peer: peer, isCurrent: isCurrent, level: currentLevel, currentLevelBoosts: currentLevelBoosts, nextLevelBoosts: nextLevelBoosts, link: nil, myBoostCount: myBoostCount)
        let nextSubject: PremiumLimitScreen.Subject = .storiesChannelBoost(peer: peer, isCurrent: isCurrent, level: currentLevel, currentLevelBoosts: currentLevelBoosts, nextLevelBoosts: nextLevelBoosts, link: nil, myBoostCount: myBoostCount + 1)
        var nextCount = Int32(status.boosts + 1)
        
        var updateImpl: (() -> Void)?
        var dismissImpl: (() -> Void)?
        let controller = PremiumLimitScreen(context: context, subject: subject, count: Int32(status.boosts), forceDark: forceDark, action: {
            let dismiss = false
            updateImpl?()
            return dismiss
        },
        openPeer: { peer in
            openPeer(peer)
        })
        pushController(controller)
        
        controller.disposed = {
            dismissed()
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        updateImpl = { [weak controller] in
            if let _ = status.nextLevelBoosts {
                if let availableBoost = availableBoosts.first {
                    let _ = context.engine.peers.applyChannelBoost(peerId: peerId, slots: [availableBoost.slot]).startStandalone()
                    controller?.updateSubject(nextSubject, count: nextCount)
                    
                    availableBoosts.removeFirst()
                    nextCount += 1
                } else if !occupiedBoosts.isEmpty, let myBoostStatus {
                    let replaceController = ReplaceBoostScreen(context: context, peerId: peerId, myBoostStatus: myBoostStatus, replaceBoosts: { slots in
                        let _ = context.engine.peers.applyChannelBoost(peerId: peerId, slots: slots).startStandalone()
                        
                        let undoController = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: "\(slots.count) boosts are reassigned from 1 other channel.", timeout: nil, customUndoText: nil), elevatedLayout: true, position: .bottom, action: { _ in return true })
                        presentController(undoController)
                    })
                    dismissImpl?()
                    pushController(replaceController)
                } else {
                    let controller = textAlertController(
                        sharedContext: context.sharedContext, 
                        updatedPresentationData: nil,
                        title: presentationData.strings.ChannelBoost_Error_PremiumNeededTitle,
                        text: presentationData.strings.ChannelBoost_Error_PremiumNeededText,
                        actions: [
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}),
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                                dismissImpl?()
                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .channelBoost(peerId), forceDark: forceDark, dismissed: nil)
                                pushController(controller)
                            })
                        ],
                        parseMarkdown: true
                    )
                    presentController(controller)
                }
            } else {
                dismissImpl?()
            }
        }
        dismissImpl = { [weak controller] in
            controller?.dismissAnimated()
        }
    })
}
