import Foundation
import UIKit
import AccountContext
import Display

public final class GalleryItemScrubberTransition {
    public final class Scrubber {
        public struct TransitionState: Equatable {
            public enum Direction {
                case `in`
                case out
            }
            
            public var sourceSize: CGSize
            public var destinationSize: CGSize
            public var progress: CGFloat
            public var direction: Direction
            
            public init(
                sourceSize: CGSize,
                destinationSize: CGSize,
                progress: CGFloat,
                direction: Direction
            ) {
                self.sourceSize = sourceSize
                self.destinationSize = destinationSize
                self.progress = progress
                self.direction = direction
            }
        }
        
        public let view: UIView
        public let makeView: () -> UIView
        public let updateView: (UIView, TransitionState, ContainedViewLayoutTransition) -> Void
        
        public init(view: UIView, makeView: @escaping () -> UIView, updateView: @escaping (UIView, TransitionState, ContainedViewLayoutTransition) -> Void) {
            self.view = view
            self.makeView = makeView
            self.updateView = updateView
        }
    }
    
    public final class Content {
        public struct TransitionState: Equatable {
            public var sourceSize: CGSize
            public var destinationSize: CGSize
            public var destinationCornerRadius: CGFloat
            public var progress: CGFloat
            
            public init(
                sourceSize: CGSize,
                destinationSize: CGSize,
                destinationCornerRadius: CGFloat,
                progress: CGFloat
            ) {
                self.sourceSize = sourceSize
                self.destinationSize = destinationSize
                self.destinationCornerRadius = destinationCornerRadius
                self.progress = progress
            }
        }
        
        public let sourceView: UIView
        public let sourceRect: CGRect
        public let makeView: () -> UIView
        public let updateView: (UIView, TransitionState, ContainedViewLayoutTransition) -> Void
        
        public init(sourceView: UIView, sourceRect: CGRect, makeView: @escaping () -> UIView, updateView: @escaping (UIView, TransitionState, ContainedViewLayoutTransition) -> Void) {
            self.sourceView = sourceView
            self.sourceRect = sourceRect
            self.makeView = makeView
            self.updateView = updateView
        }
    }
    
    public let scrubber: Scrubber?
    public let content: Content?
    
    public init(scrubber: Scrubber?, content: Content?) {
        self.scrubber = scrubber
        self.content = content
    }
}

public protocol GalleryItemTransitionNode: AnyObject {
    func isAvailableForGalleryTransition() -> Bool
    func isAvailableForInstantPageTransition() -> Bool
    var decoration: UniversalVideoDecoration? { get }
    
    func scrubberTransition() -> GalleryItemScrubberTransition?
}
