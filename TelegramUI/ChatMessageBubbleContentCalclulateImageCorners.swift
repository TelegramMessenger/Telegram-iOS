import UIKit

func chatMessageBubbleImageContentCorners(relativeContentPosition position: ChatMessageBubbleContentPosition, normalRadius: CGFloat, mergedRadius: CGFloat, mergedWithAnotherContentRadius: CGFloat) -> ImageCorners {
    let topLeftCorner: ImageCorner
    let topRightCorner: ImageCorner
    
    switch position {
        case let .linear(top, _):
            switch top {
                case .Neighbour:
                    topLeftCorner = .Corner(mergedWithAnotherContentRadius)
                    topRightCorner = .Corner(mergedWithAnotherContentRadius)
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
                    }
            }
        case let .mosaic(position, _):
            switch position.topLeft {
                case .none:
                    topLeftCorner = .Corner(normalRadius)
                case .merged:
                    topLeftCorner = .Corner(mergedWithAnotherContentRadius)
            }
            switch position.topRight {
                case .none:
                    topRightCorner = .Corner(normalRadius)
                case .merged:
                    topRightCorner = .Corner(mergedWithAnotherContentRadius)
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
                case let .None(mergeStatus):
                    switch mergeStatus {
                        case .Left:
                            bottomLeftCorner = .Corner(mergedRadius)
                            bottomRightCorner = .Corner(normalRadius)
                        case let .None(status):
                            switch status {
                                case .Incoming:
                                    bottomLeftCorner = .Tail(normalRadius, true)
                                    bottomRightCorner = .Corner(normalRadius)
                                case .Outgoing:
                                    bottomLeftCorner = .Corner(normalRadius)
                                    bottomRightCorner = .Tail(normalRadius, true)
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
                        bottomLeftCorner = .Tail(normalRadius, true)
                    } else {
                        bottomLeftCorner = .Corner(normalRadius)
                    }
                case .merged:
                    bottomLeftCorner = .Corner(mergedWithAnotherContentRadius)
                }
            switch position.bottomRight {
                case let .none(tail):
                    if tail {
                        bottomRightCorner = .Tail(normalRadius, true)
                    } else {
                        bottomRightCorner = .Corner(normalRadius)
                    }
                case .merged:
                    bottomRightCorner = .Corner(mergedWithAnotherContentRadius)
            }
    }
    
    return ImageCorners(topLeft: topLeftCorner, topRight: topRightCorner, bottomLeft: bottomLeftCorner, bottomRight: bottomRightCorner)
}
