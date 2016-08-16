
func chatMessageBubbleImageContentCorners(relativeContentPosition position: ChatMessageBubbleContentPosition, normalRadius: CGFloat, mergedRadius: CGFloat, mergedWithAnotherContentRadius: CGFloat) -> ImageCorners {
    let topLeftCorner: ImageCorner
    let topRightCorner: ImageCorner
    
    switch position.top {
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
    
    let bottomLeftCorner: ImageCorner
    let bottomRightCorner: ImageCorner
    
    switch position.bottom {
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
                            bottomLeftCorner = .Tail(normalRadius)
                            bottomRightCorner = .Corner(normalRadius)
                        case .Outgoing:
                            bottomLeftCorner = .Corner(normalRadius)
                            bottomRightCorner = .Tail(normalRadius)
                    }
                case .Right:
                    bottomLeftCorner = .Corner(normalRadius)
                    bottomRightCorner = .Corner(mergedRadius)
            }
    }
    
    return ImageCorners(topLeft: topLeftCorner, topRight: topRightCorner, bottomLeft: bottomLeftCorner, bottomRight: bottomRightCorner)
}
