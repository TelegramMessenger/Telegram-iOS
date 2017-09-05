import Foundation
import AsyncDisplayKit

protocol InstantPageNode {
    func updateIsVisible(_ isVisible: Bool)
    
    func transitionNode(media: InstantPageMedia) -> ASDisplayNode?
    func updateHiddenMedia(media: InstantPageMedia?)
    func update(strings: PresentationStrings, theme: InstantPageTheme)
}

/*@class TGInstantPageMedia;

@protocol TGInstantPageDisplayView <NSObject>

- (void)setIsVisible:(bool)isVisible;

@optional

- (void)setOpenMedia:(void (^)(id))openMedia;
- (void)setOpenFeedback:(void (^)())openFeedback;
- (UIView *)transitionViewForMedia:(TGInstantPageMedia *)media;
- (void)updateHiddenMedia:(TGInstantPageMedia *)media;

@end*/
