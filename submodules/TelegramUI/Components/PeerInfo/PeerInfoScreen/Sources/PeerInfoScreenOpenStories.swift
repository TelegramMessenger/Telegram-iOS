import Foundation
import UIKit
import Display
import AccountContext
import StoryContainerScreen
import SwiftSignalKit

extension PeerInfoScreenNode {
    func openStories(fromAvatar: Bool) {
        guard let controller = self.controller else {
            return
        }
        if let expiringStoryList = self.expiringStoryList, let expiringStoryListState = self.expiringStoryListState, !expiringStoryListState.items.isEmpty {
            if fromAvatar {
                StoryContainerScreen.openPeerStories(context: self.context, peerId: self.peerId, parentController: controller, avatarNode: self.headerNode.avatarListNode.avatarContainerNode.avatarNode)
                return
            }
            
            let _ = expiringStoryList
            let storyContent = StoryContentContextImpl(context: self.context, isHidden: false, focusedPeerId: self.peerId, singlePeer: true)
            let _ = (storyContent.state
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] storyContentState in
                guard let self else {
                    return
                }
                var transitionIn: StoryContainerScreen.TransitionIn?
                
                if fromAvatar {
                    let transitionView = self.headerNode.avatarListNode.avatarContainerNode.avatarNode.view
                    transitionIn = StoryContainerScreen.TransitionIn(
                        sourceView: transitionView,
                        sourceRect: transitionView.bounds,
                        sourceCornerRadius: transitionView.bounds.height * 0.5,
                        sourceIsAvatar: true
                    )
                    self.headerNode.avatarListNode.avatarContainerNode.avatarNode.isHidden = true
                } else if let (expandedStorySetIndicatorTransitionView, subRect) = self.headerNode.avatarListNode.listContainerNode.expandedStorySetIndicatorTransitionView {
                    transitionIn = StoryContainerScreen.TransitionIn(
                        sourceView: expandedStorySetIndicatorTransitionView,
                        sourceRect: subRect,
                        sourceCornerRadius: expandedStorySetIndicatorTransitionView.bounds.height * 0.5,
                        sourceIsAvatar: false
                    )
                    expandedStorySetIndicatorTransitionView.isHidden = true
                }
                
                let storyContainerScreen = StoryContainerScreen(
                    context: self.context,
                    content: storyContent,
                    transitionIn: transitionIn,
                    transitionOut: { [weak self] peerId, _ in
                        guard let self else {
                            return nil
                        }
                        if !fromAvatar {
                            self.headerNode.avatarListNode.avatarContainerNode.avatarNode.isHidden = false
                            
                            if let (expandedStorySetIndicatorTransitionView, subRect) = self.headerNode.avatarListNode.listContainerNode.expandedStorySetIndicatorTransitionView {
                                return StoryContainerScreen.TransitionOut(
                                    destinationView: expandedStorySetIndicatorTransitionView,
                                    transitionView: StoryContainerScreen.TransitionView(
                                        makeView: { [weak expandedStorySetIndicatorTransitionView] in
                                            let parentView = UIView()
                                            if let copyView = expandedStorySetIndicatorTransitionView?.snapshotContentTree(unhide: true) {
                                                copyView.layer.anchorPoint = CGPoint()
                                                parentView.addSubview(copyView)
                                            }
                                            return parentView
                                        },
                                        updateView: { copyView, state, transition in
                                            guard let view = copyView.subviews.first else {
                                                return
                                            }
                                            let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                            transition.setPosition(view: view, position: CGPoint(x: 0.0, y: 0.0))
                                            transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                        },
                                        insertCloneTransitionView: nil
                                    ),
                                    destinationRect: subRect,
                                    destinationCornerRadius: expandedStorySetIndicatorTransitionView.bounds.height * 0.5,
                                    destinationIsAvatar: false,
                                    completed: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        
                                        if let (expandedStorySetIndicatorTransitionView, _) = self.headerNode.avatarListNode.listContainerNode.expandedStorySetIndicatorTransitionView {
                                            expandedStorySetIndicatorTransitionView.isHidden = false
                                        }
                                    }
                                )
                            }
                            
                            return nil
                        }
                        
                        let transitionView = self.headerNode.avatarListNode.avatarContainerNode.avatarNode.view
                        return StoryContainerScreen.TransitionOut(
                            destinationView: transitionView,
                            transitionView: StoryContainerScreen.TransitionView(
                                makeView: { [weak transitionView] in
                                    let parentView = UIView()
                                    if let copyView = transitionView?.snapshotContentTree(unhide: true) {
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
                            destinationRect: transitionView.bounds,
                            destinationCornerRadius: transitionView.bounds.height * 0.5,
                            destinationIsAvatar: true,
                            completed: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.headerNode.avatarListNode.avatarContainerNode.avatarNode.isHidden = false
                            }
                        )
                    }
                )
                self.controller?.push(storyContainerScreen)
            })
            
            return
        }
    }
}
