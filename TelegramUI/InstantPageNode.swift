import Foundation
import AsyncDisplayKit

protocol InstantPageNode {
    func updateIsVisible(_ isVisible: Bool)
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
