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

private struct BoostState {
    let level: Int32
    let currentLevelBoosts: Int32
    let nextLevelBoosts: Int32?
    let boosts: Int32
    
    func displayData(peer: EnginePeer, isCurrent: Bool, myBoostCount: Int32, currentMyBoostCount: Int32, replacedBoosts: Int32? = nil) -> (subject: PremiumLimitScreen.Subject, count: Int32) {
        var currentLevel = self.level
        var nextLevelBoosts = self.nextLevelBoosts
        var currentLevelBoosts = self.currentLevelBoosts
        var boosts = self.boosts
        if let replacedBoosts {
            boosts = max(currentLevelBoosts, boosts - replacedBoosts)
        }
        
        if currentMyBoostCount > 0 && self.boosts == currentLevelBoosts {
            currentLevel = max(0, currentLevel - 1)
            nextLevelBoosts = currentLevelBoosts
            currentLevelBoosts = max(0, currentLevelBoosts - 1)
        }
        
        return (
            .storiesChannelBoost(peer: peer, isCurrent: isCurrent, level: currentLevel, currentLevelBoosts: currentLevelBoosts, nextLevelBoosts: nextLevelBoosts, link: nil, myBoostCount: myBoostCount),
            boosts
        )
    }
}

public func PremiumBoostScreen(
    context: AccountContext,
    contentContext: Any?,
    peerId: EnginePeer.Id,
    isCurrent: Bool,
    status: ChannelBoostStatus?,
    myBoostStatus: MyBoostStatus?,
    replacedBoosts: (Int32, Int32)? = nil,
    forceDark: Bool,
    openPeer: @escaping (EnginePeer) -> Void,
    presentController: @escaping (ViewController) -> Void,
    pushController: @escaping (ViewController) -> Void,
    dismissed: @escaping () -> Void
) {
    let _ = (context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
        TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
    )
    |> deliverOnMainQueue).startStandalone(next: { peer, accountPeer in
        guard let peer, let accountPeer, let status else {
            return
        }
        
        let isPremium = accountPeer.isPremium
        
        var myBoostCount: Int32 = 0
        var currentMyBoostCount: Int32 = 0
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
                
        let initialState = BoostState(level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), boosts: Int32(status.boosts))
        let updatedState = Promise<BoostState?>()
        updatedState.set(.single(BoostState(level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), boosts: Int32(status.boosts + 1))))
        
        var updateImpl: (() -> Void)?
        var dismissImpl: (() -> Void)?
        
        let (initialSubject, initialCount) = initialState.displayData(peer: peer, isCurrent: isCurrent, myBoostCount: myBoostCount, currentMyBoostCount: 0, replacedBoosts: replacedBoosts?.0)
        let controller = PremiumLimitScreen(context: context, subject: initialSubject, count: initialCount, forceDark: forceDark, action: {
            let dismiss = false
            updateImpl?()
            return dismiss
        },
        openPeer: { peer in
            openPeer(peer)
        })
        pushController(controller)
                
        if let (replacedBoosts, inChannels) = replacedBoosts {
            currentMyBoostCount += 1
            let (subject, count) = initialState.displayData(peer: peer, isCurrent: isCurrent, myBoostCount: myBoostCount, currentMyBoostCount: 1, replacedBoosts: nil)
            controller.updateSubject(subject, count: count)
            
            Queue.mainQueue().after(0.3) {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let undoController = UndoOverlayController(presentationData: presentationData, content: .image(image: generateTintedImage(image: UIImage(bundleImageName: "Premium/BoostReplaceIcon"), color: .white)!, title: nil, text: "\(replacedBoosts) boosts are reassigned from \(inChannels) other channel.", round: false, undoText: nil), elevatedLayout: false, position: .bottom, action: { _ in return true })
                controller.present(undoController, in: .current)
            }
        }
        
        controller.disposed = {
            dismissed()
        }
        
        var updating = false
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        updateImpl = { [weak controller] in
            guard !updating else {
                return
            }
            if let _ = status.nextLevelBoosts {
                if let availableBoost = availableBoosts.first {
                    currentMyBoostCount += 1
                    myBoostCount += 1
                    
                    updating = true
                    let _ = (context.engine.peers.applyChannelBoost(peerId: peerId, slots: [availableBoost.slot])
                    |> deliverOnMainQueue).startStandalone(completed: {
                        updating = false

                        updatedState.set(context.engine.peers.getChannelBoostStatus(peerId: peerId)
                        |> map { status in
                            if let status {
                                return BoostState(level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), boosts: Int32(status.boosts + 1))
                            } else {
                                return nil
                            }
                        })
                    })
                   
                    let _ = (updatedState.get()
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { state in
                        guard let state else {
                            return
                        }
                        let (subject, count) = state.displayData(peer: peer, isCurrent: isCurrent, myBoostCount: myBoostCount, currentMyBoostCount: currentMyBoostCount)
                        controller?.updateSubject(subject, count: count)
                    })
                    
                    availableBoosts.removeFirst()
                } else if !occupiedBoosts.isEmpty, let myBoostStatus {
                    var dismissReplaceImpl: (() -> Void)?
                    let replaceController = ReplaceBoostScreen(context: context, peerId: peerId, myBoostStatus: myBoostStatus, replaceBoosts: { slots in
                        var channelIds = Set<EnginePeer.Id>()
                        for boost in myBoostStatus.boosts {
                            if slots.contains(boost.slot) {
                                if let peer = boost.peer {
                                    channelIds.insert(peer.id)
                                }
                            }
                        }
                        
                        let _ = context.engine.peers.applyChannelBoost(peerId: peerId, slots: slots).startStandalone(completed: {
                            let _ = combineLatest(queue: Queue.mainQueue(),
                                context.engine.peers.getChannelBoostStatus(peerId: peerId),
                                context.engine.peers.getMyBoostStatus()
                            ).startStandalone(next: { boostStatus, myBoostStatus in
                                dismissReplaceImpl?()
                                PremiumBoostScreen(context: context, contentContext: contentContext, peerId: peerId, isCurrent: isCurrent, status: boostStatus, myBoostStatus: myBoostStatus, replacedBoosts: (Int32(slots.count), Int32(channelIds.count)), forceDark: forceDark, openPeer: openPeer, presentController: presentController, pushController: pushController, dismissed: dismissed)
                            })
                        })
                    })
                    dismissImpl?()
                    pushController(replaceController)
                    dismissReplaceImpl = { [weak replaceController] in
                        replaceController?.dismiss(animated: true)
                    }
                } else {
                    if isPremium {
                        let controller = textAlertController(
                            sharedContext: context.sharedContext,
                            updatedPresentationData: nil,
                            title: "More Boosts Needed",
                            text: "To boost **\(peer.compactDisplayTitle)**, get more boosts by gifting **Telegram Premium** to a friend.",
                            actions: [
                                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                            ],
                            parseMarkdown: true
                        )
                        presentController(controller)
                    } else {
                        let controller = textAlertController(
                            sharedContext: context.sharedContext,
                            updatedPresentationData: nil,
                            title: presentationData.strings.ChannelBoost_Error_PremiumNeededTitle,
                            text: presentationData.strings.ChannelBoost_Error_PremiumNeededText,
                            actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
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
