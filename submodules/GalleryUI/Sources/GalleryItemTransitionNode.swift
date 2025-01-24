import Foundation
import UIKit
import AccountContext
import Display

public final class GalleryItemScrubberTransition {
    public struct TransitionState: Equatable {
        public var sourceSize: CGSize
        public var destinationSize: CGSize
        public var progress: CGFloat
        
        public init(
            sourceSize: CGSize,
            destinationSize: CGSize,
            progress: CGFloat
        ) {
            self.sourceSize = sourceSize
            self.destinationSize = destinationSize
            self.progress = progress
        }
    }
    
    public let view: UIView
    public let makeView: () -> UIView
    public let updateView: (UIView, TransitionState, ContainedViewLayoutTransition) -> Void
    public let insertCloneTransitionView: ((UIView) -> Void)?
    
    public init(view: UIView, makeView: @escaping () -> UIView, updateView: @escaping (UIView, TransitionState, ContainedViewLayoutTransition) -> Void, insertCloneTransitionView: ((UIView) -> Void)?) {
        self.view = view
        self.makeView = makeView
        self.updateView = updateView
        self.insertCloneTransitionView = insertCloneTransitionView
    }
}

public protocol GalleryItemTransitionNode: AnyObject {
    func isAvailableForGalleryTransition() -> Bool
    func isAvailableForInstantPageTransition() -> Bool
    var decoration: UniversalVideoDecoration? { get }
    
    func scrubberTransition() -> GalleryItemScrubberTransition?
}
