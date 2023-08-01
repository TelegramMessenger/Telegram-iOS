import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import Postbox
import AvatarNode

public extension StoryContainerScreen {
    static func openArchivedStories(context: AccountContext, parentController: ViewController, avatarNode: AvatarNode) {
        let storyContent = StoryContentContextImpl(context: context, isHidden: true, focusedPeerId: nil, singlePeer: false)
        let signal = storyContent.state
        |> take(1)
        |> mapToSignal { state -> Signal<Void, NoError> in
            if let slice = state.slice {
                return waitUntilStoryMediaPreloaded(context: context, peerId: slice.peer.id, storyItem: slice.item.storyItem)
                |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                |> map { _ -> Void in
                }
                |> then(.single(Void()))
            } else {
                return .single(Void())
            }
        }
        |> deliverOnMainQueue
        |> map { [weak parentController, weak avatarNode] _ -> Void in
            var transitionIn: StoryContainerScreen.TransitionIn?
            if let avatarNode {
                transitionIn = StoryContainerScreen.TransitionIn(
                    sourceView: avatarNode.view,
                    sourceRect: avatarNode.view.bounds,
                    sourceCornerRadius: avatarNode.view.bounds.width * 0.5,
                    sourceIsAvatar: false
                )
                avatarNode.isHidden = true
            }
            
            let storyContainerScreen = StoryContainerScreen(
                context: context,
                content: storyContent,
                transitionIn: transitionIn,
                transitionOut: { peerId, _ in
                    if let avatarNode {
                        let destinationView = avatarNode.view
                        return StoryContainerScreen.TransitionOut(
                            destinationView: destinationView,
                            transitionView: StoryContainerScreen.TransitionView(
                                makeView: { [weak destinationView] in
                                    let parentView = UIView()
                                    if let copyView = destinationView?.snapshotContentTree(unhide: true) {
                                        parentView.addSubview(copyView)
                                    }
                                    return parentView
                                },
                                updateView: { copyView, state, transition in
                                    guard let view = copyView.subviews.first else {
                                        return
                                    }
                                    let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                    transition.setPosition(view: view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                                    transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                },
                                insertCloneTransitionView: nil
                            ),
                            destinationRect: destinationView.bounds,
                            destinationCornerRadius: destinationView.bounds.width * 0.5,
                            destinationIsAvatar: false,
                            completed: { [weak avatarNode] in
                                guard let avatarNode else {
                                    return
                                }
                                avatarNode.isHidden = false
                            }
                        )
                    } else {
                        return nil
                    }
                }
            )
            parentController?.push(storyContainerScreen)
        }
        |> ignoreValues
        
        let _ = avatarNode.pushLoadingStatus(signal: signal)
    }
    
    static func openPeerStories(context: AccountContext, peerId: EnginePeer.Id, parentController: ViewController, avatarNode: AvatarNode?, sharedProgressDisposable: MetaDisposable? = nil) {
        return openPeerStoriesCustom(
            context: context,
            peerId: peerId,
            isHidden: false,
            singlePeer: true,
            parentController: parentController,
            transitionIn: { [weak avatarNode] in
                if let avatarNode {
                    let transitionIn = StoryContainerScreen.TransitionIn(
                        sourceView: avatarNode.view,
                        sourceRect: avatarNode.view.bounds,
                        sourceCornerRadius: avatarNode.view.bounds.width * 0.5,
                        sourceIsAvatar: false
                    )
                    avatarNode.isHidden = true
                    return transitionIn
                } else {
                    return nil
                }
            },
            transitionOut: { [weak avatarNode] _ in
                if let avatarNode {
                    let destinationView = avatarNode.view
                    return StoryContainerScreen.TransitionOut(
                        destinationView: destinationView,
                        transitionView: StoryContainerScreen.TransitionView(
                            makeView: { [weak destinationView] in
                                let parentView = UIView()
                                if let copyView = destinationView?.snapshotContentTree(unhide: true) {
                                    parentView.addSubview(copyView)
                                }
                                return parentView
                            },
                            updateView: { copyView, state, transition in
                                guard let view = copyView.subviews.first else {
                                    return
                                }
                                let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                transition.setPosition(view: view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                                transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                            },
                            insertCloneTransitionView: nil
                        ),
                        destinationRect: destinationView.bounds,
                        destinationCornerRadius: destinationView.bounds.width * 0.5,
                        destinationIsAvatar: false,
                        completed: { [weak avatarNode] in
                            guard let avatarNode else {
                                return
                            }
                            avatarNode.isHidden = false
                        }
                    )
                } else {
                    return nil
                }
            },
            setFocusedItem: { _ in
            },
            setProgress: { [weak avatarNode] signal in
                guard let avatarNode else {
                    return
                }
                let disposable = avatarNode.pushLoadingStatus(signal: signal)
                if let sharedProgressDisposable {
                    sharedProgressDisposable.set(disposable)
                }
            }
        )
    }
    
    static func openPeerStoriesCustom(
        context: AccountContext,
        peerId: EnginePeer.Id,
        isHidden: Bool,
        initialOrder: [EnginePeer.Id] = [],
        singlePeer: Bool,
        parentController: ViewController,
        transitionIn: @escaping () -> StoryContainerScreen.TransitionIn?,
        transitionOut: @escaping (EnginePeer.Id) -> StoryContainerScreen.TransitionOut?,
        setFocusedItem: @escaping (Signal<StoryId?, NoError>) -> Void,
        setProgress: @escaping (Signal<Never, NoError>) -> Void
    ) {
        let storyContent = StoryContentContextImpl(context: context, isHidden: isHidden, focusedPeerId: peerId, singlePeer: singlePeer, fixedOrder: initialOrder)
        let signal = storyContent.state
        |> take(1)
        |> mapToSignal { state -> Signal<StoryContentContextState, NoError> in
            if let slice = state.slice {
                #if DEBUG && false
                if "".isEmpty {
                    return .single(state)
                    |> delay(4.0, queue: .mainQueue())
                }
                #endif
                
                return waitUntilStoryMediaPreloaded(context: context, peerId: slice.peer.id, storyItem: slice.item.storyItem)
                |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                |> map { _ -> StoryContentContextState in
                }
                |> then(.single(state))
            } else {
                return .single(state)
            }
        }
        |> deliverOnMainQueue
        |> map { [weak parentController] state -> Void in
            if state.slice == nil {
                return
            }
            
            let transitionIn: StoryContainerScreen.TransitionIn? = transitionIn()
            
            let storyContainerScreen = StoryContainerScreen(
                context: context,
                content: storyContent,
                transitionIn: transitionIn,
                transitionOut: { peerId, _ in
                    return transitionOut(peerId)
                }
            )
            setFocusedItem(storyContainerScreen.focusedItem)
            parentController?.push(storyContainerScreen)
        }
        |> ignoreValues
        
        setProgress(signal)
    }
}
