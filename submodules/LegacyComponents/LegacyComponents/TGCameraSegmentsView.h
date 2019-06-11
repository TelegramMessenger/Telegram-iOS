#import <UIKit/UIKit.h>

@interface TGCameraSegmentsView : UIView

@property (nonatomic, copy) void (^deletePressed)(void);

- (void)setSegments:(NSArray *)segments;

- (void)startCurrentSegment;
- (void)setCurrentSegment:(CGFloat)length;
- (void)commitCurrentSegmentWithCompletion:(void (^)(void))completion;

- (void)highlightLastSegment;
- (void)removeLastSegment;

- (void)setHidden:(bool)hidden animated:(bool)animated delay:(NSTimeInterval)delay;

- (void)setDeleteButtonHidden:(bool)hidden animated:(bool)animated;

@end
