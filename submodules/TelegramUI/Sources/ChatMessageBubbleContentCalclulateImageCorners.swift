import Foundation
import UIKit
import Display
import TelegramPresentationData

func chatMessageBubbleImageContentCorners(relativeContentPosition position: ChatMessageBubbleContentPosition, normalRadius: CGFloat, mergedRadius: CGFloat, mergedWithAnotherContentRadius: CGFloat, layoutConstants: ChatMessageItemLayoutConstants, chatPresentationData: ChatPresentationData) -> ImageCorners {
    let topLeftCorner: ImageCorner
    let topRightCorner: ImageCorner
    
    switch position {
        case let .linear(top, _):
            switch top {
                case .Neighbour:
                    topLeftCorner = .Corner(mergedWithAnotherContentRadius)
                    topRightCorner = .Corner(mergedWithAnotherContentRadius)
                case .BubbleNeighbour:
                    topLeftCorner = .Corner(mergedRadius)
                    topRightCorner = .Corner(mergedRadius)
                case let .None(mergeStatus):
                    switch mergeStatus {
                        case .Left:
                            topLeftCorner = .Corner(mergedRadius)
                            topRightCorner = .Corner(normalRadius)
                        case .None:
                            topLeftCorner = .Corner(normalRadius)
                            topRightCorner = .Corner(normalRadius)
                        case .Right:
                            topLeftCorner = .Corner(normalRadius)
                            topRightCorner = .Corner(mergedRadius)
                        case .Both:
                            topLeftCorner = .Corner(mergedRadius)
                            topRightCorner = .Corner(mergedRadius)
                    }
            }
        case let .mosaic(position, _):
            switch position.topLeft {
                case .none:
                    topLeftCorner = .Corner(normalRadius)
                case .merged:
                    topLeftCorner = .Corner(mergedWithAnotherContentRadius)
                case .mergedBubble:
                    topLeftCorner = .Corner(mergedRadius)
            }
            switch position.topRight {
                case .none:
                    topRightCorner = .Corner(normalRadius)
                case .merged:
                    topRightCorner = .Corner(mergedWithAnotherContentRadius)
                case .mergedBubble:
                    topRightCorner = .Corner(mergedRadius)
            }
    }
    
    let bottomLeftCorner: ImageCorner
    let bottomRightCorner: ImageCorner
    
    switch position {
        case let .linear(_, bottom):
            switch bottom {
                case .Neighbour:
                    bottomLeftCorner = .Corner(mergedWithAnotherContentRadius)
                    bottomRightCorner = .Corner(mergedWithAnotherContentRadius)
                case .BubbleNeighbour:
                    bottomLeftCorner = .Corner(mergedRadius)
                    bottomRightCorner = .Corner(mergedRadius)
                case let .None(mergeStatus):
                    switch mergeStatus {
                        case .Left:
                            bottomLeftCorner = .Corner(mergedRadius)
                            bottomRightCorner = .Corner(normalRadius)
                        case .Both:
                            bottomLeftCorner = .Corner(mergedRadius)
                            bottomRightCorner = .Corner(mergedRadius)
                        case let .None(status):
                            let bubbleInsets: UIEdgeInsets
                            if case .color = chatPresentationData.theme.wallpaper {
                                let colors: PresentationThemeBubbleColorComponents
                                switch status {
                                case .Incoming:
                                    colors = chatPresentationData.theme.theme.chat.message.incoming.bubble.withoutWallpaper
                                case .Outgoing:
                                    colors = chatPresentationData.theme.theme.chat.message.outgoing.bubble.withoutWallpaper
                                case .None:
                                    colors = chatPresentationData.theme.theme.chat.message.incoming.bubble.withoutWallpaper
                                }
                                if colors.fill[0] == colors.stroke || colors.stroke.alpha.isZero {
                                    bubbleInsets = UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
                                } else {
                                    bubbleInsets = layoutConstants.bubble.strokeInsets
                                }
                            } else {
                                bubbleInsets = layoutConstants.image.bubbleInsets
                            }
                            
                            switch status {
                                case .Incoming:
                                    bottomLeftCorner = .Tail(normalRadius, PresentationResourcesChat.chatBubbleMediaCorner(chatPresentationData.theme.theme, incoming: true, mainRadius: normalRadius, inset: max(0.0, bubbleInsets.left - 1.0))!)
                                    bottomRightCorner = .Corner(normalRadius)
                                case .Outgoing:
                                    bottomLeftCorner = .Corner(normalRadius)
                                    bottomRightCorner = .Tail(normalRadius, PresentationResourcesChat.chatBubbleMediaCorner(chatPresentationData.theme.theme, incoming: false, mainRadius: normalRadius, inset: max(0.0, bubbleInsets.right - 1.0))!)
                                case .None:
                                    bottomLeftCorner = .Corner(normalRadius)
                                    bottomRightCorner = .Corner(normalRadius)
                            }
                        case .Right:
                            bottomLeftCorner = .Corner(normalRadius)
                            bottomRightCorner = .Corner(mergedRadius)
                    }
            }
        case let .mosaic(position, _):
            switch position.bottomLeft {
                case let .none(tail):
                    if tail {
                        let bubbleInsets: UIEdgeInsets
                        if case .color = chatPresentationData.theme.wallpaper {
                            let colors: PresentationThemeBubbleColorComponents
                            colors = chatPresentationData.theme.theme.chat.message.incoming.bubble.withoutWallpaper
                            if colors.fill[0] == colors.stroke || colors.stroke.alpha.isZero {
                                bubbleInsets = UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
                            } else {
                                bubbleInsets = layoutConstants.bubble.strokeInsets
                            }
                        } else {
                            bubbleInsets = layoutConstants.image.bubbleInsets
                        }
                        
                        bottomLeftCorner = .Tail(normalRadius, PresentationResourcesChat.chatBubbleMediaCorner(chatPresentationData.theme.theme, incoming: true, mainRadius: normalRadius, inset: max(0.0, bubbleInsets.left - 1.0))!)
                    } else {
                        bottomLeftCorner = .Corner(normalRadius)
                    }
                case .merged:
                    bottomLeftCorner = .Corner(mergedWithAnotherContentRadius)
                case .mergedBubble:
                    bottomLeftCorner = .Corner(mergedRadius)
            }
            switch position.bottomRight {
                case let .none(tail):
                    if tail {
                        let bubbleInsets: UIEdgeInsets
                        if case .color = chatPresentationData.theme.wallpaper {
                            let colors: PresentationThemeBubbleColorComponents
                            colors = chatPresentationData.theme.theme.chat.message.outgoing.bubble.withoutWallpaper
                            if colors.fill[0] == colors.stroke || colors.stroke.alpha.isZero {
                                bubbleInsets = UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
                            } else {
                                bubbleInsets = layoutConstants.bubble.strokeInsets
                            }
                        } else {
                            bubbleInsets = layoutConstants.image.bubbleInsets
                        }
                        bottomRightCorner = .Tail(normalRadius, PresentationResourcesChat.chatBubbleMediaCorner(chatPresentationData.theme.theme, incoming: false, mainRadius: normalRadius, inset: max(0.0, bubbleInsets.right - 1.0))!)
                    } else {
                        bottomRightCorner = .Corner(normalRadius)
                    }
                case .merged:
                    bottomRightCorner = .Corner(mergedWithAnotherContentRadius)
                case .mergedBubble:
                    bottomRightCorner = .Corner(mergedRadius)
            }
    }
    
    return ImageCorners(topLeft: topLeftCorner, topRight: topRightCorner, bottomLeft: bottomLeftCorner, bottomRight: bottomRightCorner)
}
